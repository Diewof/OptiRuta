-- pgTAP: cierre de brechas de requisitos (RF-11, RF-14, RF-20, RF-24, RF-25).
-- Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(13);

select has_column(
  'public', 'costo_viaje', 'descripcion',
  'RF-14: existe costo_viaje.descripcion'
);

-- ---------------------------------------------------------------------------
-- Datos de prueba
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-0000000000cb',
   'authenticated', 'authenticated', 'admin.brechas@optiruta.test', '{"nombre":"Admin Brechas"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000cb',
   'authenticated', 'authenticated', 'conductor.brechas@optiruta.test', '{"nombre":"Conductor Brechas"}', now(), now());

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000cb';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-0000000000cb';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'CONDUCTOR')
 where id = 'c0000000-0000-0000-0000-0000000000cb';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('11111111-0000-0000-0000-0000000000cb', 'BRC001', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values ('22222222-0000-0000-0000-0000000000cb', 'c0000000-0000-0000-0000-0000000000cb', 'LIC-BRC-001', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre)
values ('33333333-0000-0000-0000-0000000000cb', 'Cliente Brechas');

-- Viaje cerrado: 100 km, estimado 600 min, hizo 300 min; ACPM real 200.000.
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, distancia_estimada, tiempo_estimado_min, valor_flete, estado)
values ('44444444-0000-0000-0000-0000000000c1', 'BRC-REM-001',
  '11111111-0000-0000-0000-0000000000cb', '22222222-0000-0000-0000-0000000000cb', '33333333-0000-0000-0000-0000000000cb',
  'Medellin', 'Bogota', 100, 600, 1000000, 'ASIGNADO');
update public.viaje set estado = 'EN_CURSO' where id = '44444444-0000-0000-0000-0000000000c1';
insert into public.hito_viaje (viaje_id, tipo, fecha_hora) values
  ('44444444-0000-0000-0000-0000000000c1', 'SALIDA', now() - interval '10 hours'),
  ('44444444-0000-0000-0000-0000000000c1', 'LLEGADA_DESTINO', now() - interval '5 hours');
insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
values ('44444444-0000-0000-0000-0000000000c1', 'ACPM', 150000, 200000, 'AUTOMATICO');
update public.viaje set estado = 'FINALIZADO' where id = '44444444-0000-0000-0000-0000000000c1';
update public.viaje set estado = 'CERRADO', fecha_cierre = now() where id = '44444444-0000-0000-0000-0000000000c1';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('11111111-0000-0000-0000-0000000000cd', 'BRC003', 'DOBLE_TROQUE', 17, 9, true);

-- Viajes EN_CURSO para el margen de retraso (estimado 600 min => margen 120 min).
insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('11111111-0000-0000-0000-0000000000cc', 'BRC002', 'DOBLE_TROQUE', 17, 9, true);

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, tiempo_estimado_min, valor_flete, estado)
values ('44444444-0000-0000-0000-0000000000c2', 'BRC-REM-002',
  '11111111-0000-0000-0000-0000000000cc', '22222222-0000-0000-0000-0000000000cb', '33333333-0000-0000-0000-0000000000cb',
  'Cali', 'Pasto', 600, 1000000, 'ASIGNADO');
update public.viaje set estado = 'EN_CURSO' where id = '44444444-0000-0000-0000-0000000000c2';
-- 11 h de camino con 10 h estimadas: dentro del margen (12 h), aun sin retraso.
insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
values ('44444444-0000-0000-0000-0000000000c2', 'SALIDA', now() - interval '11 hours');

select public.notificacion_generar();

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'RETRASO' and viaje_id = '44444444-0000-0000-0000-0000000000c2'),
  0,
  'RF-20: dentro del margen (20% o 30 min) no se notifica retraso'
);

update public.hito_viaje set fecha_hora = now() - interval '13 hours'
 where viaje_id = '44444444-0000-0000-0000-0000000000c2' and tipo = 'SALIDA';

select public.notificacion_generar();

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'RETRASO' and viaje_id = '44444444-0000-0000-0000-0000000000c2'),
  1,
  'RF-20: pasado el margen se notifica el retraso'
);

-- ---------------------------------------------------------------------------
-- RF-24/25: metricas (solo administrador)
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'a0000000-0000-0000-0000-0000000000cb',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR')
  )::text,
  true
);

select is(
  (select costo_por_km from public.metricas_periodo(current_date - 1, current_date + 1)),
  2000.00,
  'RF-24: costo por km = costos directos / km (200.000 / 100)'
);

select is(
  (select viajes_a_tiempo || '/' || viajes_medidos from public.metricas_periodo(current_date - 1, current_date + 1)),
  '1/1',
  'RF-25: el viaje que llego dentro del estimado cuenta como a tiempo'
);

select is(
  (select clave from public.metricas_por_dimension(current_date - 1, current_date + 1, 'RUTA')),
  'Medellin → Bogota',
  'RF-25: agrupa por ruta'
);

select is(
  (select rentabilidad from public.metricas_por_dimension(current_date - 1, current_date + 1, 'CLIENTE')),
  800000::numeric,
  'RF-25: rentabilidad por cliente = flete - costos'
);

select throws_ok(
  $$ select * from public.metricas_por_dimension(current_date, current_date, 'OTRA') $$,
  'OR121',
  null,
  'RF-25: rechaza una dimension desconocida'
);

-- ---------------------------------------------------------------------------
-- RF-11: sin tarifa de ACPM para el origen, el viaje se crea y se avisa
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ select public.viaje_crear(
       'BRC-REM-003', '11111111-0000-0000-0000-0000000000cd',
       '22222222-0000-0000-0000-0000000000cb', '33333333-0000-0000-0000-0000000000cb',
       'Ciudad Sin Tarifa', 'Bogota', now(), 300, 400, 20, 2000000
     ) $$,
  'RF-11: viaje_crear no falla cuando no hay tarifa de ACPM'
);

select is(
  (select count(*)::int from public.notificacion n
     join public.viaje v on v.id = n.viaje_id
    where v.remision = 'BRC-REM-003' and n.tipo = 'NOVEDAD' and n.titulo = 'Sin tarifa de ACPM'),
  1,
  'RF-11: avisa al administrador que el ACPM estimado quedo en $0'
);

-- ---------------------------------------------------------------------------
-- RF-14: el conductor agrega un costo libre en su viaje en curso
-- ---------------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'c0000000-0000-0000-0000-0000000000cb',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR')
  )::text,
  true
);

select throws_ok(
  $$ select * from public.metricas_periodo(current_date, current_date) $$,
  'OR105',
  null,
  'las metricas son solo para el administrador'
);

select lives_ok(
  $$ insert into public.costo_viaje (viaje_id, categoria, descripcion, valor_estimado, valor_real, fuente)
     values ('44444444-0000-0000-0000-0000000000c2', 'OTRO', 'Grua', 0, 350000, 'MANUAL') $$,
  'RF-14: el conductor agrega un costo OTRO con descripcion en su viaje en curso'
);

select throws_ok(
  $$ insert into public.costo_viaje (viaje_id, categoria, descripcion, valor_estimado, valor_real, fuente)
     values ('44444444-0000-0000-0000-0000000000c2', 'OTRO', 'Grua 2', 100, 350000, 'MANUAL') $$,
  '42501',
  null,
  'RF-14: el conductor no puede fijar un estimado en un costo libre'
);

reset role;

select * from finish();

rollback;
