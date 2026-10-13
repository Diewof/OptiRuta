-- pgTAP: desglose de costos por categoria y mantenimiento del periodo en la
-- rentabilidad consolidada (rentabilidad_consolidada_v3).

begin;

create extension if not exists pgtap with schema extensions;

select plan(7);

insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', 'c2000000-0000-0000-0000-0000000000a1',
        'authenticated', 'authenticated', 'conductor.resumen@optiruta.test', '{"nombre":"Conductor Resumen"}', now(), now());

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon)
values ('52000000-0000-0000-0000-0000000000a1', 'RES001', 'DOBLE_TROQUE', 17, 9);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base)
values ('62000000-0000-0000-0000-0000000000a1', 'c2000000-0000-0000-0000-0000000000a1',
        'LIC-RES-1', date '2030-01-01', 'COMISION', 10, 0);

insert into public.cliente (id, nombre) values ('72000000-0000-0000-0000-0000000000a1', 'Cliente Resumen');

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete)
values ('82000000-0000-0000-0000-0000000000a1', 'RES-REM-1', '52000000-0000-0000-0000-0000000000a1',
        '62000000-0000-0000-0000-0000000000a1', '72000000-0000-0000-0000-0000000000a1',
        'Medellín', 'Bogotá', 'ASIGNADO', 1000000);

-- ACPM: el real (250.000) manda sobre el estimado (200.000).
insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
values
  ('82000000-0000-0000-0000-0000000000a1', 'ACPM', 200000, 250000, 'AUTOMATICO'),
  ('82000000-0000-0000-0000-0000000000a1', 'PEAJE', 50000, null, 'MANUAL'),
  ('82000000-0000-0000-0000-0000000000a1', 'COMISION', 100000, null, 'AUTOMATICO');

update public.viaje set estado = 'EN_CURSO' where id = '82000000-0000-0000-0000-0000000000a1';
update public.viaje set estado = 'FINALIZADO' where id = '82000000-0000-0000-0000-0000000000a1';
update public.viaje set estado = 'CERRADO', fecha_cierre = now() where id = '82000000-0000-0000-0000-0000000000a1';

-- Mantenimiento del periodo del mismo vehiculo.
insert into public.mantenimiento_vehiculo (vehiculo_id, tipo, costo, fecha)
values ('52000000-0000-0000-0000-0000000000a1', 'Cambio de llantas', 80000, public.hoy_bogota());

set local role authenticated;

select set_config('request.jwt.claims', json_build_object(
  'sub', 'c2000000-0000-0000-0000-0000000000a1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select * from public.rentabilidad_consolidada_v3(public.hoy_bogota() - 1, public.hoy_bogota() + 1) $$,
  'OR105', null, 'un conductor no consulta la rentabilidad consolidada'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'a2000000-0000-0000-0000-0000000000a1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

-- Filtrado por el vehiculo de la prueba: solo este viaje y este mantenimiento.
select is(
  (select (costos_por_categoria ->> 'ACPM')::numeric
     from public.rentabilidad_consolidada_v3(
       public.hoy_bogota() - 1, public.hoy_bogota() + 1, null, null,
       '52000000-0000-0000-0000-0000000000a1')),
  250000::numeric,
  'el desglose usa el valor real del ACPM cuando existe'
);

select is(
  (select (costos_por_categoria ->> 'PEAJE')::numeric
     from public.rentabilidad_consolidada_v3(
       public.hoy_bogota() - 1, public.hoy_bogota() + 1, null, null,
       '52000000-0000-0000-0000-0000000000a1')),
  50000::numeric,
  'el desglose usa el estimado cuando no hay valor real'
);

select is(
  (select total_costos_directos
     from public.rentabilidad_consolidada_v3(
       public.hoy_bogota() - 1, public.hoy_bogota() + 1, null, null,
       '52000000-0000-0000-0000-0000000000a1')),
  400000::numeric,
  'las categorias del desglose suman los costos directos'
);

select is(
  (select mantenimiento_amortizado
     from public.rentabilidad_consolidada_v3(
       public.hoy_bogota() - 1, public.hoy_bogota() + 1, null, null,
       '52000000-0000-0000-0000-0000000000a1')),
  80000::numeric,
  'el costo de los mantenimientos del periodo entra al consolidado'
);

select is(
  (select rentabilidad_consolidada
     from public.rentabilidad_consolidada_v3(
       public.hoy_bogota() - 1, public.hoy_bogota() + 1, null, null,
       '52000000-0000-0000-0000-0000000000a1')),
  520000::numeric,
  'la rentabilidad resta costos directos y mantenimiento: 1.000.000 - 400.000 - 80.000'
);

select is(
  (select costos_por_categoria
     from public.rentabilidad_consolidada_v3(
       public.hoy_bogota() - 1, public.hoy_bogota() + 1, null, null,
       '52000000-0000-0000-0000-0000000000a1')) ? 'MANTENIMIENTO_AMORTIZADO',
  false,
  'el mantenimiento no se cuenta dos veces dentro de los costos directos'
);

reset role;

select * from finish();

rollback;
