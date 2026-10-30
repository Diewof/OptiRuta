-- Correcciones de la auditoria 2026-10-13 (Documentacion/Auditoria-procesos-2026-10-13.md),
-- hallazgos 1, 2, 4, 5, 6, 7, 8, 9, 11, 12 y 13. Todo en una migracion nueva:
-- no se edita ninguna ya mergeada.
--
-- Decisiones del dueño (2026-10-13):
--   * #5  Los ajustes de un viaje cerrado son numericos (flete o costo por categoria)
--         y SI afectan rentabilidad, metricas y reporte.
--   * #2  Se restringen las lecturas por RLS; el registro publico no se toca.
--   * #11 Conductor inactivo o con licencia vencida no puede comenzar un viaje, y la
--         licencia genera alertas de vencimiento. Crear/asignar no se bloquea.
--   * #7  Cancelar vence la encuesta; eliminar un viaje borra la encuesta sin responder.

-- ---------------------------------------------------------------------------
-- Ayudantes
-- ---------------------------------------------------------------------------
create or replace function public.es_conductor_activo()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.conductor c
      join public.usuario u on u.id = c.usuario_id
     where c.usuario_id = (select auth.uid()) and c.activo and u.activo
  );
$$;

revoke all on function public.es_conductor_activo() from public, anon;
grant execute on function public.es_conductor_activo() to authenticated;

-- Lanza OR149 si el conductor no esta habilitado para salir (inactivo o licencia vencida).
create or replace function public.conductor_validar_habilitado(p_conductor_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_activo   boolean;
  v_licencia date;
begin
  select c.activo and u.activo, c.fecha_vencimiento_licencia
    into v_activo, v_licencia
    from public.conductor c
    join public.usuario u on u.id = c.usuario_id
   where c.id = p_conductor_id;

  if not found or not v_activo then
    raise exception 'Tu cuenta de conductor esta inactiva. Contacta al administrador.'
      using errcode = 'OR149';
  end if;

  if v_licencia < public.hoy_bogota() then
    raise exception 'No se puede comenzar el viaje: la licencia de conduccion vencio el %.',
      to_char(v_licencia, 'DD/MM/YYYY')
      using errcode = 'OR149';
  end if;
end;
$$;

revoke all on function public.conductor_validar_habilitado(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- #1 viaje_cambiar_estado ya no es un atajo para saltarse las reglas de salida
--
-- EN_CURSO solo por viaje_iniciar (documentos, checklist, 500 m, hito SALIDA),
-- CERRADO solo por viaje_cerrar (sella fecha_cierre) y CANCELADO solo por
-- viaje_cancelar (motivo). El conductor finaliza con el hito LLEGADA_DESTINO.
-- El administrador conserva FINALIZADO manual para rescatar un viaje atascado.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_cambiar_estado(p_viaje_id uuid, p_nuevo_estado text)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rol           text := (auth.jwt() -> 'app_metadata' ->> 'rol');
  v_estado_actual text;
  v_viaje         public.viaje;
begin
  select v.estado
    into v_estado_actual
    from public.viaje v
   where v.id = p_viaje_id
   for update;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_rol is distinct from 'ADMINISTRADOR' then
    raise exception 'No autorizado para cambiar el estado de este viaje.'
      using errcode = 'OR105';
  end if;

  if p_nuevo_estado in ('EN_CURSO', 'CERRADO', 'CANCELADO') then
    raise exception 'Este estado no se asigna aqui: use comenzar, cerrar o cancelar el viaje.'
      using errcode = 'OR145';
  end if;

  if p_nuevo_estado = 'FINALIZADO' and v_estado_actual = 'EN_CURSO' then
    perform public.viaje_fijar_km(p_viaje_id);
  end if;

  update public.viaje
     set estado = p_nuevo_estado
   where id = p_viaje_id
   returning * into v_viaje;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_cambiar_estado(uuid, text) from public;
grant execute on function public.viaje_cambiar_estado(uuid, text) to authenticated;

-- Un viaje CERRADO siempre tiene fecha_cierre (y al reves). NOT VALID: no
-- revisa filas antiguas, solo las nuevas.
alter table public.viaje
  add constraint viaje_cierre_fecha_ck
  check ((estado = 'CERRADO') = (fecha_cierre is not null)) not valid;

-- ---------------------------------------------------------------------------
-- #2 Lecturas por RLS: un usuario autenticado cualquiera ya no lee clientes,
-- flota ni documentos. Conductor: solo lo de sus propios viajes.
-- ---------------------------------------------------------------------------
drop policy vehiculo_select_autenticado on public.vehiculo;
create policy vehiculo_select_admin_o_propio
  on public.vehiculo
  for select
  to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR'
    or exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.vehiculo_id = vehiculo.id
        and c.usuario_id = (select auth.uid())
    )
  );

drop policy cliente_select_autenticado on public.cliente;
create policy cliente_select_admin_o_propio
  on public.cliente
  for select
  to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR'
    or exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.cliente_id = cliente.id
        and c.usuario_id = (select auth.uid())
    )
  );

-- Los documentos solo los consulta el administrador (el conductor ve el
-- bloqueo por el mensaje de viaje_iniciar).
drop policy documento_vehiculo_select_autenticado on public.documento_vehiculo;

-- Las tarifas las lee el administrador y los conductores activos (estimado de ACPM).
drop policy tarifa_combustible_select_autenticado on public.tarifa_combustible;
create policy tarifa_combustible_select_admin_o_conductor
  on public.tarifa_combustible
  for select
  to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR'
    or public.es_conductor_activo()
  );

-- ---------------------------------------------------------------------------
-- #9 El conductor no toca su propia comision y solo confirma costos de un
-- viaje en curso o finalizado.
-- ---------------------------------------------------------------------------
create or replace function public.costo_viaje_restringir_conductor()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    if new.categoria is distinct from old.categoria
       or new.valor_estimado is distinct from old.valor_estimado
       or new.fuente is distinct from old.fuente
       or new.viaje_id is distinct from old.viaje_id
    then
      raise exception 'El conductor solo puede actualizar el valor real del costo.'
        using errcode = 'OR115';
    end if;

    if old.categoria = 'COMISION' and new.valor_real is distinct from old.valor_real then
      raise exception 'La comision la confirma el administrador.'
        using errcode = 'OR115';
    end if;
  end if;
  return new;
end;
$$;

