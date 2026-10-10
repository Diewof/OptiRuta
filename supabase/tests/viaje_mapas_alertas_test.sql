-- pgTAP: coordenadas de viaje, viaje_crear_v2 y viaje_registrar_alerta
-- (parada prolongada / desvio de ruta). Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(18);

select has_column('public', 'viaje', 'origen_lat', 'existe viaje.origen_lat');
select has_column('public', 'viaje', 'ruta_polilinea', 'existe viaje.ruta_polilinea');

-- ---------------------------------------------------------------------------
-- Datos de prueba: un admin, dos conductores, un viaje EN_CURSO del primero
-- y uno PLANIFICADO.
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-0000000000bb',
   'authenticated', 'authenticated', 'admin.mapas@optiruta.test', '{"nombre":"Admin Mapas"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000b1',
   'authenticated', 'authenticated', 'conductor1.mapas@optiruta.test', '{"nombre":"Conductor Uno"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000b2',
   'authenticated', 'authenticated', 'conductor2.mapas@optiruta.test', '{"nombre":"Conductor Dos"}', now(), now());

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000bb';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-0000000000bb';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('55555555-0000-0000-0000-0000000000b1', 'MAP001', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values
  ('66666666-0000-0000-0000-0000000000b1', 'c0000000-0000-0000-0000-0000000000b1', 'LIC-MAP-001', date '2030-01-01', 'COMISION', 10, 0, true),
  ('66666666-0000-0000-0000-0000000000b2', 'c0000000-0000-0000-0000-0000000000b2', 'LIC-MAP-002', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre) values ('77777777-0000-0000-0000-0000000000b1', 'Cliente Mapas');

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete)
values
  ('88888888-0000-0000-0000-0000000000b1', 'MAP-REM-EC', '55555555-0000-0000-0000-0000000000b1',
   '66666666-0000-0000-0000-0000000000b1', '77777777-0000-0000-0000-0000000000b1',
   'Medellín', 'Cartagena', 'EN_CURSO', 5000000),
  ('88888888-0000-0000-0000-0000000000b2', 'MAP-REM-PL', '55555555-0000-0000-0000-0000000000b1',
   '66666666-0000-0000-0000-0000000000b1', '77777777-0000-0000-0000-0000000000b1',
   'Medellín', 'Bogotá', 'PLANIFICADO', 4000000);

insert into public.tarifa_combustible (ciudad, precio_galon, fecha_vigencia_desde)
values ('Bogotá', 10500, current_date - 30), ('Cúcuta', 9000, current_date - 30);

-- ---------------------------------------------------------------------------
-- Constraints de coordenadas
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ update public.viaje set origen_lat = 6.2 where id = '88888888-0000-0000-0000-0000000000b2' $$,
  '23514', null,
  'no se admite una latitud sin su longitud'
);

select throws_ok(
  $$ update public.viaje set origen_lat = 95, origen_lng = -75 where id = '88888888-0000-0000-0000-0000000000b2' $$,
  '23514', null,
  'la latitud debe estar entre -90 y 90'
);

-- ---------------------------------------------------------------------------
-- viaje_crear_v2 (administrador)
-- ---------------------------------------------------------------------------
-- El vehiculo ya tiene un viaje EN_CURSO, asi que se usa uno libre.
reset role;
insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('55555555-0000-0000-0000-0000000000b2', 'MAP002', 'MULA', 30, 7, true);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0000000-0000-0000-0000-0000000000bb', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select lives_ok(
  $$ select public.viaje_crear_v2(
       'MAP-REM-V2', '55555555-0000-0000-0000-0000000000b2',
       '66666666-0000-0000-0000-0000000000b2', '77777777-0000-0000-0000-0000000000b1',
       'Bogotá', 'Barranquilla', 4.711, -74.0721, 10.9685, -74.7813, '_p~iF~ps|U_ulLnnqC',
       now() + interval '1 day', 1012, 1080, 28, 9200000
     ) $$,
  'viaje_crear_v2 crea el viaje con coordenadas'
);

