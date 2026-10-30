-- pgTAP: correcciones de la auditoria 2026-10-13 (20261013110000_auditoria_correcciones.sql).
-- Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(38);

-- ---------------------------------------------------------------------------
-- Datos de prueba
--   admin AD, conductor A (viaje ASIGNADO), conductor B (licencia vencida),
--   "extrano" X (rol CONDUCTOR sin fila en conductor), cliente y flota.
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-0000000000ad',
   'authenticated', 'authenticated', 'admin.audit@optiruta.test', '{"nombre":"Admin Audit"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000a1',
   'authenticated', 'authenticated', 'conductor.a.audit@optiruta.test', '{"nombre":"Conductor A"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000b1',
   'authenticated', 'authenticated', 'conductor.b.audit@optiruta.test', '{"nombre":"Conductor B"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000c1',
   'authenticated', 'authenticated', 'conductor.c.audit@optiruta.test', '{"nombre":"Conductor C"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000e1',
   'authenticated', 'authenticated', 'extrano.audit@optiruta.test', '{"nombre":"Extrano"}', now(), now());

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000ad';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-0000000000ad';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'CONDUCTOR')
 where id in ('c0000000-0000-0000-0000-0000000000a1', 'c0000000-0000-0000-0000-0000000000b1',
              'c0000000-0000-0000-0000-0000000000c1', 'c0000000-0000-0000-0000-0000000000e1');

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo, odometro_inicial_km)
values
  ('51000000-0000-0000-0000-0000000000a1', 'AUD001', 'DOBLE_TROQUE', 17, 9, true, 1000),
  ('51000000-0000-0000-0000-0000000000a2', 'AUD002', 'DOBLE_TROQUE', 17, 9, true, 1000),
  ('51000000-0000-0000-0000-0000000000a3', 'AUD003', 'DOBLE_TROQUE', 17, 9, true, 1000),
  ('51000000-0000-0000-0000-0000000000a4', 'AUD004', 'DOBLE_TROQUE', 17, 9, true, 1000),
  ('51000000-0000-0000-0000-0000000000a5', 'AUD005', 'DOBLE_TROQUE', 17, 9, true, 1000),
  ('51000000-0000-0000-0000-0000000000a6', 'AUD006', 'DOBLE_TROQUE', 17, 9, true, 1000);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values
  ('61000000-0000-0000-0000-0000000000a1', 'c0000000-0000-0000-0000-0000000000a1', 'LIC-AUD-A', date '2030-01-01', 'COMISION', 10, 0, true),
  ('61000000-0000-0000-0000-0000000000b1', 'c0000000-0000-0000-0000-0000000000b1', 'LIC-AUD-B', date '2020-01-01', 'COMISION', 10, 0, true),
  ('61000000-0000-0000-0000-0000000000c1', 'c0000000-0000-0000-0000-0000000000c1', 'LIC-AUD-C', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre, correo)
values ('71000000-0000-0000-0000-0000000000a1', 'Cliente Audit A', 'audit@cliente.test'),
       ('71000000-0000-0000-0000-0000000000a2', 'Cliente Audit B', null);

insert into public.tarifa_combustible (ciudad, precio_galon, fecha_vigencia_desde, fuente)
values ('Auditoria', 10000, public.hoy_bogota() - 10, 'MANUAL');

-- Viajes: a1 (conductor A, ASIGNADO), b1 (conductor B, ASIGNADO).
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, distancia_estimada)
values
  ('81000000-0000-0000-0000-0000000000a1', 'AUD-REM-1', '51000000-0000-0000-0000-0000000000a1',
   '61000000-0000-0000-0000-0000000000a1', '71000000-0000-0000-0000-0000000000a1', 'Auditoria', 'Bogota', 'ASIGNADO', 1000000, 100),
  ('81000000-0000-0000-0000-0000000000b1', 'AUD-REM-B', '51000000-0000-0000-0000-0000000000a2',
   '61000000-0000-0000-0000-0000000000b1', '71000000-0000-0000-0000-0000000000a1', 'Auditoria', 'Bogota', 'ASIGNADO', 1000000, 100);

insert into public.costo_viaje (viaje_id, categoria, valor_estimado, fuente)
values ('81000000-0000-0000-0000-0000000000a1', 'ACPM', 150000, 'AUTOMATICO'),
       ('81000000-0000-0000-0000-0000000000a1', 'COMISION', 100000, 'AUTOMATICO');

