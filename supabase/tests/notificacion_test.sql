-- pgTAP: tabla notificacion (RLS solo-admin) y notificacion_generar()
-- (documentos por vencer, retrasos, viajes completados, peajes).
-- Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

-- ---------------------------------------------------------------------------
-- Estructura
-- ---------------------------------------------------------------------------
select has_table('public', 'notificacion', 'existe la tabla public.notificacion');

select is(
  (select relrowsecurity from pg_class where oid = 'public.notificacion'::regclass),
  true,
  'RLS habilitado en public.notificacion'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'notificacion'
      and cmd in ('INSERT', 'DELETE')),
  0,
  'sin politicas de INSERT/DELETE en public.notificacion (solo notificacion_generar escribe filas nuevas)'
);

-- ---------------------------------------------------------------------------
-- Datos de prueba: un admin, un conductor, un vehiculo con documento por
-- vencer, un viaje EN_CURSO con retraso y otro FINALIZADO, y un peaje de hoy.
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  (
    '00000000-0000-0000-0000-000000000000',
    'a0000000-0000-0000-0000-00000000000a',
    'authenticated', 'authenticated',
    'admin.notif@optiruta.test',
    '{"nombre":"Admin Notif"}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'c0000000-0000-0000-0000-00000000000a',
    'authenticated', 'authenticated',
    'conductor.notif@optiruta.test',
    '{"nombre":"Conductor Notif"}',
    now(), now()
  );

update public.usuario
   set rol = 'ADMINISTRADOR'
 where id = 'a0000000-0000-0000-0000-00000000000a';

update auth.users
   set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-00000000000a';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('11111111-0000-0000-0000-000000000001', 'NTF001', 'DOBLE_TROQUE', 17, 9, true);

insert into public.documento_vehiculo (vehiculo_id, tipo, fecha_vencimiento)
values ('11111111-0000-0000-0000-000000000001', 'SOAT', current_date + 10);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values ('22222222-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-00000000000a', 'LIC-NTF-001', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre)
values ('33333333-0000-0000-0000-000000000001', 'Cliente Notif');

-- Viaje EN_CURSO cuya salida + tiempo estimado ya paso (retraso).
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, tiempo_estimado_min, valor_flete, estado)
values (
  '44444444-0000-0000-0000-000000000001', 'NTF-REM-001',
  '11111111-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001',
  'Origen Test', 'Destino Test', 60, 1000000, 'ASIGNADO'
);
update public.viaje set estado = 'EN_CURSO' where id = '44444444-0000-0000-0000-000000000001';

insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
values ('44444444-0000-0000-0000-000000000001', 'SALIDA', now() - interval '3 hours');

-- Viaje FINALIZADO (completado).
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, tiempo_estimado_min, valor_flete, estado)
values (
  '44444444-0000-0000-0000-000000000002', 'NTF-REM-002',
  '11111111-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001',
  'Origen Test 2', 'Destino Test 2', 60, 1000000, 'ASIGNADO'
);
update public.viaje set estado = 'EN_CURSO' where id = '44444444-0000-0000-0000-000000000002';
update public.viaje set estado = 'FINALIZADO' where id = '44444444-0000-0000-0000-000000000002';

insert into public.peaje_capturado (viaje_id, placa, monto, fecha_hora, correo_origen_id)
values ('44444444-0000-0000-0000-000000000001', 'NTF001', 12000, now(), 'correo-notif-test-1');

-- La alerta de viaje completado nace al finalizar (trigger), sin esperar al cron.
select is(
  (select count(*)::int from public.notificacion
    where tipo = 'VIAJE_COMPLETADO' and viaje_id = '44444444-0000-0000-0000-000000000002'),
  1,
  'la alerta de viaje completado se crea al pasar a FINALIZADO, antes de notificacion_generar'
);

-- ---------------------------------------------------------------------------
-- notificacion_generar(): crea las 4 alertas esperadas
-- ---------------------------------------------------------------------------
select notificacion_generar();

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'DOCUMENTO_POR_VENCER' and vehiculo_id = '11111111-0000-0000-0000-000000000001'),
  1,
  'genera una alerta de documento por vencer para el vehiculo'
);

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'RETRASO' and viaje_id = '44444444-0000-0000-0000-000000000001'),
  1,
  'genera una alerta de retraso para el viaje EN_CURSO fuera de tiempo'
);

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'VIAJE_COMPLETADO' and viaje_id = '44444444-0000-0000-0000-000000000002'),
  1,
  'genera una alerta de viaje completado para el viaje FINALIZADO'
);

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'PEAJE_REGISTRADO' and viaje_id = '44444444-0000-0000-0000-000000000001'),
  1,
  'genera una alerta de peajes registrados hoy para el viaje'
);

-- Idempotente: correr otra vez no duplica ninguna alerta.
select notificacion_generar();

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'RETRASO' and viaje_id = '44444444-0000-0000-0000-000000000001'),
  1,
  'notificacion_generar es idempotente: no duplica la alerta de retraso'
);

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'VIAJE_COMPLETADO' and viaje_id = '44444444-0000-0000-0000-000000000002'),
  1,
  'notificacion_generar es idempotente: no duplica la alerta de viaje completado'
);

-- ---------------------------------------------------------------------------
-- RLS: solo ADMINISTRADOR ve/edita notificaciones
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'c0000000-0000-0000-0000-00000000000a',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR')
  )::text,
  true
);

select is(
  (select count(*)::int from public.notificacion),
  0,
  'un conductor no ve ninguna notificacion'
);

select throws_ok(
  $$ insert into public.notificacion (tipo, titulo, mensaje)
     values ('NOVEDAD', 'x', 'x') $$,
  '42501',
  null,
  'un conductor no puede INSERT en public.notificacion'
);

reset role;

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'a0000000-0000-0000-0000-00000000000a',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR')
  )::text,
  true
);
set local role authenticated;

select is(
  (select count(*)::int from public.notificacion),
  4,
  'el administrador ve las 4 notificaciones generadas'
);

select throws_ok(
  $$ insert into public.notificacion (tipo, titulo, mensaje)
     values ('NOVEDAD', 'x', 'x') $$,
  '42501',
  null,
  'ni siquiera el administrador puede INSERT directo (solo notificacion_generar, SECURITY DEFINER)'
);

select is(
  (with upd as (
     update public.notificacion set leida = true
      where tipo = 'VIAJE_COMPLETADO' and viaje_id = '44444444-0000-0000-0000-000000000002'
     returning 1
   )
   select count(*)::int from upd),
  1,
  'el administrador puede marcar una notificacion como leida'
);

select throws_ok(
  $$ update public.notificacion set titulo = 'cambiado'
      where tipo = 'VIAJE_COMPLETADO' and viaje_id = '44444444-0000-0000-0000-000000000002' $$,
  '42501',
  null,
  'ni siquiera el administrador puede editar columnas distintas de leida (solo esa tiene grant)'
);

reset role;

select * from finish();

rollback;
