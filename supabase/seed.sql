-- Datos base para desarrollo local. NO se aplica en produccion (solo lo corre
-- `supabase db reset` / `supabase start` segun config.toml -> [db.seed]).
--
-- Crea dos usuarios de Auth. El trigger on_auth_user_created (ver la migracion
-- 20260902195223_auth_perfil.sql) puebla public.usuario y app_metadata.rol.
--
-- Credenciales:
--   admin@optiruta.test      / Admin123!       -> ADMINISTRADOR
--   conductor@optiruta.test  / Conductor123!   -> CONDUCTOR

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  last_sign_in_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-1111-1111-111111111111',
    'authenticated',
    'authenticated',
    'admin@optiruta.test',
    extensions.crypt('Admin123!', extensions.gen_salt('bf')),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Admin Prueba","documento":"CC-1000","rol":"ADMINISTRADOR"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-2222-2222-222222222222',
    'authenticated',
    'authenticated',
    'conductor@optiruta.test',
    extensions.crypt('Conductor123!', extensions.gen_salt('bf')),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Conductor Prueba","documento":"CC-2000","rol":"CONDUCTOR"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

-- Dos conductores demo mas (uno por vehiculo de la bitacora historica
-- importada mas abajo). Mismo patron que admin/conductor de prueba.
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  last_sign_in_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '33333333-3333-3333-3333-333333333333',
    'authenticated',
    'authenticated',
    'conductor.xej344@optiruta.test',
    extensions.crypt('Conductor123!', extensions.gen_salt('bf')),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Conductor Demo - XEJ344","documento":"CC-3000","rol":"CONDUCTOR"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '44444444-4444-4444-4444-444444444444',
    'authenticated',
    'authenticated',
    'conductor.tnb574@optiruta.test',
    extensions.crypt('Conductor123!', extensions.gen_salt('bf')),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Conductor Demo - TNB574","documento":"CC-4000","rol":"CONDUCTOR"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

-- Identidad de proveedor "email" requerida por GoTrue para signInWithPassword.
insert into auth.identities (
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    '{"sub":"11111111-1111-1111-1111-111111111111","email":"admin@optiruta.test","email_verified":true,"phone_verified":false}',
    'email',
    now(),
    now(),
    now()
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    '{"sub":"22222222-2222-2222-2222-222222222222","email":"conductor@optiruta.test","email_verified":true,"phone_verified":false}',
    'email',
    now(),
    now(),
    now()
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    '33333333-3333-3333-3333-333333333333',
    '{"sub":"33333333-3333-3333-3333-333333333333","email":"conductor.xej344@optiruta.test","email_verified":true,"phone_verified":false}',
    'email',
    now(),
    now(),
    now()
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    '44444444-4444-4444-4444-444444444444',
    '{"sub":"44444444-4444-4444-4444-444444444444","email":"conductor.tnb574@optiruta.test","email_verified":true,"phone_verified":false}',
    'email',
    now(),
    now(),
    now()
  );

