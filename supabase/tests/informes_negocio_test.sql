-- pgTAP: informes de inteligencia de negocios (rentabilidad por ruta/cliente/placa,
-- tiempos de espera con SALIDA_DESCARGUE, control de combustible y tanqueos).
-- Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(24);

-- ---------------------------------------------------------------------------
-- Datos
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-0000000000f1',
   'authenticated', 'authenticated', 'admin.informes@optiruta.test', '{"nombre":"Admin Informes"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000f1',
   'authenticated', 'authenticated', 'conductor.informes@optiruta.test', '{"nombre":"Conductor Informes"}', now(), now());

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000f1';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-0000000000f1';
update auth.users set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'CONDUCTOR')
 where id = 'c0000000-0000-0000-0000-0000000000f1';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('11111111-0000-0000-0000-0000000000f1', 'TST001', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values ('22222222-0000-0000-0000-0000000000f1', 'c0000000-0000-0000-0000-0000000000f1',
        'LIC-INF-001', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre) values ('33333333-0000-0000-0000-0000000000f1', 'Cliente TST');

-- Dos viajes por ventana con tanqueo y km GPS: 3 meses previos a 10 km/gal y
-- el mes del informe (marzo 2026) a 8 km/gal (caida de 20 %).
do $$
declare
  r record;
  v_id uuid;
begin
  for r in
    select * from (values
      ('TST-C1', timestamptz '2026-01-10 12:00-05', 1000, 100),
      ('TST-C2', timestamptz '2026-02-10 12:00-05', 1000, 100),
      ('TST-C3', timestamptz '2026-03-05 12:00-05', 800, 100),
      ('TST-C4', timestamptz '2026-03-15 12:00-05', 800, 100)
    ) as t(rem, llegada, km, gal)
  loop
    insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, valor_flete, estado)
    values (r.rem, '11111111-0000-0000-0000-0000000000f1', '22222222-0000-0000-0000-0000000000f1',
            '33333333-0000-0000-0000-0000000000f1', 'Medellín', 'Bogotá', 1000000, 'ASIGNADO')
    returning id into v_id;
    update public.viaje set estado = 'EN_CURSO' where id = v_id;
    insert into public.hito_viaje (viaje_id, tipo, fecha_hora) values (v_id, 'LLEGADA_DESTINO', r.llegada);
    update public.viaje set km_recorridos = r.km, km_origen = 'GPS' where id = v_id;
    update public.viaje set estado = 'FINALIZADO' where id = v_id;
    insert into public.tanqueo_viaje (viaje_id, galones, valor) values (v_id, r.gal, r.gal * 9000);
  end loop;
end
$$;

-- Viaje con espera de cargue de 4 h y de descargue de 2 h, y margen de 5 %.
do $$
declare
  v_id uuid;
begin
  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, valor_flete, estado)
  values ('TST-E1', '11111111-0000-0000-0000-0000000000f1', '22222222-0000-0000-0000-0000000000f1',
          '33333333-0000-0000-0000-0000000000f1', 'Cali', 'Pasto', 1000000, 'ASIGNADO')
  returning id into v_id;
  update public.viaje set estado = 'EN_CURSO' where id = v_id;
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora) values
    (v_id, 'SALIDA', timestamptz '2026-03-20 06:00-05'),
    (v_id, 'LLEGADA_CARGUE', timestamptz '2026-03-20 08:00-05'),
    (v_id, 'SALIDA_CON_CARGA', timestamptz '2026-03-20 12:00-05'),
    (v_id, 'LLEGADA_DESTINO', timestamptz '2026-03-20 20:00-05'),
    (v_id, 'SALIDA_DESCARGUE', timestamptz '2026-03-20 22:00-05');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_id, 'ACPM', 900000, 950000, 'AUTOMATICO');
  update public.viaje set estado = 'FINALIZADO' where id = v_id;
end
$$;

-- Viaje en curso para probar tanqueo y salida del descargue por RPC.
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, valor_flete, estado)
values ('44444444-0000-0000-0000-0000000000f1', 'TST-D1',
        '11111111-0000-0000-0000-0000000000f1', '22222222-0000-0000-0000-0000000000f1',
        '33333333-0000-0000-0000-0000000000f1', 'A', 'B', 1000000, 'ASIGNADO');
update public.viaje set estado = 'EN_CURSO' where id = '44444444-0000-0000-0000-0000000000f1';
insert into public.hito_viaje (viaje_id, tipo, fecha_hora) values
  ('44444444-0000-0000-0000-0000000000f1', 'SALIDA', now() - interval '5 hours'),
  ('44444444-0000-0000-0000-0000000000f1', 'LLEGADA_CARGUE', now() - interval '4 hours'),
  ('44444444-0000-0000-0000-0000000000f1', 'SALIDA_CON_CARGA', now() - interval '3 hours');
insert into public.costo_viaje (viaje_id, categoria, valor_estimado, fuente)
values ('44444444-0000-0000-0000-0000000000f1', 'ACPM', 500000, 'AUTOMATICO');

-- Alerta de espera (job): la de cargue (4 h > 3 h) del viaje TST-E1.
create temp table _alertas_espera as select public.espera_alertas_generar() as n;
select ok(
  exists (
    select 1 from public.notificacion n
     where n.tipo = 'ESPERA_EXCESIVA'
       and n.clave = 'ESP:' || (select id from public.viaje where remision = 'TST-E1') || ':CARGUE'
  ),
  'el job genera ESPERA_EXCESIVA cuando el cargue supera 3 h'
);

