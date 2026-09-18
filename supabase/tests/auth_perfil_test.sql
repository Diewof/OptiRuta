-- pgTAP: tabla usuario, trigger de creacion de perfil y politicas RLS.
-- Se corre con `supabase test db`. pgTAP se habilita dentro de la transaccion
-- y el rollback final lo deshace: no llega a produccion.

begin;

create extension if not exists pgtap with schema extensions;

select plan(13);

-- ---------------------------------------------------------------------------
-- Estructura
-- ---------------------------------------------------------------------------
select has_table('public', 'usuario', 'existe la tabla public.usuario');

select has_column('public', 'usuario', 'rol', 'usuario tiene columna rol');

select col_has_check(
  'public', 'usuario', 'rol',
  'rol tiene CHECK (lista cerrada ADMINISTRADOR/CONDUCTOR)'
);

select is(
  (select relrowsecurity from pg_class where oid = 'public.usuario'::regclass),
  true,
  'RLS habilitado en public.usuario'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'usuario'
      and cmd in ('INSERT', 'DELETE')),
  0,
  'sin politicas de INSERT/DELETE en public.usuario'
);

-- ---------------------------------------------------------------------------
-- Trigger on_auth_user_created: crea el perfil y refleja el rol en app_metadata
-- ---------------------------------------------------------------------------
-- El cliente intenta colarse como ADMINISTRADOR en el signup; debe ignorarse.
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values (
  '00000000-0000-0000-0000-000000000000',
  '33333333-3333-3333-3333-333333333333',
  'authenticated', 'authenticated',
  'trigger@optiruta.test',
  '{"nombre":"Trigger Prueba","rol":"ADMINISTRADOR"}',
  now(), now()
);

select is(
  (select count(*)::int from public.usuario where id = '33333333-3333-3333-3333-333333333333'),
  1,
  'el trigger creo la fila en public.usuario'
);

select is(
  (select nombre from public.usuario where id = '33333333-3333-3333-3333-333333333333'),
  'Trigger Prueba',
  'el trigger mapeo el nombre desde raw_user_meta_data'
);

select is(
  (select rol from public.usuario where id = '33333333-3333-3333-3333-333333333333'),
  'CONDUCTOR',
  'todo usuario nuevo nace CONDUCTOR (se ignora el rol que mande el cliente)'
);

select is(
  (select raw_app_meta_data ->> 'rol' from auth.users where id = '33333333-3333-3333-3333-333333333333'),
  'CONDUCTOR',
  'el trigger escribio rol=CONDUCTOR en app_metadata (viaja en el JWT)'
);

-- Alta sin metadata (p. ej. desde el dashboard): nombre cae en la parte local
-- del correo y no falla.
insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at)
values (
  '00000000-0000-0000-0000-000000000000',
  '66666666-6666-6666-6666-666666666666',
  'authenticated', 'authenticated',
  'sinmeta@optiruta.test',
  now(), now()
);

select is(
  (select nombre from public.usuario where id = '66666666-6666-6666-6666-666666666666'),
  'sinmeta',
  'sin metadata, el nombre cae en la parte local del correo'
);

-- ---------------------------------------------------------------------------
-- Segundo usuario para probar aislamiento entre perfiles
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values (
  '00000000-0000-0000-0000-000000000000',
  '44444444-4444-4444-4444-444444444444',
  'authenticated', 'authenticated',
  'otro@optiruta.test',
  '{"nombre":"Otro Conductor","rol":"CONDUCTOR"}',
  now(), now()
);

-- ---------------------------------------------------------------------------
-- RLS: un authenticated no-admin solo ve su propia fila
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '33333333-3333-3333-3333-333333333333',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR')
  )::text,
  true
);

select is(
  (select count(*)::int from public.usuario),
  1,
  'un conductor solo ve su propia fila (RLS)'
);

select throws_ok(
  $$ insert into public.usuario (id, nombre, rol)
     values ('55555555-5555-5555-5555-555555555555', 'Colado', 'CONDUCTOR') $$,
  '42501',
  null,
  'un authenticated no puede INSERT en public.usuario'
);

select throws_ok(
  $$ delete from public.usuario where id = '33333333-3333-3333-3333-333333333333' $$,
  '42501',
  null,
  'un authenticated no puede DELETE en public.usuario'
);

reset role;

select * from finish();

rollback;
