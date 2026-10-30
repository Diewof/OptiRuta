-- pgTAP: reglas de flota (documentos, checklist pre-viaje, km por GPS,
-- odometro, alertas y mantenimiento preventivo). Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(42);

-- ---------------------------------------------------------------------------
-- Datos
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'c1000000-0000-0000-0000-0000000000f1',
   'authenticated', 'authenticated', 'conductor1.flota@optiruta.test', '{"nombre":"Conductor Flota Uno"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c1000000-0000-0000-0000-0000000000f2',
   'authenticated', 'authenticated', 'conductor2.flota@optiruta.test', '{"nombre":"Conductor Flota Dos"}', now(), now());

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo, odometro_inicial_km)
values
  ('51000000-0000-0000-0000-0000000000f1', 'FLT001', 'DOBLE_TROQUE', 17, 9, true, 0),
  ('51000000-0000-0000-0000-0000000000f2', 'FLT002', 'MULA', 30, 7, true, 0),
  ('51000000-0000-0000-0000-0000000000f3', 'FLT003', 'DOBLE_TROQUE', 17, 9, true, 1000),
  ('51000000-0000-0000-0000-0000000000f4', 'FLT004', 'DOBLE_TROQUE', 17, 9, true, 0),
  ('51000000-0000-0000-0000-0000000000f5', 'FLT005', 'DOBLE_TROQUE', 17, 9, true, 0),
  ('51000000-0000-0000-0000-0000000000f6', 'FLT006', 'DOBLE_TROQUE', 17, 9, true, 0),
  ('51000000-0000-0000-0000-0000000000f7', 'FLT007', 'DOBLE_TROQUE', 17, 9, true, 20000);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values
  ('61000000-0000-0000-0000-0000000000f1', 'c1000000-0000-0000-0000-0000000000f1', 'LIC-FLT-1', date '2030-01-01', 'COMISION', 10, 0, true),
  ('61000000-0000-0000-0000-0000000000f2', 'c1000000-0000-0000-0000-0000000000f2', 'LIC-FLT-2', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre) values ('71000000-0000-0000-0000-0000000000f1', 'Cliente Flota');

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, distancia_estimada)
values
  ('81000000-0000-0000-0000-0000000000f1', 'FLT-REM-1', '51000000-0000-0000-0000-0000000000f1',
   '61000000-0000-0000-0000-0000000000f1', '71000000-0000-0000-0000-0000000000f1', 'Medellín', 'Bogotá', 'ASIGNADO', 4000000, 400),
  ('81000000-0000-0000-0000-0000000000f2', 'FLT-REM-2', '51000000-0000-0000-0000-0000000000f2',
   '61000000-0000-0000-0000-0000000000f1', '71000000-0000-0000-0000-0000000000f1', 'Cali', 'Bogotá', 'ASIGNADO', 4000000, 400),
  ('81000000-0000-0000-0000-0000000000f3', 'FLT-REM-3', '51000000-0000-0000-0000-0000000000f3',
   '61000000-0000-0000-0000-0000000000f1', '71000000-0000-0000-0000-0000000000f1', 'Cali', 'Pasto', 'ASIGNADO', 4000000, 12),
  ('81000000-0000-0000-0000-0000000000f4', 'FLT-REM-4', '51000000-0000-0000-0000-0000000000f4',
   '61000000-0000-0000-0000-0000000000f1', '71000000-0000-0000-0000-0000000000f1', 'Cali', 'Neiva', 'ASIGNADO', 4000000, 100);

update public.viaje set estado = 'EN_CURSO'
 where id in ('81000000-0000-0000-0000-0000000000f3', '81000000-0000-0000-0000-0000000000f4');

-- GPS del viaje 3: tres puntos a lo largo de un meridiano (~11,1 km en total).
insert into public.ubicacion_viaje (viaje_id, lat, lng, fecha_hora)
values
  ('81000000-0000-0000-0000-0000000000f3', 6.2442, -75.5812, now() - interval '15 minutes'),
  ('81000000-0000-0000-0000-0000000000f3', 6.2942, -75.5812, now() - interval '10 minutes'),
  ('81000000-0000-0000-0000-0000000000f3', 6.3442, -75.5812, now() - interval '5 minutes');

