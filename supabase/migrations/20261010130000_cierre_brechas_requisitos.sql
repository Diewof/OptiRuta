-- Cierre de brechas de requisitos: RF-11 (aviso sin tarifa), RF-14 (costos
-- libres con descripcion), RF-20 (margen de retraso), RF-24/25 (costo por km y
-- metricas por ruta/cliente/conductor).

-- ---------------------------------------------------------------------------
-- RF-14: costos adicionales con descripcion libre. Varias filas OTRO por viaje
-- son validas; la descripcion distingue cada una.
-- ---------------------------------------------------------------------------
alter table public.costo_viaje
  add column descripcion text check (descripcion is null or char_length(btrim(descripcion)) between 1 and 120);

comment on column public.costo_viaje.descripcion is
  'Descripcion libre del costo (RF-14). La usan las filas OTRO creadas por el administrador; las categorias fijas la dejan nula.';

-- ---------------------------------------------------------------------------
-- RF-20: el retraso se notifica solo pasado el margen (el mayor entre 20% del
-- tiempo estimado y 30 min), definido en requisitos-funcionales.
-- ---------------------------------------------------------------------------
create or replace function public.notificacion_generar()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Documentos (SOAT/tecnomecanica) que vencen en 30 dias o menos y todavia
  -- no tienen una alerta sin leer de los ultimos 7 dias para ese vehiculo.
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id)
  select
    'DOCUMENTO_POR_VENCER',
    'Documento por vencer',
    format(
      'El %s de %s vence el %s.',
      dv.tipo, v.placa, to_char(dv.fecha_vencimiento, 'DD/MM/YYYY')
    ),
    v.id
  from public.documento_vehiculo dv
  join public.vehiculo v on v.id = dv.vehiculo_id
  where dv.fecha_vencimiento between current_date and current_date + interval '30 days'
    and not exists (
      select 1 from public.notificacion n
      where n.tipo = 'DOCUMENTO_POR_VENCER'
        and n.vehiculo_id = dv.vehiculo_id
        and n.fecha_creacion > now() - interval '7 days'
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

  -- Peajes capturados hoy para un viaje, resumidos en una sola alerta diaria
  -- por viaje (evita una notificacion por cada correo de GoPass).
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
      and p.fecha_hora::date = current_date
    group by p.viaje_id, v.remision
  ) conteo
  where not exists (
    select 1 from public.notificacion n
    where n.tipo = 'PEAJE_REGISTRADO'
      and n.viaje_id = conteo.viaje_id
      and n.fecha_creacion::date = current_date
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RF-11: viaje_crear avisa cuando no hay tarifa de ACPM. Misma firma.
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
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede crear un viaje.'
      using errcode = 'OR105';
  end if;

  select activo into v_vehiculo_activo from public.vehiculo where id = p_vehiculo_id;
  if not found or not v_vehiculo_activo then
    raise exception 'El vehiculo no existe o esta inactivo.' using errcode = 'OR111';
  end if;

  select activo, porcentaje_comision
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

  begin
    v_acpm_estimado := public.costo_acpm_estimado(p_vehiculo_id, p_distancia_estimada, btrim(p_origen));
  exception when others then
    v_acpm_estimado := 0;
    v_sin_tarifa := true;
  end;

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

  -- RF-11: sin tarifa de ACPM el estimado queda en 0; se avisa al admin en vez
  -- de dejarlo pasar en silencio.
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
  end if;

  return v_viaje;
end;
$$;

-- ---------------------------------------------------------------------------
-- RF-24/25: metricas del periodo. Base: viajes CERRADO con fecha_cierre en el
-- rango. Km = distancia_estimada (no se guarda distancia real). Un viaje
-- cumple si LLEGADA_DESTINO - SALIDA <= estimado + margen de retraso.
-- ---------------------------------------------------------------------------
create or replace function public.metricas_periodo(p_desde date, p_hasta date)
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
  select count(*)::int into v_activos from public.vehiculo where activo;

  return query
    with vp as (
      select v.id, v.distancia_estimada, v.tiempo_estimado_min,
             (select min(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
             (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada
        from public.viaje v
       where v.estado = 'CERRADO' and v.fecha_cierre::date between p_desde and p_hasta
    ),
    costos as (
      select coalesce(sum(coalesce(cv.valor_real, cv.valor_estimado)), 0) as total
        from public.costo_viaje cv join vp on vp.id = cv.viaje_id
       where cv.categoria <> 'MANTENIMIENTO_AMORTIZADO'
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

revoke all on function public.metricas_periodo(date, date) from public;
grant execute on function public.metricas_periodo(date, date) to authenticated;

create or replace function public.metricas_por_dimension(p_desde date, p_hasta date, p_dimension text)
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
      select v.id, v.valor_flete, v.distancia_estimada, v.tiempo_estimado_min,
             case p_dimension
               when 'RUTA' then v.origen || ' → ' || v.destino
               when 'CLIENTE' then cl.nombre
               else u.nombre
             end as clave,
             (select min(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
             (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada,
             (select coalesce(sum(coalesce(cv.valor_real, cv.valor_estimado)), 0)
                from public.costo_viaje cv
               where cv.viaje_id = v.id and cv.categoria <> 'MANTENIMIENTO_AMORTIZADO') as costos
        from public.viaje v
        join public.cliente cl on cl.id = v.cliente_id
        join public.conductor co on co.id = v.conductor_id
        join public.usuario u on u.id = co.usuario_id
       where v.estado = 'CERRADO' and v.fecha_cierre::date between p_desde and p_hasta
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

revoke all on function public.metricas_por_dimension(date, date, text) from public;
grant execute on function public.metricas_por_dimension(date, date, text) to authenticated;

-- ---------------------------------------------------------------------------
-- RF-14: el conductor puede anotar un costo adicional libre (OTRO con
-- descripcion) en su propio viaje abierto, siempre como valor real. No crea
-- categorias fijas ni toca estimados. Los viajes CERRADO los bloquea el
-- trigger costo_viaje_bloquear_si_cerrado.
-- ---------------------------------------------------------------------------
create policy costo_viaje_conductor_agrega_otro
  on public.costo_viaje
  for insert
  to authenticated
  with check (
    categoria = 'OTRO'
    and fuente = 'MANUAL'
    and valor_estimado = 0
    and valor_real is not null
    and descripcion is not null
    and exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = costo_viaje.viaje_id
        and v.estado in ('EN_CURSO', 'FINALIZADO')
        and c.usuario_id = (select auth.uid())
    )
  );
