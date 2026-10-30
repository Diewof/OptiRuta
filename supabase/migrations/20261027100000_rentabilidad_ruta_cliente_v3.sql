-- Informe de rentabilidad por ruta, cliente, conductor y placa (inteligencia de
-- negocios, informe 2).
--
-- Decisiones del dueño (2026-10-27):
--   * Se cuentan viajes FINALIZADOS y CERRADOS (igual que Calidad del viaje): la
--     empresa todavia no cierra viajes y las metricas _v2 saldrian vacias.
--   * Viaticos entran como categoria OTRO; no se agrega categoria nueva.
--   * El informe agrega margen promedio por viaje, margen % sobre el flete y la
--     dimension PLACA. `bajo_margen` marca rutas/clientes bajo el margen minimo;
--     el umbral vive solo aqui (c_margen_minimo_pct).
--
-- metricas_por_dimension_v2 queda intacta para la app vieja.

-- ---------------------------------------------------------------------------
-- viaje_fecha_informe: fecha (hora Colombia) con que un viaje cuenta en un
-- periodo. Cierre; mientras no se cierra, llegada al destino. Misma regla de
-- `calidad_base`. Interna.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_fecha_informe(p_viaje_id uuid)
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select (coalesce(
           v.fecha_cierre,
           (select max(h.fecha_hora) from public.hito_viaje h
             where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO'),
           v.fecha_modificacion,
           v.fecha_creacion
         ) at time zone 'America/Bogota')::date
    from public.viaje v
   where v.id = p_viaje_id;
$$;

revoke all on function public.viaje_fecha_informe(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- metricas_por_dimension_v3
-- ---------------------------------------------------------------------------
create or replace function public.metricas_por_dimension_v3(
  p_desde date,
  p_hasta date,
  p_dimension text,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  clave            text,
  viajes           integer,
  total_flete      numeric,
  total_costos     numeric,
  rentabilidad     numeric,
  margen_promedio  numeric,
  margen_pct       numeric,
  bajo_margen      boolean,
  km_total         numeric,
  viajes_a_tiempo  integer,
  viajes_medidos   integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_margen_minimo_pct constant numeric := 10;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar las metricas.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;
  if p_dimension not in ('RUTA', 'CLIENTE', 'CONDUCTOR', 'PLACA') then
    raise exception 'Dimension de metricas no valida.' using errcode = 'OR121';
  end if;

  return query
    with vp as (
      select public.viaje_flete_ajustado(v.id) as flete,
             public.viaje_costos_ajustados(v.id) as costos,
             coalesce(v.km_recorridos, v.distancia_estimada) as kms,
             v.tiempo_estimado_min as est,
             case p_dimension
               when 'RUTA' then v.origen || ' → ' || v.destino
               when 'CLIENTE' then cl.nombre
               when 'PLACA' then ve.placa
               else u.nombre
             end as la_clave,
             (select min(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
             (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada
        from public.viaje v
        join public.cliente cl on cl.id = v.cliente_id
        join public.conductor co on co.id = v.conductor_id
        join public.usuario u on u.id = co.usuario_id
        join public.vehiculo ve on ve.id = v.vehiculo_id
       where v.estado in ('FINALIZADO', 'CERRADO')
         and public.viaje_fecha_informe(v.id) between p_desde and p_hasta
         and (p_cliente_id is null or v.cliente_id = p_cliente_id)
         and (p_conductor_id is null or v.conductor_id = p_conductor_id)
         and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
         and (p_ruta is null or btrim(p_ruta) = ''
              or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
    ), agg as (
      select vp.la_clave,
             count(*)::int as n,
             sum(vp.flete) as flete,
             sum(vp.costos) as costos,
             coalesce(sum(vp.kms), 0) as kms,
             (count(*) filter (where vp.salida is not null and vp.llegada is not null and vp.est is not null
                and extract(epoch from (vp.llegada - vp.salida)) / 60
                    <= vp.est + greatest(vp.est * 0.2, 30)))::int as a_tiempo,
             (count(*) filter (where vp.salida is not null and vp.llegada is not null and vp.est is not null))::int as medidos
        from vp
       group by vp.la_clave
    )
    select a.la_clave,
           a.n,
           a.flete,
           a.costos,
           a.flete - a.costos,
           round((a.flete - a.costos) / a.n, 0),
           case when a.flete > 0 then round((a.flete - a.costos) / a.flete * 100, 1) end,
           (a.flete - a.costos) < 0
             or (a.flete > 0 and (a.flete - a.costos) / a.flete * 100 < c_margen_minimo_pct),
           a.kms,
           a.a_tiempo,
           a.medidos
      from agg a
     order by (a.flete - a.costos) / a.n desc;
end;
$$;

revoke all on function public.metricas_por_dimension_v3(date, date, text, uuid, uuid, uuid, text) from public;
grant execute on function public.metricas_por_dimension_v3(date, date, text, uuid, uuid, uuid, text) to authenticated;