-- Respuestas de checklist precalculadas (GUC local a la transaccion).
select set_config('t.ok_dt', (
  select jsonb_agg(jsonb_build_object('item_id', i.id, 'estado', 'OK'))
    from public.checklist_item i where i.activo and i.aplica_tipo is null)::text, true);
select set_config('t.ok_mula', (
  select jsonb_agg(jsonb_build_object('item_id', i.id, 'estado', 'OK'))
    from public.checklist_item i where i.activo and (i.aplica_tipo is null or i.aplica_tipo = 'MULA'))::text, true);
select set_config('t.incompleto', (
  select jsonb_agg(jsonb_build_object('item_id', i.id, 'estado', 'OK'))
    from public.checklist_item i where i.activo and i.aplica_tipo is null and i.codigo <> 'PITO')::text, true);
select set_config('t.falla_sin_obs', (
  select jsonb_agg(jsonb_build_object('item_id', i.id,
         'estado', case when i.codigo = 'FRENO_SERVICIO' then 'FALLA' else 'OK' end))
    from public.checklist_item i where i.activo and i.aplica_tipo is null)::text, true);
select set_config('t.falla_critica', (
  select jsonb_agg(jsonb_build_object('item_id', i.id,
         'estado', case when i.codigo = 'FRENO_SERVICIO' then 'FALLA' else 'OK' end,
         'observacion', case when i.codigo = 'FRENO_SERVICIO' then 'No frena bien' end))
    from public.checklist_item i where i.activo and i.aplica_tipo is null)::text, true);
select set_config('t.falla_leve', (
  select jsonb_agg(jsonb_build_object('item_id', i.id,
         'estado', case when i.codigo = 'PITO' then 'FALLA' else 'OK' end,
         'observacion', case when i.codigo = 'PITO' then 'Suena débil' end))
    from public.checklist_item i where i.activo and (i.aplica_tipo is null or i.aplica_tipo = 'MULA'))::text, true);

-- ---------------------------------------------------------------------------
-- Documentos: bloqueo al comenzar el viaje
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select public.viaje_iniciar('81000000-0000-0000-0000-0000000000f1', 6.2442, -75.5812) $$,
  'OR132', null, 'sin SOAT ni tecnomecanica registrados no se puede comenzar el viaje'
);

reset role;
insert into public.documento_vehiculo (vehiculo_id, tipo, fecha_vencimiento)
values
  ('51000000-0000-0000-0000-0000000000f1', 'SOAT', date '2099-01-01'),
  ('51000000-0000-0000-0000-0000000000f1', 'TECNOMECANICA', public.hoy_bogota() - 1);

set local role authenticated;
select throws_ok(
  $$ select public.viaje_iniciar('81000000-0000-0000-0000-0000000000f1', 6.2442, -75.5812) $$,
  'OR132', null, 'con la tecnomecanica vencida no se puede comenzar el viaje'
);

reset role;
-- Renovar es insertar una fila nueva; la vigente es la de mayor vencimiento.
insert into public.documento_vehiculo (vehiculo_id, tipo, fecha_vencimiento)
values ('51000000-0000-0000-0000-0000000000f1', 'TECNOMECANICA', date '2099-01-01');

select is(
  (select estado from public.documento_vehiculo_vigente
    where vehiculo_id = '51000000-0000-0000-0000-0000000000f1' and tipo = 'TECNOMECANICA'),
  'VIGENTE',
  'tras renovar, el documento vigente es el de mayor vencimiento'
);

-- ---------------------------------------------------------------------------
-- Checklist pre-viaje
-- ---------------------------------------------------------------------------
set local role authenticated;

select throws_ok(
  $$ select public.viaje_iniciar('81000000-0000-0000-0000-0000000000f1', 6.2442, -75.5812) $$,
  'OR137', null, 'sin checklist no se puede comenzar el viaje'
);

select throws_ok(
  $$ select public.checklist_registrar('81000000-0000-0000-0000-0000000000f1', current_setting('t.incompleto')::jsonb) $$,
  'OR134', null, 'un checklist con ítems sin responder se rechaza'
);

select throws_ok(
  $$ select public.checklist_registrar('81000000-0000-0000-0000-0000000000f1', current_setting('t.falla_sin_obs')::jsonb) $$,
  'OR135', null, 'una falla sin descripción se rechaza'
);

