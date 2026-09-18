-- RPC de estimacion de ACPM (RF-11).
--
-- Formula fijada en CLAUDE.md: distancia / rendimiento_km_galon * precio_galon,
-- con un factor de ajuste simple por rango de tonelaje (no modelo
-- estadistico). El calculo vive aqui, nunca en la app.
create or replace function public.costo_acpm_estimado(
  p_vehiculo_id uuid,
  p_distancia_km numeric,
  p_ciudad text,
  p_fecha date default current_date
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
   where ciudad = p_ciudad
     and fecha_vigencia_desde <= p_fecha
   order by fecha_vigencia_desde desc
   limit 1;

  if not found then
    raise exception 'No hay tarifa de combustible vigente para % en %.', p_ciudad, p_fecha
      using errcode = 'OR109';
  end if;

  -- Factor de ajuste simple por rango de tonelaje: a mayor capacidad, mayor
  -- consumo relativo. Rangos alineados a doble troque (17-25 t) y mula.
  v_factor := case
    when v_capacidad <= 17 then 1.0
    when v_capacidad <= 25 then 1.1
    else 1.2
  end;

  return round((p_distancia_km / v_rendimiento) * v_precio * v_factor, 2);
end;
$$;

revoke all on function public.costo_acpm_estimado(uuid, numeric, text, date) from public;
grant execute on function public.costo_acpm_estimado(uuid, numeric, text, date) to authenticated;
