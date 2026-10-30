-- Calidad del viaje: calificacion automatica (sin formulario) con 4 dimensiones
-- calculadas al vuelo desde datos que ya existen, y alerta recurrente.
--
-- Decisiones del dueño (2026-10-14):
--   * Dimensiones: PUNTUALIDAD (hitos vs tiempo estimado), RENTABILIDAD (costo
--     real vs estimado), SATISFACCION (encuesta del cliente) e INCIDENCIAS
--     (alertas generadas durante el viaje).
--   * Color global por PUNTAJE PROMEDIO: verde = 2, ambar = 1, rojo = 0 por
--     dimension medida; puntaje = promedio * 50 (0-100). >= 75 verde,
--     >= 40 ambar, menos rojo. Una dimension sin datos no cuenta.
--   * Rentabilidad: desvio de costos <= 15 % verde, <= 35 % ambar, mayor rojo.
--     Un viaje con costos por encima del flete es rojo siempre.
--   * Alerta recurrente: 3 viajes (FINALIZADOS o CERRADOS) del mismo mes
--     calendario con la misma dimension en rojo, por conductor, placa o ruta.
--   * Por ahora la empresa no cierra viajes: las metricas y alertas cuentan los
--     viajes FINALIZADOS ademas de los CERRADOS. Mientras un viaje esta solo
--     FINALIZADO sus costos reales pueden estar incompletos (p. ej. un GoPass
--     que aun no llega); la calificacion se recalcula sola con cada dato nuevo.
--   * Indicador en el perfil del conductor (conductor_calidad): el propio
--     conductor lo ve (solo el suyo) y el administrador el de cualquiera.
--
-- No hay tabla nueva: la calificacion se calcula con los datos vigentes (igual
-- que `vehiculo_hoja_vida`), asi que no hay copia que mantener ni que corregir
-- cuando llegan los peajes, un ajuste o la respuesta del cliente.

-- ---------------------------------------------------------------------------
-- notificacion: tipo nuevo
-- ---------------------------------------------------------------------------
alter table public.notificacion drop constraint if exists notificacion_tipo_check;
alter table public.notificacion
  add constraint notificacion_tipo_check check (tipo in (
    'DOCUMENTO_POR_VENCER', 'DOCUMENTO_VENCIDO', 'MANTENIMIENTO_PROXIMO',
    'MANTENIMIENTO_VENCIDO', 'CHECKLIST_FALLA', 'RETRASO', 'VIAJE_COMPLETADO',
    'PEAJE_REGISTRADO', 'NOVEDAD', 'PARADA_PROLONGADA', 'DESVIO_RUTA',
    'SATISFACCION_BAJA', 'PAUSA_ACTIVA_IGNORADA', 'CALIDAD_RECURRENTE'
  ));

