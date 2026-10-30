-- pgTAP: calidad del viaje (calificacion automatica por 4 dimensiones, color
-- global por puntaje promedio, resumen/ranking y alerta recurrente).
-- Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(25);

-- ---------------------------------------------------------------------------
-- Datos: 3 viajes CERRADOS del mismo conductor, placa y ruta. Los tres
-- gastan 160.000 de ACPM contra 100.000 estimados (desvio 60 % = rojo).
-- Solo el primero tiene hitos (llega 180 min tarde = puntualidad roja).
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', 'c3000000-0000-0000-0000-0000000000a1',
        'authenticated', 'authenticated', 'conductor.calidad@optiruta.test', '{"nombre":"Conductor Calidad"}', now(), now());

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon)
values ('53000000-0000-0000-0000-0000000000a1', 'CAL001', 'DOBLE_TROQUE', 17, 9);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base)
values ('63000000-0000-0000-0000-0000000000a1', 'c3000000-0000-0000-0000-0000000000a1',
        'LIC-CAL-1', date '2030-01-01', 'COMISION', 10, 0);

insert into public.cliente (id, nombre) values ('73000000-0000-0000-0000-0000000000a1', 'Cliente Calidad');

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, tiempo_estimado_min, estado, valor_flete)
select ('83000000-0000-0000-0000-0000000000a' || n)::uuid, 'CAL-REM-' || n,
       '53000000-0000-0000-0000-0000000000a1', '63000000-0000-0000-0000-0000000000a1',
       '73000000-0000-0000-0000-0000000000a1', 'Medellín', 'Bogotá', 60, 'ASIGNADO', 1000000
  from generate_series(1, 3) n;

insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
select ('83000000-0000-0000-0000-0000000000a' || n)::uuid, 'ACPM', 100000, 160000, 'AUTOMATICO'
  from generate_series(1, 3) n;

update public.viaje set estado = 'EN_CURSO' where remision like 'CAL-REM-%';
insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
values
  ('83000000-0000-0000-0000-0000000000a1', 'SALIDA', now() - interval '5 hours'),
  ('83000000-0000-0000-0000-0000000000a1', 'LLEGADA_DESTINO', now() - interval '1 hour');
update public.viaje set estado = 'FINALIZADO' where remision like 'CAL-REM-%';
-- El viaje 3 queda FINALIZADO: la empresa no cierra viajes por ahora.
update public.viaje set estado = 'CERRADO', fecha_cierre = now()
 where remision in ('CAL-REM-1', 'CAL-REM-2');

-- Una incidencia en el viaje 2 (desvio de ruta).
insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
values ('DESVIO_RUTA', 'Desvío', 'Se desvió de la ruta', '83000000-0000-0000-0000-0000000000a2');

select has_function('public', 'viaje_calidad', array['uuid'], 'existe viaje_calidad');

-- ---------------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c3000000-0000-0000-0000-0000000000a1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select * from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1') $$,
  'OR105', null, 'el conductor no consulta la calidad del viaje'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'a3000000-0000-0000-0000-0000000000a1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

