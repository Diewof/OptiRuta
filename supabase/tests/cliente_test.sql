-- pgTAP: tabla cliente (Fase 3 del plan de features) - lectura amplia
-- (admin y conductor) y escritura solo-admin, mas las columnas documento y
-- direccion agregadas en 20260918211500_cliente_documento_direccion.sql.
-- Se corre con `supabase test db`. pgTAP se habilita dentro de la transaccion
-- y el rollback final lo deshace: no llega a produccion.

begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

-- ---------------------------------------------------------------------------
-- Estructura
-- ---------------------------------------------------------------------------
select has_table('public', 'cliente', 'existe la tabla public.cliente');
select has_column('public', 'cliente', 'documento', 'cliente tiene columna documento');
select has_column('public', 'cliente', 'direccion', 'cliente tiene columna direccion');

select is(
  (select relrowsecurity from pg_class where oid = 'public.cliente'::regclass),
  true,
  'RLS habilitado en public.cliente'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'cliente'
      and cmd = 'DELETE'),
  0,
  'sin politicas de DELETE en public.cliente (baja logica con activo=false)'
);

-- ---------------------------------------------------------------------------
-- Datos de prueba: un admin y un conductor
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  (
    '00000000-0000-0000-0000-000000000000',
    'a1000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated',
    'admin.cli@optiruta.test',
    '{"nombre":"Admin Cliente"}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'c1000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated',
    'conductor.cli@optiruta.test',
    '{"nombre":"Conductor Cliente"}',
    now(), now()
  );

update public.usuario
   set rol = 'ADMINISTRADOR'
 where id = 'a1000000-0000-0000-0000-000000000001';

update auth.users
   set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a1000000-0000-0000-0000-000000000001';

insert into public.cliente (nombre, documento, telefono, direccion, activo)
values ('Cliente Prueba pgTAP', '900555666-1', '3009998877', 'Cra 9 # 9-09, Medellin', true);

-- ---------------------------------------------------------------------------
-- Lectura: el admin ve todo; el conductor solo los clientes de sus viajes
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'c1000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR')
  )::text,
  true
);

select is(
  (select count(*)::int from public.cliente where nombre = 'Cliente Prueba pgTAP'),
  0,
  'un conductor sin viajes con ese cliente no lo ve (solo los clientes de sus viajes)'
);

-- ---------------------------------------------------------------------------
-- Escritura: solo admin
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.cliente (nombre) values ('Colado') $$,
  '42501',
  null,
  'un conductor no puede INSERT en public.cliente'
);

select is(
  (with upd as (
     update public.cliente set telefono = '000' where nombre = 'Cliente Prueba pgTAP' returning 1
   )
   select count(*)::int from upd),
  0,
  'un conductor no puede UPDATE public.cliente (RLS filtra la fila, 0 afectadas)'
);

reset role;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'a1000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR')
  )::text,
  true
);
set local role authenticated;

select lives_ok(
  $$ insert into public.cliente (nombre, documento, telefono, direccion)
     values ('Cliente Admin pgTAP', '900777888-3', '3001112200', 'Cra 5 # 5-05, Medellin') $$,
  'el administrador puede INSERT en public.cliente'
);

select lives_ok(
  $$ update public.cliente set direccion = 'Nueva direccion 123'
      where nombre = 'Cliente Prueba pgTAP' $$,
  'el administrador puede UPDATE public.cliente, incluida la columna direccion nueva'
);

reset role;

select * from finish();

rollback;
