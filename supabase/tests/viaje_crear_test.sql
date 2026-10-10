-- pgTAP: columna fecha_salida_programada y RPC viaje_crear con el nuevo
-- parametro. Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

select has_column(
  'public', 'viaje', 'fecha_salida_programada',
  'existe la columna public.viaje.fecha_salida_programada'
);

-- ---------------------------------------------------------------------------
-- Datos de prueba
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values (
  '00000000-0000-0000-0000-000000000000',
  'a0000000-0000-0000-0000-0000000000aa',
  'authenticated', 'authenticated',
  'admin.vc-fecha@optiruta.test',
  '{"nombre":"Admin Fecha"}',
  now(), now()
), (
  '00000000-0000-0000-0000-000000000000',
  'c0000000-0000-0000-0000-0000000000aa',
  'authenticated', 'authenticated',
  'conductor.vc-fecha@optiruta.test',
  '{"nombre":"Conductor Fecha"}',
  now(), now()
);

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000aa';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-0000000000aa';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('55555555-0000-0000-0000-000000000001', 'VCF001', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values ('66666666-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-0000000000aa', 'LIC-VCF-001', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre)
values ('77777777-0000-0000-0000-000000000001', 'Cliente Fecha');

insert into public.tarifa_combustible (ciudad, precio_galon, fecha_vigencia_desde)
values ('Bogotá', 10500, current_date - 30);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'a0000000-0000-0000-0000-0000000000aa',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR')
  )::text,
  true
);

select lives_ok(
  $$ select public.viaje_crear(
       'VCF-REM-001',
       '55555555-0000-0000-0000-000000000001',
       '66666666-0000-0000-0000-000000000001',
       '77777777-0000-0000-0000-000000000001',
       'Bogotá', 'Barranquilla',
       (current_date + 3)::timestamptz + interval '6 hours',
       1012, 1080, 28, 9200000
     ) $$,
  'viaje_crear acepta p_fecha_salida_programada'
);

select is(
  (select fecha_salida_programada::date from public.viaje where remision = 'VCF-REM-001'),
  current_date + 3,
  'el viaje creado guarda la fecha de salida programada'
);

select is(
  (select estado from public.viaje where remision = 'VCF-REM-001'),
  'ASIGNADO',
  'el viaje creado nace ASIGNADO'
);

reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'c0000000-0000-0000-0000-0000000000aa',
    'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR')
  )::text,
  true
);

select throws_ok(
  $$ select public.viaje_crear(
       'VCF-REM-002', '55555555-0000-0000-0000-000000000001',
       '66666666-0000-0000-0000-000000000001', '77777777-0000-0000-0000-000000000001',
       'Bogotá', 'Cali', now(), 500, 600, 20, 3000000
     ) $$,
  'OR105',
  null,
  'un conductor no puede crear un viaje'
);

reset role;

select * from finish();

rollback;
