-- RPC usada por la Edge Function precio-acpm-scraper (service_role) para
-- registrar el precio de ACPM mensual scrapeado, con la validacion de
-- seguridad de diseno-base-de-datos-optiruta.md seccion 6: si el valor
-- difiere mas de +/-15% del ultimo precio guardado para esa ciudad, no se
-- sobrescribe: se mantiene el ultimo precio valido y se devuelve el motivo
-- para que la Edge Function genere la alerta (log estructurado) y el
-- administrador lo revise a mano. Nunca es la unica via de escritura: la
-- tabla sigue siendo editable manualmente (RPC de PostgREST via UPDATE con
-- el grant de administrador de la migracion de catalogos).
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
  -- Ni current_user (siempre resuelve al dueno de la funcion dentro de un
  -- SECURITY DEFINER) ni session_user (PostgREST usa un rol de conexion fijo
  -- y cambia el rol efectivo con SET LOCAL ROLE por request) sirven aqui: el
  -- claim 'role' del JWT es la forma documentada de saber con que rol de
  -- PostgREST llego la peticion (mismo patron que auth.jwt() -> 'app_metadata'
  -- ->> 'rol' que usan las demas RPC de negocio).
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Solo el proceso de scraping (service_role) puede registrar precios automaticos.'
      using errcode = 'OR105';
  end if;

  if p_precio_galon <= 0 then
    raise exception 'El precio de ACPM debe ser mayor a cero.' using errcode = 'OR110';
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

-- Solo service_role: ni anon ni authenticated deben poder inyectar precios
-- "automaticos" saltandose la revision de administrador.
revoke all on function public.tarifa_combustible_registrar_automatico(text, numeric, date) from public, anon, authenticated;
grant execute on function public.tarifa_combustible_registrar_automatico(text, numeric, date) to service_role;

-- ---------------------------------------------------------------------------
-- Valor de arranque real (diseno-base-de-datos-optiruta.md seccion 5), antes
-- de que el scraper mensual tome el control. No es dato de demo: es la
-- referencia inicial de produccion para Medellin, ciudad de casi todas las
-- rutas historicas.
-- ---------------------------------------------------------------------------
insert into public.tarifa_combustible (ciudad, precio_galon, fecha_vigencia_desde, fuente)
values ('Medellin', 11641, date '2026-09-01', 'MANUAL')
on conflict (ciudad, fecha_vigencia_desde) do nothing;
