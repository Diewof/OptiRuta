-- pgTAP: tablas vehiculo y conductor (Fase 2 del plan de features) - RLS de
-- lectura amplia / escritura solo-admin en vehiculo, y aislamiento por
-- usuario_id en conductor salvo para el administrador.
-- Se corre con `supabase test db`. pgTAP se habilita dentro de la transaccion
-- y el rollback final lo deshace: no llega a produccion.

begin;

create extension if not exists pgtap with schema extensions;

select plan(17);

-- ---------------------------------------------------------------------------
-- Estructura
-- ---------------------------------------------------------------------------
select has_table('public', 'vehiculo', 'existe la tabla public.vehiculo');
select has_table('public', 'conductor', 'existe la tabla public.conductor');

select is(
  (select relrowsecurity from pg_class where oid = 'public.vehiculo'::regclass),
  true,
  'RLS habilitado en public.vehiculo'
);

select is(
  (select relrowsecurity from pg_class where oid = 'public.conductor'::regclass),
  true,
  'RLS habilitado en public.conductor'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'vehiculo'
      and cmd = 'DELETE'),
  0,
  'sin politicas de DELETE en public.vehiculo (baja logica con activo=false)'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'conductor'
      and cmd = 'DELETE'),
  0,
  'sin politicas de DELETE en public.conductor (baja logica con activo=false)'
);

-- ---------------------------------------------------------------------------
-- Datos de prueba: un admin y dos conductores
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  (
    '00000000-0000-0000-0000-000000000000',
    'a0000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated',
    'admin.vc@optiruta.test',
    '{"nombre":"Admin VC"}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'c0000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated',
    'conductor.vc1@optiruta.test',
    '{"nombre":"Conductor VC Uno"}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'c0000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated',
    'conductor.vc2@optiruta.test',
    '{"nombre":"Conductor VC Dos"}',
    now(), now()
  );

-- Promover el primero a ADMINISTRADOR (todo alta nace CONDUCTOR; promover es
-- una operacion aparte, igual que en produccion).
update public.usuario
   set rol = 'ADMINISTRADOR'
 where id = 'a0000000-0000-0000-0000-000000000001';

update auth.users
   set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-000000000001';

insert into public.vehiculo (placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values
  ('PGT001', 'DOBLE_TROQUE', 17, 9, true),
  ('PGT002', 'MULA', 34, 7, true);

insert into public.conductor (usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values
  ('c0000000-0000-0000-0000-000000000001', 'LIC-PGT-001', date '2030-01-01', 'COMISION', 10, 0, true),
  ('c0000000-0000-0000-0000-000000000002', 'LIC-PGT-002', date '2030-01-01', 'COMISION', 10, 0, true);

-- ---------------------------------------------------------------------------
-- vehiculo: lectura amplia para cualquier autenticado
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'c0000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR')
  )::text,
  true
);

select is(
  (select count(*)::int from public.vehiculo where placa in ('PGT001', 'PGT002')),
  0,
  'un conductor solo ve los vehiculos de sus propios viajes'
);

-- ---------------------------------------------------------------------------
-- vehiculo: escritura solo admin
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.vehiculo (placa, tipo, capacidad_carga, rendimiento_km_galon)
     values ('PGT999', 'MULA', 30, 8) $$,
  '42501',
  null,
  'un conductor no puede INSERT en public.vehiculo'
);

select is(
  (with upd as (
     update public.vehiculo set capacidad_carga = 99 where placa = 'PGT001' returning 1
   )
   select count(*)::int from upd),
  0,
  'un conductor no puede UPDATE public.vehiculo (RLS filtra la fila, 0 afectadas)'
);

reset role;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'a0000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR')
  )::text,
  true
);
set local role authenticated;

select lives_ok(
  $$ insert into public.vehiculo (placa, tipo, capacidad_carga, rendimiento_km_galon)
     values ('PGT999', 'MULA', 30, 8) $$,
  'el administrador puede INSERT en public.vehiculo'
);

select is(
  (with upd as (
     update public.vehiculo set capacidad_carga = 20 where placa = 'PGT001' returning 1
   )
   select count(*)::int from upd),
  1,
  'el administrador puede UPDATE public.vehiculo'
);

reset role;

-- ---------------------------------------------------------------------------
-- conductor: cada quien ve su propia fila; el administrador las ve todas
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'c0000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR')
  )::text,
  true
);

select is(
  (select count(*)::int from public.conductor),
  1,
  'un conductor solo ve su propia fila en public.conductor'
);

select is(
  (select usuario_id from public.conductor limit 1),
  'c0000000-0000-0000-0000-000000000001'::uuid,
  'la unica fila visible para el conductor es la suya'
);

select throws_ok(
  $$ insert into public.conductor (usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago)
     values ('c0000000-0000-0000-0000-000000000002', 'COLADO', current_date, 'FIJO') $$,
  '42501',
  null,
  'un conductor no puede INSERT en public.conductor'
);

select is(
  (with upd as (
     update public.conductor set sueldo_base = 999
      where usuario_id = 'c0000000-0000-0000-0000-000000000001'
     returning 1
   )
   select count(*)::int from upd),
  0,
  'un conductor no puede UPDATE ni siquiera su propia fila de public.conductor (solo admin edita)'
);

reset role;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'a0000000-0000-0000-0000-000000000001',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR')
  )::text,
  true
);
set local role authenticated;

select is(
  (select count(*)::int from public.conductor
    where usuario_id in ('c0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002')),
  2,
  'el administrador ve todas las filas de public.conductor'
);

select lives_ok(
  $$ update public.conductor set sueldo_base = 500000
      where usuario_id = 'c0000000-0000-0000-0000-000000000001' $$,
  'el administrador puede UPDATE public.conductor'
);

reset role;

select * from finish();

rollback;