-- ---------------------------------------------------------------------------
-- #1 viaje_cambiar_estado no es un atajo para saltarse las reglas de salida
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000a1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select public.viaje_cambiar_estado('81000000-0000-0000-0000-0000000000a1', 'EN_CURSO') $$,
  'OR105', null, 'el conductor no puede pasar a EN_CURSO por viaje_cambiar_estado (sin checklist ni documentos)'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0000000-0000-0000-0000-0000000000ad', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select throws_ok(
  $$ select public.viaje_cambiar_estado('81000000-0000-0000-0000-0000000000a1', 'EN_CURSO') $$,
  'OR145', null, 'ni siquiera el administrador inicia un viaje por viaje_cambiar_estado'
);
select throws_ok(
  $$ select public.viaje_cambiar_estado('81000000-0000-0000-0000-0000000000a1', 'CERRADO') $$,
  'OR145', null, 'cerrar solo se hace con viaje_cerrar (sella fecha_cierre)'
);
select throws_ok(
  $$ select public.viaje_cambiar_estado('81000000-0000-0000-0000-0000000000a1', 'CANCELADO') $$,
  'OR145', null, 'cancelar solo se hace con viaje_cancelar (motivo obligatorio)'
);

reset role;

-- ---------------------------------------------------------------------------
-- #2 Lecturas por RLS: el extrano no ve datos; el conductor solo lo suyo
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000e1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select is(
  (select count(*)::int from public.cliente), 0,
  'un usuario CONDUCTOR sin fila en conductor no lee clientes'
);
select is(
  (select count(*)::int from public.vehiculo), 0,
  'un usuario CONDUCTOR sin fila en conductor no lee la flota'
);
select is(
  (select count(*)::int from public.tarifa_combustible), 0,
  'un usuario CONDUCTOR sin fila en conductor no lee tarifas'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000a1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select is(
  (select count(*)::int from public.cliente), 1,
  'el conductor solo ve el cliente de su viaje'
);
select is(
  (select count(*)::int from public.vehiculo), 1,
  'el conductor solo ve el vehiculo de su viaje'
);

-- ---------------------------------------------------------------------------
-- #9 El conductor no toca su comision; solo confirma costos de un viaje en curso/finalizado
-- ---------------------------------------------------------------------------
select is(
  (with upd as (
     update public.costo_viaje set valor_real = 120000
      where viaje_id = '81000000-0000-0000-0000-0000000000a1' and categoria = 'ACPM' returning 1
   ) select count(*)::int from upd),
  0,
  'con el viaje ASIGNADO el conductor no confirma costos'
);

reset role;
update public.viaje set estado = 'EN_CURSO' where id = '81000000-0000-0000-0000-0000000000a1';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000a1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select lives_ok(
  $$ update public.costo_viaje set valor_real = 120000
      where viaje_id = '81000000-0000-0000-0000-0000000000a1' and categoria = 'ACPM' $$,
  'con el viaje EN_CURSO el conductor confirma el ACPM real'
);
select throws_ok(
  $$ update public.costo_viaje set valor_real = 1
      where viaje_id = '81000000-0000-0000-0000-0000000000a1' and categoria = 'COMISION' $$,
  'OR115', null, 'el conductor no puede fijar el valor real de su propia comision'
);

-- ---------------------------------------------------------------------------
-- #4 / #13 viaje_crear: conductor ocupado y flete valido
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0000000-0000-0000-0000-0000000000ad', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select throws_ok(
  $$ select public.viaje_crear('AUD-REM-2', '51000000-0000-0000-0000-0000000000a3',
       '61000000-0000-0000-0000-0000000000a1', '71000000-0000-0000-0000-0000000000a1',
       'Auditoria', 'Cali', now(), 100, 120, 10, 1000000) $$,
  'OR146', null, 'un conductor con un viaje asignado o en curso no recibe otro'
);

select throws_ok(
  $$ select public.viaje_crear('AUD-REM-3', '51000000-0000-0000-0000-0000000000a3',
       '61000000-0000-0000-0000-0000000000c1', '71000000-0000-0000-0000-0000000000a1',
       'Auditoria', 'Cali', now(), 100, 120, 10, 0) $$,
  'OR130', null, 'el flete de un viaje nuevo debe ser mayor a 0'
);

select lives_ok(
  $$ select public.viaje_crear('AUD-REM-4', '51000000-0000-0000-0000-0000000000a3',
       '61000000-0000-0000-0000-0000000000c1', '71000000-0000-0000-0000-0000000000a1',
       'Auditoria', 'Cali', now(), 100, 120, 10, 1000000) $$,
  'con conductor y vehiculo libres el viaje se crea'
);

reset role;

