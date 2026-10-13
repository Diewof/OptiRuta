-- pgTAP: viaje_registrar_hito (orden y FINALIZADO), comision de conductor FIJO,
-- viaje_actualizar y usuario.rol no editable. Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(11);

insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-0000000000ee',
   'authenticated', 'authenticated', 'admin.hito@optiruta.test', '{"nombre":"Admin Hito"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000ee',
   'authenticated', 'authenticated', 'conductor.hito@optiruta.test', '{"nombre":"Conductor Hito"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000ef',
   'authenticated', 'authenticated', 'conductor.fijo@optiruta.test', '{"nombre":"Conductor Fijo"}', now(), now());

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000ee';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-0000000000ee';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'CONDUCTOR')
 where id in ('c0000000-0000-0000-0000-0000000000ee', 'c0000000-0000-0000-0000-0000000000ef');

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo) values
  ('11111111-0000-0000-0000-0000000000ee', 'HIT001', 'DOBLE_TROQUE', 17, 9, true),
  ('11111111-0000-0000-0000-0000000000ef', 'HIT002', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo) values
  ('22222222-0000-0000-0000-0000000000ee', 'c0000000-0000-0000-0000-0000000000ee', 'LIC-HIT-001', date '2030-01-01', 'COMISION', 10, 0, true),
  ('22222222-0000-0000-0000-0000000000ef', 'c0000000-0000-0000-0000-0000000000ef', 'LIC-HIT-002', date '2030-01-01', 'FIJO', 10, 2000000, true);

insert into public.cliente (id, nombre) values ('33333333-0000-0000-0000-0000000000ee', 'Cliente Hito');

-- Viaje EN_CURSO con SALIDA ya registrada.
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, valor_flete, estado)
values ('44444444-0000-0000-0000-0000000000e1', 'HIT-REM-1',
  '11111111-0000-0000-0000-0000000000ee', '22222222-0000-0000-0000-0000000000ee', '33333333-0000-0000-0000-0000000000ee',
  'A', 'B', 1000000, 'ASIGNADO');
update public.viaje set estado = 'EN_CURSO' where id = '44444444-0000-0000-0000-0000000000e1';
insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
values ('44444444-0000-0000-0000-0000000000e1', 'SALIDA', now() - interval '2 hours');
insert into public.costo_viaje (viaje_id, categoria, valor_estimado, fuente)
values ('44444444-0000-0000-0000-0000000000e1', 'COMISION', 100000, 'AUTOMATICO');

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'c0000000-0000-0000-0000-0000000000ee', 'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text,
  true
);

select throws_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000e1', 'LLEGADA_DESTINO') $$,
  'OR127', null, 'no se puede llegar a destino sin los hitos anteriores'
);

select lives_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000e1', 'LLEGADA_CARGUE') $$,
  'registra LLEGADA_CARGUE en orden'
);

select throws_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000e1', 'LLEGADA_CARGUE') $$,
  'OR128', null, 'no se repite un hito'
);

select throws_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000e1', 'SALIDA_CON_CARGA', now() + interval '1 day') $$,
  'OR129', null, 'la hora del hito no puede ser futura'
);

select throws_ok(
  $$ insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
     values ('44444444-0000-0000-0000-0000000000e1', 'SALIDA_CON_CARGA', now()) $$,
  '42501', null, 'el conductor ya no inserta hitos directo en la tabla'
);

select lives_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000e1', 'SALIDA_CON_CARGA') $$,
  'registra SALIDA_CON_CARGA'
);

select lives_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000e1', 'LLEGADA_DESTINO') $$,
  'registra LLEGADA_DESTINO'
);

select is(
  (select estado from public.viaje where id = '44444444-0000-0000-0000-0000000000e1'),
  'FINALIZADO',
  'LLEGADA_DESTINO deja el viaje FINALIZADO'
);

-- ---------------------------------------------------------------------------
-- Admin: viaje_actualizar y comision FIJO
-- ---------------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a0000000-0000-0000-0000-0000000000ee', 'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text,
  true
);

select is(
  (select valor_flete from public.viaje_actualizar(
     '44444444-0000-0000-0000-0000000000e1', now(), 20, 2000000)),
  2000000::numeric,
  'RF-04: el administrador edita el flete'
);

select is(
  (select valor_estimado from public.costo_viaje
    where viaje_id = '44444444-0000-0000-0000-0000000000e1' and categoria = 'COMISION'),
  200000.00,
  'RF-04: la comision estimada se recalcula (10% de 2.000.000)'
);

insert into public.tarifa_combustible (ciudad, precio_galon, fecha_vigencia_desde)
values ('Fijolandia', 10000, current_date - 10);

select is(
  (select valor_estimado from public.costo_viaje c
    where c.categoria = 'COMISION'
      and c.viaje_id = (public.viaje_crear(
        'HIT-REM-2', '11111111-0000-0000-0000-0000000000ef',
        '22222222-0000-0000-0000-0000000000ef', '33333333-0000-0000-0000-0000000000ee',
        'Fijolandia', 'B', now(), 100, 120, 10, 1000000)).id),
  0.00,
  'RF-15: un conductor con pago FIJO no genera comision en el viaje'
);

reset role;

select * from finish();

rollback;
