-- costo_acpm_estimado: la ciudad se compara sin tildes ni mayusculas.
--
-- Los nombres de lugar que llegan del mapa vienen de OpenStreetMap, donde la
-- misma ciudad aparece como "Medellín" o "Medellin" segun quien la editó,
-- mientras que tarifa_combustible.ciudad guarda "Medellín". Sin normalizar, la
-- coincidencia fallaba de forma intermitente y el ACPM quedaba en 0.
--
-- Misma firma y misma formula que 20261008130000; solo cambia el filtro de
-- ciudad. No se usa la extension unaccent para no depender de otra extension
-- por un caso tan acotado (letras del español).
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
   where position(
           translate(lower(ciudad), 'áéíóúüñ', 'aeiouun')
           in translate(lower(p_ciudad), 'áéíóúüñ', 'aeiouun')
         ) > 0
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
