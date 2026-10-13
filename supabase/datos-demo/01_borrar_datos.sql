-- Borra TODOS los datos de negocio y los usuarios, menos el administrador
-- jdgutierrezotalvaro04@gmail.com. NO es una migración: se corre a mano, una
-- sola vez, con
--   npx supabase db query --linked -f supabase/datos-demo/01_borrar_datos.sql
-- Es una sola transacción: si algo falla, no se borra nada.

do $$
begin
  if not exists (
    select 1 from auth.users where email = 'jdgutierrezotalvaro04@gmail.com'
  ) then
    raise exception 'No existe el administrador a conservar; no se borra nada.';
  end if;
end $$;

-- TRUNCATE no dispara los triggers de append-only (ajuste_viaje,
-- viaje_eliminado) ni los de "viaje cerrado no se borra".
truncate table
  public.ajuste_viaje,
  public.viaje_eliminado,
  public.ubicacion_viaje,
  public.peaje_capturado,
  public.notificacion,
  public.hito_viaje,
  public.costo_viaje,
  public.checklist_autorizacion,
  public.checklist_respuesta,
  public.checklist_viaje,
  public.viaje,
  public.documento_vehiculo,
  public.mantenimiento_vehiculo,
  public.plan_mantenimiento,
  public.tarifa_combustible,
  public.conductor,
  public.cliente,
  public.vehiculo;

-- public.usuario, auth.identities y las sesiones caen en cascada.
delete from auth.users where email <> 'jdgutierrezotalvaro04@gmail.com';