select is(
  (select ruta_polilinea from public.viaje where remision = 'MAP-REM-V2'),
  '_p~iF~ps|U_ulLnnqC',
  'viaje_crear_v2 guarda el trazado'
);

select is(
  (select destino_lat from public.viaje where remision = 'MAP-REM-V2'),
  10.9685::double precision,
  'viaje_crear_v2 guarda las coordenadas del destino'
);

select throws_ok(
  $$ select public.viaje_crear_v2(
       'MAP-REM-V3', '55555555-0000-0000-0000-0000000000b2',
       '66666666-0000-0000-0000-0000000000b2', '77777777-0000-0000-0000-0000000000b1',
       'Bogotá', 'Cali', null, null, 3.4, -76.5, null,
       now(), 500, 600, 20, 3000000
     ) $$,
  'OR117', null,
  'viaje_crear_v2 exige ubicacion de origen y destino'
);

select isnt(
  public.costo_acpm_estimado(
    '55555555-0000-0000-0000-0000000000b2', 1000, 'Terminal de carga, Bogotá, Cundinamarca'
  ),
  null,
  'costo_acpm_estimado encuentra la tarifa por la ciudad contenida en el nombre del lugar'
);

select isnt(
  public.costo_acpm_estimado(
    '55555555-0000-0000-0000-0000000000b2', 1000, 'Calle 5, CUCUTA, Norte de Santander'
  ),
  null,
  'costo_acpm_estimado compara la ciudad sin tildes ni mayusculas'
);

-- ---------------------------------------------------------------------------
-- viaje_registrar_alerta
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000b1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select is(
  public.viaje_registrar_alerta('88888888-0000-0000-0000-0000000000b1', 'PARADA_PROLONGADA', 7.1, -75.5),
  true,
  'el conductor registra una parada prolongada en su viaje EN_CURSO'
);

select is(
  public.viaje_registrar_alerta('88888888-0000-0000-0000-0000000000b1', 'PARADA_PROLONGADA', 7.1, -75.5),
  false,
  'una alerta repetida en la ventana de 60 min no se duplica'
);

select throws_ok(
  $$ select public.viaje_registrar_alerta('88888888-0000-0000-0000-0000000000b2', 'DESVIO_RUTA', 7.1, -75.5) $$,
  'OR118', null,
  'no se registran alertas en un viaje que no esta EN_CURSO'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000b2', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select public.viaje_registrar_alerta('88888888-0000-0000-0000-0000000000b1', 'DESVIO_RUTA', 7.1, -75.5) $$,
  'OR103', null,
  'un conductor no registra alertas de un viaje ajeno'
);

select throws_ok(
  $$ select public.viaje_registrar_alerta('88888888-0000-0000-0000-0000000000b1', 'OTRO', 7.1, -75.5) $$,
  'OR116', null,
  'tipo de alerta invalido'
);

reset role;

select is(
  (select count(*)::int from public.notificacion
    where viaje_id = '88888888-0000-0000-0000-0000000000b1' and tipo = 'PARADA_PROLONGADA'),
  1,
  'queda una sola notificacion de parada para el administrador'
);

select results_eq(
  $$ select lat, lng from public.notificacion
      where viaje_id = '88888888-0000-0000-0000-0000000000b1' and tipo = 'PARADA_PROLONGADA' $$,
  $$ values (7.1::double precision, -75.5::double precision) $$,
  'la notificacion guarda la ubicacion donde se detecto la parada'
);

select throws_ok(
  $$ insert into public.notificacion (tipo, titulo, mensaje, lat)
     values ('NOVEDAD', 'x', 'x', 7.1) $$,
  '23514', null,
  'una notificacion no admite una latitud sin su longitud'
);

select * from finish();

rollback;