select is(
  (public.checklist_registrar('81000000-0000-0000-0000-0000000000f1', current_setting('t.falla_critica')::jsonb)).resultado,
  'BLOQUEADO',
  'una falla en un ítem crítico deja el checklist BLOQUEADO'
);

select throws_ok(
  $$ select public.viaje_iniciar('81000000-0000-0000-0000-0000000000f1', 6.2442, -75.5812) $$,
  'OR138', null, 'con el checklist bloqueado no se puede comenzar sin autorización'
);

select throws_ok(
  $$ select public.checklist_autorizar_salida('81000000-0000-0000-0000-0000000000f1', 'quiero salir') $$,
  'OR105', null, 'un conductor no puede autorizar su propia salida'
);

-- RLS: otro conductor no ve checklists ajenos.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c1000000-0000-0000-0000-0000000000f2', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select is(
  (select count(*)::int from public.checklist_viaje),
  0,
  'un conductor no ve los checklists de otro'
);

-- Administrador autoriza.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select throws_ok(
  $$ select public.checklist_autorizar_salida('81000000-0000-0000-0000-0000000000f1', '   ') $$,
  'OR106', null, 'la autorización exige motivo'
);

select is(
  (public.checklist_autorizar_salida('81000000-0000-0000-0000-0000000000f1', 'Freno revisado en taller')).motivo,
  'Freno revisado en taller',
  'el administrador autoriza la salida con motivo'
);

select throws_ok(
  $$ insert into public.checklist_viaje (viaje_id, vehiculo_id, conductor_id, resultado)
     values ('81000000-0000-0000-0000-0000000000f1', '51000000-0000-0000-0000-0000000000f1',
             '61000000-0000-0000-0000-0000000000f1', 'APROBADO') $$,
  '42501', null, 'el checklist no se inserta directo (solo por la RPC)'
);

-- Con la autorización el conductor sale.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select is(
  (public.viaje_iniciar('81000000-0000-0000-0000-0000000000f1', 6.2442, -75.5812)).estado,
  'EN_CURSO',
  'autorizado el checklist bloqueado, el viaje comienza'
);

select throws_ok(
  $$ select public.checklist_registrar('81000000-0000-0000-0000-0000000000f1', current_setting('t.ok_dt')::jsonb) $$,
  'OR133', null, 'el checklist solo se llena con el viaje asignado'
);

-- Mula: incluye los ítems de acople; una falla leve no bloquea.
select is(
  (public.checklist_registrar('81000000-0000-0000-0000-0000000000f2', current_setting('t.ok_mula')::jsonb)).resultado,
  'APROBADO',
  'un checklist sin fallas queda APROBADO'
);

select is(
  (public.checklist_registrar('81000000-0000-0000-0000-0000000000f2', current_setting('t.falla_leve')::jsonb)).resultado,
  'CON_OBSERVACIONES',
  'una falla no crítica deja el checklist CON_OBSERVACIONES'
);

reset role;

select is(
  (select count(*)::int from public.checklist_respuesta r
     join public.checklist_viaje k on k.id = r.checklist_id
    where k.viaje_id = '81000000-0000-0000-0000-0000000000f2' and k.resultado = 'APROBADO'),
  (select count(*)::int from public.checklist_item where activo),
  'el checklist de una mula responde todos los ítems, incluidos los de acople'
);

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'CHECKLIST_FALLA' and vehiculo_id = '51000000-0000-0000-0000-0000000000f1'),
  1,
  'una falla de checklist avisa al administrador al instante'
);

-- ---------------------------------------------------------------------------
-- Kilometraje por GPS y odometro
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select is(
  (public.viaje_cambiar_estado('81000000-0000-0000-0000-0000000000f3', 'FINALIZADO')).km_origen,
  'GPS',
  'al finalizar con puntos GPS suficientes los km salen del GPS'
);

select is(
  (public.viaje_cambiar_estado('81000000-0000-0000-0000-0000000000f4', 'FINALIZADO')).km_origen,
  'ESTIMADO',
  'sin puntos GPS los km se toman de la distancia estimada y se marcan ESTIMADO'
);

reset role;

