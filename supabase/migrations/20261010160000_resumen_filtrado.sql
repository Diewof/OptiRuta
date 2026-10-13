-- Resumen con filtros (fecha, cliente, conductor, vehiculo, ruta).
--
-- Versiones _v2 de las RPC del Resumen con filtros opcionales (un nulo no
-- filtra). Las funciones sin filtros siguen existiendo (app vieja en uso) y
-- ahora delegan en las v2 para no duplicar la logica.
--
-- Costos fijos con filtros (decision): el mantenimiento se atribuye al
-- vehiculo y el sueldo fijo al conductor, asi que:
--   * mantenimiento: se filtra por vehiculo; con filtro de cliente, conductor
--     o ruta no es atribuible y vale 0.
--   * sueldo fijo prorrateado: se filtra por conductor; con filtro de
--     cliente, vehiculo o ruta no es atribuible y vale 0.

-- ---------------------------------------------------------------------------
-- rentabilidad_consolidada_v2
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
    select v.id, v.valor_flete
      from public.viaje v
     where v.estado = 'CERRADO'
       and v.fecha_cierre::date between p_desde and p_hasta
       and (p_cliente_id is null or v.cliente_id = p_cliente_id)
       and (p_conductor_id is null or v.conductor_id = p_conductor_id)
       and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
       and (p_ruta is null or btrim(p_ruta) = ''
            or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
  )
  select coalesce(sum(vp.valor_flete), 0), count(*)::int,
         (select coalesce(sum(coalesce(cv.valor_real, cv.valor_estimado)), 0)
            from public.costo_viaje cv join vp vp2 on vp2.id = cv.viaje_id
           where cv.categoria <> 'MANTENIMIENTO_AMORTIZADO')
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

create or replace function public.rentabilidad_consolidada(p_desde date, p_hasta date)
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
begin
  return query select * from public.rentabilidad_consolidada_v2(p_desde, p_hasta);
end;
$$;

-- ---------------------------------------------------------------------------
-- metricas_periodo_v2
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
      select v.id, v.distancia_estimada, v.tiempo_estimado_min,
             (select min(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
             (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada
        from public.viaje v
       where v.estado = 'CERRADO' and v.fecha_cierre::date between p_desde and p_hasta
         and (p_cliente_id is null or v.cliente_id = p_cliente_id)
         and (p_conductor_id is null or v.conductor_id = p_conductor_id)
         and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
         and (p_ruta is null or btrim(p_ruta) = ''
              or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
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

revoke all on function public.metricas_periodo_v2(date, date, uuid, uuid, uuid, text) from public;
grant execute on function public.metricas_periodo_v2(date, date, uuid, uuid, uuid, text) to authenticated;

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
begin
  return query select * from public.metricas_periodo_v2(p_desde, p_hasta);
end;
$$;

-- ---------------------------------------------------------------------------
-- metricas_por_dimension_v2
-- ---------------------------------------------------------------------------
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
  return query select * from public.metricas_por_dimension_v2(p_desde, p_hasta, p_dimension);
end;
$$;
