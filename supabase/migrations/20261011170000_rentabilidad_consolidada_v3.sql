-- Desglose de costos del Resumen: rentabilidad_consolidada_v3 devuelve lo mismo
-- que _v2 mas el total de cada categoria de costo directo (ACPM, peajes,
-- cargue...) de los viajes CERRADO del periodo, con los mismos filtros.
--
-- Es una funcion nueva (y no una columna mas en _v2) porque la funcion sin
-- filtros hace `select * from _v2` y cambiaria de forma con app vieja en uso.
--
-- Mantenimiento: la rentabilidad consolidada ya resta el costo de los
-- mantenimientos con fecha dentro del periodo (mantenimiento_vehiculo.costo),
-- filtrado por vehiculo; con filtro de cliente, conductor o ruta no es
-- atribuible y vale 0 (decision de 20261010160000_resumen_filtrado.sql).

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
                 select cv.categoria,
                        sum(coalesce(cv.valor_real, cv.valor_estimado)) as total
                   from public.costo_viaje cv
                   join public.viaje v on v.id = cv.viaje_id
                  where v.estado = 'CERRADO'
                    and v.fecha_cierre::date between p_desde and p_hasta
                    and (p_cliente_id is null or v.cliente_id = p_cliente_id)
                    and (p_conductor_id is null or v.conductor_id = p_conductor_id)
                    and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
                    and (p_ruta is null or btrim(p_ruta) = ''
                         or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
                    and cv.categoria <> 'MANTENIMIENTO_AMORTIZADO'
                  group by cv.categoria
               ) x
           ), '{}'::jsonb)
      from public.rentabilidad_consolidada_v2(
             p_desde, p_hasta, p_cliente_id, p_conductor_id, p_vehiculo_id, p_ruta
           ) r;
end;
$$;

revoke all on function public.rentabilidad_consolidada_v3(date, date, uuid, uuid, uuid, text) from public;
grant execute on function public.rentabilidad_consolidada_v3(date, date, uuid, uuid, uuid, text) to authenticated;