select is(
  (select count(*)::int from public.notificacion n join public.viaje v on v.id = n.viaje_id
    where v.remision = 'AUD-REM-4' and n.titulo in ('Sin tarifa de ACPM', 'ACPM sin calcular')),
  0,
  'con tarifa y datos validos no hay aviso de ACPM'
);

-- ---------------------------------------------------------------------------
-- #11 Conductor con licencia vencida no puede comenzar el viaje
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000b1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select public.viaje_iniciar('81000000-0000-0000-0000-0000000000b1', 6.2442, -75.5812) $$,
  'OR149', null, 'con la licencia vencida no se puede comenzar el viaje'
);

reset role;
update public.usuario set activo = false where id = 'c0000000-0000-0000-0000-0000000000b1';
update public.conductor set fecha_vencimiento_licencia = date '2030-01-01'
 where id = '61000000-0000-0000-0000-0000000000b1';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000b1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select public.viaje_iniciar('81000000-0000-0000-0000-0000000000b1', 6.2442, -75.5812) $$,
  'OR149', null, 'un usuario inactivo no puede comenzar el viaje'
);

reset role;
update public.conductor set fecha_vencimiento_licencia = date '2020-01-01'
 where id = '61000000-0000-0000-0000-0000000000c1';
update public.usuario set activo = true where id = 'c0000000-0000-0000-0000-0000000000b1';

select notificacion_generar();
select is(
  (select count(*)::int from public.notificacion
    where tipo = 'DOCUMENTO_VENCIDO' and titulo = 'Licencia vencida' and mensaje like 'La licencia de Conductor C%'),
  1,
  'la licencia vencida genera una alerta al administrador'
);
select notificacion_generar();
select is(
  (select count(*)::int from public.notificacion
    where tipo = 'DOCUMENTO_VENCIDO' and titulo = 'Licencia vencida' and mensaje like 'La licencia de Conductor C%'),
  1,
  'la alerta de licencia no se repite'
);

-- ---------------------------------------------------------------------------
-- #5 Ajustes numericos de un viaje cerrado
--   flete 1.000.000, ACPM real 200.000 => marginal 800.000
-- ---------------------------------------------------------------------------
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, distancia_estimada)
values ('81000000-0000-0000-0000-0000000000c1', 'AUD-REM-C', '51000000-0000-0000-0000-0000000000a5',
        '61000000-0000-0000-0000-0000000000a1', '71000000-0000-0000-0000-0000000000a1', 'A', 'B', 'FINALIZADO', 1000000, 100);
insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
values ('81000000-0000-0000-0000-0000000000c1', 'ACPM', 150000, 200000, 'AUTOMATICO');

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0000000-0000-0000-0000-0000000000ad', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select throws_ok(
  $$ select public.viaje_registrar_ajuste_v2('81000000-0000-0000-0000-0000000000c1', 'x', 'FLETE', 1200000) $$,
  'OR147', null, 'solo se ajusta un viaje cerrado'
);

select lives_ok($$ select public.viaje_cerrar('81000000-0000-0000-0000-0000000000c1') $$, 'se cierra el viaje');

select throws_ok(
  $$ select public.viaje_registrar_ajuste_v2('81000000-0000-0000-0000-0000000000c1', 'x', 'INVENTADO', 5) $$,
  'OR148', null, 'el concepto debe ser FLETE o una categoria de costo'
);

select lives_ok(
  $$ select public.viaje_registrar_ajuste_v2('81000000-0000-0000-0000-0000000000c1', 'El cliente pago un recargo', 'FLETE', 1200000) $$,
  'el administrador ajusta el flete de un viaje cerrado'
);
select lives_ok(
  $$ select public.viaje_registrar_ajuste_v2('81000000-0000-0000-0000-0000000000c1', 'El recibo traia otro valor', 'ACPM', 250000) $$,
  'el administrador ajusta el ACPM de un viaje cerrado'
);

select is(
  (select rentabilidad from public.rentabilidad_marginal('81000000-0000-0000-0000-0000000000c1')),
  950000::numeric,
  'la rentabilidad marginal incluye los ajustes: 1.200.000 - 250.000'
);

select is(
  (select total_flete::text || '/' || total_costos_directos::text
     from public.rentabilidad_consolidada_v2(public.hoy_bogota() - 1, public.hoy_bogota() + 1,
            null, null, '51000000-0000-0000-0000-0000000000a5')),
  '1200000/250000',
  'la rentabilidad consolidada incluye los ajustes'
);

select is(
  (select (costos_por_categoria ->> 'ACPM')::numeric
     from public.rentabilidad_consolidada_v3(public.hoy_bogota() - 1, public.hoy_bogota() + 1,
            null, null, '51000000-0000-0000-0000-0000000000a5')),
  250000::numeric,
  'el desglose por categoria incluye los ajustes de costo'
);