select ok(
  (select km_recorridos from public.viaje where id = '81000000-0000-0000-0000-0000000000f3') between 10.9 and 11.3,
  'los km del GPS suman la distancia entre puntos (~11,1 km)'
);

select is(
  (select km_recorridos from public.viaje where id = '81000000-0000-0000-0000-0000000000f4'),
  100::numeric,
  'los km estimados copian distancia_estimada'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select ok(
  (select odometro_km from public.vehiculo_resumen('51000000-0000-0000-0000-0000000000f3')) between 1010.9 and 1011.3,
  'el odómetro es la lectura inicial más los km de los viajes finalizados'
);

-- ---------------------------------------------------------------------------
-- Mantenimiento preventivo y hoja de vida
-- ---------------------------------------------------------------------------
reset role;

select is(
  (select count(*)::int from public.plan_mantenimiento where vehiculo_id = '51000000-0000-0000-0000-0000000000f7'),
  (select count(*)::int from public.tipo_mantenimiento where activo),
  'un vehículo nuevo nace con el plan de mantenimiento del catálogo'
);

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, distancia_estimada, km_recorridos, km_origen)
values ('81000000-0000-0000-0000-0000000000f9', 'FLT-REM-9', '51000000-0000-0000-0000-0000000000f7',
        '61000000-0000-0000-0000-0000000000f1', '71000000-0000-0000-0000-0000000000f1', 'A', 'B', 'FINALIZADO', 1000000, 19000, 19000, 'GPS');

set local role authenticated;

select throws_ok(
  $$ select public.mantenimiento_registrar('51000000-0000-0000-0000-0000000000f7', 'x', 100000,
       public.hoy_bogota() + 1) $$,
  'OR139', null, 'un mantenimiento no puede tener fecha futura'
);

-- Un viaje finalizado de 19.000 km lleva el odómetro de 20.000 a 39.000. El km
-- digitado en el mantenimiento no entra al cálculo: la base es el odómetro
-- derivado a la fecha (20.000), así que van 19.000 de 20.000 km => faltan 1.000
-- (dentro de la antelación de 1.500).
select ok(
  (public.mantenimiento_registrar(
     '51000000-0000-0000-0000-0000000000f7', '', 450000, public.hoy_bogota() - 30, 1000,
     (select id from public.tipo_mantenimiento where codigo = 'ACEITE_MOTOR'))).id is not null,
  'el administrador registra un mantenimiento del catálogo (el tipo toma el nombre del catálogo)'
);

select is(
  (select estado from public.plan_mantenimiento_estado('51000000-0000-0000-0000-0000000000f7')
    where tipo_nombre like 'Cambio de aceite%'),
  'PROXIMO',
  'el plan marca PROXIMO cuando faltan menos km que la antelación'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'c1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select public.mantenimiento_registrar('51000000-0000-0000-0000-0000000000f7', 'x', 100000, public.hoy_bogota()) $$,
  'OR105', null, 'un conductor no registra mantenimientos'
);

select throws_ok(
  $$ insert into public.documento_vehiculo (vehiculo_id, tipo, fecha_vencimiento)
     values ('51000000-0000-0000-0000-0000000000f7', 'SOAT', date '2099-01-01') $$,
  '42501', null, 'un conductor no registra documentos del vehículo'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'a1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select throws_ok(
  $$ delete from public.documento_vehiculo where vehiculo_id = '51000000-0000-0000-0000-0000000000f1' $$,
  '42501', null, 'los documentos no se borran: el historial se conserva'
);

reset role;

-- Alerta de mantenimiento antes de renovar el cambio de aceite.
select notificacion_generar();

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'MANTENIMIENTO_PROXIMO' and vehiculo_id = '51000000-0000-0000-0000-0000000000f7'),
  1,
  'el cron avisa del mantenimiento próximo (una vez por plan y ciclo)'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

-- Registrado hoy sin km: usa el odómetro actual (39.000) y reinicia el plan.
select is(
  (public.mantenimiento_registrar(
     '51000000-0000-0000-0000-0000000000f7', '', 450000, public.hoy_bogota(), null,
     (select id from public.tipo_mantenimiento where codigo = 'ACEITE_MOTOR'))).kilometraje,
  39000::numeric,
  'un mantenimiento de hoy sin km toma el odómetro actual'
);

