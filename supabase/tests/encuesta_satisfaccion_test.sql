-- pgTAP: encuesta de satisfaccion (RLS solo-admin, creacion al finalizar el
-- viaje, respuesta de un solo uso, alerta de baja satisfaccion, metricas).
-- Se corre con `supabase test db`.

begin;

create extension if not exists pgtap with schema extensions;

select plan(23);

-- ---------------------------------------------------------------------------
-- Estructura
-- ---------------------------------------------------------------------------
select has_table('public', 'encuesta_satisfaccion', 'existe la tabla encuesta_satisfaccion');

select is(
  (select relrowsecurity from pg_class where oid = 'public.encuesta_satisfaccion'::regclass),
  true,
  'RLS habilitado en encuesta_satisfaccion'
);

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'encuesta_satisfaccion'
      and cmd in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'sin politicas de escritura: solo se escribe por RPC'
);

-- ---------------------------------------------------------------------------
-- Datos
-- ---------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-0000000000e1',
   'authenticated', 'authenticated', 'admin.enc@optiruta.test', '{"nombre":"Admin Enc"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c0000000-0000-0000-0000-0000000000e1',
   'authenticated', 'authenticated', 'conductor.enc@optiruta.test', '{"nombre":"Conductor Enc"}', now(), now());

update public.usuario set rol = 'ADMINISTRADOR' where id = 'a0000000-0000-0000-0000-0000000000e1';
update auth.users
   set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'ADMINISTRADOR')
 where id = 'a0000000-0000-0000-0000-0000000000e1';
update auth.users
   set raw_app_meta_data = raw_app_meta_data || jsonb_build_object('rol', 'CONDUCTOR')
 where id = 'c0000000-0000-0000-0000-0000000000e1';

