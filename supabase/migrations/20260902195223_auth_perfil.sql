-- Migracion inicial de autenticacion: perfil de usuario ligado a Supabase Auth.
--
-- Contexto (CLAUDE.md / arquitectura-y-estandares.md seccion 8):
--   * Credenciales y sesiones las gestiona Supabase Auth (GoTrue). Esta tabla
--     solo guarda datos de negocio del usuario (nombre, documento, rol, activo).
--   * El rol se refleja ademas en app_metadata.rol del usuario de Auth para que
--     viaje en el JWT y las politicas RLS lo puedan leer.
--   * Toda tabla nace con RLS habilitado y politicas explicitas en esta misma
--     migracion.

-- ---------------------------------------------------------------------------
-- Tabla
-- ---------------------------------------------------------------------------
create table public.usuario (
  id                  uuid primary key references auth.users (id) on delete cascade,
  nombre              text not null,
  documento           text,
  rol                 text not null check (rol in ('ADMINISTRADOR', 'CONDUCTOR')),
  activo              boolean not null default true,
  creado_por          uuid,
  fecha_creacion      timestamptz not null default now(),
  modificado_por      uuid,
  fecha_modificacion  timestamptz
);

comment on table public.usuario is
  'Datos de negocio del usuario. Autenticacion y sesiones viven en auth.users (GoTrue).';

-- ---------------------------------------------------------------------------
-- Trigger: crear el perfil cuando Auth crea un usuario, y reflejar el rol en
-- app_metadata para que viaje en el JWT.
--
-- Alternativa considerada: una Edge Function con service_role que llame a
-- auth.admin.updateUserById(id, { app_metadata: { rol } }) tras el signup. Se
-- descarta por la prioridad #1 (simplicidad): anade un salto de red y una
-- funcion desplegable para algo que Postgres resuelve en el mismo trigger. No
-- hay recursion: solo existe trigger AFTER INSERT sobre auth.users (no AFTER
-- UPDATE), asi que el UPDATE de raw_app_meta_data no vuelve a disparar.
--
-- SECURITY DEFINER + search_path vacio: la funcion corre como su dueno (con
-- permiso para escribir en auth.users y public.usuario) y todo objeto va
-- calificado por esquema para evitar secuestro de search_path.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nombre    text := nullif(trim(new.raw_user_meta_data ->> 'nombre'), '');
  v_documento text := nullif(trim(new.raw_user_meta_data ->> 'documento'), '');
  v_rol       text := upper(nullif(trim(new.raw_user_meta_data ->> 'rol'), ''));
begin
  if v_nombre is null then
    raise exception 'El nombre del usuario es obligatorio en raw_user_meta_data.'
      using errcode = 'OR001';
  end if;

  if v_rol is null or v_rol not in ('ADMINISTRADOR', 'CONDUCTOR') then
    raise exception 'El rol del usuario debe ser ADMINISTRADOR o CONDUCTOR.'
      using errcode = 'OR002';
  end if;

  insert into public.usuario (id, nombre, documento, rol)
  values (new.id, v_nombre, v_documento, v_rol);

  update auth.users
     set raw_app_meta_data =
           coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('rol', v_rol)
   where id = new.id;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Trigger: auditoria de la fila de perfil (columnas estandar pobladas con
-- auth.uid()). Solo escribe columnas de auditoria; la logica con ramas de
-- negocio no vive en triggers.
-- ---------------------------------------------------------------------------
create or replace function public.usuario_set_audit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.creado_por := auth.uid();
    new.fecha_creacion := now();
  else
    new.creado_por := old.creado_por;
    new.fecha_creacion := old.fecha_creacion;
    new.modificado_por := auth.uid();
    new.fecha_modificacion := now();
  end if;
  return new;
end;
$$;

create trigger usuario_set_audit
  before insert or update on public.usuario
  for each row execute function public.usuario_set_audit();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.usuario enable row level security;

-- Denegar por defecto: sin grants ni politicas la tabla es inaccesible.
revoke all on public.usuario from anon, authenticated;

-- Lectura para usuarios autenticados (las politicas acotan que filas).
grant select on public.usuario to authenticated;

-- El administrador solo puede actualizar estos campos: RLS no filtra por
-- columna, asi que el acotamiento se hace con grant a nivel de columna.
grant update (nombre, rol, activo) on public.usuario to authenticated;

-- Cada quien ve unicamente su propia fila.
create policy usuario_select_propio
  on public.usuario
  for select
  to authenticated
  using (id = (select auth.uid()));

-- El administrador ve todas las filas.
create policy usuario_select_admin
  on public.usuario
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- El administrador actualiza (limitado por el grant de columnas de arriba).
create policy usuario_update_admin
  on public.usuario
  for update
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- Sin politicas de INSERT/DELETE para anon/authenticated: las filas nacen por
-- el trigger on_auth_user_created y mueren por ON DELETE CASCADE con auth.users.
