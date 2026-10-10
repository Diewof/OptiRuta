-- pgTAP: viaje_iniciar (radio de 500 m al punto de inicio) y bloqueo del
-- INSERT directo del hito SALIDA. Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(9);

insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000c1',
   'authenticated', 'authenticated', 'conductor1.inicio@optiruta.test', '{"nombre":"Conductor Uno"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000c2',
   'authenticated', 'authenticated', 'conductor2.inicio@optiruta.test', '{"nombre":"Conductor Dos"}', now(), now());

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values
  ('55555555-0000-0000-0000-0000000000c1', 'INI001', 'DOBLE_TROQUE', 17, 9, true),
  ('55555555-0000-0000-0000-0000000000c2', 'INI002', 'MULA', 30, 7, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values
  ('66666666-0000-0000-0000-0000000000c1', 'c0000000-0000-0000-0000-0000000000c1', 'LIC-INI-001', date '2030-01-01', 'COMISION', 10, 0, true),
  ('66666666-0000-0000-0000-0000000000c2', 'c0000000-0000-0000-0000-0000000000c2', 'LIC-INI-002', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre) values ('77777777-0000-0000-0000-0000000000c1', 'Cliente Inicio');

-- Origen en 6.2442, -75.5812 (Medellin). Uno con coordenadas y uno antiguo sin ellas.
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino,
                          origen_lat, origen_lng, estado, valor_flete)
values
  ('88888888-0000-0000-0000-0000000000c1', 'INI-REM-1', '55555555-0000-0000-0000-0000000000c1',
   '66666666-0000-0000-0000-0000000000c1', '77777777-0000-0000-0000-0000000000c1',
   'Medellín', 'Bogotá', 6.2442, -75.5812, 'ASIGNADO', 4000000),
  ('88888888-0000-0000-0000-0000000000c2', 'INI-REM-2', '55555555-0000-0000-0000-0000000000c2',
   '66666666-0000-0000-0000-0000000000c1', '77777777-0000-0000-0000-0000000000c1',
   'Cali', 'Bogotá', null, null, 'ASIGNADO', 4000000);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000c1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

-- ~1.1 km al norte del origen (0.01 grados de latitud).
select throws_ok(
  $$ select public.viaje_iniciar('88888888-0000-0000-0000-0000000000c1', 6.2542, -75.5812) $$,
  'OR120', null,
  'no se puede comenzar el viaje a mas de 500 m del punto de inicio'
);

select throws_ok(
  $$ select public.viaje_iniciar('88888888-0000-0000-0000-0000000000c1', null, null) $$,
  'OR117', null,
  'sin ubicacion no se puede comenzar el viaje'
);

select throws_ok(
  $$ insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
     values ('88888888-0000-0000-0000-0000000000c1', 'SALIDA', now()) $$,
  '42501', null,
  'el conductor no registra SALIDA con INSERT directo'
);

-- ~220 m al norte (0.002 grados).
select is(
  (public.viaje_iniciar('88888888-0000-0000-0000-0000000000c1', 6.2462, -75.5812)).estado,
  'EN_CURSO',
  'a 220 m del inicio el viaje pasa a EN_CURSO'
);

select throws_ok(
  $$ select public.viaje_iniciar('88888888-0000-0000-0000-0000000000c1', 6.2462, -75.5812) $$,
  'OR119', null,
  'un viaje ya en curso no se puede comenzar otra vez'
);

select is(
  (public.viaje_iniciar('88888888-0000-0000-0000-0000000000c2', 1.0, -70.0)).estado,
  'EN_CURSO',
  'un viaje sin coordenadas de origen se inicia sin validar la distancia'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000c2', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select public.viaje_iniciar('88888888-0000-0000-0000-0000000000c1', 6.2442, -75.5812) $$,
  'OR103', null,
  'un conductor no comienza el viaje de otro'
);

reset role;

select is(
  (select count(*)::int from public.hito_viaje
    where viaje_id = '88888888-0000-0000-0000-0000000000c1' and tipo = 'SALIDA'),
  1,
  'viaje_iniciar registra un solo hito SALIDA'
);

select is(
  (select estado from public.viaje where id = '88888888-0000-0000-0000-0000000000c1'),
  'EN_CURSO',
  'el viaje queda EN_CURSO en la base'
);

select * from finish();

rollback;