-- ---------------------------------------------------------------------------
-- Conductor: tanqueo y salida del descargue
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'c0000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text,
  true
);

select throws_ok(
  $$ select public.viaje_registrar_tanqueo('44444444-0000-0000-0000-0000000000f1', 0, 100000) $$,
  'OR151', null, 'el tanqueo exige galones mayores que 0'
);
select throws_ok(
  $$ select public.viaje_registrar_tanqueo('44444444-0000-0000-0000-0000000000f1', 10, 0) $$,
  'OR152', null, 'el tanqueo exige un valor mayor que 0'
);
select lives_ok(
  $$ select public.viaje_registrar_tanqueo('44444444-0000-0000-0000-0000000000f1', 50, 600000) $$,
  'el conductor registra un tanqueo en su viaje en curso'
);
select lives_ok(
  $$ select public.viaje_registrar_tanqueo('44444444-0000-0000-0000-0000000000f1', 10, 100000) $$,
  'el conductor registra un segundo tanqueo'
);
select is(
  (select valor_real from public.costo_viaje
    where viaje_id = '44444444-0000-0000-0000-0000000000f1' and categoria = 'ACPM'),
  700000::numeric,
  'el ACPM real del viaje es la suma de los tanqueos'
);

select throws_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000f1', 'SALIDA_DESCARGUE') $$,
  'OR118', null, 'la salida del descargue no se registra con el viaje en curso'
);
select lives_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000f1', 'LLEGADA_DESTINO') $$,
  'registra LLEGADA_DESTINO'
);
select throws_ok(
  $$ select public.viaje_registrar_tanqueo('44444444-0000-0000-0000-0000000000f1', 10, 100000) $$,
  'OR118', null, 'no se registran tanqueos con el viaje finalizado'
);
select is(
  (select count(*)::int from public.viaje_descargue_pendiente()),
  1,
  'el viaje finalizado queda con el descargue pendiente'
);
select lives_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000f1', 'SALIDA_DESCARGUE') $$,
  'registra SALIDA_DESCARGUE con el viaje finalizado'
);
select throws_ok(
  $$ select public.viaje_registrar_hito('44444444-0000-0000-0000-0000000000f1', 'SALIDA_DESCARGUE') $$,
  'OR128', null, 'no se repite la salida del descargue'
);
select is(
  (select count(*)::int from public.viaje_descargue_pendiente()),
  0,
  'sin descargue pendiente después de registrarlo'
);

select throws_ok(
  $$ select * from public.combustible_rendimiento(date '2026-03-01', date '2026-03-31') $$,
  'OR105', null, 'el conductor no consulta el informe de combustible'
);

-- ---------------------------------------------------------------------------
-- Administrador: informes
-- ---------------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a0000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
    'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text,
  true
);

select throws_ok(
  $$ select public.viaje_registrar_tanqueo('44444444-0000-0000-0000-0000000000f1', 10, 100000) $$,
  'OR105', null, 'el administrador no registra tanqueos'
);

select is(
  (select espera_cargue_h from public.tiempos_espera(date '2026-03-01', date '2026-03-31')
    where cliente = 'Cliente TST'),
  4.0::numeric,
  'espera de cargue = salida con carga - llegada al cargue'
);
select is(
  (select viajes_sobre_umbral from public.tiempos_espera(date '2026-03-01', date '2026-03-31')
    where cliente = 'Cliente TST'),
  1,
  'un viaje supera el umbral de 3 h'
);

select is(
  (select viajes from public.metricas_por_dimension_v3(date '2026-03-01', date '2026-03-31', 'PLACA')
    where clave = 'TST001'),
  3,
  'la rentabilidad por placa cuenta viajes finalizados del periodo'
);
select ok(
  (select bajo_margen from public.metricas_por_dimension_v3(date '2026-03-01', date '2026-03-31', 'RUTA')
    where clave = 'Cali → Pasto'),
  'la ruta con margen de 5 % queda marcada como bajo margen'
);
select ok(
  not (select bajo_margen from public.metricas_por_dimension_v3(date '2026-03-01', date '2026-03-31', 'RUTA')
        where clave = 'Medellín → Bogotá'),
  'la ruta con buen margen no se marca'
);
select throws_ok(
  $$ select * from public.metricas_por_dimension_v3(date '2026-03-01', date '2026-03-31', 'XX') $$,
  'OR121', null, 'dimensión no válida'
);

select is(
  (select km_por_galon from public.combustible_rendimiento(date '2026-03-01', date '2026-03-31')
    where clave = 'TST001'),
  8.00::numeric,
  'rendimiento real = km GPS / galones comprados'
);
select is(
  (select variacion_pct from public.combustible_rendimiento(date '2026-03-01', date '2026-03-31')
    where clave = 'TST001'),
  -20.0::numeric,
  'variación contra los 3 meses previos'
);
select ok(
  (select alerta from public.combustible_rendimiento(date '2026-03-01', date '2026-03-31')
    where clave = 'TST001'),
  'una caída de 20 % activa la alerta de consumo anómalo'
);

reset role;

select * from finish();

rollback;