reset role;

-- ---------------------------------------------------------------------------
-- #7 / #8 Cancelar y eliminar con encuesta; cancelar en ruta conserva los km
-- ---------------------------------------------------------------------------
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, distancia_estimada)
values ('81000000-0000-0000-0000-0000000000d1', 'AUD-REM-D', '51000000-0000-0000-0000-0000000000a6',
        '61000000-0000-0000-0000-0000000000c1', '71000000-0000-0000-0000-0000000000a1', 'A', 'B', 'ASIGNADO', 1000000, 500),
       ('81000000-0000-0000-0000-0000000000d2', 'AUD-REM-E', '51000000-0000-0000-0000-0000000000a4',
        '61000000-0000-0000-0000-0000000000b1', '71000000-0000-0000-0000-0000000000a2', 'A', 'B', 'ASIGNADO', 1000000, 500);

update public.viaje set estado = 'EN_CURSO' where id = '81000000-0000-0000-0000-0000000000d1';
insert into public.ubicacion_viaje (viaje_id, lat, lng, fecha_hora) values
  ('81000000-0000-0000-0000-0000000000d1', 6.0, -75.0, now() - interval '20 minutes'),
  ('81000000-0000-0000-0000-0000000000d1', 6.1, -75.0, now() - interval '10 minutes');

update public.viaje set estado = 'EN_CURSO' where id = '81000000-0000-0000-0000-0000000000d2';
update public.viaje set estado = 'FINALIZADO' where id = '81000000-0000-0000-0000-0000000000d2';

select is(
  (select estado from public.encuesta_satisfaccion where viaje_id = '81000000-0000-0000-0000-0000000000d2'),
  'SIN_CONTACTO',
  'al finalizar nace la encuesta (cliente sin correo => SIN_CONTACTO)'
);

select throws_ok(
  $$ update public.viaje set estado = 'CERRADO' where id = '81000000-0000-0000-0000-0000000000d2' $$,
  '23514', null, 'un viaje no pasa a CERRADO sin fecha_cierre'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0000000-0000-0000-0000-0000000000ad', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select lives_ok(
  $$ select public.viaje_eliminar('81000000-0000-0000-0000-0000000000d2', 'Cargado por error') $$,
  'un viaje FINALIZADO con encuesta sin responder se puede eliminar'
);
select is(
  (select count(*)::int from public.encuesta_satisfaccion where viaje_id = '81000000-0000-0000-0000-0000000000d2'),
  0,
  'al eliminar el viaje se borra su encuesta sin responder'
);

select lives_ok(
  $$ select public.viaje_cancelar('81000000-0000-0000-0000-0000000000d1', 'Cliente cancelo en ruta') $$,
  'se cancela un viaje en curso'
);

reset role;

select ok(
  (select km_recorridos from public.viaje where id = '81000000-0000-0000-0000-0000000000d1') between 10.9 and 11.3,
  'cancelado en ruta conserva los ~11 km medidos por GPS (no la distancia estimada de 500)'
);

select is(
  (select vehiculo_odometro_km('51000000-0000-0000-0000-0000000000a6')) between 1010.9 and 1011.3,
  true,
  'el odometro suma los km del viaje cancelado en ruta'
);

-- ---------------------------------------------------------------------------
-- #8 Mantenimiento registrado sin km queda con el odometro derivado de su fecha
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0000000-0000-0000-0000-0000000000ad', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select is(
  (public.mantenimiento_registrar('51000000-0000-0000-0000-0000000000a1', 'Engrase', 80000,
     public.hoy_bogota() - 40, null,
     (select id from public.tipo_mantenimiento where codigo = 'ENGRASE'))).kilometraje,
  1000::numeric,
  'un mantenimiento pasado sin km toma el odometro derivado a esa fecha (no queda nulo)'
);

reset role;

-- ---------------------------------------------------------------------------
-- #13 El precio automatico de ACPM no pisa una tarifa manual de la misma fecha
-- ---------------------------------------------------------------------------
set local role service_role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);

select is(
  (select aplicado from public.tarifa_combustible_registrar_automatico(
     'Auditoria', 10100, public.hoy_bogota() - 10)),
  false,
  'el scraper no sobrescribe una tarifa manual del mismo dia'
);

reset role;

select is(
  (select precio_galon from public.tarifa_combustible
    where ciudad = 'Auditoria' and fecha_vigencia_desde = public.hoy_bogota() - 10),
  10000::numeric,
  'la tarifa manual conserva su precio'
);

select * from finish();

rollback;
