-- pgTAP: cancelar y eliminar viajes, y filtros del Resumen (v2).
-- Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-0000000000dd',
   'authenticated', 'authenticated', 'admin.cancel@optiruta.test', '{"nombre":"Admin Cancel"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000dd',
   'authenticated', 'authenticated', 'conductor.cancel@optiruta.test', '{"nombre":"Conductor Cancel"}', now(), now());

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000dd';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-0000000000dd';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'CONDUCTOR')
 where id = 'c0000000-0000-0000-0000-0000000000dd';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('11111111-0000-0000-0000-0000000000dd', 'CAN001', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values ('22222222-0000-0000-0000-0000000000dd', 'c0000000-0000-0000-0000-0000000000dd', 'LIC-CAN-001', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre) values ('33333333-0000-0000-0000-0000000000dd', 'Cliente Cancel');

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, valor_flete, estado) values
  ('44444444-0000-0000-0000-0000000000d1', 'CAN-REM-1', '11111111-0000-0000-0000-0000000000dd', '22222222-0000-0000-0000-0000000000dd', '33333333-0000-0000-0000-0000000000dd', 'A', 'B', 1000000, 'ASIGNADO'),
  ('44444444-0000-0000-0000-0000000000d2', 'CAN-REM-2', '11111111-0000-0000-0000-0000000000dd', '22222222-0000-0000-0000-0000000000dd', '33333333-0000-0000-0000-0000000000dd', 'A', 'B', 1000000, 'FINALIZADO'),
  ('44444444-0000-0000-0000-0000000000d3', 'CAN-REM-3', '11111111-0000-0000-0000-0000000000dd', '22222222-0000-0000-0000-0000000000dd', '33333333-0000-0000-0000-0000000000dd', 'A', 'B', 1000000, 'FINALIZADO');
update public.viaje set estado = 'CERRADO', fecha_cierre = now() where id = '44444444-0000-0000-0000-0000000000d3';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'c0000000-0000-0000-0000-0000000000dd', 'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text,
  true
);

select throws_ok(
  $$ select public.viaje_cancelar('44444444-0000-0000-0000-0000000000d1', 'Motivo valido') $$,
  'OR105', null, 'un conductor no puede cancelar viajes'
);
select throws_ok(
  $$ select public.viaje_eliminar('44444444-0000-0000-0000-0000000000d1', 'Motivo valido') $$,
  'OR105', null, 'un conductor no puede eliminar viajes'
);

select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a0000000-0000-0000-0000-0000000000dd', 'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text,
  true
);

select throws_ok(
  $$ select public.viaje_cancelar('44444444-0000-0000-0000-0000000000d1', 'no') $$,
  'OR124', null, 'cancelar exige un motivo de al menos 5 caracteres'
);

select is(
  (select estado from public.viaje_cancelar('44444444-0000-0000-0000-0000000000d1', 'Cliente desistio')),
  'CANCELADO',
  'el administrador cancela un viaje asignado'
);

select is(
  (select motivo_cancelacion from public.viaje where id = '44444444-0000-0000-0000-0000000000d1'),
  'Cliente desistio',
  'el motivo queda guardado'
);

select throws_ok(
  $$ select public.viaje_cancelar('44444444-0000-0000-0000-0000000000d1', 'Otra vez cancelado') $$,
  'OR125', null, 'un viaje cancelado no se vuelve a cancelar'
);

select throws_ok(
  $$ select public.viaje_cancelar('44444444-0000-0000-0000-0000000000d3', 'Intento sobre cerrado') $$,
  'OR125', null, 'un viaje cerrado no se puede cancelar'
);

select throws_ok(
  $$ select public.viaje_eliminar('44444444-0000-0000-0000-0000000000d3', 'Intento sobre cerrado') $$,
  'OR100', null, 'un viaje cerrado no se puede eliminar'
);

select lives_ok(
  $$ select public.viaje_eliminar('44444444-0000-0000-0000-0000000000d2', 'Cargado por error') $$,
  'el administrador elimina un viaje no cerrado'
);

select is(
  (select count(*)::int from public.viaje where id = '44444444-0000-0000-0000-0000000000d2'),
  0,
  'el viaje eliminado ya no existe'
);

select is(
  (select motivo from public.viaje_eliminado where remision = 'CAN-REM-2'),
  'Cargado por error',
  'queda la bitacora con el motivo'
);

-- Filtros del Resumen: otro cliente no ve el viaje cerrado.
select is(
  (select viajes_incluidos from public.rentabilidad_consolidada_v2(
     current_date - 1, current_date + 1, '33333333-0000-0000-0000-0000000000de', null, null, null)),
  0,
  'el filtro por otro cliente excluye el viaje cerrado'
);

reset role;

select * from finish();

rollback;