select is(
  (select estado from public.plan_mantenimiento_estado('51000000-0000-0000-0000-0000000000f7')
    where tipo_nombre like 'Cambio de aceite%'),
  'AL_DIA',
  'registrar el mantenimiento reinicia el contador del plan'
);

select is(
  (select count(*)::int from public.vehiculo_hoja_vida('51000000-0000-0000-0000-0000000000f7')
    where tipo = 'MANTENIMIENTO'),
  2,
  'la hoja de vida lista los mantenimientos del vehículo'
);

reset role;

-- ---------------------------------------------------------------------------
-- Alertas de documentos: una por documento y escalón
-- ---------------------------------------------------------------------------
insert into public.documento_vehiculo (vehiculo_id, tipo, fecha_vencimiento)
values
  ('51000000-0000-0000-0000-0000000000f5', 'SOAT', public.hoy_bogota() + 5),
  ('51000000-0000-0000-0000-0000000000f5', 'TECNOMECANICA', public.hoy_bogota() + 20),
  ('51000000-0000-0000-0000-0000000000f6', 'SOAT', public.hoy_bogota() - 10);

select notificacion_generar();
select notificacion_generar();

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'DOCUMENTO_POR_VENCER' and vehiculo_id = '51000000-0000-0000-0000-0000000000f5'),
  2,
  'SOAT y tecnomecanica por vencer del mismo vehículo generan una alerta cada uno'
);

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'DOCUMENTO_VENCIDO' and vehiculo_id = '51000000-0000-0000-0000-0000000000f6'),
  1,
  'un documento vencido genera una sola alerta aunque el cron corra varias veces'
);

-- ---------------------------------------------------------------------------
-- Correcciones: odometro con km estimados, documento vigente = ultimo
-- registrado y alerta inmediata al registrar
-- ---------------------------------------------------------------------------
insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, distancia_estimada)
values ('81000000-0000-0000-0000-0000000000f5', 'FLT-REM-5', '51000000-0000-0000-0000-0000000000f6',
        '61000000-0000-0000-0000-0000000000f1', '71000000-0000-0000-0000-0000000000f1', 'Cali', 'Buga', 'ASIGNADO', 1000000, 50);
update public.viaje set estado = 'EN_CURSO' where id = '81000000-0000-0000-0000-0000000000f5';
update public.viaje set estado = 'FINALIZADO' where id = '81000000-0000-0000-0000-0000000000f5';

select is(
  public.vehiculo_odometro_km('51000000-0000-0000-0000-0000000000f6'),
  50::numeric,
  'un viaje finalizado sin km medidos suma su distancia estimada al odómetro'
);

-- Un SOAT registrado ayer con vencimiento lejano (se desactiva el trigger de
-- auditoria solo para fijar la fecha de registro).
alter table public.documento_vehiculo disable trigger documento_vehiculo_set_audit;
insert into public.documento_vehiculo (vehiculo_id, tipo, fecha_vencimiento, fecha_creacion)
values ('51000000-0000-0000-0000-0000000000f4', 'SOAT', date '2099-01-01', now() - interval '1 day');
alter table public.documento_vehiculo enable trigger documento_vehiculo_set_audit;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select throws_ok(
  $$ select public.documento_vehiculo_registrar('51000000-0000-0000-0000-0000000000f4', 'SOAT', public.hoy_bogota() + 3) $$,
  'OR105', null, 'un conductor no registra documentos'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'a1000000-0000-0000-0000-0000000000f1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select ok(
  (public.documento_vehiculo_registrar('51000000-0000-0000-0000-0000000000f4', 'SOAT', public.hoy_bogota() + 3)).id is not null,
  'el administrador registra un SOAT que vence antes que el anterior'
);

select is(
  (select dias_restantes from public.documento_vehiculo_vigente
    where vehiculo_id = '51000000-0000-0000-0000-0000000000f4' and tipo = 'SOAT'),
  3,
  'el documento vigente es el último registrado, aunque venza antes'
);

reset role;

select is(
  (select count(*)::int from public.notificacion
    where tipo = 'DOCUMENTO_POR_VENCER' and vehiculo_id = '51000000-0000-0000-0000-0000000000f4'),
  1,
  'registrar el documento avisa al instante, sin esperar al cron'
);

select * from finish();

rollback;