insert into public.vehiculo (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values ('11000000-0000-0000-0000-0000000000e1', 'ENC001', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values ('22000000-0000-0000-0000-0000000000e1', 'c0000000-0000-0000-0000-0000000000e1', 'LIC-ENC-1', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (id, nombre, correo)
values
  ('33000000-0000-0000-0000-0000000000e1', 'Cliente Con Correo', 'cliente@enc.test'),
  ('33000000-0000-0000-0000-0000000000e2', 'Cliente Sin Correo', null);

insert into public.viaje (id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, tiempo_estimado_min, valor_flete, estado)
values
  ('44000000-0000-0000-0000-0000000000e1', 'ENC-REM-1', '11000000-0000-0000-0000-0000000000e1',
   '22000000-0000-0000-0000-0000000000e1', '33000000-0000-0000-0000-0000000000e1', 'Medellin', 'Bogota', 60, 1000000, 'ASIGNADO'),
  ('44000000-0000-0000-0000-0000000000e2', 'ENC-REM-2', '11000000-0000-0000-0000-0000000000e1',
   '22000000-0000-0000-0000-0000000000e1', '33000000-0000-0000-0000-0000000000e2', 'Medellin', 'Cali', 60, 1000000, 'ASIGNADO');

select is((select count(*)::int from public.encuesta_satisfaccion), 0, 'sin encuestas antes de finalizar');

update public.viaje set estado = 'EN_CURSO' where id in ('44000000-0000-0000-0000-0000000000e1', '44000000-0000-0000-0000-0000000000e2');
insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
values
  ('44000000-0000-0000-0000-0000000000e1', 'SALIDA', now() - interval '5 hours'),
  ('44000000-0000-0000-0000-0000000000e1', 'LLEGADA_DESTINO', now() - interval '1 hour');

update public.viaje set estado = 'FINALIZADO' where id in ('44000000-0000-0000-0000-0000000000e1', '44000000-0000-0000-0000-0000000000e2');

select is(
  (select estado from public.encuesta_satisfaccion where viaje_id = '44000000-0000-0000-0000-0000000000e1'),
  'PENDIENTE',
  'al finalizar el viaje nace la encuesta PENDIENTE'
);
select is(
  (select estado from public.encuesta_satisfaccion where viaje_id = '44000000-0000-0000-0000-0000000000e2'),
  'SIN_CONTACTO',
  'un cliente sin correo deja la encuesta SIN_CONTACTO'
);
select is(
  (select minutos_retraso from public.encuesta_satisfaccion where viaje_id = '44000000-0000-0000-0000-0000000000e1'),
  180.0,
  'minutos_retraso = tiempo real (240) - estimado (60)'
);

-- Idempotente: no duplica.
select public.encuesta_crear_para_viaje('44000000-0000-0000-0000-0000000000e1');
select is((select count(*)::int from public.encuesta_satisfaccion), 2, 'crear_para_viaje es idempotente');

select set_config('t.token', (select token::text from public.encuesta_satisfaccion
  where viaje_id = '44000000-0000-0000-0000-0000000000e1'), true);
select set_config('t.id', (select id::text from public.encuesta_satisfaccion
  where viaje_id = '44000000-0000-0000-0000-0000000000e1'), true);

-- ---------------------------------------------------------------------------
-- RLS y permisos
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'c0000000-0000-0000-0000-0000000000e1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'CONDUCTOR'))::text, true);

select is((select count(*)::int from public.encuesta_satisfaccion), 0, 'el conductor no ve encuestas');
select throws_ok(
  $$ select * from public.satisfaccion_resumen(current_date - 1, current_date) $$,
  'OR105', null, 'el conductor no consulta el resumen de satisfaccion'
);
select throws_ok(
  $$ select public.encuesta_registrar_respuesta(current_setting('t.token')::uuid, 5, 5, 5, 5, 10, null) $$,
  '42501', null, 'un usuario autenticado no puede registrar respuestas (solo service_role)'
);

select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0000000-0000-0000-0000-0000000000e1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select is((select count(*)::int from public.encuesta_satisfaccion), 2, 'el administrador ve las encuestas');

-- ---------------------------------------------------------------------------
-- Envio y respuesta (service_role)
-- ---------------------------------------------------------------------------
reset role;
set local role service_role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);

select is(
  (select count(*)::int from public.encuesta_pendientes_envio()),
  2,
  'pendientes: la PENDIENTE con correo y la SIN_CONTACTO sin enlace'
);

select public.encuesta_registrar_envio(current_setting('t.id')::uuid, 'https://forms.example/x?t=1', true);
select is(
  (select estado from public.encuesta_satisfaccion where id = current_setting('t.id')::uuid),
  'ENVIADA',
  'registrar_envio marca la encuesta ENVIADA'
);

select throws_ok(
  $$ select public.encuesta_registrar_respuesta(current_setting('t.token')::uuid, 6, 5, 5, 5, 10, null) $$,
  'OR144', null, 'calificacion fuera de 1-5 se rechaza'
);
select throws_ok(
  $$ select public.encuesta_registrar_respuesta(gen_random_uuid(), 5, 5, 5, 5, 10, null) $$,
  'OR141', null, 'token inexistente se rechaza'
);

select public.encuesta_registrar_respuesta(current_setting('t.token')::uuid, 2, 5, 5, 4, 6, 'Llego tarde');
select is(
  (select estado from public.encuesta_satisfaccion where id = current_setting('t.id')::uuid),
  'RESPONDIDA',
  'la respuesta valida deja la encuesta RESPONDIDA'
);
select throws_ok(
  $$ select public.encuesta_registrar_respuesta(current_setting('t.token')::uuid, 5, 5, 5, 5, 10, null) $$,
  'OR142', null, 'una encuesta no se responde dos veces'
);
select is(
  (select count(*)::int from public.notificacion where tipo = 'SATISFACCION_BAJA'
    and viaje_id = '44000000-0000-0000-0000-0000000000e1'),
  1,
  'una respuesta baja genera la alerta SATISFACCION_BAJA'
);

-- ---------------------------------------------------------------------------
-- Metricas
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0000000-0000-0000-0000-0000000000e1', 'role', 'authenticated',
  'app_metadata', json_build_object('rol', 'ADMINISTRADOR'))::text, true);

select is(
  (select csat_global from public.satisfaccion_resumen(current_date - 1, current_date + 1)),
  4.00,
  'CSAT global = promedio de las 4 dimensiones (2+5+5+4)/4'
);
select is(
  (select nps from public.satisfaccion_resumen(current_date - 1, current_date + 1)),
  -100::numeric,
  'NPS con un detractor = -100'
);
select is(
  (select sin_contacto from public.satisfaccion_resumen(current_date - 1, current_date + 1)),
  1,
  'cuenta las encuestas sin contacto'
);
select is(
  (select comentario from public.satisfaccion_comentarios(current_date - 1, current_date + 1)),
  'Llego tarde',
  'lista el comentario de la respuesta'
);

select * from finish();

rollback;