-- ---------------------------------------------------------------------------
-- Detalle del viaje 1: puntualidad y rentabilidad rojas, incidencias verdes
-- ---------------------------------------------------------------------------
select is((select puntualidad_nivel from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1')),
  'ROJO', 'llegar 180 min tarde con 60 estimados es puntualidad roja');
select is((select minutos_retraso from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1')),
  180.0, 'minutos de retraso = real (240) - estimado (60)');
select is((select rentabilidad_nivel from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1')),
  'ROJO', 'costos 60 % sobre lo estimado = rentabilidad roja (> 35 %)');
select is((select desvio_costos_pct from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1')),
  60.0, 'desvio de costos = (160.000 - 100.000) / 100.000');
select is((select categoria_mayor_desvio from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1')),
  'ACPM', 'la categoria con mayor desvio es ACPM');
select is((select satisfaccion_nivel from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1')),
  null, 'sin encuesta respondida la dimension de cliente queda sin datos');
select is((select incidencias_nivel from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1')),
  'VERDE', 'sin alertas en ruta, incidencias verde');
select is((select puntaje from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1')),
  33.3, 'puntaje = (0 + 0 + 2) / 3 * 50, la dimension sin datos no cuenta');
select is((select nivel from public.viaje_calidad('83000000-0000-0000-0000-0000000000a1')),
  'ROJO', 'puntaje 33,3 (< 40) es rojo global');

-- Viaje 3: sin hitos (puntualidad sin datos): (0 + 2) / 2 * 50 = 50 = ambar.
select is((select nivel from public.viaje_calidad('83000000-0000-0000-0000-0000000000a3')),
  'AMBAR', 'puntaje 50 es ambar global');
select is((select incidencias_nivel from public.viaje_calidad('83000000-0000-0000-0000-0000000000a2')),
  'AMBAR', 'una alerta en ruta deja incidencias en ambar');

-- ---------------------------------------------------------------------------
-- Resumen y ranking del periodo
-- ---------------------------------------------------------------------------
select is(
  (select viajes_evaluados from public.calidad_resumen(public.hoy_bogota() - 1, public.hoy_bogota() + 1,
     null, '63000000-0000-0000-0000-0000000000a1')),
  3, 'el resumen evalua los 3 viajes (el finalizado sin cerrar tambien cuenta)');
select is(
  (select rojos from public.calidad_resumen(public.hoy_bogota() - 1, public.hoy_bogota() + 1,
     null, '63000000-0000-0000-0000-0000000000a1')),
  2, 'el resumen cuenta 2 viajes en rojo (puntajes 33,3 y 25)');
select is(
  (select rentabilidad_rojos from public.calidad_por_dimension(public.hoy_bogota() - 1, public.hoy_bogota() + 1,
     'VEHICULO', null, '63000000-0000-0000-0000-0000000000a1')),
  3, 'el ranking por placa cuenta los 3 viajes con rentabilidad roja');
select throws_ok(
  $$ select * from public.calidad_por_dimension(public.hoy_bogota() - 1, public.hoy_bogota(), 'CLIENTE') $$,
  'OR121', null, 'una dimension de ranking no valida se rechaza'
);

-- ---------------------------------------------------------------------------
-- Indicador del perfil del conductor
-- ---------------------------------------------------------------------------
select is(
  (select viajes_evaluados from public.conductor_calidad('63000000-0000-0000-0000-0000000000a1',
     public.hoy_bogota() - 1, public.hoy_bogota() + 1)),
  3, 'el administrador consulta la calidad de un conductor');
select is(
  (select puntaje_promedio from public.conductor_calidad('63000000-0000-0000-0000-0000000000a1',
     public.hoy_bogota() - 1, public.hoy_bogota() + 1)),
  36.1, 'puntaje promedio del conductor = (33,3 + 25 + 50) / 3');

select set_config('request.jwt.claims', json_build_object(
  'sub', 'c3000000-0000-0000-0000-0000000000a1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);
select is(
  (select viajes_evaluados from public.conductor_calidad('63000000-0000-0000-0000-0000000000a1',
     public.hoy_bogota() - 1, public.hoy_bogota() + 1)),
  3, 'el conductor consulta su propia calidad');
select throws_ok(
  $$ select * from public.conductor_calidad('00000000-0000-0000-0000-000000000099',
       public.hoy_bogota() - 1, public.hoy_bogota() + 1) $$,
  'OR105', null, 'el conductor no consulta la calidad de otro conductor'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'a3000000-0000-0000-0000-0000000000a1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

-- ---------------------------------------------------------------------------
-- Alerta recurrente: 3 viajes con rentabilidad roja (conductor, placa y ruta)
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from public.calidad_recurrentes(public.hoy_bogota() - 1, public.hoy_bogota() + 1)
    where dimension = 'RENTABILIDAD'),
  3, '3 viajes rojos en el mes activan la recurrencia por conductor, placa y ruta');

reset role;

select is(public.calidad_alertas_generar(), 3, 'el job genera las 3 alertas recurrentes');
select is(public.calidad_alertas_generar(), 0, 'una segunda corrida no duplica las alertas (clave por mes)');
select is(
  (select count(*)::int from public.notificacion where tipo = 'CALIDAD_RECURRENTE'),
  3, 'quedan 3 notificaciones CALIDAD_RECURRENTE');

select * from finish();

rollback;
