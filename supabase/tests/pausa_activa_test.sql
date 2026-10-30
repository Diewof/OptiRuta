-- pgTAP: pausa activa (prueba del administrador y alerta por ignorarla).
-- Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-0000000000cc',
   'authenticated', 'authenticated', 'admin.pausa@optiruta.test', '{"nombre":"Admin Pausa"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000c1',
   'authenticated', 'authenticated', 'conductor1.pausa@optiruta.test', '{"nombre":"Conductor Pausa"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000c2',
   'authenticated', 'authenticated', 'conductor2.pausa@optiruta.test', '{"nombre":"Conductor Ajeno"}', now(), now());

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000cc';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('55555555-0000-0000-0000-0000000000c1', 'PAU001', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values
  ('66666666-0000-0000-0000-0000000000c1', 'c0000000-0000-0000-0000-0000000000c1', 'LIC-PAU-001', date '2030-01-01', 'COMISION', 10, 0, true),
  ('66666666-0000-0000-0000-0000000000c2', 'c0000000-0000-0000-0000-0000000000c2', 'LIC-PAU-002', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre) values ('77777777-0000-0000-0000-0000000000c1', 'Cliente Pausa');

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete)
values
  ('88888888-0000-0000-0000-0000000000c1', 'PAU-REM-EC', '55555555-0000-0000-0000-0000000000c1',
   '66666666-0000-0000-0000-0000000000c1', '77777777-0000-0000-0000-0000000000c1',
   'Medellín', 'Cartagena', 'EN_CURSO', 5000000);

set local role authenticated;

-- Conductor sin orden de prueba
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000c1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select is(
  public.viaje_consumir_pausa_prueba('88888888-0000-0000-0000-0000000000c1'),
  false,
  'sin orden de prueba no hay aviso'
);

select throws_ok(
  $$ select public.viaje_probar_pausa_activa('88888888-0000-0000-0000-0000000000c1') $$,
  'OR105', null,
  'el conductor no puede lanzar la prueba'
);

-- Administrador lanza la prueba
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0000000-0000-0000-0000-0000000000cc', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select lives_ok(
  $$ select public.viaje_probar_pausa_activa('88888888-0000-0000-0000-0000000000c1') $$,
  'el administrador lanza la prueba en un viaje EN_CURSO'
);

-- Otro conductor no la recibe
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000c2', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select is(
  public.viaje_consumir_pausa_prueba('88888888-0000-0000-0000-0000000000c1'),
  false,
  'un conductor ajeno no recibe la prueba'
);

-- El conductor del viaje la recibe una sola vez
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000c1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select is(
  public.viaje_consumir_pausa_prueba('88888888-0000-0000-0000-0000000000c1'),
  true,
  'el conductor recibe la prueba'
);

select is(
  public.viaje_consumir_pausa_prueba('88888888-0000-0000-0000-0000000000c1'),
  false,
  'la prueba se entrega una sola vez'
);

-- Ignorar la alerta notifica al administrador
select is(
  public.viaje_registrar_pausa_ignorada('88888888-0000-0000-0000-0000000000c1', 250, 15, true),
  true,
  'ignorar la pausa activa crea la notificacion'
);

select is(
  public.viaje_registrar_pausa_ignorada('88888888-0000-0000-0000-0000000000c1', 260, 25, false),
  false,
  'no se repite dentro de 60 minutos'
);

select throws_ok(
  $$ select public.viaje_registrar_pausa_ignorada('88888888-0000-0000-0000-0000000000c1', -1, 15) $$,
  'OR116', null,
  'rechaza minutos negativos'
);

reset role;

select matches(
  (select mensaje from public.notificacion
    where tipo = 'PAUSA_ACTIVA_IGNORADA' and viaje_id = '88888888-0000-0000-0000-0000000000c1'),
  'Conductor Pausa.*PAU-REM-EC.*4 h 10 min.*15 min.*Prueba',
  'el mensaje incluye conductor, viaje y lo que hizo'
);

select * from finish();
rollback;