-- ---------------------------------------------------------------------------
-- viaje_calidad_calcular: interna. Una fila por viaje FINALIZADO o CERRADO.
-- Niveles: 'VERDE' | 'AMBAR' | 'ROJO' | null (sin datos para medir).
-- ---------------------------------------------------------------------------
create or replace function public.viaje_calidad_calcular(p_viaje_id uuid)
returns table (
  viaje_id                uuid,
  puntualidad_nivel       text,
  minutos_retraso         numeric,
  rentabilidad_nivel      text,
  desvio_costos_pct       numeric,
  categoria_mayor_desvio  text,
  satisfaccion_nivel      text,
  csat_promedio           numeric,
  incidencias_nivel       text,
  incidencias_total       integer,
  puntaje                 numeric,
  nivel                   text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_viaje     public.viaje;
  v_salida    timestamptz;
  v_llegada   timestamptz;
  v_real      numeric;
  v_est       numeric;
  v_retraso   numeric;
  v_punt      text;
  v_costo_est numeric;
  v_costo_real numeric;
  v_flete     numeric;
  v_desvio    numeric;
  v_rent      text;
  v_cat       text;
  v_enc       public.encuesta_satisfaccion;
  v_csat      numeric;
  v_sat       text;
  v_inc_n     integer;
  v_inc       text;
  v_suma      numeric := 0;
  v_n         integer := 0;
  v_puntaje   numeric;
  v_nivel     text;
begin
  select * into v_viaje from public.viaje where id = p_viaje_id;
  if not found or v_viaje.estado not in ('FINALIZADO', 'CERRADO') then
    return;
  end if;

  -- Puntualidad: mismo criterio que metricas_periodo_v2 (a tiempo = estimado +
  -- el mayor entre 20 % y 30 min). Verde solo si no se paso del estimado.
  select min(h.fecha_hora) filter (where h.tipo = 'SALIDA'),
         max(h.fecha_hora) filter (where h.tipo = 'LLEGADA_DESTINO')
    into v_salida, v_llegada
    from public.hito_viaje h where h.viaje_id = p_viaje_id;
  v_est := v_viaje.tiempo_estimado_min;
  if v_salida is not null and v_llegada is not null and v_llegada >= v_salida
     and v_est is not null then
    v_real := extract(epoch from (v_llegada - v_salida)) / 60;
    v_retraso := round(v_real - v_est, 1);
    v_punt := case
      when v_real <= v_est then 'VERDE'
      when v_real <= v_est + greatest(v_est * 0.2, 30) then 'AMBAR'
      else 'ROJO'
    end;
  end if;

  -- Rentabilidad: costo real (con ajustes) contra el estimado de las mismas
  -- categorias. El mantenimiento amortizado no entra (igual que la marginal).
  select coalesce(sum(cv.valor_estimado), 0) into v_costo_est
    from public.costo_viaje cv
   where cv.viaje_id = p_viaje_id and cv.categoria <> 'MANTENIMIENTO_AMORTIZADO';
  v_costo_real := public.viaje_costos_ajustados(p_viaje_id);
  v_flete := public.viaje_flete_ajustado(p_viaje_id);
  if v_costo_est > 0 then
    v_desvio := round((v_costo_real - v_costo_est) / v_costo_est * 100, 1);
  end if;
  if v_flete - v_costo_real < 0 then
    v_rent := 'ROJO';
  elsif v_desvio is not null then
    v_rent := case when v_desvio <= 15 then 'VERDE' when v_desvio <= 35 then 'AMBAR' else 'ROJO' end;
  end if;
  select cv.categoria into v_cat
    from public.costo_viaje cv
   where cv.viaje_id = p_viaje_id and cv.categoria <> 'MANTENIMIENTO_AMORTIZADO'
     and coalesce(cv.valor_real, cv.valor_estimado) > cv.valor_estimado
   order by coalesce(cv.valor_real, cv.valor_estimado) - cv.valor_estimado desc
   limit 1;

  -- Satisfaccion: solo si el cliente respondio. Mismos umbrales del semaforo
  -- de la pestaña Satisfaccion (CSAT 4,2 / 3,5) y la regla de SATISFACCION_BAJA.
  select * into v_enc from public.encuesta_satisfaccion
   where encuesta_satisfaccion.viaje_id = p_viaje_id and estado = 'RESPONDIDA';
  if found then
    v_csat := round((v_enc.csat_entrega + v_enc.csat_servicio + v_enc.csat_atencion
                     + v_enc.csat_puntualidad) / 4.0, 2);
    v_sat := case
      when least(v_enc.csat_entrega, v_enc.csat_servicio, v_enc.csat_atencion,
                 v_enc.csat_puntualidad) <= 2 or v_enc.nps <= 6 or v_csat < 3.5 then 'ROJO'
      when v_csat >= 4.2 then 'VERDE'
      else 'AMBAR'
    end;
  end if;

  -- Incidencias: alertas del viaje generadas por el telefono o el checklist.
  select count(*)::int into v_inc_n
    from public.notificacion n
   where n.viaje_id = p_viaje_id
     and n.tipo in ('DESVIO_RUTA', 'PARADA_PROLONGADA', 'PAUSA_ACTIVA_IGNORADA', 'CHECKLIST_FALLA');
  v_inc := case when v_inc_n = 0 then 'VERDE' when v_inc_n <= 2 then 'AMBAR' else 'ROJO' end;

  select coalesce(sum(case x when 'VERDE' then 2 when 'AMBAR' then 1 else 0 end), 0),
         count(x)::int
    into v_suma, v_n
    from unnest(array[v_punt, v_rent, v_sat, v_inc]) as t(x)
   where x is not null;
  if v_n > 0 then
    v_puntaje := round(v_suma / v_n * 50, 1);
    v_nivel := case when v_puntaje >= 75 then 'VERDE' when v_puntaje >= 40 then 'AMBAR' else 'ROJO' end;
  end if;

  return query select p_viaje_id, v_punt, v_retraso, v_rent, v_desvio, v_cat,
                      v_sat, v_csat, v_inc, v_inc_n, v_puntaje, v_nivel;
end;
$$;

revoke all on function public.viaje_calidad_calcular(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- viaje_calidad: detalle de un viaje (solo administrador)
-- ---------------------------------------------------------------------------
create or replace function public.viaje_calidad(p_viaje_id uuid)
returns table (
  viaje_id                uuid,
  puntualidad_nivel       text,
  minutos_retraso         numeric,
  rentabilidad_nivel      text,
  desvio_costos_pct       numeric,
  categoria_mayor_desvio  text,
  satisfaccion_nivel      text,
  csat_promedio           numeric,
  incidencias_nivel       text,
  incidencias_total       integer,
  puntaje                 numeric,
  nivel                   text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la calidad del viaje.' using errcode = 'OR105';
  end if;
  if not exists (select 1 from public.viaje v where v.id = p_viaje_id) then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;
  return query select * from public.viaje_calidad_calcular(p_viaje_id);
end;
$$;

revoke all on function public.viaje_calidad(uuid) from public;
grant execute on function public.viaje_calidad(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- calidad_base: viajes FINALIZADOS o CERRADOS del periodo con su calificacion y
-- los filtros del Resumen. La fecha del viaje es la de cierre o, mientras no se
-- cierra, la de la llegada al destino (o la ultima modificacion). Interna: cada RPC publica valida el rol antes de llamarla.
-- ---------------------------------------------------------------------------
create or replace function public.calidad_base(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid,
  p_conductor_id uuid,
  p_vehiculo_id uuid,
  p_ruta text
)
returns table (
  viaje_id           uuid,
  conductor_id       uuid,
  conductor          text,
  vehiculo_id        uuid,
  placa              text,
  ruta               text,
  puntualidad_nivel  text,
  rentabilidad_nivel text,
  satisfaccion_nivel text,
  incidencias_nivel  text,
  puntaje            numeric,
  nivel              text
)
language sql
stable
security definer
set search_path = ''
as $$
  select v.id, v.conductor_id, u.nombre, v.vehiculo_id, ve.placa,
         v.origen || ' → ' || v.destino,
         q.puntualidad_nivel, q.rentabilidad_nivel, q.satisfaccion_nivel,
         q.incidencias_nivel, q.puntaje, q.nivel
    from public.viaje v
    join public.conductor co on co.id = v.conductor_id
    join public.usuario u on u.id = co.usuario_id
    join public.vehiculo ve on ve.id = v.vehiculo_id
    cross join lateral public.viaje_calidad_calcular(v.id) q
   where v.estado in ('FINALIZADO', 'CERRADO')
     and (coalesce(
            v.fecha_cierre,
            (select max(h.fecha_hora) from public.hito_viaje h
              where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO'),
            v.fecha_modificacion,
            v.fecha_creacion
          ) at time zone 'America/Bogota')::date between p_desde and p_hasta
     and (p_cliente_id is null or v.cliente_id = p_cliente_id)
     and (p_conductor_id is null or v.conductor_id = p_conductor_id)
     and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
     and (p_ruta is null or btrim(p_ruta) = ''
          or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0);
$$;

revoke all on function public.calidad_base(date, date, uuid, uuid, uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- calidad_resumen: cifras del periodo (pestaña «Calidad»)
-- ---------------------------------------------------------------------------
create or replace function public.calidad_resumen(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  viajes_evaluados   integer,
  verdes             integer,
  ambares            integer,
  rojos              integer,
  puntaje_promedio   numeric,
  puntualidad_rojos  integer,
  rentabilidad_rojos integer,
  satisfaccion_rojos integer,
  incidencias_rojos  integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la calidad.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;

  return query
    select count(*)::int,
           (count(*) filter (where b.nivel = 'VERDE'))::int,
           (count(*) filter (where b.nivel = 'AMBAR'))::int,
           (count(*) filter (where b.nivel = 'ROJO'))::int,
           round(avg(b.puntaje), 1),
           (count(*) filter (where b.puntualidad_nivel = 'ROJO'))::int,
           (count(*) filter (where b.rentabilidad_nivel = 'ROJO'))::int,
           (count(*) filter (where b.satisfaccion_nivel = 'ROJO'))::int,
           (count(*) filter (where b.incidencias_nivel = 'ROJO'))::int
      from public.calidad_base(p_desde, p_hasta, p_cliente_id, p_conductor_id, p_vehiculo_id, p_ruta) b
     where b.nivel is not null;
end;
$$;

revoke all on function public.calidad_resumen(date, date, uuid, uuid, uuid, text) from public;
grant execute on function public.calidad_resumen(date, date, uuid, uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- conductor_calidad: indicador del perfil del conductor. El administrador
-- consulta el de cualquiera; el conductor solo el suyo. Mismas cifras que
-- calidad_resumen, filtradas por conductor.
-- ---------------------------------------------------------------------------
create or replace function public.conductor_calidad(
  p_conductor_id uuid,
  p_desde date,
  p_hasta date
)
returns table (
  viajes_evaluados   integer,
  verdes             integer,
  ambares            integer,
  rojos              integer,
  puntaje_promedio   numeric,
  puntualidad_rojos  integer,
  rentabilidad_rojos integer,
  satisfaccion_rojos integer,
  incidencias_rojos  integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rol       text := (auth.jwt() -> 'app_metadata' ->> 'rol');
  v_es_propio boolean;
begin
  select exists (
           select 1 from public.conductor c
            where c.id = p_conductor_id and c.usuario_id = (select auth.uid())
         ) into v_es_propio;

  if v_rol <> 'ADMINISTRADOR' and not (v_rol = 'CONDUCTOR' and v_es_propio) then
    raise exception 'No autorizado para consultar la calidad de este conductor.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;

  return query
    select count(*)::int,
           (count(*) filter (where b.nivel = 'VERDE'))::int,
           (count(*) filter (where b.nivel = 'AMBAR'))::int,
           (count(*) filter (where b.nivel = 'ROJO'))::int,
           round(avg(b.puntaje), 1),
           (count(*) filter (where b.puntualidad_nivel = 'ROJO'))::int,
           (count(*) filter (where b.rentabilidad_nivel = 'ROJO'))::int,
           (count(*) filter (where b.satisfaccion_nivel = 'ROJO'))::int,
           (count(*) filter (where b.incidencias_nivel = 'ROJO'))::int
      from public.calidad_base(p_desde, p_hasta, null, p_conductor_id, null, null) b
     where b.nivel is not null;
end;
$$;

revoke all on function public.conductor_calidad(uuid, date, date) from public;
grant execute on function public.conductor_calidad(uuid, date, date) to authenticated;

-- ---------------------------------------------------------------------------
-- calidad_por_dimension: ranking por RUTA, CONDUCTOR o VEHICULO (peor primero)
-- ---------------------------------------------------------------------------
create or replace function public.calidad_por_dimension(
  p_desde date,
  p_hasta date,
  p_dimension text,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  clave              text,
  viajes             integer,
  puntaje_promedio   numeric,
  rojos              integer,
  puntualidad_rojos  integer,
  rentabilidad_rojos integer,
  satisfaccion_rojos integer,
  incidencias_rojos  integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la calidad.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;
  if p_dimension not in ('RUTA', 'CONDUCTOR', 'VEHICULO') then
    raise exception 'Dimension de calidad no valida.' using errcode = 'OR121';
  end if;

  return query
    select case p_dimension when 'RUTA' then b.ruta when 'CONDUCTOR' then b.conductor else b.placa end,
           count(*)::int,
           round(avg(b.puntaje), 1),
           (count(*) filter (where b.nivel = 'ROJO'))::int,
           (count(*) filter (where b.puntualidad_nivel = 'ROJO'))::int,
           (count(*) filter (where b.rentabilidad_nivel = 'ROJO'))::int,
           (count(*) filter (where b.satisfaccion_nivel = 'ROJO'))::int,
           (count(*) filter (where b.incidencias_nivel = 'ROJO'))::int
      from public.calidad_base(p_desde, p_hasta, p_cliente_id, p_conductor_id, p_vehiculo_id, p_ruta) b
     where b.nivel is not null
     group by 1
     order by avg(b.puntaje) asc, 1;
end;
$$;

revoke all on function public.calidad_por_dimension(date, date, text, uuid, uuid, uuid, text) from public;
grant execute on function public.calidad_por_dimension(date, date, text, uuid, uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- calidad_recurrentes_base: interna. Entidades con >= 3 viajes del
-- mes con la misma dimension en rojo.
-- ---------------------------------------------------------------------------
create or replace function public.calidad_recurrentes_base(p_desde date, p_hasta date)
returns table (
  entidad      text,
  clave        text,
  vehiculo_id  uuid,
  dimension    text,
  viajes       integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with b as (
    select * from public.calidad_base(p_desde, p_hasta, null, null, null, null)
  ), rojo as (
    select b.*, d.dimension
      from b
      cross join lateral (values
        ('PUNTUALIDAD', b.puntualidad_nivel),
        ('RENTABILIDAD', b.rentabilidad_nivel),
        ('SATISFACCION', b.satisfaccion_nivel),
        ('INCIDENCIAS', b.incidencias_nivel)
      ) as d(dimension, nivel)
     where d.nivel = 'ROJO'
  )
  select 'CONDUCTOR', r.conductor, null::uuid, r.dimension, count(*)::int
    from rojo r group by r.conductor, r.dimension having count(*) >= 3
  union all
  select 'VEHICULO', r.placa, min(r.vehiculo_id::text)::uuid, r.dimension, count(*)::int
    from rojo r group by r.placa, r.dimension having count(*) >= 3
  union all
  select 'RUTA', r.ruta, null::uuid, r.dimension, count(*)::int
    from rojo r group by r.ruta, r.dimension having count(*) >= 3;
$$;

revoke all on function public.calidad_recurrentes_base(date, date) from public, anon, authenticated;

-- Alertas recurrentes del mes para la pestaña «Calidad» (solo administrador).
create or replace function public.calidad_recurrentes(p_desde date, p_hasta date)
returns table (
  entidad    text,
  clave      text,
  dimension  text,
  viajes     integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la calidad.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;
  return query
    select r.entidad, r.clave, r.dimension, r.viajes
      from public.calidad_recurrentes_base(p_desde, p_hasta) r
     order by r.viajes desc, r.entidad, r.clave;
end;
$$;

revoke all on function public.calidad_recurrentes(date, date) from public;
grant execute on function public.calidad_recurrentes(date, date) to authenticated;

-- ---------------------------------------------------------------------------
-- calidad_alertas_generar: job diario de pg_cron. Una notificacion por
-- entidad + dimension + mes (la clave evita repetirla en cada corrida).
-- ---------------------------------------------------------------------------
create or replace function public.calidad_alertas_generar()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_desde date := date_trunc('month', (now() at time zone 'America/Bogota'))::date;
  v_hasta date := (date_trunc('month', (now() at time zone 'America/Bogota')) + interval '1 month' - interval '1 day')::date;
  v_mes   text := to_char(v_desde, 'YYYY-MM');
  v_n     integer;
begin
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, clave)
  select 'CALIDAD_RECURRENTE',
         case r.entidad
           when 'VEHICULO' then 'Calidad: revisar placa ' || r.clave
           when 'CONDUCTOR' then 'Calidad: revisar conductor ' || r.clave
           else 'Calidad: revisar ruta ' || r.clave
         end,
         format('%s viajes del mes con %s. %s', r.viajes,
           case r.dimension
             when 'PUNTUALIDAD' then 'retrasos'
             when 'RENTABILIDAD' then 'sobrecostos'
             when 'SATISFACCION' then 'satisfacción baja del cliente'
             else 'incidencias en ruta (desvíos, paradas o pausas ignoradas)'
           end,
           case
             when r.entidad = 'VEHICULO' and r.dimension = 'INCIDENCIAS'
               then 'Revisar hábitos de conducción en placa ' || r.clave || '.'
             when r.entidad = 'RUTA' and r.dimension = 'RENTABILIDAD'
               then 'Ruta ' || r.clave || ' con sobrecostos frecuentes.'
             when r.entidad = 'RUTA' and r.dimension = 'PUNTUALIDAD'
               then 'Ruta ' || r.clave || ' con retrasos frecuentes.'
             else 'Conviene revisar ' || lower(r.entidad) || ' ' || r.clave || '.'
           end),
         r.vehiculo_id,
         'CAL:' || r.entidad || ':' || r.clave || ':' || r.dimension || ':' || v_mes
    from public.calidad_recurrentes_base(v_desde, v_hasta) r
   where not exists (
     select 1 from public.notificacion n
      where n.clave = 'CAL:' || r.entidad || ':' || r.clave || ':' || r.dimension || ':' || v_mes
   );
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.calidad_alertas_generar() from public, anon, authenticated;

select cron.schedule(
  'calidad-alertas-diario',
  '0 12 * * *',
  $$select public.calidad_alertas_generar();$$
);
