-- Google OAuth es solo para INICIAR SESION en cuentas ya existentes; no crea
-- cuentas. El alta publica sigue siendo por correo + contrasena.
--
-- Supabase Auth no permite deshabilitar el alta solo para un proveedor, asi que
-- se rechaza aqui el INSERT en auth.users cuando el origen es Google. Si el
-- correo ya existe, GoTrue vincula la identidad de Google al usuario actual
-- (UPDATE/INSERT en auth.identities) y no inserta en auth.users: el login pasa.

create or replace function public.rechazar_alta_oauth_google()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.raw_app_meta_data ->> 'provider' = 'google' then
    raise exception 'No existe una cuenta con ese correo. Registrate primero con correo y contraseña.'
      using errcode = 'OR002';
  end if;
  return new;
end;
$$;

create trigger on_auth_user_before_created_google
  before insert on auth.users
  for each row execute function public.rechazar_alta_oauth_google();