-- ---------------------------------------------------------------------------
-- Dominio de negocio: 2 vehiculos, 2 conductores demo, 2 clientes demo y 77
-- viajes historicos reales de la bitacora de la empresa (BASES_DE_DATOS_VEHICULAR.xlsx),
-- limpiados en viajes_demo_limpios.csv / registro-limpieza-datos-viajes.csv
-- (ver diseno-base-de-datos-optiruta.md). Nombrados explicitamente como demo
-- porque no hay cliente/conductor real detras de la bitacora: es por placa,
-- no por persona ni por cliente.
--
-- Perfil de vehiculo: un solo perfil de referencia para las 2 placas (no hay
-- señal en los costos reales para distinguir cual seria la mula de la flota
-- de 4). Reemplazar por la ficha tecnica real en cuanto se tenga.
-- ---------------------------------------------------------------------------
insert into public.vehiculo (placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
values
  ('XEJ344', 'DOBLE_TROQUE', 17, 9, true),
  ('TNB574', 'DOBLE_TROQUE', 17, 9, true);

insert into public.conductor (usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo)
values
  ('33333333-3333-3333-3333-333333333333', 'DEMO-XEJ344', date '2030-01-01', 'COMISION', 10, 0, true),
  ('44444444-4444-4444-4444-444444444444', 'DEMO-TNB574', date '2030-01-01', 'COMISION', 10, 0, true);

insert into public.cliente (nombre, documento, telefono, direccion, activo)
values
  ('Cliente Demo - XEJ344', '900111222-1', '3001112233', 'Cra 1 # 1-01, Medellin', true),
  ('Cliente Demo - TNB574', '900333444-2', '3004445566', 'Cra 2 # 2-02, Medellin', true);


-- Viajes historicos reales (bitacora 2025-09 a 2026-08), importados desde
-- viajes_demo_limpios.csv (77 de 87 viajes; 10 excluidos por datos
-- irrecuperables -- fecha y/o origen/destino no registrados, detalle en
-- registro-limpieza-datos-viajes.csv aportado por el usuario). Cliente y
-- conductor demo por placa; vehiculo con perfil de referencia (ver migracion
-- de catalogos). Costos reales ya confirmados: valor_estimado = valor_real
-- (no hay estimado distinto disponible para datos historicos).
--
-- Se inserta primero en FINALIZADO (nunca bloqueado por
-- viaje_bloquear_si_cerrado) para poder cargar costo_viaje/hito_viaje, y
-- solo al final se hace el UPDATE a CERRADO -- unica forma de que la
-- transicion FINALIZADO->CERRADO del trigger viaje_validar_transicion la
-- acepte con costos e hitos ya cargados.
do $$
declare
  v_viaje_id uuid;
begin
  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '878',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Alcala', 'Don Matías', 'FINALIZADO', 3570000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 450000.0, 450000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 64000.0, 64000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 60000.0, 60000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 357000, 357000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 130000.0, 130000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 38500.0, 38500.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-03 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-04 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-04 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '879',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Copacabana', 'Turbo', 'FINALIZADO', 2200000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 330000.0, 330000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 127200.0, 127200.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 220000, 220000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-06 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-07 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-07 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '880',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Carepa', 'Marmato', 'FINALIZADO', 3500000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 920000.0, 920000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 354300.0, 354300.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 350000, 350000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-08 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-09 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-09 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '881',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Yotoco', 'Caicedo', 'FINALIZADO', 3600000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 964200.0, 964200.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 302600.0, 302600.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 179300.0, 179300.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 240000.0, 240000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 360000, 360000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-10 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-11 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-11 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '882',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Girardota', 'Apartado', 'FINALIZADO', 2869200.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 500000.0, 500000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 123100.0, 123100.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 190000.0, 190000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 370000.0, 370000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 57400.0, 57400.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 286920, 286920, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-11 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-13 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-13 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '883',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Caucheras', 'Guarne', 'FINALIZADO', 3500000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 670200.0, 670200.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 186500.0, 186500.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 45000.0, 45000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 350000, 350000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-14 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-15 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-15 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '885',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Rio Sucio', 'Marinilla', 'FINALIZADO', 4500000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1175000.0, 1175000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 289900.0, 289900.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 450000, 450000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-21 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-22 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-22 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '886',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Girardota', 'Bajirá', 'FINALIZADO', 2759300.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 400000.0, 400000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 237200.0, 237200.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 190000.0, 190000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 355000.0, 355000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 275930, 275930, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 50000.0, 50000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-22 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-24 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-24 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '887',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Rio Sucio', 'Medellin', 'FINALIZADO', 3800000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 895050.0, 895050.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 237200.0, 237200.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 380000, 380000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 17000.0, 17000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-24 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-25 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-25 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '888',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Girardota', 'Rio Sucio', 'FINALIZADO', 2925000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 475000.0, 475000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 163000.0, 163000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 190000.0, 190000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 50000.0, 50000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 292500, 292500, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-27 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-28 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-28 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '889',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Rio Sucio', 'San Jerónimo', 'FINALIZADO', 4000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 825000.0, 825000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 91300.0, 91300.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 50000.0, 50000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 400000, 400000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 35000.0, 35000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-29 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-31 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-31 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '891',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Girardota', 'Bajirá', 'FINALIZADO', 2841000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 520000.0, 520000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 91600.0, 91600.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 190000.0, 190000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 365000.0, 365000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 284100, 284100, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-08-10 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-08-12 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-08-12 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '892',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Brisas', 'Medellin', 'FINALIZADO', 3200000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 700000.0, 700000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 163100.0, 163100.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 38500.0, 38500.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 320000, 320000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-08-12 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-08-13 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-08-13 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '893',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Amaga', 'Apartado', 'FINALIZADO', 2400000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 751000.0, 751000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 75000.0, 75000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 240000, 240000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 303600.0, 303600.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-08-15 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-08-18 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-08-18 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '894',
    (select id from public.vehiculo where placa = 'TNB574'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - TNB574'),
    (select id from public.cliente where nombre = 'Cliente Demo - TNB574'),
    'Changas', 'Retiro', 'FINALIZADO', 0.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1325000.0, 1325000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 0, 0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 23900.0, 23900.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-08-19 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-08-22 00:00:00-05', 'MANUAL');

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '597',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Medellin', 'Apartado', 'FINALIZADO', 1600000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 427000.0, 427000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 160000, 160000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-09-15 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-09-16 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-09-16 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '598',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'San pedro Uraba', 'Medellin', 'FINALIZADO', 3500000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1010150.0, 1010150.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 16000.0, 16000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 350000, 350000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 21000.0, 21000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-09-17 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-09-19 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-09-19 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '599',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Medellin', 'Cali', 'FINALIZADO', 3253000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 550000.0, 550000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 49600.0, 49600.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 325300, 325300, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 162000.0, 162000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-09-19 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-09-20 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-09-20 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '600',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Tolú', 'Yarumal', 'FINALIZADO', 3840000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 920000.0, 920000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 263800.0, 263800.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 265000.0, 265000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 290000.0, 290000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 18000.0, 18000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 384000, 384000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 70000.0, 70000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-09-20 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-09-22 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-09-22 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '802',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'San Jose', 'Valledupar', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 750000.0, 750000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 789000.0, 789000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-09-27 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-09-27 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-09-27 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '803',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Agua chica', 'Medellin', 'FINALIZADO', 1860000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 400000.0, 400000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 28000.0, 28000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 186000, 186000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 133000.0, 133000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-09-29 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-09-30 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-09-30 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '804',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Canelos', 'Puerto Acasias', 'FINALIZADO', 5000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1200000.0, 1200000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 322500.0, 322500.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 36000.0, 36000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 500000, 500000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 200000.0, 200000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-02 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-10-04 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-10-04 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '805',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Canelos', 'Puerto Acasias', 'FINALIZADO', 5000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1241000.0, 1241000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 95300.0, 95300.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 33000.0, 33000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 500000, 500000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 500000.0, 500000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-06 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-10-08 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-10-08 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '806',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Amaga', 'Managru', 'FINALIZADO', 4444000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 921000.0, 921000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 450000.0, 450000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 72000.0, 72000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 444400, 444400, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 130000.0, 130000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 164500.0, 164500.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-09 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-10-10 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-10-10 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '807',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Amaga', 'Managru', 'FINALIZADO', 4444000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1046000.0, 1046000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 450000.0, 450000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 444400, 444400, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 575000.0, 575000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-14 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-10-15 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-10-15 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '808',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Amaga', 'Managru', 'FINALIZADO', 4127000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 500000.0, 500000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 14000.0, 14000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 450000.0, 450000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 412700, 412700, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 60000.0, 60000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-16 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-10-18 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-10-18 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '809',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Certeguis', 'Medellin', 'FINALIZADO', 3380000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 720000.0, 720000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 36000.0, 36000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 338000, 338000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 123000.0, 123000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-18 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-10-19 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-10-19 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '810',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Medellin', 'Caucasia', 'FINALIZADO', 3150000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 409000.0, 409000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 33000.0, 33000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 315000, 315000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 84500.0, 84500.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-21 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-10-22 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-10-22 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '811',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Planeta rica', 'Medellin', 'FINALIZADO', 3400000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 780000.0, 780000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 49000.0, 49000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 340000, 340000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 50000.0, 50000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-23 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-10-24 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-10-24 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '812',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Girardota', 'El Bagre', 'FINALIZADO', 2550000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 400000.0, 400000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 170000.0, 170000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 270000.0, 270000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 33000.0, 33000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 255000, 255000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 81000.0, 81000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-28 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-10-29 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-10-29 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '813',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Apartado', 'Bogota', 'FINALIZADO', 4000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1000000.0, 1000000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 60600.0, 60600.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 71000.0, 71000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 400000, 400000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 244000.0, 244000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-10-30 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-01 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-01 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '814',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Bogota', 'Medellin', 'FINALIZADO', 3740000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1190000.0, 1190000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 65000.0, 65000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 51000.0, 51000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 374000, 374000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 708600.0, 708600.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-03 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-07 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-07 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '815',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Medellin', 'Apartado', 'FINALIZADO', 2700000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 394000.0, 394000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 174000.0, 174000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 332000.0, 332000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 270000, 270000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-07 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-08 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-08 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '816',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Changas', 'Cienaga de oro', 'FINALIZADO', 2000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 537000.0, 537000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 200000, 200000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 45000.0, 45000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-10 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-11 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-11 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '817',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Changas', 'Chigorodo', 'FINALIZADO', 2000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 430000.0, 430000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 200000, 200000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-12 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-13 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-13 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '818',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Totumo', 'Medellin', 'FINALIZADO', 4000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 995000.0, 995000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 72000.0, 72000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 400000, 400000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 336500.0, 336500.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-13 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-15 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-15 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '819',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Medellin', 'Caicedo', 'FINALIZADO', 2000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 450000.0, 450000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 36000.0, 36000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 200000, 200000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 130000.0, 130000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-18 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-19 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-19 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '820',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Copacabana', 'Apartado', 'FINALIZADO', 1680000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 497000.0, 497000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 33000.0, 33000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 168000, 168000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-20 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-22 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-22 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '821',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'San pedro Uraba', 'Guarne', 'FINALIZADO', 4000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1176150.0, 1176150.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 50800.0, 50800.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 400000, 400000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 90000.0, 90000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-23 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-26 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-26 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '822',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Marinilla', 'San juan', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1070000.0, 1070000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 81500.0, 81500.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 93800.0, 93800.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-26 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-11-28 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-11-28 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '823',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Barranquilla', 'Uraba', 'FINALIZADO', 3060000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 500000.0, 500000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 49000.0, 49000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 211100.0, 211100.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 204000.0, 204000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 306000, 306000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 62200.0, 62200.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-11-29 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-12-01 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-12-01 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '824',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Bajirá', 'Medellin', 'FINALIZADO', 3640000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 500000.0, 500000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 50000.0, 50000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 52000.0, 52000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 364000, 364000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-12-03 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-12-05 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-12-05 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '825',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Marinilla', 'San juan', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 680000.0, 680000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 51500.0, 51500.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 50000.0, 50000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 556000.0, 556000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-12-11 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-12-13 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-12-13 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '826',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Planeta rica', 'Medellin', 'FINALIZADO', 3400000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 977950.0, 977950.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 100600.0, 100600.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 23000.0, 23000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 340000, 340000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-12-13 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-12-15 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-12-15 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '827',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Planeta rica', 'Medellin', 'FINALIZADO', 4400000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1201000.0, 1201000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 107800.0, 107800.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 35000.0, 35000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 440000, 440000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 35000.0, 35000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 598000.0, 598000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-12-16 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-12-18 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-12-18 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '828',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Caldas', 'Bogota', 'FINALIZADO', 3500000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 623000.0, 623000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 350000, 350000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 110000.0, 110000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-12-19 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-12-20 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-12-20 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '829',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Tolú', 'San pedro Uraba', 'FINALIZADO', 3444000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 500000.0, 500000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 55200.0, 55200.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 300000.0, 300000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 310000.0, 310000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 105000.0, 105000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 344400, 344400, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 150000.0, 150000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 62500.0, 62500.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-12-20 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-12-22 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-12-22 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '830',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Marinilla', 'San juan', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 819630.0, 819630.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 92500.0, 92500.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-12-27 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-12-28 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-12-28 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '831',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Guarando', 'Santa rosa de osos', 'FINALIZADO', 3607500.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1133000.0, 1133000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 300000.0, 300000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 237104.0, 237104.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 86000.0, 86000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 360750, 360750, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 121000.0, 121000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 293700.0, 293700.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2025-12-29 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2025-12-30 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2025-12-30 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '832',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Marinilla', 'San juan', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 965300.0, 965300.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 82000.0, 82000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 65000.0, 65000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-01-03 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-01-04 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-01-04 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '833',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Barranquilla', 'Barbosa', 'FINALIZADO', 3400000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 195500.0, 195500.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 204000.0, 204000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 41000.0, 41000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 340000, 340000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-01-06 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-01-08 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-01-08 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '834',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Medellin', 'Turbo', 'FINALIZADO', 1900000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 350000.0, 350000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 49100.0, 49100.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 15000.0, 15000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 115000.0, 115000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 190000, 190000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 517000.0, 517000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-01-12 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-01-13 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-01-13 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '835',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Brisas', 'Medellin', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 750000.0, 750000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 118900.0, 118900.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-01-14 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-01-16 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-01-16 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '836',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Girardota', 'El Bagre', 'FINALIZADO', 0.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 860000.0, 860000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 29800.0, 29800.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 375000.0, 375000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 691000.0, 691000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 70000.0, 70000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 0, 0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 114000.0, 114000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-01-20 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-01-22 00:00:00-05', 'MANUAL');

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '837',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Girardota', 'Bajirá', 'FINALIZADO', 2700000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 300000.0, 300000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 91600.0, 91600.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 173000.0, 173000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 301000.0, 301000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 55000.0, 55000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 270000, 270000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 60000.0, 60000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-01-24 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-01-26 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-01-26 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '838',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Brisas', 'Medellin', 'FINALIZADO', 0.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1135000.0, 1135000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 75000.0, 75000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 0, 0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 91000.0, 91000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 35000.0, 35000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 435000.0, 435000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-01-29 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-01-31 00:00:00-05', 'MANUAL');

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '839',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Medellin', 'Turbo', 'FINALIZADO', 2537000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 450000.0, 450000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 125700.0, 125700.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 220000.0, 220000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 55000.0, 55000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 253700, 253700, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-02 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-03 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-03 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '840',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Apartado', 'Sincelejo', 'FINALIZADO', 6840000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1474500.0, 1474500.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 60000.0, 60000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 684000, 684000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 165100.0, 165100.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-05 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-07 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-07 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '841',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Tolú', 'Medellin', 'FINALIZADO', 2957000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 70000.0, 70000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 263000.0, 263000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 295700, 295700, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 165500.0, 165500.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-08 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-09 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-09 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '842',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Girardota', 'Necocli', 'FINALIZADO', 4440000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 660000.0, 660000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 356000.0, 356000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 42000.0, 42000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 444000, 444000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 743650.0, 743650.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-11 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-12 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-12 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '843',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Turbo', 'Cali', 'FINALIZADO', 5014000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1180000.0, 1180000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 45000.0, 45000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 501400, 501400, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 380000.0, 380000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-13 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-15 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-15 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '844',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Zarzal', 'Medellin', 'FINALIZADO', 3412800.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 560000.0, 560000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 353950.0, 353950.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 429800.0, 429800.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 53000.0, 53000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 341280, 341280, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 150000.0, 150000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 35000.0, 35000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 306000.0, 306000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-18 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-19 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-19 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '845',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Rio Negro', 'Rio Claro', 'FINALIZADO', 2000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 739950.0, 739950.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 200000, 200000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 15400.0, 15400.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-19 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-20 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-20 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '846',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Rio Claro', 'Medellin', 'FINALIZADO', 1800000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 180000, 180000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 83000.0, 83000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-20 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-20 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-20 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '848',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Riosucio', 'Rio Negro', 'FINALIZADO', 4600000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 833300.0, 833300.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 460000, 460000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 15150.0, 15150.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-24 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-25 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-25 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '849',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Rio Negro', 'Buritica', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 370000.0, 370000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 62550.0, 62550.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-02-26 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-02-28 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-02-28 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '850',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Amaga', 'Santa rita', 'FINALIZADO', 6000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 1078100.0, 1078100.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 41000.0, 41000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 25000.0, 25000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 600000, 600000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 130000.0, 130000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-03-03 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-03-05 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-03-05 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '851',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Medellin', 'Apartado', 'FINALIZADO', 1700000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 500000.0, 500000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 170000, 170000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 33000.0, 33000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-03-07 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-03-09 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-03-09 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '852',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Totumo', 'Medellin', 'FINALIZADO', 3500000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 929950.0, 929950.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 60000.0, 60000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 350000, 350000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-03-09 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-03-11 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-03-11 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '853',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Medellin', 'Turbo', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 500000.0, 500000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 160000.0, 160000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-03-13 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-03-14 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-03-14 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '854',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Brisas', 'Medellin', 'FINALIZADO', 3200000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 798000.0, 798000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 320000, 320000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-03-17 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-03-19 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-03-19 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '855',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Rio Negro', 'Cisnero', 'FINALIZADO', 2300000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 250200.0, 250200.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 63400.0, 63400.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 10000.0, 10000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 60000.0, 60000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 230000, 230000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-03-20 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-03-21 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-03-21 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '856',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Amaga', 'Santa rita', 'FINALIZADO', 5200000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 990000.0, 990000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 520000, 520000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 100000.0, 100000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 42000.0, 42000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-03-24 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-03-25 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-03-25 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '857',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Rio Negro', 'Buritica', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 350000.0, 350000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 71500.0, 71500.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-03-27 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-03-28 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-03-28 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '859',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'San pedro Uraba', 'Plato magdalena', 'FINALIZADO', 4000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 603700.0, 603700.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 191300.0, 191300.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 40000.0, 40000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 20000.0, 20000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 400000, 400000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 70000.0, 70000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 0.0, 0.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-04-15 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-04-17 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-04-17 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '860',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Barranquilla', 'Salgar', 'FINALIZADO', 4420000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 450000.0, 450000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 87200.0, 87200.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 250000.0, 250000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 442000, 442000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 20000.0, 20000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-04-18 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-04-20 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-04-20 00:00:00-05' where id = v_viaje_id;

  insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id, origen, destino, estado, valor_flete, valor_anticipo)
  values (
    '884',
    (select id from public.vehiculo where placa = 'XEJ344'),
    (select c.id from public.conductor c join public.usuario u on u.id = c.usuario_id where u.nombre = 'Conductor Demo - XEJ344'),
    (select id from public.cliente where nombre = 'Cliente Demo - XEJ344'),
    'Rio Negro', 'Buritica', 'FINALIZADO', 3000000.0, 0.0
  )
  returning id into v_viaje_id;
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACPM', 435000.0, 435000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PEAJE', 300000.0, 300000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'CARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'DESCARGUE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'PARQUEADERO', 80000.0, 80000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'COMISION', 300000, 300000, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ACEITE', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'LAVADO', 0.0, 0.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'ENGRASE', 30000.0, 30000.0, 'MANUAL');
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
  values (v_viaje_id, 'OTRO', 30000.0, 30000.0, 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'SALIDA', timestamptz '2026-07-18 00:00:00-05', 'MANUAL');
  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (v_viaje_id, 'LLEGADA_DESTINO', timestamptz '2026-07-19 00:00:00-05', 'MANUAL');
  update public.viaje set estado = 'CERRADO', fecha_cierre = timestamptz '2026-07-19 00:00:00-05' where id = v_viaje_id;

end $$;