-- pgTAP: consentimiento y ubicacion del viaje (RF-21/23) y reporte_viajes
-- (RF-27). Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

select has_table('public', 'ubicacion_viaje', 'existe public.ubicacion_viaje');

select is(
  (select relrowsecurity from pg_class where oid = 'public.ubicacion_viaje'::regclass),
  true,
  'RLS habilitado en ubicacion_viaje'
);

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'ubicacion_viaje'
      and cmd in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'sin politicas de escritura: el historial de ubicacion no se edita'
);

-- ---------------------------------------------------------------------------
-- Datos de prueba
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-0000000000ab',
   'authenticated', 'authenticated', 'admin.ubi@optiruta.test', '{"nombre":"Admin Ubi"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000ab',
   'authenticated', 'authenticated', 'conductor.ubi@optiruta.test', '{"nombre":"Conductor Ubi"}', now(), now());

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000ab';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-0000000000ab';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'CONDUCTOR')
 where id = 'c0000000-0000-0000-0000-0000000000ab';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('11111111-0000-0000-0000-0000000000ab', 'UBI001', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values ('22222222-0000-0000-0000-0000000000ab', 'c0000000-0000-0000-0000-0000000000ab', 'LIC-UBI-001', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre) values
  ('33333333-0000-0000-0000-0000000000ab', 'Cliente Ubi'),
  ('33333333-0000-0000-0000-0000000000ac', 'Otro Cliente');

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, valor_flete, estado)
values ('44444444-0000-0000-0000-0000000000ab', 'UBI-REM-001',
  '11111111-0000-0000-0000-0000000000ab', '22222222-0000-0000-0000-0000000000ab', '33333333-0000-0000-0000-0000000000ab',
  'Medellin', 'Bogota', 1000000, 'ASIGNADO');
update public.viaje set estado = 'EN_CURSO' where id = '44444444-0000-0000-0000-0000000000ab';

-- ---------------------------------------------------------------------------
-- Conductor: sin consentimiento no se registra; con consentimiento si
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'c0000000-0000-0000-0000-0000000000ab',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR')
  )::text,
  true
);

select throws_ok(
  $$ select public.viaje_registrar_ubicacion('44444444-0000-0000-0000-0000000000ab', 6.2, -75.5) $$,
  'OR122',
  null,
  'RF-23: sin consentimiento no se registra la ubicacion'
);

select isnt(
  public.conductor_consentimiento_ubicacion(true),
  null,
  'RF-23: el conductor acepta y queda la fecha'
);

select is(
  public.viaje_registrar_ubicacion('44444444-0000-0000-0000-0000000000ab', 6.2, -75.5),
  true,
  'RF-21: con consentimiento guarda el punto'
);

select is(
  public.viaje_registrar_ubicacion('44444444-0000-0000-0000-0000000000ab', 6.3, -75.6),
  false,
  'RF-21: un segundo punto en menos de 4 minutos se descarta'
);

-- ---------------------------------------------------------------------------
-- Reporte: solo administrador
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ select * from public.reporte_viajes(current_date - 1, current_date) $$,
  'OR105',
  null,
  'RF-27: el reporte es solo para el administrador'
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'a0000000-0000-0000-0000-0000000000ab',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR')
  )::text,
  true
);

select is(
  (select count(*)::int from public.ubicacion_viaje where viaje_id = '44444444-0000-0000-0000-0000000000ab'),
  1,
  'RF-21: el administrador lee los puntos del viaje'
);

select is(
  (select count(*)::int from public.reporte_viajes(current_date - 1, current_date + 1,
     '33333333-0000-0000-0000-0000000000ac', null, null, null)),
  0,
  'RF-27: un filtro por otro cliente no devuelve el viaje'
);

reset role;

select * from finish();

rollback;
