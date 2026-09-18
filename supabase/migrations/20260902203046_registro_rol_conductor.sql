-- Registro publico: todo usuario nuevo nace con rol CONDUCTOR.
--
-- Cambio respecto a 20260902_auth_perfil.sql: la funcion del trigger ya NO
-- exige un `rol` en `raw_user_meta_data` ni lo lee del cliente. El rol es una
-- decision del servidor y en el alta siempre es CONDUCTOR; promover a
-- ADMINISTRADOR es una operacion aparte (por ahora, UPDATE por SQL de un
-- administrador). Asi, aunque el cliente mande `rol` en el signUp, se ignora.
--
-- `nombre`: se toma de `raw_user_meta_data.nombre`; si falta, cae en la parte
-- local del correo, para que un alta sin metadata (p. ej. desde el dashboard)
-- no falle (`usuario.nombre` es NOT NULL).

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nombre    text := coalesce(
                 nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''),
                 split_part(new.email, '@', 1)
               );
  v_documento text := nullif(trim(new.raw_user_meta_data ->> 'documento'), '');
  v_rol       text := 'CONDUCTOR';
begin
  insert into public.usuario (id, nombre, documento, rol)
  values (new.id, v_nombre, v_documento, v_rol);

  update auth.users
     set raw_app_meta_data =
           coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('rol', v_rol)
   where id = new.id;

  return new;
end;
$$;