drop policy costo_viaje_conductor_actualiza_real on public.costo_viaje;
create policy costo_viaje_conductor_actualiza_real
  on public.costo_viaje
  for update
  to authenticated
  using (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = costo_viaje.viaje_id
        and v.estado in ('EN_CURSO', 'FINALIZADO')
        and c.usuario_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = costo_viaje.viaje_id
        and v.estado in ('EN_CURSO', 'FINALIZADO')
        and c.usuario_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- #5 Ajustes numericos de un viaje cerrado
--
-- concepto: 'FLETE' o una categoria de costo. monto: diferencia firmada
-- (valor nuevo - valor vigente) que se suma al valor del viaje. El valor
-- vigente = valor original + ajustes anteriores del mismo concepto.
-- ---------------------------------------------------------------------------
alter table public.ajuste_viaje
  add column concepto text,
  add column monto numeric,
  add constraint ajuste_viaje_concepto_ck check (concepto is null or concepto in (
    'FLETE', 'ACPM', 'PEAJE', 'CARGUE', 'DESCARGUE', 'PARQUEADERO', 'COMISION',
    'ACEITE', 'LAVADO', 'ENGRASE', 'OTRO'
  )),
  add constraint ajuste_viaje_monto_ck check ((concepto is null) = (monto is null));

comment on column public.ajuste_viaje.monto is
  'Diferencia firmada que el ajuste suma al flete (concepto FLETE) o al costo de la categoria. Nulo en ajustes solo informativos.';

-- Un INSERT directo no puede fabricar ajustes con efecto numerico: solo la RPC.
drop policy ajuste_viaje_insert_admin on public.ajuste_viaje;
create policy ajuste_viaje_insert_admin
  on public.ajuste_viaje
  for insert
  to authenticated
  with check (
    (auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR'
    and usuario_id = (select auth.uid())
    and concepto is null
    and monto is null
  );

create or replace function public.viaje_ajuste_total(p_viaje_id uuid, p_concepto text)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(a.monto), 0)
    from public.ajuste_viaje a
   where a.viaje_id = p_viaje_id and a.concepto = p_concepto;
$$;

revoke all on function public.viaje_ajuste_total(uuid, text) from public, anon, authenticated;

create or replace function public.viaje_flete_ajustado(p_viaje_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select v.valor_flete + public.viaje_ajuste_total(v.id, 'FLETE')
    from public.viaje v where v.id = p_viaje_id;
$$;

revoke all on function public.viaje_flete_ajustado(uuid) from public, anon, authenticated;

-- Costos directos del viaje (sin mantenimiento amortizado) mas sus ajustes de costo.
create or replace function public.viaje_costos_ajustados(p_viaje_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
           select sum(coalesce(cv.valor_real, cv.valor_estimado))
             from public.costo_viaje cv
            where cv.viaje_id = p_viaje_id and cv.categoria <> 'MANTENIMIENTO_AMORTIZADO'
         ), 0)
         + coalesce((
           select sum(a.monto)
             from public.ajuste_viaje a
            where a.viaje_id = p_viaje_id and a.concepto is not null and a.concepto <> 'FLETE'
         ), 0);
$$;

revoke all on function public.viaje_costos_ajustados(uuid) from public, anon, authenticated;

create or replace function public.viaje_registrar_ajuste_v2(
  p_viaje_id uuid,
  p_motivo text,
  p_concepto text,
  p_valor_nuevo numeric
)
returns public.ajuste_viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje    public.viaje;
  v_anterior numeric;
  v_etiqueta text;
  v_ajuste   public.ajuste_viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede registrar ajustes de viaje.' using errcode = 'OR105';
  end if;

  if btrim(coalesce(p_motivo, '')) = '' then
    raise exception 'El motivo del ajuste es obligatorio.' using errcode = 'OR106';
  end if;

  if p_concepto is null
     or p_concepto not in ('FLETE', 'ACPM', 'PEAJE', 'CARGUE', 'DESCARGUE', 'PARQUEADERO',
                           'COMISION', 'ACEITE', 'LAVADO', 'ENGRASE', 'OTRO')
     or p_valor_nuevo is null or p_valor_nuevo < 0 then
    raise exception 'El concepto o el valor del ajuste no es valido.' using errcode = 'OR148';
  end if;

  select * into v_viaje from public.viaje where id = p_viaje_id for update;
  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado <> 'CERRADO' then
    raise exception 'Solo se ajusta un viaje cerrado; los demas se editan directamente.'
      using errcode = 'OR147';
  end if;

  if p_concepto = 'FLETE' then
    v_anterior := v_viaje.valor_flete + public.viaje_ajuste_total(p_viaje_id, 'FLETE');
    v_etiqueta := 'Flete pactado';
  else
    v_anterior := coalesce((
                    select sum(coalesce(cv.valor_real, cv.valor_estimado))
                      from public.costo_viaje cv
                     where cv.viaje_id = p_viaje_id and cv.categoria = p_concepto
                  ), 0) + public.viaje_ajuste_total(p_viaje_id, p_concepto);
    v_etiqueta := case p_concepto when 'ACPM' then 'ACPM' else initcap(lower(p_concepto)) end;
  end if;

  if p_valor_nuevo = v_anterior then
    raise exception 'El valor nuevo es igual al valor vigente.' using errcode = 'OR148';
  end if;

  insert into public.ajuste_viaje (
    viaje_id, usuario_id, motivo, campo_modificado, valor_anterior, valor_nuevo, concepto, monto
  )
  values (
    p_viaje_id, (select auth.uid()), btrim(p_motivo), v_etiqueta,
    '$ ' || replace(to_char(v_anterior, 'FM999,999,999,999'), ',', '.'),
    '$ ' || replace(to_char(p_valor_nuevo, 'FM999,999,999,999'), ',', '.'),
    p_concepto, p_valor_nuevo - v_anterior
  )
  returning * into v_ajuste;

  return v_ajuste;
end;
$$;

revoke all on function public.viaje_registrar_ajuste_v2(uuid, text, text, numeric) from public;
grant execute on function public.viaje_registrar_ajuste_v2(uuid, text, text, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Rentabilidad marginal: incluye ajustes (#5)
-- ---------------------------------------------------------------------------
create or replace function public.rentabilidad_marginal(p_viaje_id uuid)
returns table (
  valor_flete       numeric,
  costos_totales    numeric,
  rentabilidad      numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rol       text := (auth.jwt() -> 'app_metadata' ->> 'rol');
  v_es_propio boolean;
  v_flete     numeric;
  v_costos    numeric;
begin
  select v.valor_flete, exists (
           select 1 from public.conductor c
           where c.id = v.conductor_id and c.usuario_id = (select auth.uid())
         )
    into v_flete, v_es_propio
    from public.viaje v
   where v.id = p_viaje_id;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_rol <> 'ADMINISTRADOR' and not (v_rol = 'CONDUCTOR' and v_es_propio) then
    raise exception 'No autorizado para consultar la rentabilidad de este viaje.'
      using errcode = 'OR105';
  end if;

  v_flete := v_flete + public.viaje_ajuste_total(p_viaje_id, 'FLETE');
  v_costos := public.viaje_costos_ajustados(p_viaje_id);

  return query select v_flete, v_costos, v_flete - v_costos;
end;
$$;

revoke all on function public.rentabilidad_marginal(uuid) from public;
grant execute on function public.rentabilidad_marginal(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Consolidada v2 / v3: ajustes (#5) y fecha de cierre en hora de Colombia (#6)
-- ---------------------------------------------------------------------------
create or replace function public.rentabilidad_consolidada_v2(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  total_flete               numeric,
  total_costos_directos     numeric,
  mantenimiento_amortizado  numeric,
  sueldo_fijo_prorrateado   numeric,
  rentabilidad_consolidada  numeric,
  viajes_incluidos          integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dias    numeric;
  v_flete   numeric;
  v_costos  numeric;
  v_mant    numeric := 0;
  v_sueldo  numeric := 0;
  v_n       integer;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la rentabilidad consolidada.'
      using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.'
      using errcode = 'OR107';
  end if;

  v_dias := (p_hasta - p_desde) + 1;

  with vp as (
    select v.id
      from public.viaje v
     where v.estado = 'CERRADO'
       and (v.fecha_cierre at time zone 'America/Bogota')::date between p_desde and p_hasta
       and (p_cliente_id is null or v.cliente_id = p_cliente_id)
       and (p_conductor_id is null or v.conductor_id = p_conductor_id)
       and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
       and (p_ruta is null or btrim(p_ruta) = ''
            or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
  )
  select coalesce(sum(public.viaje_flete_ajustado(vp.id)), 0),
         count(*)::int,
         coalesce(sum(public.viaje_costos_ajustados(vp.id)), 0)
    into v_flete, v_n, v_costos
    from vp;

  if p_cliente_id is null and p_conductor_id is null
     and (p_ruta is null or btrim(p_ruta) = '') then
    select coalesce(sum(mv.costo), 0) into v_mant
      from public.mantenimiento_vehiculo mv
     where mv.fecha between p_desde and p_hasta
       and (p_vehiculo_id is null or mv.vehiculo_id = p_vehiculo_id);
  end if;

  if p_cliente_id is null and p_vehiculo_id is null
     and (p_ruta is null or btrim(p_ruta) = '') then
    select coalesce(sum(c.sueldo_base * (v_dias / 30.0)), 0) into v_sueldo
      from public.conductor c
     where c.activo and c.tipo_pago in ('FIJO', 'MIXTO')
       and (p_conductor_id is null or c.id = p_conductor_id);
  end if;

  return query select v_flete, v_costos, v_mant, v_sueldo,
                      v_flete - v_costos - v_mant - v_sueldo, v_n;
end;
$$;

revoke all on function public.rentabilidad_consolidada_v2(date, date, uuid, uuid, uuid, text) from public;
grant execute on function public.rentabilidad_consolidada_v2(date, date, uuid, uuid, uuid, text) to authenticated;

create or replace function public.rentabilidad_consolidada_v3(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  total_flete               numeric,
  total_costos_directos     numeric,
  mantenimiento_amortizado  numeric,
  sueldo_fijo_prorrateado   numeric,
  rentabilidad_consolidada  numeric,
  viajes_incluidos          integer,
  costos_por_categoria      jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  -- _v2 valida rol (solo administrador) y rango de fechas.
  return query
    select r.total_flete, r.total_costos_directos, r.mantenimiento_amortizado,
           r.sueldo_fijo_prorrateado, r.rentabilidad_consolidada, r.viajes_incluidos,
           coalesce((
             select jsonb_object_agg(x.categoria, x.total)
               from (
                 select y.categoria, sum(y.valor) as total
                   from (
                     select cv.categoria, coalesce(cv.valor_real, cv.valor_estimado) as valor
                       from public.costo_viaje cv
                       join public.viaje v on v.id = cv.viaje_id
                      where v.estado = 'CERRADO'
                        and (v.fecha_cierre at time zone 'America/Bogota')::date between p_desde and p_hasta
                        and (p_cliente_id is null or v.cliente_id = p_cliente_id)
                        and (p_conductor_id is null or v.conductor_id = p_conductor_id)
                        and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
                        and (p_ruta is null or btrim(p_ruta) = ''
                             or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
                        and cv.categoria <> 'MANTENIMIENTO_AMORTIZADO'
                     union all
                     select a.concepto, a.monto
                       from public.ajuste_viaje a
                       join public.viaje v on v.id = a.viaje_id
                      where a.concepto is not null and a.concepto <> 'FLETE'
                        and v.estado = 'CERRADO'
                        and (v.fecha_cierre at time zone 'America/Bogota')::date between p_desde and p_hasta
                        and (p_cliente_id is null or v.cliente_id = p_cliente_id)
                        and (p_conductor_id is null or v.conductor_id = p_conductor_id)
                        and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
                        and (p_ruta is null or btrim(p_ruta) = ''
                             or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
                   ) y
                  group by y.categoria
               ) x
           ), '{}'::jsonb)
      from public.rentabilidad_consolidada_v2(
             p_desde, p_hasta, p_cliente_id, p_conductor_id, p_vehiculo_id, p_ruta
           ) r;
end;
$$;

revoke all on function public.rentabilidad_consolidada_v3(date, date, uuid, uuid, uuid, text) from public;
grant execute on function public.rentabilidad_consolidada_v3(date, date, uuid, uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Metricas: ajustes (#5), hora de Colombia (#6) y km reales (#12)
-- ---------------------------------------------------------------------------
create or replace function public.metricas_periodo_v2(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  viajes_cerrados        integer,
  km_total               numeric,
  costos_directos        numeric,
  costo_por_km           numeric,
  viajes_a_tiempo        integer,
  viajes_medidos         integer,
  utilizacion_flota_pct  numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dias numeric;
  v_activos integer;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar las metricas.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;

  v_dias := (p_hasta - p_desde) + 1;
  select count(*)::int into v_activos from public.vehiculo
   where activo and (p_vehiculo_id is null or id = p_vehiculo_id);

  return query
    with vp as (
      select v.id,
             coalesce(v.km_recorridos, v.distancia_estimada) as distancia_estimada,
             v.tiempo_estimado_min,
             (select min(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
             (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada
        from public.viaje v
       where v.estado = 'CERRADO'
         and (v.fecha_cierre at time zone 'America/Bogota')::date between p_desde and p_hasta
         and (p_cliente_id is null or v.cliente_id = p_cliente_id)
         and (p_conductor_id is null or v.conductor_id = p_conductor_id)
         and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
         and (p_ruta is null or btrim(p_ruta) = ''
              or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
    ),
    costos as (
      select coalesce(sum(public.viaje_costos_ajustados(vp.id)), 0) as total from vp
    ),
    kms as (select coalesce(sum(vp.distancia_estimada), 0) as total from vp),
    medidos as (
      select * from vp where salida is not null and llegada is not null and tiempo_estimado_min is not null
    )
    select
      (select count(*)::int from vp),
      (select total from kms),
      (select total from costos),
      case when (select total from kms) > 0 then round((select total from costos) / (select total from kms), 2) end,
      (select count(*)::int from medidos m
        where extract(epoch from (m.llegada - m.salida)) / 60
              <= m.tiempo_estimado_min + greatest(m.tiempo_estimado_min * 0.2, 30)),
      (select count(*)::int from medidos),
      case when v_activos > 0 then least(100, round(
        (select coalesce(sum(greatest(1, ceil(extract(epoch from (m.llegada - m.salida)) / 86400))), 0) from medidos m)
        / (v_activos * v_dias) * 100, 1)) else 0 end;
end;
$$;

revoke all on function public.metricas_periodo_v2(date, date, uuid, uuid, uuid, text) from public;
grant execute on function public.metricas_periodo_v2(date, date, uuid, uuid, uuid, text) to authenticated;

create or replace function public.metricas_por_dimension_v2(
  p_desde date,
  p_hasta date,
  p_dimension text,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  clave           text,
  viajes          integer,
  total_flete     numeric,
  total_costos    numeric,
  rentabilidad    numeric,
  km_total        numeric,
  viajes_a_tiempo integer,
  viajes_medidos  integer
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar las metricas.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;
  if p_dimension not in ('RUTA', 'CLIENTE', 'CONDUCTOR') then
    raise exception 'Dimension de metricas no valida.' using errcode = 'OR121';
  end if;

  return query
    with vp as (
      select v.id,
             public.viaje_flete_ajustado(v.id) as valor_flete,
             coalesce(v.km_recorridos, v.distancia_estimada) as distancia_estimada,
             v.tiempo_estimado_min,
             case p_dimension
               when 'RUTA' then v.origen || ' → ' || v.destino
               when 'CLIENTE' then cl.nombre
               else u.nombre
             end as clave,
             (select min(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
             (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada,
             public.viaje_costos_ajustados(v.id) as costos
        from public.viaje v
        join public.cliente cl on cl.id = v.cliente_id
        join public.conductor co on co.id = v.conductor_id
        join public.usuario u on u.id = co.usuario_id
       where v.estado = 'CERRADO'
         and (v.fecha_cierre at time zone 'America/Bogota')::date between p_desde and p_hasta
         and (p_cliente_id is null or v.cliente_id = p_cliente_id)
         and (p_conductor_id is null or v.conductor_id = p_conductor_id)
         and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
         and (p_ruta is null or btrim(p_ruta) = ''
              or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
    )
    select
      vp.clave,
      count(*)::int,
      sum(vp.valor_flete),
      sum(vp.costos),
      sum(vp.valor_flete - vp.costos),
      coalesce(sum(vp.distancia_estimada), 0),
      (count(*) filter (where vp.salida is not null and vp.llegada is not null and vp.tiempo_estimado_min is not null
         and extract(epoch from (vp.llegada - vp.salida)) / 60
             <= vp.tiempo_estimado_min + greatest(vp.tiempo_estimado_min * 0.2, 30)))::int,
      (count(*) filter (where vp.salida is not null and vp.llegada is not null and vp.tiempo_estimado_min is not null))::int
    from vp
    group by vp.clave
    order by sum(vp.valor_flete - vp.costos) desc;
end;
$$;

revoke all on function public.metricas_por_dimension_v2(date, date, text, uuid, uuid, uuid, text) from public;
grant execute on function public.metricas_por_dimension_v2(date, date, text, uuid, uuid, uuid, text) to authenticated;

create or replace function public.reporte_viajes(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  viaje_id      uuid,
  remision      text,
  fecha_cierre  date,
  ruta          text,
  cliente       text,
  conductor     text,
  placa         text,
  km            numeric,
  valor_flete   numeric,
  costos        numeric,
  rentabilidad  numeric,
  a_tiempo      boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar reportes.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;

  return query
    with base as (
      select v.id, v.remision as rem,
             (v.fecha_cierre at time zone 'America/Bogota')::date as cierre,
             v.origen || ' → ' || v.destino as la_ruta,
             cl.nombre as nom_cliente, u.nombre as nom_conductor, ve.placa as la_placa,
             coalesce(v.km_recorridos, v.distancia_estimada, 0) as kms,
             public.viaje_flete_ajustado(v.id) as flete,
             v.tiempo_estimado_min as est,
             (select min(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
             (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada,
             public.viaje_costos_ajustados(v.id) as costo_total
        from public.viaje v
        join public.cliente cl on cl.id = v.cliente_id
        join public.conductor co on co.id = v.conductor_id
        join public.usuario u on u.id = co.usuario_id
        join public.vehiculo ve on ve.id = v.vehiculo_id
       where v.estado = 'CERRADO'
         and (v.fecha_cierre at time zone 'America/Bogota')::date between p_desde and p_hasta
         and (p_cliente_id is null or v.cliente_id = p_cliente_id)
         and (p_conductor_id is null or v.conductor_id = p_conductor_id)
         and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
         and (p_ruta is null or btrim(p_ruta) = ''
              or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
    )
    select b.id, b.rem, b.cierre, b.la_ruta, b.nom_cliente, b.nom_conductor, b.la_placa,
           b.kms, b.flete, b.costo_total, b.flete - b.costo_total,
           case when b.salida is not null and b.llegada is not null and b.est is not null
                then extract(epoch from (b.llegada - b.salida)) / 60 <= b.est + greatest(b.est * 0.2, 30)
           end
      from base b
     order by b.cierre desc, b.rem;
end;
$$;

revoke all on function public.reporte_viajes(date, date, uuid, uuid, uuid, text) from public;
grant execute on function public.reporte_viajes(date, date, uuid, uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- #6 ACPM: la tarifa vigente se busca con la fecha de hoy en Colombia
-- ---------------------------------------------------------------------------
create or replace function public.costo_acpm_estimado(
  p_vehiculo_id uuid,
  p_distancia_km numeric,
  p_ciudad text,
  p_fecha date default public.hoy_bogota()
)
returns numeric
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_rendimiento numeric;
  v_capacidad   numeric;
  v_precio      numeric;
  v_factor      numeric;
begin
  select rendimiento_km_galon, capacidad_carga
    into v_rendimiento, v_capacidad
    from public.vehiculo
   where id = p_vehiculo_id;

  if not found then
    raise exception 'El vehiculo no existe.' using errcode = 'OR108';
  end if;

  select precio_galon
    into v_precio
    from public.tarifa_combustible
   where position(lower(ciudad) in lower(p_ciudad)) > 0
     and fecha_vigencia_desde <= p_fecha
   order by length(ciudad) desc, fecha_vigencia_desde desc
   limit 1;

  if not found then
    raise exception 'No hay tarifa de combustible vigente para % en %.', p_ciudad, p_fecha
      using errcode = 'OR109';
  end if;

  v_factor := case
    when v_capacidad <= 17 then 1.0
    when v_capacidad <= 25 then 1.1
    else 1.2
  end;

  return round((p_distancia_km / v_rendimiento) * v_precio * v_factor, 2);
end;
$$;

-- El precio automatico no pisa una tarifa digitada a mano para la misma fecha.
create or replace function public.tarifa_combustible_registrar_automatico(
  p_ciudad text,
  p_precio_galon numeric,
  p_fecha_vigencia date
)
returns table (
  aplicado         boolean,
  precio_anterior  numeric,
  motivo           text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_precio_anterior numeric;
  v_variacion       numeric;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Solo el proceso de scraping (service_role) puede registrar precios automaticos.'
      using errcode = 'OR105';
  end if;

  if p_precio_galon <= 0 then
    raise exception 'El precio de ACPM debe ser mayor a cero.' using errcode = 'OR110';
  end if;

  if exists (
    select 1 from public.tarifa_combustible t
     where t.ciudad = p_ciudad and t.fecha_vigencia_desde = p_fecha_vigencia
       and t.fuente = 'MANUAL'
  ) then
    return query select false, null::numeric,
      'Ya hay una tarifa manual para esa ciudad y fecha; no se sobrescribe.'::text;
    return;
  end if;

  select precio_galon
    into v_precio_anterior
    from public.tarifa_combustible
   where ciudad = p_ciudad
   order by fecha_vigencia_desde desc
   limit 1;

  if v_precio_anterior is null then
    insert into public.tarifa_combustible (ciudad, precio_galon, fecha_vigencia_desde, fuente)
    values (p_ciudad, p_precio_galon, p_fecha_vigencia, 'AUTOMATICO')
    on conflict (ciudad, fecha_vigencia_desde)
    do update set precio_galon = excluded.precio_galon, fuente = 'AUTOMATICO';

    return query select true, null::numeric, 'Sin precio previo para la ciudad; se registro el valor scrapeado.';
    return;
  end if;

  v_variacion := abs(p_precio_galon - v_precio_anterior) / v_precio_anterior;

  if v_variacion > 0.15 then
    return query select
      false,
      v_precio_anterior,
      format('El precio scrapeado (%s) difiere %s%% del ultimo valido (%s); se mantiene el ultimo precio.',
             p_precio_galon, round(v_variacion * 100, 1), v_precio_anterior);
    return;
  end if;

  insert into public.tarifa_combustible (ciudad, precio_galon, fecha_vigencia_desde, fuente)
  values (p_ciudad, p_precio_galon, p_fecha_vigencia, 'AUTOMATICO')
  on conflict (ciudad, fecha_vigencia_desde)
  do update set precio_galon = excluded.precio_galon, fuente = 'AUTOMATICO';

  return query select true, v_precio_anterior, 'Precio dentro del rango esperado (+/-15%); se registro.';
end;
$$;

revoke all on function public.tarifa_combustible_registrar_automatico(text, numeric, date) from public, anon, authenticated;
grant execute on function public.tarifa_combustible_registrar_automatico(text, numeric, date) to service_role;

-- ---------------------------------------------------------------------------
-- #4 / #13 viaje_crear: conductor ocupado, flete valido, sin carrera y sin
-- tragarse errores del calculo de ACPM
-- ---------------------------------------------------------------------------
create or replace function public.viaje_crear(
  p_remision text,
  p_vehiculo_id uuid,
  p_conductor_id uuid,
  p_cliente_id uuid,
  p_origen text,
  p_destino text,
  p_fecha_salida_programada timestamptz,
  p_distancia_estimada numeric,
  p_tiempo_estimado_min numeric,
  p_peso_carga numeric,
  p_valor_flete numeric
)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_vehiculo_activo   boolean;
  v_conductor_activo  boolean;
  v_porcentaje_comision numeric;
  v_acpm_estimado     numeric;
  v_viaje             public.viaje;
  v_sin_tarifa        boolean := false;
  v_sin_calculo       boolean := false;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede crear un viaje.'
      using errcode = 'OR105';
  end if;

  if p_valor_flete is null or p_valor_flete <= 0 then
    raise exception 'El valor del flete debe ser mayor a 0.' using errcode = 'OR130';
  end if;

  -- Serializa la creacion por vehiculo y por conductor: sin esto dos
  -- solicitudes simultaneas pasan juntas la verificacion de disponibilidad.
  perform pg_advisory_xact_lock(hashtextextended('viaje_vehiculo:' || p_vehiculo_id::text, 0));
  perform pg_advisory_xact_lock(hashtextextended('viaje_conductor:' || p_conductor_id::text, 0));

  select activo into v_vehiculo_activo from public.vehiculo where id = p_vehiculo_id;
  if not found or not v_vehiculo_activo then
    raise exception 'El vehiculo no existe o esta inactivo.' using errcode = 'OR111';
  end if;

  select activo,
         case when tipo_pago = 'FIJO' then 0 else porcentaje_comision end
    into v_conductor_activo, v_porcentaje_comision
    from public.conductor
   where id = p_conductor_id;
  if not found or not v_conductor_activo then
    raise exception 'El conductor no existe o esta inactivo.' using errcode = 'OR112';
  end if;

  if not exists (select 1 from public.cliente where id = p_cliente_id) then
    raise exception 'El cliente no existe.' using errcode = 'OR113';
  end if;

  if exists (
    select 1 from public.viaje
     where vehiculo_id = p_vehiculo_id
       and estado in ('ASIGNADO', 'EN_CURSO')
  ) then
    raise exception 'El vehiculo ya tiene un viaje asignado o en curso.' using errcode = 'OR114';
  end if;

  if exists (
    select 1 from public.viaje
     where conductor_id = p_conductor_id
       and estado in ('ASIGNADO', 'EN_CURSO')
  ) then
    raise exception 'El conductor ya tiene un viaje asignado o en curso.' using errcode = 'OR146';
  end if;

  begin
    v_acpm_estimado := public.costo_acpm_estimado(p_vehiculo_id, p_distancia_estimada, btrim(p_origen));
  exception
    when sqlstate 'OR109' then
      v_sin_tarifa := true;
    when others then
      v_sin_calculo := true;
  end;

  if v_acpm_estimado is null then
    v_acpm_estimado := 0;
    if not v_sin_tarifa then
      v_sin_calculo := true;
    end if;
  end if;

  insert into public.viaje (
    remision, vehiculo_id, conductor_id, cliente_id, origen, destino,
    fecha_salida_programada, distancia_estimada, tiempo_estimado_min, peso_carga,
    estado, valor_flete
  )
  values (
    p_remision, p_vehiculo_id, p_conductor_id, p_cliente_id, p_origen, p_destino,
    p_fecha_salida_programada, p_distancia_estimada, p_tiempo_estimado_min, p_peso_carga,
    'ASIGNADO', p_valor_flete
  )
  returning * into v_viaje;

  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, fuente)
  values
    (v_viaje.id, 'ACPM', v_acpm_estimado, 'AUTOMATICO'),
    (v_viaje.id, 'COMISION', round(p_valor_flete * v_porcentaje_comision / 100, 2), 'AUTOMATICO'),
    (v_viaje.id, 'PEAJE', 0, 'MANUAL'),
    (v_viaje.id, 'CARGUE', 0, 'MANUAL'),
    (v_viaje.id, 'DESCARGUE', 0, 'MANUAL'),
    (v_viaje.id, 'PARQUEADERO', 0, 'MANUAL'),
    (v_viaje.id, 'ACEITE', 0, 'MANUAL'),
    (v_viaje.id, 'LAVADO', 0, 'MANUAL'),
    (v_viaje.id, 'ENGRASE', 0, 'MANUAL'),
    (v_viaje.id, 'OTRO', 0, 'MANUAL');

  if v_sin_tarifa then
    insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
    values (
      'NOVEDAD',
      'Sin tarifa de ACPM',
      format(
        'El viaje %s (%s → %s) quedo con ACPM estimado en $0: no hay tarifa de combustible vigente para el origen. Registrela en Tarifas de ACPM.',
        p_remision, p_origen, p_destino
      ),
      v_viaje.id
    );
  elsif v_sin_calculo then
    insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
    values (
      'NOVEDAD',
      'ACPM sin calcular',
      format(
        'El viaje %s (%s → %s) quedo con ACPM estimado en $0: no se pudo calcular con la distancia o el rendimiento del vehiculo. Revise esos datos.',
        p_remision, p_origen, p_destino
      ),
      v_viaje.id
    );
  end if;

  return v_viaje;
end;
$$;

-- ---------------------------------------------------------------------------
-- #11 viaje_iniciar: conductor habilitado (activo y licencia vigente)
-- ---------------------------------------------------------------------------
create or replace function public.viaje_iniciar(
  p_viaje_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_fecha_hora timestamptz default now()
)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_radio_max_m  constant numeric := 500;
  c_checklist_h  constant integer := 12;
  v_viaje        public.viaje;
  v_distancia_m  numeric;
  v_check        public.checklist_viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede comenzarlo.'
      using errcode = 'OR105';
  end if;

  if p_lat is null or p_lng is null
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'No se pudo leer tu ubicacion. Activa el GPS e intenta de nuevo.'
      using errcode = 'OR117';
  end if;

  select v.* into v_viaje
    from public.viaje v
    join public.conductor c on c.id = v.conductor_id
   where v.id = p_viaje_id
     and c.usuario_id = (select auth.uid())
   for update of v;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado <> 'ASIGNADO' then
    raise exception 'Solo se puede comenzar un viaje asignado.' using errcode = 'OR119';
  end if;

  -- Conductor activo y con la licencia vigente (OR149).
  perform public.conductor_validar_habilitado(v_viaje.conductor_id);

  -- SOAT y tecnomecanica vigentes (OR132).
  perform public.vehiculo_validar_documentos(v_viaje.vehiculo_id);

  -- Checklist reciente y sin bloqueo pendiente.
  select k.* into v_check
    from public.checklist_viaje k
   where k.viaje_id = p_viaje_id
   order by k.fecha_hora desc
   limit 1;

  if not found or v_check.fecha_hora < now() - make_interval(hours => c_checklist_h) then
    raise exception 'Antes de comenzar debes completar el checklist del vehículo (vale % horas).', c_checklist_h
      using errcode = 'OR137';
  end if;

  if v_check.resultado = 'BLOQUEADO'
     and not exists (select 1 from public.checklist_autorizacion a where a.checklist_id = v_check.id) then
    raise exception 'El checklist tiene fallas críticas. Espera la autorización del administrador para salir.'
      using errcode = 'OR138';
  end if;

  if v_viaje.origen_lat is not null then
    v_distancia_m := public.distancia_haversine_m(
      v_viaje.origen_lat, v_viaje.origen_lng, p_lat, p_lng
    );

    if v_distancia_m > c_radio_max_m then
      raise exception
        'Debes estar a menos de % m del punto de inicio para comenzar el viaje (estas a % m).',
        c_radio_max_m, round(v_distancia_m)
        using errcode = 'OR120';
    end if;
  end if;

  insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
  values (p_viaje_id, 'SALIDA', p_fecha_hora);

  update public.viaje
     set estado = 'EN_CURSO'
   where id = p_viaje_id
   returning * into v_viaje;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_iniciar(uuid, double precision, double precision, timestamptz) from public;
grant execute on function public.viaje_iniciar(uuid, double precision, double precision, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- #8 Odometro y mantenimiento
--
-- El km digitado de un mantenimiento no entra al calculo del plan: el odometro
-- es derivado (CLAUDE.md), asi que la base del plan es el odometro derivado a
-- la fecha del mantenimiento. Sin esto un km nulo apagaba la alerta y un km
-- del tablero (otra escala) la dejaba "al dia" o vencida de inmediato.
-- ---------------------------------------------------------------------------
-- Un viaje cancelado en ruta conserva los km que alcanzo a recorrer.
create or replace function public.vehiculo_odometro_km(p_vehiculo_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select v.odometro_inicial_km + coalesce((
    select sum(coalesce(t.km_recorridos, t.distancia_estimada))
      from public.viaje t
     where t.vehiculo_id = v.id
       and (t.estado in ('FINALIZADO', 'CERRADO')
            or (t.estado = 'CANCELADO' and t.km_recorridos is not null))
  ), 0)
  from public.vehiculo v
  where v.id = p_vehiculo_id;
$$;

revoke all on function public.vehiculo_odometro_km(uuid) from public, anon, authenticated;

-- Odometro derivado a una fecha: viajes terminados hasta ese dia (hora de Colombia).
create or replace function public.vehiculo_odometro_km_al(p_vehiculo_id uuid, p_fecha date)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select v.odometro_inicial_km + coalesce((
    select sum(coalesce(t.km_recorridos, t.distancia_estimada))
      from public.viaje t
     where t.vehiculo_id = v.id
       and (t.estado in ('FINALIZADO', 'CERRADO')
            or (t.estado = 'CANCELADO' and t.km_recorridos is not null))
       and (coalesce(
              (select max(h.fecha_hora) from public.hito_viaje h
                where h.viaje_id = t.id and h.tipo = 'LLEGADA_DESTINO'),
              t.fecha_cancelacion, t.fecha_modificacion, t.fecha_creacion
            ) at time zone 'America/Bogota')::date <= p_fecha
  ), 0)
  from public.vehiculo v
  where v.id = p_vehiculo_id;
$$;

revoke all on function public.vehiculo_odometro_km_al(uuid, date) from public, anon, authenticated;

-- viaje_fijar_km: con p_solo_gps (viaje cancelado en ruta) no se usa la distancia
-- estimada de relleno: solo cuenta lo que el GPS midio.
drop function public.viaje_fijar_km(uuid);

create or replace function public.viaje_fijar_km(p_viaje_id uuid, p_solo_gps boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_cobertura_min constant numeric := 0.5;
  v_estimada numeric;
  v_puntos   integer;
  v_gps_km   numeric;
begin
  select v.distancia_estimada into v_estimada
    from public.viaje v where v.id = p_viaje_id;

  select count(*)::int,
         coalesce(sum(public.distancia_haversine_m(t.lat0, t.lng0, t.lat, t.lng)), 0) / 1000
    into v_puntos, v_gps_km
    from (
      select u.lat, u.lng,
             lag(u.lat) over (order by u.fecha_hora) as lat0,
             lag(u.lng) over (order by u.fecha_hora) as lng0
        from public.ubicacion_viaje u
       where u.viaje_id = p_viaje_id
    ) t;

  if p_solo_gps then
    if v_puntos >= 2 and v_gps_km > 0 then
      update public.viaje
         set km_recorridos = round(v_gps_km, 1), km_origen = 'GPS'
       where id = p_viaje_id;
    end if;
    return;
  end if;

  if v_puntos >= 2 and v_gps_km > 0
     and (v_estimada is null or v_gps_km >= v_estimada * c_cobertura_min) then
    update public.viaje
       set km_recorridos = round(v_gps_km, 1), km_origen = 'GPS'
     where id = p_viaje_id;
  elsif v_estimada is not null then
    update public.viaje
       set km_recorridos = v_estimada, km_origen = 'ESTIMADO'
     where id = p_viaje_id;
  end if;
end;
$$;

revoke all on function public.viaje_fijar_km(uuid, boolean) from public, anon, authenticated;

create or replace function public.mantenimiento_registrar(
  p_vehiculo_id uuid,
  p_tipo text,
  p_costo numeric,
  p_fecha date,
  p_kilometraje numeric default null,
  p_tipo_mantenimiento_id uuid default null,
  p_categoria text default 'PREVENTIVO',
  p_taller text default null,
  p_descripcion text default null
)
returns public.mantenimiento_vehiculo
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tipo    text := btrim(coalesce(p_tipo, ''));
  v_catalogo text;
  v_km      numeric := p_kilometraje;
  v_fila public.mantenimiento_vehiculo;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede registrar mantenimientos.' using errcode = 'OR105';
  end if;

  if not exists (select 1 from public.vehiculo where id = p_vehiculo_id) then
    raise exception 'El vehículo no existe.' using errcode = 'OR111';
  end if;

  if p_categoria not in ('PREVENTIVO', 'CORRECTIVO') then
    raise exception 'La categoría del mantenimiento no es válida.' using errcode = 'OR139';
  end if;

  if p_costo is null or p_costo <= 0 or (v_km is not null and v_km < 0) then
    raise exception 'El costo debe ser mayor a 0 y el kilometraje no puede ser negativo.' using errcode = 'OR139';
  end if;

  if p_fecha is null or p_fecha > public.hoy_bogota() then
    raise exception 'La fecha del mantenimiento no puede ser futura.' using errcode = 'OR139';
  end if;

  if p_tipo_mantenimiento_id is not null then
    select t.nombre into v_catalogo
      from public.tipo_mantenimiento t
     where t.id = p_tipo_mantenimiento_id;
    if not found then
      raise exception 'El tipo de mantenimiento no existe.' using errcode = 'OR139';
    end if;
    if v_tipo = '' then
      v_tipo := v_catalogo;
    end if;
  end if;

  if v_tipo = '' then
    raise exception 'El tipo de mantenimiento es obligatorio.' using errcode = 'OR139';
  end if;

  -- Sin km digitado: odometro derivado a la fecha del mantenimiento (de hoy o pasada).
  if v_km is null then
    v_km := round(public.vehiculo_odometro_km_al(p_vehiculo_id, p_fecha));
  end if;

  insert into public.mantenimiento_vehiculo
    (vehiculo_id, tipo, costo, fecha, kilometraje, tipo_mantenimiento_id, categoria, taller, descripcion)
  values
    (p_vehiculo_id, v_tipo, p_costo, p_fecha, v_km, p_tipo_mantenimiento_id, p_categoria,
     nullif(btrim(coalesce(p_taller, '')), ''), nullif(btrim(coalesce(p_descripcion, '')), ''))
  returning * into v_fila;

  return v_fila;
end;
$$;

revoke all on function public.mantenimiento_registrar(uuid, text, numeric, date, numeric, uuid, text, text, text) from public;
grant execute on function public.mantenimiento_registrar(uuid, text, numeric, date, numeric, uuid, text, text, text) to authenticated;

create or replace function public.plan_mantenimiento_calculo()
returns setof public.plan_mantenimiento_item
language sql
stable
security definer
set search_path = ''
as $$
  with base as (
    select p.id as plan_id, p.vehiculo_id, v.placa, p.tipo_mantenimiento_id,
           t.nombre as tipo_nombre, p.intervalo_km, p.intervalo_dias,
           p.antelacion_km, p.antelacion_dias,
           u.fecha as ultimo_fecha, u.kilometraje as ultimo_km,
           o.km as odometro_km,
           coalesce(u.fecha, (v.fecha_creacion at time zone 'America/Bogota')::date) as base_fecha,
           case when u.fecha is not null
                then public.vehiculo_odometro_km_al(p.vehiculo_id, u.fecha)
                else v.odometro_inicial_km end as base_km
      from public.plan_mantenimiento p
      join public.vehiculo v on v.id = p.vehiculo_id and v.activo
      join public.tipo_mantenimiento t on t.id = p.tipo_mantenimiento_id
      left join lateral (
        select m.fecha, m.kilometraje
          from public.mantenimiento_vehiculo m
         where m.vehiculo_id = p.vehiculo_id
           and m.tipo_mantenimiento_id = p.tipo_mantenimiento_id
         order by m.fecha desc, m.fecha_creacion desc
         limit 1
      ) u on true
      cross join lateral (select public.vehiculo_odometro_km(v.id) as km) o
     where p.activo
  ),
  calc as (
    select b.*,
           case when b.intervalo_km is not null and b.base_km is not null
                then b.intervalo_km - greatest(b.odometro_km - b.base_km, 0) end as km_restantes,
           case when b.intervalo_dias is not null
                then b.intervalo_dias - (public.hoy_bogota() - b.base_fecha) end as dias_restantes
      from base b
  )
  select c.plan_id, c.vehiculo_id, c.placa, c.tipo_mantenimiento_id, c.tipo_nombre,
         c.intervalo_km, c.intervalo_dias, c.ultimo_fecha, c.ultimo_km,
         round(c.odometro_km), round(c.km_restantes), c.dias_restantes,
         case
           when coalesce(c.km_restantes <= 0, false) or coalesce(c.dias_restantes <= 0, false)
             then 'VENCIDO'
           when coalesce(c.km_restantes <= c.antelacion_km, false)
                or coalesce(c.dias_restantes <= c.antelacion_dias, false)
             then 'PROXIMO'
           else 'AL_DIA'
         end
    from calc c;
$$;

revoke all on function public.plan_mantenimiento_calculo() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- #7 Cancelar y eliminar viajes con encuesta; #8 cancelar en ruta conserva los km
-- ---------------------------------------------------------------------------
create or replace function public.viaje_cancelar(p_viaje_id uuid, p_motivo text)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje public.viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede cancelar un viaje.' using errcode = 'OR105';
  end if;

  if p_motivo is null or char_length(btrim(p_motivo)) < 5 then
    raise exception 'El motivo de la cancelacion es obligatorio (minimo 5 caracteres).'
      using errcode = 'OR124';
  end if;

  select * into v_viaje from public.viaje where id = p_viaje_id for update;
  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado in ('CERRADO', 'CANCELADO') then
    raise exception 'Un viaje % no se puede cancelar.', lower(v_viaje.estado)
      using errcode = 'OR125';
  end if;

  -- Cancelado en ruta: los km que el GPS alcanzo a medir cuentan en el odometro.
  if v_viaje.estado = 'EN_CURSO' then
    perform public.viaje_fijar_km(p_viaje_id, true);
  end if;

  update public.viaje
     set estado = 'CANCELADO',
         motivo_cancelacion = btrim(p_motivo),
         fecha_cancelacion = now()
   where id = p_viaje_id
   returning * into v_viaje;

  -- No se le pide opinion al cliente de un servicio cancelado.
  update public.encuesta_satisfaccion
     set estado = 'VENCIDA'
   where viaje_id = p_viaje_id
     and estado in ('PENDIENTE', 'ENVIADA', 'SIN_CONTACTO');

  return v_viaje;
end;
$$;

revoke all on function public.viaje_cancelar(uuid, text) from public;
grant execute on function public.viaje_cancelar(uuid, text) to authenticated;

create or replace function public.viaje_eliminar(p_viaje_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje public.viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede eliminar un viaje.' using errcode = 'OR105';
  end if;

  if p_motivo is null or char_length(btrim(p_motivo)) < 5 then
    raise exception 'El motivo de la eliminacion es obligatorio (minimo 5 caracteres).'
      using errcode = 'OR124';
  end if;

  select * into v_viaje from public.viaje where id = p_viaje_id for update;
  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado = 'CERRADO' then
    raise exception 'Un viaje cerrado no se elimina; registre un ajuste.' using errcode = 'OR100';
  end if;

  if exists (
    select 1 from public.encuesta_satisfaccion e
     where e.viaje_id = p_viaje_id and e.estado = 'RESPONDIDA'
  ) then
    raise exception 'El cliente ya respondio la encuesta de este viaje; no se puede eliminar. Cancelelo en su lugar.'
      using errcode = 'OR150';
  end if;

  if exists (select 1 from public.ajuste_viaje a where a.viaje_id = p_viaje_id) then
    raise exception 'El viaje tiene ajustes registrados; no se puede eliminar.'
      using errcode = 'OR150';
  end if;

  insert into public.viaje_eliminado (
    viaje_id, remision, estado, origen, destino, valor_flete, motivo, eliminado_por
  )
  values (
    v_viaje.id, v_viaje.remision, v_viaje.estado, v_viaje.origen, v_viaje.destino,
    v_viaje.valor_flete, btrim(p_motivo), (select auth.uid())
  );

  -- La encuesta sin respuesta no tiene sentido sin su viaje.
  delete from public.encuesta_satisfaccion where viaje_id = p_viaje_id;
  delete from public.viaje where id = p_viaje_id;
end;
$$;

revoke all on function public.viaje_eliminar(uuid, text) from public;
grant execute on function public.viaje_eliminar(uuid, text) to authenticated;

-- Nunca se envia la encuesta de un viaje cancelado.
create or replace function public.encuesta_pendientes_envio()
returns table (
  id            uuid,
  token         uuid,
  destinatario  text,
  cliente       text,
  origen        text,
  destino       text,
  remision      text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Solo el proceso de encuestas (service_role) puede consultar los envios pendientes.'
      using errcode = 'OR105';
  end if;

  return query
    select e.id, e.token, e.destinatario, cl.nombre, v.origen, v.destino, v.remision
      from public.encuesta_satisfaccion e
      join public.viaje v on v.id = e.viaje_id
      join public.cliente cl on cl.id = e.cliente_id
     where e.vence_en > now()
       and v.estado <> 'CANCELADO'
       and (
         (e.estado = 'PENDIENTE' and e.destinatario is not null and e.intentos_envio < 3)
         or (e.estado = 'SIN_CONTACTO' and e.enlace is null)
       )
     order by e.fecha_creacion
     limit 50;
end;
$$;

revoke all on function public.encuesta_pendientes_envio() from public, anon, authenticated;
grant execute on function public.encuesta_pendientes_envio() to service_role;

-- ---------------------------------------------------------------------------
-- Notificaciones: alertas de licencia (#11), mantenimiento sin colision de clave
-- el mismo dia (#8) y fechas del peaje en hora de Colombia (#6)
-- ---------------------------------------------------------------------------
create or replace function public.notificacion_generar()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Documentos a 30 dias (31..8) y a 7 dias (7..0): una alerta por documento y escalon.
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, clave)
  select
    'DOCUMENTO_POR_VENCER',
    'Documento por vencer',
    format(
      'El %s de %s vence %s (%s).',
      case dv.tipo when 'SOAT' then 'SOAT' else 'la revisión técnico-mecánica' end,
      v.placa,
      case dv.dias_restantes when 0 then 'hoy' when 1 then 'mañana' else 'en ' || dv.dias_restantes || ' días' end,
      to_char(dv.fecha_vencimiento, 'DD/MM/YYYY')
    ),
    v.id,
    'DOC:' || dv.id || ':' || case when dv.dias_restantes <= 7 then '7' else '30' end
  from public.documento_vehiculo_vigente dv
  join public.vehiculo v on v.id = dv.vehiculo_id and v.activo
  where dv.dias_restantes between 0 and 30
    and not exists (
      select 1 from public.notificacion n
      where n.clave = 'DOC:' || dv.id || ':' || case when dv.dias_restantes <= 7 then '7' else '30' end
    );

  -- Documentos vencidos: una sola vez por documento.
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, clave)
  select
    'DOCUMENTO_VENCIDO',
    'Documento vencido',
    format(
      '%s de %s venció el %s. El vehículo no puede comenzar viajes hasta renovarlo.',
      case dv.tipo when 'SOAT' then 'El SOAT' else 'La revisión técnico-mecánica' end,
      v.placa,
      to_char(dv.fecha_vencimiento, 'DD/MM/YYYY')
    ),
    v.id,
    'DOC:' || dv.id || ':0'
  from public.documento_vehiculo_vigente dv
  join public.vehiculo v on v.id = dv.vehiculo_id and v.activo
  where dv.dias_restantes < 0
    and not exists (
      select 1 from public.notificacion n where n.clave = 'DOC:' || dv.id || ':0'
    );

  -- Licencia de conduccion a 30 y 7 dias. La clave lleva la fecha de vencimiento:
  -- al renovarla (otra fecha) la alerta se rearma.
  insert into public.notificacion (tipo, titulo, mensaje, clave)
  select
    'DOCUMENTO_POR_VENCER',
    'Licencia por vencer',
    format(
      'La licencia de %s vence %s (%s).',
      u.nombre,
      case (c.fecha_vencimiento_licencia - public.hoy_bogota())
        when 0 then 'hoy' when 1 then 'mañana'
        else 'en ' || (c.fecha_vencimiento_licencia - public.hoy_bogota()) || ' días' end,
      to_char(c.fecha_vencimiento_licencia, 'DD/MM/YYYY')
    ),
    'LIC:' || c.id || ':' || c.fecha_vencimiento_licencia || ':'
      || case when c.fecha_vencimiento_licencia - public.hoy_bogota() <= 7 then '7' else '30' end
  from public.conductor c
  join public.usuario u on u.id = c.usuario_id and u.activo
  where c.activo
    and c.fecha_vencimiento_licencia - public.hoy_bogota() between 0 and 30
    and not exists (
      select 1 from public.notificacion n
      where n.clave = 'LIC:' || c.id || ':' || c.fecha_vencimiento_licencia || ':'
        || case when c.fecha_vencimiento_licencia - public.hoy_bogota() <= 7 then '7' else '30' end
    );

  insert into public.notificacion (tipo, titulo, mensaje, clave)
  select
    'DOCUMENTO_VENCIDO',
    'Licencia vencida',
    format(
      'La licencia de %s venció el %s. No podrá comenzar viajes hasta renovarla.',
      u.nombre, to_char(c.fecha_vencimiento_licencia, 'DD/MM/YYYY')
    ),
    'LIC:' || c.id || ':' || c.fecha_vencimiento_licencia || ':0'
  from public.conductor c
  join public.usuario u on u.id = c.usuario_id and u.activo
  where c.activo
    and c.fecha_vencimiento_licencia < public.hoy_bogota()
    and not exists (
      select 1 from public.notificacion n
      where n.clave = 'LIC:' || c.id || ':' || c.fecha_vencimiento_licencia || ':0'
    );

  -- Mantenimiento preventivo proximo o vencido, por plan. La clave lleva cuantos
  -- mantenimientos de ese tipo hay: dos en el mismo dia tambien rearman la alerta.
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, clave)
  select
    case p.estado when 'VENCIDO' then 'MANTENIMIENTO_VENCIDO' else 'MANTENIMIENTO_PROXIMO' end,
    case p.estado when 'VENCIDO' then 'Mantenimiento vencido' else 'Mantenimiento próximo' end,
    format(
      '%s de %s: %s.',
      p.tipo_nombre,
      p.placa,
      array_to_string(array[
        case when p.km_restantes is null then null
             when p.km_restantes <= 0
               then 'excedido por ' || replace(to_char(abs(p.km_restantes), 'FM999,999,999'), ',', '.') || ' km'
             else 'faltan ' || replace(to_char(p.km_restantes, 'FM999,999,999'), ',', '.') || ' km' end,
        case when p.dias_restantes is null then null
             when p.dias_restantes <= 0 then 'excedido por ' || abs(p.dias_restantes) || ' días'
             else 'faltan ' || p.dias_restantes || ' días' end
      ], ' / ')
    ),
    p.vehiculo_id,
    'MANT:' || p.plan_id || ':' || p.estado || ':' || coalesce(p.ultimo_fecha::text, 'base') || ':' || p.n_registros
  from (
    select c.*, (
             select count(*) from public.mantenimiento_vehiculo m
              where m.vehiculo_id = c.vehiculo_id
                and m.tipo_mantenimiento_id = c.tipo_mantenimiento_id
           ) as n_registros
      from public.plan_mantenimiento_calculo() c
  ) p
  where p.estado in ('PROXIMO', 'VENCIDO')
    and not exists (
      select 1 from public.notificacion n
      where n.clave = 'MANT:' || p.plan_id || ':' || p.estado || ':' || coalesce(p.ultimo_fecha::text, 'base') || ':' || p.n_registros
    );

  -- Viajes ASIGNADO/EN_CURSO cuya salida + tiempo estimado + margen (el mayor
  -- entre 20% del estimado y 30 min, RF-20) ya pasó, sin
  -- alerta de retraso previa para ese viaje.
  insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
  select
    'RETRASO',
    'Retraso en viaje',
    format(
      '%s → %s (viaje %s) lleva retraso sobre el tiempo estimado.',
      v.origen, v.destino, v.remision
    ),
    v.id
  from public.viaje v
  join public.hito_viaje h on h.viaje_id = v.id and h.tipo = 'SALIDA'
  where v.estado in ('ASIGNADO', 'EN_CURSO')
    and v.tiempo_estimado_min is not null
    and now() > h.fecha_hora + ((v.tiempo_estimado_min + greatest(v.tiempo_estimado_min * 0.2, 30)) || ' minutes')::interval
    and not exists (
      select 1 from public.notificacion n
      where n.tipo = 'RETRASO' and n.viaje_id = v.id
    );

  -- Viajes que llegaron a FINALIZADO y todavia no tienen la alerta de
  -- completado (una sola vez por viaje).
  insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
  select
    'VIAJE_COMPLETADO',
    'Viaje completado',
    format('%s → %s (viaje %s) llegó a destino.', v.origen, v.destino, v.remision),
    v.id
  from public.viaje v
  where v.estado = 'FINALIZADO'
    and not exists (
      select 1 from public.notificacion n
      where n.tipo = 'VIAJE_COMPLETADO' and n.viaje_id = v.id
    );

  -- Peajes capturados hoy (hora de Colombia) para un viaje, resumidos en una
  -- sola alerta diaria por viaje (evita una notificacion por cada correo de GoPass).
  insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
  select
    'PEAJE_REGISTRADO',
    'Peajes registrados',
    format('GoPass: %s peaje(s) asociados al viaje %s hoy.', conteo.total, conteo.remision),
    conteo.viaje_id
  from (
    select p.viaje_id, v.remision, count(*) as total
    from public.peaje_capturado p
    join public.viaje v on v.id = p.viaje_id
    where p.viaje_id is not null
      and (p.fecha_hora at time zone 'America/Bogota')::date = public.hoy_bogota()
    group by p.viaje_id, v.remision
  ) conteo
  where not exists (
    select 1 from public.notificacion n
    where n.tipo = 'PEAJE_REGISTRADO'
      and n.viaje_id = conteo.viaje_id
      and (n.fecha_creacion at time zone 'America/Bogota')::date = public.hoy_bogota()
  );
end;
$$;

revoke all on function public.notificacion_generar() from public, anon, authenticated;
