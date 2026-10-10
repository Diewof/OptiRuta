-- pgTAP: el alta via Google se rechaza; el alta por correo sigue funcionando.
begin;

create extension if not exists pgtap with schema extensions;

select plan(2);

select throws_ok(
  $$insert into auth.users (instance_id, id, aud, role, email, raw_app_meta_data, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000',
            '44444444-4444-4444-4444-444444444444',
            'authenticated', 'authenticated', 'nuevo-google@optiruta.test',
            '{"provider":"google","providers":["google"]}', now(), now())$$,
  'OR002',
  null,
  'no se crea un usuario nuevo con provider google'
);

select lives_ok(
  $$insert into auth.users (instance_id, id, aud, role, email, raw_app_meta_data, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000',
            '55555555-5555-5555-5555-555555555555',
            'authenticated', 'authenticated', 'nuevo-correo@optiruta.test',
            '{"provider":"email","providers":["email"]}', now(), now())$$,
  'el alta con provider email sigue permitida'
);

select * from finish();
rollback;
