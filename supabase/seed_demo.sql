-- Datos de demostracion operativos de OptiRuta (BD remota de pruebas / demo).
--
-- BORRA todos los datos de negocio y todas las cuentas excepto el administrador
-- (jdgutierrezotalvaro04@gmail.com) y los catalogos cargados por migracion
-- (checklist_item, tipo_mantenimiento), y los vuelve a poblar con ~6 meses de
-- operacion de una flota de 4 vehiculos (3 doble troque + 1 mula). Pensado para
-- correrse UNA vez completo, dentro de una sola transaccion:
--   npx supabase db query --linked -f supabase/seed_demo.sql
--
-- Es determinista (setseed) y toma como "hoy" el now() del servidor: los viajes
-- terminan en el presente (dos en curso, uno asignado para manana y uno recien
-- finalizado esperando la salida del descargue) para que la demo se vea viva.
--
-- Credenciales de los conductores de demo: conductorN@optiruta.test / Conductor123!
-- (los mismos correos de antes). El administrador conserva su acceso Google.
--
-- Cubre: vehiculos con ficha tecnica y documentos, plan y hoja de vida de
-- mantenimiento, clientes, tarifas de ACPM, viajes en todos los estados
-- (ASIGNADO, EN_CURSO, FINALIZADO, CERRADO, CANCELADO), hitos con esperas de
-- cargue/descargue, costos estimado/real, tanqueos, peajes GoPass, ubicaciones
-- GPS, checklists (con fallas y autorizaciones), encuestas de satisfaccion,
-- alertas, ajustes de viajes cerrados y viajes eliminados.

begin;

select setseed(0.2610);

-- ---------------------------------------------------------------------------
-- Utilidades (temporales: desaparecen al terminar la sesion)
-- ---------------------------------------------------------------------------
create function pg_temp.rnd(a numeric, b numeric) returns numeric
language sql as $$ select a + random()::numeric * (b - a) $$;

create function pg_temp.mins(n numeric) returns interval
language sql as $$ select n::float8 * interval '1 minute' $$;

create function pg_temp.horas(n numeric) returns interval
language sql as $$ select n::float8 * interval '1 hour' $$;

-- Codificacion de polilinea (precision 5, la que devuelve OSRM).
create function pg_temp.enc_val(v bigint) returns text
language plpgsql as $$
declare
  n bigint := v << 1;
  s text := '';
begin
  if v < 0 then n := ~n; end if;
  while n >= 32 loop
    s := s || chr((32 | (n & 31))::int + 63);
    n := n >> 5;
  end loop;
  return s || chr(n::int + 63);
end;
$$;

create function pg_temp.enc_poli(lat0 float8, lng0 float8, lat1 float8, lng1 float8) returns text
language plpgsql as $$
declare
  s text := '';
  pla bigint := 0;
  plo bigint := 0;
  la bigint;
  lo bigint;
  i int;
  f float8;
begin
  for i in 0..8 loop
    f := i / 8.0;
    la := round((lat0 + (lat1 - lat0) * f + case when i in (0, 8) then 0 else 0.05 * sin(f * 9.4) end) * 1e5);
    lo := round((lng0 + (lng1 - lng0) * f + case when i in (0, 8) then 0 else 0.05 * cos(f * 7.1) end) * 1e5);
    s := s || pg_temp.enc_val(la - pla) || pg_temp.enc_val(lo - plo);
    pla := la;
    plo := lo;
  end loop;
  return s;
end;
$$;

-- Salidas entre las 05:00 y las 18:00 (hora Colombia).
create function pg_temp.ajustar_salida(ts timestamptz) returns timestamptz
language plpgsql as $$
declare
  l timestamp := ts at time zone 'America/Bogota';
begin
  if extract(hour from l) < 5 then
    l := date_trunc('day', l) + interval '5 hours' + pg_temp.mins(pg_temp.rnd(0, 90));
  elsif extract(hour from l) >= 18 then
    l := date_trunc('day', l) + interval '1 day 5 hours' + pg_temp.mins(pg_temp.rnd(0, 90));
  end if;
  return l at time zone 'America/Bogota';
end;
$$;

-- ---------------------------------------------------------------------------
-- 0. Borrado (todo menos catalogos y administrador)
-- ---------------------------------------------------------------------------
truncate table
  public.ajuste_viaje, public.checklist_autorizacion, public.checklist_respuesta,
  public.checklist_viaje, public.cliente, public.conductor, public.costo_viaje,
  public.documento_vehiculo, public.encuesta_satisfaccion, public.hito_viaje,
  public.mantenimiento_vehiculo, public.notificacion, public.pausa_activa_prueba,
  public.peaje_capturado, public.plan_mantenimiento, public.tanqueo_viaje,
  public.tarifa_combustible, public.ubicacion_viaje, public.vehiculo,
  public.viaje, public.viaje_eliminado
  restart identity cascade;

delete from public.usuario where id <> '885ff539-0afa-49e5-9bb3-3866a4e260b2';
delete from auth.users where id <> '885ff539-0afa-49e5-9bb3-3866a4e260b2';

-- Los timestamps y autores historicos se escriben a mano: se apagan solo los
-- triggers de auditoria (los de dominio -transiciones, encuesta, notificacion,
-- plan de mantenimiento- siguen activos).
alter table public.viaje disable trigger viaje_set_audit;
alter table public.costo_viaje disable trigger costo_viaje_set_audit;
alter table public.hito_viaje disable trigger hito_viaje_set_audit;
alter table public.tanqueo_viaje disable trigger tanqueo_viaje_set_audit;
alter table public.mantenimiento_vehiculo disable trigger mantenimiento_vehiculo_set_audit;
alter table public.documento_vehiculo disable trigger documento_vehiculo_set_audit;
alter table public.cliente disable trigger cliente_set_audit;
alter table public.conductor disable trigger conductor_set_audit;
alter table public.vehiculo disable trigger vehiculo_set_audit;
alter table public.tarifa_combustible disable trigger tarifa_combustible_set_audit;
alter table public.plan_mantenimiento disable trigger plan_mantenimiento_set_audit;

-- ---------------------------------------------------------------------------
-- 1. Geografia y rutas
-- ---------------------------------------------------------------------------
create temp table t_ciudad (
  cod text primary key, nombre text, tarifa text, lat float8, lng float8
);
insert into t_ciudad values
  ('MDE', 'Medellín, Antioquia',         'Medellin',     6.2442, -75.5812),
  ('BOG', 'Bogotá, D.C.',                'Bogota',       4.7110, -74.0721),
  ('CLO', 'Cali, Valle del Cauca',       'Cali',         3.4516, -76.5320),
  ('BAQ', 'Barranquilla, Atlántico',     'Barranquilla', 10.9685, -74.7813),
  ('CTG', 'Cartagena, Bolívar',          'Cartagena',    10.3910, -75.4794),
  ('BGA', 'Bucaramanga, Santander',      'Bucaramanga',  7.1193, -73.1227),
  ('BUN', 'Buenaventura, Valle del Cauca','Buenaventura', 3.8801, -77.0312);

create temp table t_lane_dir (a text, b text, km numeric, peajes text[]);
insert into t_lane_dir (a, b, km, peajes)
select a, b, km, pj from (values
  ('MDE','BOG',415,  array['Peaje Cocorná','Peaje Puerto Triunfo','Peaje Doradal','Peaje Puerto Salgar','Peaje Villeta','Peaje Siberia']),
  ('MDE','CTG',640,  array['Peaje Caucasia','Peaje Cuturú','Peaje Planeta Rica','Peaje Sincelejo','Peaje Turbaco','Peaje Papayal']),
  ('MDE','BAQ',765,  array['Peaje Caucasia','Peaje Cuturú','Peaje Sahagún','Peaje Sincelejo','Peaje Malambo','Peaje Sabanagrande']),
  ('MDE','CLO',420,  array['Peaje Pintada','Peaje Tres Puertas','Peaje Cartago','Peaje Cerritos','Peaje Estambul']),
  ('BOG','CLO',465,  array['Peaje Chusacá','Peaje Melgar','Peaje Gualanday','Peaje Cajamarca','Peaje Armenia','Peaje Tuluá']),
  ('BOG','BGA',395,  array['Peaje Albarracín','Peaje Chiquinquirá','Peaje Barbosa','Peaje Curití','Peaje Lisbona']),
  ('BOG','BAQ',1005, array['Peaje Puerto Salgar','Peaje Aguachica','Peaje Plato','Peaje Palermo','Peaje Sitionuevo']),
  ('BOG','BUN',520,  array['Peaje Chusacá','Peaje Gualanday','Peaje Armenia','Peaje Tuluá','Peaje Loboguerrero']),
  ('CLO','BUN',115,  array['Peaje Cencar','Peaje Loboguerrero']),
  ('CTG','BAQ',120,  array['Peaje Turbaco','Peaje Papayal','Peaje Sabanagrande']),
  ('BAQ','BGA',590,  array['Peaje Plato','Peaje Aguachica','Peaje San Alberto','Peaje Rionegro'])
) l(a, b, km, pj);
insert into t_lane_dir (a, b, km, peajes)
select b, a, km, peajes from t_lane_dir;

-- ---------------------------------------------------------------------------
-- 2. Tarifas de ACPM (precio por galon, serie mensual)
-- ---------------------------------------------------------------------------
insert into public.tarifa_combustible
  (ciudad, precio_galon, fecha_vigencia_desde, fuente, creado_por, fecha_creacion)
select c.ciudad, b.p + c.diferencia, b.mes,
       case when c.ciudad = 'Medellin' then 'AUTOMATICO' else 'MANUAL' end,
       case when c.ciudad = 'Medellin' then null else '885ff539-0afa-49e5-9bb3-3866a4e260b2'::uuid end,
       b.mes::timestamptz + interval '8 hours'
  from (values ('Medellin', 0), ('Bogota', 60), ('Cali', -20), ('Barranquilla', -150),
               ('Cartagena', -120), ('Bucaramanga', 40), ('Buenaventura', 20)) c(ciudad, diferencia)
 cross join (values (date '2026-04-01', 10880), (date '2026-05-01', 10950),
                    (date '2026-06-01', 11050), (date '2026-07-01', 11210),
                    (date '2026-08-01', 11340), (date '2026-09-01', 11480),
                    (date '2026-10-01', 11560)) b(mes, p);

-- ---------------------------------------------------------------------------
-- 3. Clientes
-- ---------------------------------------------------------------------------
create temp table t_cli (
  idx int primary key, id uuid default gen_random_uuid(), nombre text, ciudad text,
  documento text, telefono text, correo text, direccion text,
  factor numeric, espera_alta boolean, sesgo numeric
);
insert into t_cli (idx, nombre, ciudad, documento, telefono, correo, direccion, factor, espera_alta, sesgo) values
  (1, 'Cementos del Valle S.A.S.',                 'CLO', '900.412.775-3', '602 485 1200', 'logistica@cementosdelvalle.example',     'Calle 15 # 31-45, Yumbo, Valle del Cauca',          1.04, false,  0.15),
  (2, 'Alimentos La Sabana Ltda.',                 'BOG', '860.357.912-1', '601 743 5500', 'despachos@alimentoslasabana.example',     'Autopista Norte Km 18, Chía, Cundinamarca',         1.00, true,  -0.30),
  (3, 'Distribuidora Andina S.A.S.',               'MDE', '811.045.638-9', '604 372 9800', 'transporte@distandina.example',           'Carrera 52 # 12 Sur-60, Medellín, Antioquia',       1.02, false,  0.10),
  (4, 'Agroinsumos del Caribe S.A.S.',             'BAQ', '890.114.206-7', '605 360 4100', 'compras@agroinsumoscaribe.example',       'Vía 40 # 73-120, Barranquilla, Atlántico',          0.98, false,  0.00),
  (5, 'Siderúrgica del Pacífico S.A.',             'BUN', '800.221.540-5', '602 241 7700', 'patio@siderurgicadelpacifico.example',    'Zona Industrial Bahía, Buenaventura, Valle del Cauca', 1.01, true,  -0.55),
  (6, 'Plásticos Industriales de Antioquia S.A.S.', 'MDE', '900.688.019-2', '604 285 6300', 'logistica@plasticosantioquia.example',   'Carrera 48 # 98 Sur-30, Sabaneta, Antioquia',       1.03, false,  0.10),
  (7, 'Bebidas y Refrescos del Sur S.A.S.',        'CTG', '806.009.431-6', '605 653 2200', null,                                       'Zona Franca Parque Central, Cartagena, Bolívar',    0.84, false, -0.10),
  (8, 'Papeles y Empaques Nacionales S.A.',        'BOG', '860.052.144-0', '601 411 8800', null,                                       'Carrera 68 # 17-80, Fontibón, Bogotá D.C.',         0.96, false,  0.00);

insert into public.cliente (id, nombre, documento, telefono, correo, direccion, activo, creado_por, fecha_creacion)
select id, nombre, documento, telefono, correo, direccion, true,
       '885ff539-0afa-49e5-9bb3-3866a4e260b2', now() - interval '210 days' + idx * interval '2 days'
  from t_cli;

-- ---------------------------------------------------------------------------
-- 4. Vehiculos (ficha tecnica) y conductores
-- ---------------------------------------------------------------------------
create temp table t_veh (
  idx int primary key, id uuid default gen_random_uuid(), placa text, tipo text, cap numeric,
  rend numeric, rend_real numeric, marca text, linea text, anio int, vin text, motor text,
  ejes int, llantas int, pbv numeric, odo_ini numeric, ciudad_ini text
);
insert into t_veh (idx, placa, tipo, cap, rend, rend_real, marca, linea, anio, vin, motor, ejes, llantas, pbv, odo_ini, ciudad_ini) values
  (1, 'SXK418', 'DOBLE_TROQUE', 17, 7.2, 7.00, 'Kenworth',     'T370',          2019, '3BKHLN8X5KF512384', 'ISL9-3318842',  3, 10, 28000, 286400, 'MDE'),
  (2, 'TQB752', 'DOBLE_TROQUE', 17, 7.4, 7.20, 'Freightliner', 'M2 106',        2017, '3ALHCYDT9HDJX7731', 'DD13-9006127',  3, 10, 28000, 342950, 'BOG'),
  (3, 'WLN309', 'DOBLE_TROQUE', 17, 6.8, 6.70, 'Hino',         '500 FM 2635',   2016, 'JHDFM2PK9GXX10296', 'J08E-UV51207',  3, 10, 26000, 418300, 'BAQ'),
  (4, 'UZP627', 'MULA',         34, 4.8, 4.30, 'Kenworth',     'T800 tractocamión', 2020, '1XKDD49X4LJ455218', 'ISX15-7740931', 6, 22, 52000, 198700, 'CLO');

create temp table t_cond (
  idx int primary key, uid uuid default gen_random_uuid(), cid uuid default gen_random_uuid(),
  nombre text, doc text, email text, licencia text, venc date, tipo_pago text,
  pct numeric, sueldo numeric, consent boolean
);
insert into t_cond (idx, nombre, doc, email, licencia, venc, tipo_pago, pct, sueldo, consent) values
  (1, 'Carlos Andrés Restrepo Jaramillo', '71652318',   'conductor1@optiruta.test', '05001-3-0451829', date '2028-03-14', 'COMISION', 10, 0,       true),
  (2, 'Jhon Fredy Zapata Úsuga',          '98541207',   'conductor2@optiruta.test', '05045-3-0219374', date '2027-08-22', 'MIXTO',    5,  1800000, true),
  (3, 'Luis Alberto Giraldo Mejía',       '70118946',   'conductor3@optiruta.test', '05615-3-0087712', date '2027-11-05', 'FIJO',     0,  3200000, true),
  (4, 'Mauricio Henao Vélez',             '1037612884', 'conductor4@optiruta.test', '05001-3-1264403', date '2029-01-30', 'COMISION', 12, 0,       true),
  (5, 'Édgar Darío Montoya Pérez',        '8350771',    'conductor5@optiruta.test', '05266-3-0173958', date '2026-12-02', 'MIXTO',    6,  1800000, false);

insert into public.vehiculo
  (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo, marca, linea, modelo_anio, vin,
   numero_motor, numero_ejes, cantidad_llantas, pbv_kg, odometro_inicial_km, creado_por, fecha_creacion)
select id, placa, tipo, cap, rend, true, marca, linea, anio, vin, motor, ejes, llantas, pbv, odo_ini,
       '885ff539-0afa-49e5-9bb3-3866a4e260b2', now() - interval '200 days'
  from t_veh;

-- Cuentas de conductor (mismo patron que supabase/seed.sql). El trigger
-- handle_new_user crea public.usuario con rol CONDUCTOR.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, last_sign_in_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
select '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', email,
       extensions.crypt('Conductor123!', extensions.gen_salt('bf')), now(), now() - interval '1 day',
       '{"provider":"email","providers":["email"]}',
       jsonb_build_object('nombre', nombre, 'documento', doc),
       now() - interval '200 days', now(), '', '', '', ''
  from t_cond;

insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select uid::text, uid,
       jsonb_build_object('sub', uid::text, 'email', email, 'email_verified', true, 'phone_verified', false),
       'email', now() - interval '1 day', now() - interval '200 days', now()
  from t_cond;

insert into public.conductor
  (id, usuario_id, licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base,
   activo, creado_por, fecha_creacion, consentimiento_ubicacion_fecha)
select cid, uid, licencia, venc, tipo_pago, pct, sueldo, true,
       '885ff539-0afa-49e5-9bb3-3866a4e260b2', now() - interval '199 days',
       case when consent then now() - interval '198 days' end
  from t_cond;

-- ---------------------------------------------------------------------------
-- 5. Documentos de los vehiculos (el ultimo registrado por tipo es el vigente)
-- ---------------------------------------------------------------------------
insert into public.documento_vehiculo
  (vehiculo_id, tipo, numero, entidad_emisora, fecha_expedicion, fecha_vencimiento, creado_por, fecha_creacion)
select v.id, d.tipo, d.numero, d.entidad, d.expedicion, d.vencimiento,
       '885ff539-0afa-49e5-9bb3-3866a4e260b2', d.expedicion::timestamptz + interval '9 hours'
  from (values
    (1, 'SOAT',          '28741190652', 'Seguros del Estado S.A.',             date '2025-06-12', date '2026-06-11'),
    (1, 'SOAT',          '28741233910', 'Seguros del Estado S.A.',             date '2026-06-09', date '2027-06-08'),
    (1, 'TECNOMECANICA', 'CDA-0418872',  'CDA Diesel Medellín S.A.S.',          date '2025-09-03', date '2026-09-02'),
    (1, 'TECNOMECANICA', 'CDA-0509341',  'CDA Diesel Medellín S.A.S.',          date '2026-08-28', date '2027-08-27'),
    (2, 'SOAT',          '28650027714', 'Seguros Bolívar S.A.',                date '2025-08-20', date '2026-08-19'),
    (2, 'SOAT',          '28650099321', 'Seguros Bolívar S.A.',                date '2026-08-18', date '2027-08-17'),
    (2, 'TECNOMECANICA', 'RTM-7730218',  'Revisar Bogotá CDA Ltda.',            date '2025-11-10', date '2026-11-09'),
    (3, 'SOAT',          '28592204466', 'Mapfre Seguros Generales de Colombia', date '2025-05-03', date '2026-05-02'),
    (3, 'SOAT',          '28592288015', 'Mapfre Seguros Generales de Colombia', date '2026-04-29', date '2027-04-28'),
    (3, 'TECNOMECANICA', 'CDA-1127455',  'CDA Costa Caribe S.A.S.',             date '2025-07-15', date '2026-07-14'),
    (3, 'TECNOMECANICA', 'CDA-1190602',  'CDA Costa Caribe S.A.S.',             date '2026-07-10', date '2027-07-09'),
    (4, 'SOAT',          '28811346209', 'Seguros del Estado S.A.',             date '2025-11-25', date '2026-11-24'),
    (4, 'TECNOMECANICA', 'CDA-2204318',  'CDA Pacífico Cali S.A.S.',            date '2025-12-02', date '2026-12-01')
  ) d(vi, tipo, numero, entidad, expedicion, vencimiento)
  join t_veh v on v.idx = d.vi;

-- ---------------------------------------------------------------------------
-- 6. Plan de viajes de los ultimos 6 meses
-- ---------------------------------------------------------------------------
create temp table t_plan (
  seq int, vi int, ci int, org text, dst text, cli int, dep timestamptz, modo text,
  lc_off numeric, wait_c numeric, drive numeric, wait_d numeric, reg_sd boolean,
  km numeric, est numeric, peso numeric, flete numeric, rem text, motivo text
);

do $$
declare
  v_now timestamptz := now();
  vi int;
  vr record;
  cur text;
  prev text;
  t timestamptz;
  ln record;
  cli_i int;
  ci_i int;
  espera boolean;
  estx numeric;
  lc numeric; wc numeric; dr numeric; wd numeric;
  dep timestamptz;
  fin_ts timestamptz;
  rest_h numeric;
  trips int;
  modo text;
  total numeric;
  ratekm numeric;
  base_flete numeric;
begin
  for vi in 1..4 loop
    select * into vr from t_veh where idx = vi;
    cur := vr.ciudad_ini;
    prev := null;
    t := v_now - interval '182 days' + (vi - 1) * interval '7 hours';
    trips := 0;

    loop
      select a, b, km into ln
        from t_lane_dir
       where a = cur and (prev is null or b <> prev or random() < 0.3)
       order by random() limit 1;

      select idx, espera_alta into cli_i, espera
        from t_cli
       order by case when ciudad = cur then random() * 0.8 else random() end limit 1;

      estx := round(ln.km / 38 * 60 / 5) * 5;
      lc := round(pg_temp.rnd(15, 70));
      wc := round(case when espera then pg_temp.rnd(110, 330) else pg_temp.rnd(35, 105) end);
      dr := round(estx * pg_temp.rnd(0.84, 1.08));
      wd := round(case when espera then pg_temp.rnd(90, 260) else pg_temp.rnd(30, 100) end);
      modo := 'COMPLETO';
      if vi = 3 and trips = 14 then
        modo := 'CANCELADO_RUTA';
        dr := 180;
        wd := 0;
      end if;

      dep := pg_temp.ajustar_salida(t);
      total := lc + wc + dr + wd;
      fin_ts := dep + pg_temp.mins(total);
      rest_h := pg_temp.rnd(72, 120);
      exit when fin_ts + pg_temp.horas(rest_h) > v_now - interval '28 hours';

      ci_i := case when vi = 1 and random() < 0.12 then 5 else vi end;

      ratekm := case when vr.tipo = 'MULA' then 7900 else 5600 end;
      base_flete := greatest(ln.km * ratekm, case when vr.tipo = 'MULA' then 1500000 else 950000 end);

      insert into t_plan (vi, ci, org, dst, cli, dep, modo, lc_off, wait_c, drive, wait_d, reg_sd, km, est, peso, flete)
      values (vi, ci_i, ln.a, ln.b, cli_i, dep, modo, lc, wc, dr, wd,
              modo = 'COMPLETO' and random() < 0.80, ln.km, estx,
              case when vr.tipo = 'MULA' then round(pg_temp.rnd(24, 33.5), 1) else round(pg_temp.rnd(12.5, 17), 1) end,
              round(base_flete * (select factor from t_cli where idx = cli_i) * pg_temp.rnd(0.94, 1.07) / 10000) * 10000);

      prev := cur;
      cur := ln.b;
      t := fin_ts + pg_temp.horas(rest_h);
      trips := trips + 1;
    end loop;

    -- Viaje final de cada vehiculo (estado "de hoy")
    select a, b, km into ln
      from t_lane_dir
     where a = cur and (vi <> 4 or km <= 520)
     order by random() limit 1;
    estx := round(ln.km / 38 * 60 / 5) * 5;
    ratekm := case when vr.tipo = 'MULA' then 7900 else 5600 end;
    base_flete := greatest(ln.km * ratekm, case when vr.tipo = 'MULA' then 1500000 else 950000 end);

    if vi = 1 then       -- en ruta, ~40 % del trayecto
      select idx into cli_i from t_cli where not espera_alta order by case when ciudad = cur then 0 else 1 end, random() limit 1;
      lc := 40; wc := 95; dr := estx; wd := 0;
      dep := v_now - pg_temp.mins(lc + wc + 0.4 * dr);
      modo := 'EN_CURSO_RUTA';
    elsif vi = 2 then    -- esperando para cargar hace mas de 3 h
      select idx into cli_i from t_cli where espera_alta order by random() limit 1;
      lc := 25; wc := 330; dr := estx; wd := 0;
      dep := v_now - interval '3 hours 36 minutes';
      modo := 'EN_CURSO_CARGUE';
    elsif vi = 3 then    -- asignado para manana 6:00
      select idx into cli_i from t_cli order by case when ciudad = cur then 0 else 1 end, random() limit 1;
      lc := 30; wc := 90; dr := estx; wd := 0;
      dep := (date_trunc('day', v_now at time zone 'America/Bogota') + interval '1 day 6 hours') at time zone 'America/Bogota';
      modo := 'ASIGNADO';
    else                 -- finalizado hace 5 h, falta la salida del descargue
      select idx into cli_i from t_cli where not espera_alta order by case when ciudad = cur then 0 else 1 end, random() limit 1;
      lc := 30; wc := 110; dr := estx; wd := 0;
      dep := v_now - interval '5 hours' - pg_temp.mins(lc + wc + dr);
      modo := 'FINAL_SIN_DESCARGUE';
    end if;

    insert into t_plan (vi, ci, org, dst, cli, dep, modo, lc_off, wait_c, drive, wait_d, reg_sd, km, est, peso, flete)
    values (vi, vi, ln.a, ln.b, cli_i, dep, modo, lc, wc, dr, wd, false, ln.km, estx,
            case when vr.tipo = 'MULA' then 29.5 else 15.2 end,
            round(base_flete * (select factor from t_cli where idx = cli_i) * pg_temp.rnd(0.97, 1.05) / 10000) * 10000);
  end loop;

  -- Despachos cancelados antes de salir
  insert into t_plan (vi, ci, org, dst, cli, dep, modo, lc_off, wait_c, drive, wait_d, reg_sd, km, est, peso, flete, motivo)
  select s.vi, s.vi, l.a, l.b, s.cli, v_now - s.dias * interval '1 day' + interval '6 hours', 'CANCELADO_PRE',
         30, 90, round(l.km / 38 * 60 / 5) * 5, 60, false, l.km, round(l.km / 38 * 60 / 5) * 5,
         case when s.vi = 4 then 29.0 else 14.5 end,
         round(greatest(l.km * case when s.vi = 4 then 7900 else 5600 end, 950000) / 10000) * 10000,
         s.motivo
    from (values
      (2, 3, 143, 'Cliente canceló el despacho: sin producto disponible en planta'),
      (1, 6,  96, 'Vehículo retenido en taller por cambio de embrague; se reasignó el despacho'),
      (4, 5,  38, 'Cliente reprogramó la carga para la semana siguiente (se creó un viaje nuevo)')
    ) s(vi, cli, dias, motivo)
    join lateral (select a, b, km from t_lane_dir where a = (select ciudad_ini from t_veh where idx = s.vi) order by random() limit 1) l on true;
end;
$$;

-- Numeracion cronologica de remisiones
update t_plan p set seq = n.rn, rem = 'REM-2026-' || lpad(n.rn::text, 4, '0')
  from (select ctid c, row_number() over (order by dep) rn from t_plan) n
 where p.ctid = n.c;

-- ---------------------------------------------------------------------------
-- 7. Creacion de cada viaje con todo lo que lo rodea
-- ---------------------------------------------------------------------------
create function pg_temp.crear_viaje(p_seq int) returns void
language plpgsql as $$
declare
  v_now constant timestamptz := now();
  v_admin constant uuid := '885ff539-0afa-49e5-9bb3-3866a4e260b2';
  rp record; rv record; rc record; rl record; ro record; rd record; rk record;
  vid uuid := gen_random_uuid();
  t_sal timestamptz; t_lc timestamptz; t_sc timestamptz; t_ld timestamptz; t_sd timestamptz;
  t_cut timestamptz;
  lat0 float8; lng0 float8; lat1 float8; lng1 float8;
  v_precio numeric; v_factor numeric; v_pct numeric;
  acpm_est numeric; com_est numeric; peaje_est numeric; cargue_est numeric; desc_est numeric;
  parq_est numeric; viat_est numeric;
  acpm_real numeric; peaje_real numeric;
  rend_real numeric; gal_tot numeric; n_fill int; n_p int; n_p_ok int;
  frac numeric; horas_viaje numeric; noches int;
  km_gps numeric; km_orig text;
  completado boolean; activo boolean; con_hitos boolean; con_chk boolean;
  est_final text; sal_prog timestamptz; fcre timestamptz;
  chk_id uuid; chk_res text; falla text; falla_obs text; r numeric;
  pen_hasta numeric;
  v_placa text;
  u_cond uuid;
  num_inc int;
  lim numeric;
begin
  select * into rp from t_plan where seq = p_seq;
  select * into rv from t_veh where idx = rp.vi;
  select * into rc from t_cond where idx = rp.ci;
  select * into rk from t_cli where idx = rp.cli;
  select * into ro from t_ciudad where cod = rp.org;
  select * into rd from t_ciudad where cod = rp.dst;
  select * into rl from t_lane_dir where a = rp.org and b = rp.dst;
  v_placa := rv.placa;
  u_cond := rc.uid;

  t_sal := rp.dep;
  t_lc := t_sal + pg_temp.mins(rp.lc_off);
  t_sc := t_lc + pg_temp.mins(rp.wait_c);
  t_ld := t_sc + pg_temp.mins(rp.drive);
  t_sd := case when rp.reg_sd then t_ld + pg_temp.mins(rp.wait_d) end;

  completado := rp.modo in ('COMPLETO', 'FINAL_SIN_DESCARGUE');
  activo := rp.modo in ('EN_CURSO_RUTA', 'EN_CURSO_CARGUE');
  con_hitos := rp.modo not in ('ASIGNADO', 'CANCELADO_PRE');
  con_chk := con_hitos;

  lat0 := ro.lat + sin(p_seq) * 0.012;           lng0 := ro.lng + cos(p_seq * 1.7) * 0.012;
  lat1 := rd.lat + sin(p_seq * 2.3) * 0.012;     lng1 := rd.lng + cos(p_seq * 0.9) * 0.012;

  -- fraccion del trayecto recorrido al momento de corte
  if completado then
    frac := 1; t_cut := t_ld;
  elsif rp.modo = 'EN_CURSO_RUTA' then
    frac := least(1, greatest(0, extract(epoch from (v_now - t_sc)) / nullif(extract(epoch from (t_ld - t_sc)), 0)));
    t_cut := v_now;
  elsif rp.modo = 'EN_CURSO_CARGUE' then
    frac := 0; t_cut := v_now;
  elsif rp.modo = 'CANCELADO_RUTA' then
    frac := 0.25; t_cut := t_sc + interval '3 hours';
    t_ld := t_cut;
  else
    frac := 0; t_cut := null;
  end if;

  select precio_galon into v_precio
    from public.tarifa_combustible
   where ciudad = ro.tarifa and fecha_vigencia_desde <= (t_sal at time zone 'America/Bogota')::date
   order by fecha_vigencia_desde desc limit 1;
  v_factor := case when rv.cap <= 17 then 1.0 when rv.cap <= 25 then 1.1 else 1.2 end;
  acpm_est := round(rp.km / rv.rend * v_precio * v_factor, 2);
  v_pct := case when rc.tipo_pago = 'FIJO' then 0 else rc.pct end;
  com_est := round(rp.flete * v_pct / 100, 2);

  horas_viaje := extract(epoch from ((case when rp.modo = 'ASIGNADO' then t_sal + pg_temp.mins(rp.lc_off + rp.wait_c + rp.drive) else t_ld end) - t_sal)) / 3600;
  noches := greatest(0, ceil((horas_viaje - 10) / 24)::int);
  viat_est := 85000 * greatest(1, ceil(horas_viaje / 24)::int);
  parq_est := 40000 * noches;
  cargue_est := case when rv.tipo = 'MULA' then 320000 else 230000 end;
  desc_est := cargue_est;
  peaje_est := round(rp.km * 750 * case when rv.tipo = 'MULA' then 1.3 else 1 end / 1000) * 1000;

  fcre := least(v_now - interval '1 hour', t_sal - pg_temp.horas(pg_temp.rnd(20, 110)));
  if rp.modo = 'ASIGNADO' then fcre := v_now - interval '5 hours'; end if;
  sal_prog := t_sal - pg_temp.mins(pg_temp.rnd(-5, 35));

  -- Viaje (nace ASIGNADO, como en viaje_crear; los cancelados antes de salir
  -- nacen ya CANCELADO)
  insert into public.viaje (
    id, remision, vehiculo_id, conductor_id, cliente_id, origen, destino, distancia_estimada,
    tiempo_estimado_min, peso_carga, estado, valor_flete, valor_anticipo, fecha_salida_programada,
    origen_lat, origen_lng, destino_lat, destino_lng, ruta_polilinea, creado_por, fecha_creacion,
    motivo_cancelacion, fecha_cancelacion
  ) values (
    vid, rp.rem, rv.id, rc.cid, rk.id, ro.nombre, rd.nombre, rp.km, rp.est, rp.peso,
    case when rp.modo = 'CANCELADO_PRE' then 'CANCELADO' else 'ASIGNADO' end,
    rp.flete,
    case when random() < 0.5 then round(rp.flete * (case when random() < 0.5 then 0.3 else 0.5 end) / 10000) * 10000 else 0 end,
    sal_prog, lat0, lng0, lat1, lng1, pg_temp.enc_poli(lat0, lng0, lat1, lng1), v_admin, fcre,
    case when rp.modo = 'CANCELADO_PRE' then rp.motivo end,
    case when rp.modo = 'CANCELADO_PRE' then t_sal - pg_temp.horas(pg_temp.rnd(2, 20)) end
  );

  if rp.modo = 'CANCELADO_PRE' then
    insert into public.costo_viaje (viaje_id, categoria, valor_estimado, fuente, creado_por, fecha_creacion)
    values (vid, 'ACPM', acpm_est, 'AUTOMATICO', v_admin, fcre),
           (vid, 'COMISION', com_est, 'AUTOMATICO', v_admin, fcre);
    return;
  end if;

  -- Hitos
  if con_hitos then
    insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato, creado_por, fecha_creacion)
    select vid, h.tipo, h.ts,
           case when h.tipo <> 'SALIDA' and random() < 0.06 then 'MANUAL' else 'APP' end,
           u_cond, h.ts + interval '20 seconds'
      from (values
        ('SALIDA', t_sal, true),
        ('LLEGADA_CARGUE', t_lc, t_lc <= t_cut or rp.modo = 'EN_CURSO_CARGUE'),
        ('SALIDA_CON_CARGA', t_sc, rp.modo <> 'EN_CURSO_CARGUE'),
        ('LLEGADA_DESTINO', t_ld, completado),
        ('SALIDA_DESCARGUE', t_sd, completado and t_sd is not null)
      ) h(tipo, ts, existe)
     where h.existe and h.ts is not null;
  end if;

  -- Checklist de pre-arranque
  if con_chk then
    r := random();
    chk_res := case when r < 0.84 then 'APROBADO' when r < 0.96 then 'CON_OBSERVACIONES' else 'BLOQUEADO' end;
    falla := null; falla_obs := null;
    if chk_res = 'CON_OBSERVACIONES' then
      select x.codigo, x.obs into falla, falla_obs from (values
        ('LLANTA_REPUESTO',      'Llanta de repuesto con baja presión; se infló en ruta'),
        ('LUCES_REVERSA_ESTAC',  'Luz de reversa no enciende; se reemplaza el bombillo al regreso'),
        ('LIMPIABRISAS',         'Plumilla derecha desgastada'),
        ('BOTIQUIN',             'Botiquín incompleto: falta gasa estéril'),
        ('KIT_CARRETERA',        'Falta un cono del kit de carretera'),
        ('PITO',                 'Pito con sonido débil'),
        ('ESPEJOS',              'Espejo lateral derecho flojo')
      ) x(codigo, obs) order by random() limit 1;
    elsif chk_res = 'BLOQUEADO' then
      select x.codigo, x.obs into falla, falla_obs from (values
        ('FRENO_PARQUEO',     'Freno de parqueo con recorrido excesivo'),
        ('LUCES_STOP_DIRECC', 'Luz de stop izquierda fundida'),
        ('LLANTAS_ESTADO',    'Llanta trasera con desgaste irregular y corte en el costado'),
        ('FUGAS_AIRE_LIQUIDO','Fuga de aire en la cámara de freno trasera')
      ) x(codigo, obs) order by random() limit 1;
    end if;
    chk_id := gen_random_uuid();
    insert into public.checklist_viaje (id, viaje_id, vehiculo_id, conductor_id, fecha_hora, resultado, observaciones)
    values (chk_id, vid, rv.id, rc.cid, t_sal - pg_temp.mins(pg_temp.rnd(25, 70)), chk_res,
            case chk_res when 'APROBADO' then null when 'BLOQUEADO' then 'Se detuvo la salida hasta revisión de taller.' else 'Salida con observaciones menores.' end);
    insert into public.checklist_respuesta (checklist_id, item_id, estado, critico, observacion)
    select chk_id, i.id, case when i.codigo = falla then 'FALLA' else 'OK' end, i.critico,
           case when i.codigo = falla then falla_obs end
      from public.checklist_item i
     where i.activo and (i.aplica_tipo is null or i.aplica_tipo = rv.tipo);
    if chk_res = 'BLOQUEADO' then
      insert into public.checklist_autorizacion (checklist_id, usuario_id, motivo, fecha_hora)
      values (chk_id, v_admin,
              'Falla corregida en taller (' || falla_obs || '); revisión del jefe de flota y salida autorizada.',
              t_sal - pg_temp.mins(pg_temp.rnd(8, 20)));
    end if;
    if chk_res <> 'APROBADO' then
      insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, leida, fecha_creacion, clave)
      values ('CHECKLIST_FALLA', 'Falla en checklist · ' || v_placa,
              case when chk_res = 'BLOQUEADO'
                   then 'Falla crítica: ' || falla_obs || '. Salida bloqueada hasta autorización (viaje ' || rp.rem || ').'
                   else falla_obs || ' (no crítica, viaje ' || rp.rem || ').' end,
              vid, rv.id, (t_sal < v_now - interval '3 days'), t_sal - pg_temp.mins(40), 'CHK:' || chk_id);
    end if;
  end if;

  -- Peajes GoPass (correo -> peaje_capturado)
  if con_hitos and frac > 0 then
    n_p := greatest(1, round(rp.km / 52 * case when rp.modo = 'CANCELADO_RUTA' then 0.25 else 1 end)::int);
    insert into public.peaje_capturado (viaje_id, placa, monto, fecha_hora, punto_peaje, correo_origen_id)
    select vid, v_placa, round(39000 * case when rv.tipo = 'MULA' then 1.3 else 1 end * pg_temp.rnd(0.85, 1.15), -2),
           ts, rl.peajes[1 + (g - 1) % array_length(rl.peajes, 1)], 'gopass-' || md5(vid::text || g)
      from (select g, t_sc + (t_ld - t_sc) * (g::float8 / (n_p + 1)) as ts from generate_series(1, n_p) g) q(g, ts)
     where ts <= v_now and ts <= t_cut;
    select sum(monto), count(*) into peaje_real, n_p_ok from public.peaje_capturado where viaje_id = vid;
  end if;

  -- Combustible: tanqueos y rendimiento real del vehiculo
  if con_hitos and frac > 0 then
    rend_real := rv.rend_real * pg_temp.rnd(0.96, 1.04);
    if rv.idx = 3 and t_sal > v_now - interval '28 days' then
      -- Desde hace ~4 semanas el consumo de este vehiculo empeora ~20 %
      rend_real := rend_real * pg_temp.rnd(0.76, 0.82);
    end if;
    km_orig := case when random() < 0.9 then 'GPS' else 'ESTIMADO' end;
    km_gps := round(rp.km * case when km_orig = 'GPS' then pg_temp.rnd(1.005, 1.035) else 1 end, 1);
    gal_tot := (case when completado then km_gps else rp.km * frac end) / rend_real;
    if activo then gal_tot := gal_tot * 0.9 + 25; end if;
    n_fill := case when activo then 1 else least(4, greatest(1, round(gal_tot / case when rv.tipo = 'MULA' then 150 else 110 end)::int)) end;
    with w as (select g, pg_temp.rnd(0.8, 1.2) as w from generate_series(1, n_fill) g),
         s as (select sum(w) as sw from w)
    insert into public.tanqueo_viaje (viaje_id, galones, valor, fecha_hora, creado_por, fecha_creacion)
    select vid, round(gal_tot * w.w / s.sw, 1),
           round(round(gal_tot * w.w / s.sw, 1) * v_precio * pg_temp.rnd(0.97, 1.04), -2),
           ft, u_cond, ft
      from w cross join s
      cross join lateral (select case when w.g = 1 then t_sc - pg_temp.mins(pg_temp.rnd(10, 40))
                                      else t_sc + (t_cut - t_sc) * ((w.g - 1)::float8 / n_fill) end) f(ft);
    select sum(valor) into acpm_real from public.tanqueo_viaje where viaje_id = vid;
  end if;

  -- Costos (mismas 10 categorias que crea viaje_crear)
  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente, descripcion, creado_por, fecha_creacion)
  values
    (vid, 'ACPM',        acpm_est, acpm_real, 'AUTOMATICO', null, v_admin, fcre),
    (vid, 'COMISION',    com_est,  case when completado then com_est end, 'AUTOMATICO', null, v_admin, fcre),
    (vid, 'PEAJE',       case when rp.modo = 'ASIGNADO' then 0 else peaje_est end, peaje_real, 'MANUAL', null, v_admin, fcre),
    (vid, 'CARGUE',      cargue_est, case when completado then round(cargue_est * pg_temp.rnd(0.9, 1.22) / 5000) * 5000 end, 'MANUAL', null, v_admin, fcre),
    (vid, 'DESCARGUE',   desc_est,   case when completado then round(desc_est * pg_temp.rnd(0.9, 1.22) / 5000) * 5000 end, 'MANUAL', null, v_admin, fcre),
    (vid, 'PARQUEADERO', parq_est,   case when completado then round(parq_est * pg_temp.rnd(0.9, 1.15) / 1000) * 1000 end, 'MANUAL', null, v_admin, fcre),
    (vid, 'ACEITE',      0, case when completado and random() < 0.06 then round(pg_temp.rnd(80000, 120000), -3) end, 'MANUAL', null, v_admin, fcre),
    (vid, 'LAVADO',      0, case when completado and random() < 0.15 then round(pg_temp.rnd(45000, 70000), -3) end, 'MANUAL', null, v_admin, fcre),
    (vid, 'ENGRASE',     0, case when completado and random() < 0.08 then round(pg_temp.rnd(55000, 75000), -3) end, 'MANUAL', null, v_admin, fcre),
    (vid, 'OTRO',        viat_est, case when completado then round(viat_est * pg_temp.rnd(0.92, 1.1) / 1000) * 1000 end, 'MANUAL', 'Viáticos del conductor', v_admin, fcre);

  if completado then
    -- espera larga en cliente exigente: horas extra de cuadrilla pagadas
    if rk.espera_alta and rp.wait_c > 240 then
      insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente, descripcion, creado_por, fecha_creacion)
      values (vid, 'OTRO', 0, round(pg_temp.rnd(90000, 160000), -3), 'MANUAL', 'Horas extra de cuadrilla por demora en cargue', u_cond, t_sc);
    end if;
    if random() < 0.10 then
      insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente, descripcion, creado_por, fecha_creacion)
      select vid, 'OTRO', 0, x.v, 'MANUAL', x.d, u_cond, t_sc + (t_ld - t_sc) / 2
        from (values ('Reparación de pinchazo', 65000), ('Reparación de pinchazo', 80000),
                     ('Cambio de manguera de aire', 120000), ('Grúa por varada corta', 380000)) x(d, v)
       order by random() limit 1;
    end if;
  end if;

  -- Ubicaciones GPS (solo con consentimiento del conductor)
  if rc.consent and con_hitos and t_cut is not null then
    insert into public.ubicacion_viaje (viaje_id, lat, lng, fecha_hora)
    select vid,
           lat0 + (lat1 - lat0) * q.p + 0.008 * sin(q.p * 14 + p_seq),
           lng0 + (lng1 - lng0) * q.p + 0.008 * cos(q.p * 11 + p_seq),
           q.ts
      from (select ts,
                   case when rp.modo = 'CANCELADO_RUTA' then 0.25 * least(1, greatest(0, extract(epoch from (ts - t_sc)) / 10800.0))
                        else least(1, greatest(0, extract(epoch from (ts - t_sc)) / nullif(extract(epoch from (t_ld - t_sc)), 0))) end as p
              from generate_series(t_sal, t_cut + case when completado then interval '10 minutes' else interval '0 minutes' end,
                                   case when activo then interval '5 minutes' else interval '20 minutes' end) ts) q;
  end if;

  -- Incidencias en ruta (alimentan «Incidencias» de Calidad)
  if con_hitos and frac > 0 then
    num_inc := 0;
    lim := (case when rv.idx = 3 then 0.25 else 0.12 end);
    if rv.idx = 4 and t_sal >= date_trunc('month', v_now) and completado and not (rp.modo = 'FINAL_SIN_DESCARGUE') then
      -- Octubre: tres viajes con tres incidencias (alerta recurrente)
      insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, lat, lng, leida, fecha_creacion)
      values
        ('PARADA_PROLONGADA', 'Parada prolongada · ' || v_placa,
         format('El vehículo %s estuvo detenido %s min fuera de zona de descanso (%s → %s).', v_placa, 47, ro.nombre, rd.nombre),
         vid, rv.id, lat0 + (lat1 - lat0) * 0.4, lng0 + (lng1 - lng0) * 0.4, false, t_sc + (t_ld - t_sc) * 0.4),
        ('DESVIO_RUTA', 'Desvío de ruta · ' || v_placa,
         format('El vehículo %s se apartó %s km de la ruta %s → %s.', v_placa, 3.4, ro.nombre, rd.nombre),
         vid, rv.id, lat0 + (lat1 - lat0) * 0.55 + 0.03, lng0 + (lng1 - lng0) * 0.55 + 0.03, false, t_sc + (t_ld - t_sc) * 0.55),
        ('PAUSA_ACTIVA_IGNORADA', 'Pausa activa ignorada · ' || rc.nombre,
         format('%s no tomó la pausa activa tras %s min de conducción continua (%s → %s).', rc.nombre, 255, ro.nombre, rd.nombre),
         vid, rv.id, null, null, false, t_sc + (t_ld - t_sc) * 0.7);
    else
      if random() < lim then
        insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, lat, lng, leida, fecha_creacion)
        values ('PARADA_PROLONGADA', 'Parada prolongada · ' || v_placa,
                format('El vehículo %s estuvo detenido %s min en ruta (%s → %s).', v_placa, round(pg_temp.rnd(32, 75)), ro.nombre, rd.nombre),
                vid, rv.id, lat0 + (lat1 - lat0) * 0.45, lng0 + (lng1 - lng0) * 0.45,
                t_sal < v_now - interval '3 days', t_sc + (t_ld - t_sc) * 0.45);
      end if;
      if random() < 0.06 then
        insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, lat, lng, leida, fecha_creacion)
        values ('DESVIO_RUTA', 'Desvío de ruta · ' || v_placa,
                format('El vehículo %s se apartó %s km de la ruta %s → %s.', v_placa, round(pg_temp.rnd(1.2, 6), 1), ro.nombre, rd.nombre),
                vid, rv.id, lat0 + (lat1 - lat0) * 0.6 + 0.02, lng0 + (lng1 - lng0) * 0.6 + 0.02,
                t_sal < v_now - interval '3 days', t_sc + (t_ld - t_sc) * 0.6);
      end if;
      if random() < (case when rc.idx = 4 then 0.30 else 0.04 end) then
        insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, leida, fecha_creacion)
        values ('PAUSA_ACTIVA_IGNORADA', 'Pausa activa ignorada · ' || rc.nombre,
                format('%s no tomó la pausa activa tras %s min de conducción continua (%s → %s).', rc.nombre, round(pg_temp.rnd(250, 290)), ro.nombre, rd.nombre),
                vid, rv.id, t_sal < v_now - interval '3 days', t_sc + (t_ld - t_sc) * 0.7);
      end if;
    end if;
  end if;

  -- Retraso y peajes registrados
  if completado and extract(epoch from (t_ld - t_sal)) / 60 > rp.est + greatest(rp.est * 0.2, 30) and random() < 0.7 then
    insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, leida, fecha_creacion)
    values ('RETRASO', 'Viaje con retraso · ' || rp.rem,
            format('%s → %s supera el tiempo estimado en %s min.', ro.nombre, rd.nombre,
                   round(extract(epoch from (t_ld - t_sal)) / 60 - rp.est)),
            vid, rv.id, t_sal < v_now - interval '3 days', t_sal + pg_temp.mins(rp.est + greatest(rp.est * 0.2, 30) + 5));
  end if;
  if completado and n_p_ok > 0 then
    insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, leida, fecha_creacion)
    values ('PEAJE_REGISTRADO', 'Peajes registrados · ' || v_placa,
            format('Se registraron %s peajes por $%s del viaje %s.', n_p_ok, to_char(peaje_real, 'FM999G999G999'), rp.rem),
            vid, rv.id, t_sal < v_now - interval '3 days', t_ld + interval '12 minutes');
  end if;

  -- Estado final y km (los hitos y costos ya estan: despues del cierre no se pueden tocar)
  if rp.modo in ('COMPLETO', 'FINAL_SIN_DESCARGUE') then
    update public.viaje set estado = 'EN_CURSO' where id = vid;
    update public.viaje set estado = 'FINALIZADO', km_recorridos = case when km_orig = 'GPS' then km_gps else rp.km end,
           km_origen = km_orig where id = vid;
    if rp.modo = 'COMPLETO' and t_ld < v_now - interval '45 days' then
      update public.viaje set estado = 'CERRADO',
             fecha_cierre = least(v_now - interval '1 day', t_ld + pg_temp.horas(pg_temp.rnd(24, 150)))
       where id = vid;
    end if;
  elsif rp.modo in ('EN_CURSO_RUTA', 'EN_CURSO_CARGUE') then
    update public.viaje set estado = 'EN_CURSO' where id = vid;
  elsif rp.modo = 'CANCELADO_RUTA' then
    update public.viaje set estado = 'EN_CURSO' where id = vid;
    update public.viaje set estado = 'CANCELADO', motivo_cancelacion = 'Falla mecánica en ruta (manguera de turbo); el vehículo fue remolcado al taller y la carga se transbordó con otro transportador',
           fecha_cancelacion = t_cut + interval '40 minutes', km_recorridos = round(rp.km * 0.25, 1), km_origen = 'GPS'
     where id = vid;
  end if;
end;
$$;

do $$
declare s int;
begin
  for s in select seq from t_plan order by seq loop
    perform pg_temp.crear_viaje(s);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Encuestas de satisfaccion (las crea el trigger al finalizar cada viaje)
-- ---------------------------------------------------------------------------
create temp table t_enc as
select e.id as enc_id, e.viaje_id, c.correo, c.sesgo, e.minutos_retraso,
       (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = e.viaje_id and h.tipo = 'LLEGADA_DESTINO') as t_ld,
       random() as r1, random() as r2, random() as r3, random() as ra, random() as rb, random() as rc,
       random() as rd, random() as rn, random() as rcom
  from public.encuesta_satisfaccion e
  join t_cli c on c.id = e.cliente_id;

update public.encuesta_satisfaccion e set
  fecha_creacion = x.t_ld,
  vence_en = x.t_ld + interval '14 days',
  estado = x.estado,
  canal = case when x.correo is not null then 'CORREO' end,
  enlace = case when x.correo is not null then 'https://forms.gle/optiruta-satisfaccion?token=' || e.token end,
  intentos_envio = case when x.correo is not null then 1 else 0 end,
  fecha_envio = case when x.correo is not null then x.t_ld + x.envio_h * interval '1 hour' end,
  fecha_respuesta = case when x.estado = 'RESPONDIDA' then x.t_ld + (x.envio_h + 2 + x.r3 * 60) * interval '1 hour' end,
  csat_entrega    = case when x.estado = 'RESPONDIDA' then greatest(1, least(5, round(x.base + (x.ra - 0.5) * 1.6)))::smallint end,
  csat_servicio   = case when x.estado = 'RESPONDIDA' then greatest(1, least(5, round(x.base + (x.rb - 0.5) * 1.6)))::smallint end,
  csat_atencion   = case when x.estado = 'RESPONDIDA' then greatest(1, least(5, round(x.base + (x.rc - 0.5) * 1.6)))::smallint end,
  csat_puntualidad= case when x.estado = 'RESPONDIDA' then greatest(1, least(5, round(x.base - greatest(0, coalesce(x.minutos_retraso, 0) - 90) / 150.0 + (x.rd - 0.5) * 1.2)))::smallint end,
  nps             = case when x.estado = 'RESPONDIDA' then greatest(0, least(10, round(x.base * 2.1 - 0.6 + (x.rn - 0.5) * 3)))::smallint end,
  comentario      = case when x.estado = 'RESPONDIDA' and x.rcom < 0.4 then
                      case when x.base >= 4.0 then (array['Entrega puntual y conductor muy atento.','Sin novedades, la carga llegó en perfecto estado.','Buena comunicación durante todo el trayecto.','Todo conforme, seguiremos programando con ustedes.'])[1 + floor(x.ra * 4)::int]
                           when x.base >= 3.0 then (array['El servicio fue bueno, pero llegaron un poco tarde a la bodega.','Falta más comunicación sobre la hora estimada de llegada.','Cumplieron, aunque hubo demora en el cargue.'])[1 + floor(x.rb * 3)::int]
                           else (array['Llegaron muy tarde y no avisaron del retraso.','Demora excesiva en la entrega; afectó nuestra programación.','Mala comunicación con el despachador y la estiba llegó desordenada.'])[1 + floor(x.rc * 3)::int] end
                    end
from (
  select t.*, 4.6 + t.sesgo - least(0.8, greatest(0, coalesce(t.minutos_retraso, 0) - 90) / 300.0) as base,
         least(1 + t.r2 * 18, greatest(0.2, extract(epoch from (now() - t.t_ld)) / 3600 * 0.8)) as envio_h,
         case when t.correo is null then 'SIN_CONTACTO'
              when now() - t.t_ld > interval '14 days' then (case when t.r1 < 0.55 then 'RESPONDIDA' else 'VENCIDA' end)
              when now() - t.t_ld > interval '4 days'  then (case when t.r1 < 0.40 then 'RESPONDIDA' else 'ENVIADA' end)
              else 'ENVIADA' end as estado
    from t_enc t
) x
where e.id = x.enc_id;

insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, leida, fecha_creacion, clave)
select 'SATISFACCION_BAJA', 'Satisfacción baja · ' || c.nombre,
       format('El cliente calificó el viaje %s con %s/5 en puntualidad y NPS %s.', v.remision, e.csat_puntualidad, e.nps),
       e.viaje_id, e.vehiculo_id, e.fecha_respuesta < now() - interval '3 days', e.fecha_respuesta, 'SAT:' || e.id
  from public.encuesta_satisfaccion e
  join public.viaje v on v.id = e.viaje_id
  join public.cliente c on c.id = e.cliente_id
 where e.estado = 'RESPONDIDA'
   and (least(e.csat_entrega, e.csat_servicio, e.csat_atencion, e.csat_puntualidad) <= 2 or e.nps <= 6);

-- ---------------------------------------------------------------------------
-- 9. Mantenimiento (hoja de vida): historial previo + preventivos que van
--    venciendo por kilometraje durante los 6 meses + correctivos
-- ---------------------------------------------------------------------------
create function pg_temp.odometro_en(p_veh uuid, p_ts timestamptz) returns numeric
language sql as $$
  select coalesce((select odometro_inicial_km from public.vehiculo where id = p_veh), 0)
       + coalesce((select sum(v.km_recorridos)
                     from public.viaje v
                    where v.vehiculo_id = p_veh and v.estado in ('FINALIZADO', 'CERRADO')
                      and (select max(h.fecha_hora) from public.hito_viaje h
                            where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') <= p_ts), 0)
$$;

do $$
declare
  v_now timestamptz := now();
  v_admin constant uuid := '885ff539-0afa-49e5-9bb3-3866a4e260b2';
  w_ini date := (v_now - interval '182 days')::date;
  vr record; tp record; tr record;
  last_km numeric; odo numeric; off_km numeric; f date; costo numeric; taller text;
  talleres text[] := array['Diesel Service Medellín','Lubricantes y Frenos El Pesado','Taller Autodiésel Bogotá',
                           'Centro de Servicio Kenworth','Frenos y Embragues del Valle','Llantas y Servicios del Caribe'];
begin
  for vr in select * from t_veh order by idx loop
    for tp in select * from public.tipo_mantenimiento where intervalo_km is not null order by orden loop
      off_km := case tp.codigo
        when 'ACEITE_MOTOR' then pg_temp.rnd(5000, 12000)
        when 'FILTROS_AIRE_COMB' then pg_temp.rnd(10000, 30000)
        when 'ACEITE_CAJA_DIF' then pg_temp.rnd(15000, 50000)
        when 'ENGRASE' then pg_temp.rnd(2000, 8000)
        when 'REVISION_FRENOS' then pg_temp.rnd(10000, 32000)
        when 'ALINEACION_BALANCEO' then pg_temp.rnd(6000, 17000)
        else pg_temp.rnd(2000, 8000) end;
      last_km := round(vr.odo_ini - off_km);
      costo := case tp.codigo when 'ACEITE_MOTOR' then 1650000 when 'FILTROS_AIRE_COMB' then 480000 when 'ACEITE_CAJA_DIF' then 1350000
                              when 'ENGRASE' then 115000 when 'REVISION_FRENOS' then 2000000 when 'ALINEACION_BALANCEO' then 200000
                              else 300000 end * case when vr.tipo = 'MULA' then 1.45 else 1 end;
      taller := talleres[1 + floor(random() * 6)::int];
      insert into public.mantenimiento_vehiculo
        (vehiculo_id, tipo, costo, fecha, kilometraje, tipo_mantenimiento_id, categoria, taller, descripcion, creado_por, fecha_creacion)
      values (vr.id, tp.nombre, round(costo * pg_temp.rnd(0.9, 1.12), -3), w_ini - round(off_km / 330)::int, last_km, tp.id,
              'PREVENTIVO', taller, 'Mantenimiento programado según plan del vehículo.', v_admin, (w_ini - round(off_km / 330)::int)::timestamptz);

      for tr in
        select v.id, v.km_recorridos,
               (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as t_ld
          from public.viaje v
         where v.vehiculo_id = vr.id and v.estado in ('FINALIZADO', 'CERRADO')
         order by 3
      loop
        odo := pg_temp.odometro_en(vr.id, tr.t_ld);
        if odo - last_km >= tp.intervalo_km * pg_temp.rnd(0.94, 1.0)
           and not (vr.idx = 3 and tp.codigo = 'ALINEACION_BALANCEO')
           and tr.t_ld + interval '1 day' < v_now then
          insert into public.mantenimiento_vehiculo
            (vehiculo_id, tipo, costo, fecha, kilometraje, tipo_mantenimiento_id, categoria, taller, descripcion, creado_por, fecha_creacion)
          values (vr.id, tp.nombre, round(costo * pg_temp.rnd(0.95, 1.2), -3),
                  ((tr.t_ld + interval '1 day') at time zone 'America/Bogota')::date, round(odo), tp.id, 'PREVENTIVO',
                  talleres[1 + floor(random() * 6)::int], 'Mantenimiento programado según plan del vehículo.', v_admin, tr.t_ld + interval '1 day');
          last_km := odo;
        end if;
      end loop;
    end loop;
  end loop;

  -- Mantenimientos por tiempo (refrigerante/correas y bateria): ultimo servicio
  insert into public.mantenimiento_vehiculo
    (vehiculo_id, tipo, costo, fecha, kilometraje, tipo_mantenimiento_id, categoria, taller, descripcion, creado_por, fecha_creacion)
  select v.id, tm.nombre, m.costo, m.fecha, round(v.odo_ini - (w_ini - m.fecha) * 330), tm.id, 'PREVENTIVO', m.taller,
         'Mantenimiento programado según plan del vehículo.', v_admin, m.fecha::timestamptz
    from (values
      (1, 'REFRIGERANTE_CORREAS', date '2025-12-08', 620000, 'Diesel Service Medellín'),
      (1, 'BATERIA',              date '2026-01-20', 780000, 'Diesel Service Medellín'),
      (2, 'REFRIGERANTE_CORREAS', date '2025-11-15', 590000, 'Taller Autodiésel Bogotá'),
      (2, 'BATERIA',              date '2025-11-12', 840000, 'Taller Autodiésel Bogotá'),
      (3, 'REFRIGERANTE_CORREAS', date '2026-02-03', 560000, 'Llantas y Servicios del Caribe'),
      (3, 'BATERIA',              date '2025-09-30', 720000, 'Llantas y Servicios del Caribe'),
      (4, 'REFRIGERANTE_CORREAS', date '2026-03-18', 910000, 'Frenos y Embragues del Valle'),
      (4, 'BATERIA',              date '2026-03-18', 1080000, 'Frenos y Embragues del Valle')
    ) m(vi, codigo, fecha, costo, taller)
    join t_veh v on v.idx = m.vi
    join public.tipo_mantenimiento tm on tm.codigo = m.codigo;

  -- Correctivos
  insert into public.mantenimiento_vehiculo
    (vehiculo_id, tipo, costo, fecha, kilometraje, categoria, taller, descripcion, creado_por, fecha_creacion)
  select v.id, c.tipo, c.costo, c.fecha, round(pg_temp.odometro_en(v.id, c.fecha::timestamptz + interval '12 hours')),
         'CORRECTIVO', c.taller, c.descripcion, v_admin, c.fecha::timestamptz + interval '10 hours'
    from (values
      (1, 'Cambio de llantas direccionales', (v_now - interval '120 days')::date, 2840000, 'Llantas y Servicios del Caribe', 'Reemplazo de 2 llantas direccionales por desgaste irregular.'),
      (2, 'Cambio de kit de embrague',        (v_now - interval '96 days')::date,  3920000, 'Frenos y Embragues del Valle',   'Kit de embrague completo y rectificación de volante.'),
      (3, 'Reparación de manguera de turbo',  (v_now - interval '140 days')::date, 1180000, 'Taller Autodiésel Bogotá',        'Cambio de manguera de turbo y abrazaderas.'),
      (4, 'Cambio de manguera de radiador',   (v_now - interval '62 days')::date,  760000,  'Centro de Servicio Kenworth',     'Cambio de manguera superior de radiador y refrigerante.')
    ) c(vi, tipo, fecha, costo, taller, descripcion)
    join t_veh v on v.idx = c.vi;
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. Ajustes de viajes cerrados, viajes eliminados y pruebas de pausa activa
-- ---------------------------------------------------------------------------
with c as (
  select v.id, v.valor_flete, v.fecha_cierre, row_number() over (order by v.fecha_cierre) as rn
    from public.viaje v where v.estado = 'CERRADO'
), s as (
  select c.*, (c.rn / 18)::int % 6 + 1 as n from c where c.rn % 18 = 0
)
insert into public.ajuste_viaje (viaje_id, usuario_id, motivo, campo_modificado, valor_anterior, valor_nuevo, concepto, monto, fecha)
select s.id, '885ff539-0afa-49e5-9bb3-3866a4e260b2', m.motivo, m.campo,
       '$ ' || to_char(cur.valor, 'FM999G999G999'), '$ ' || to_char(cur.valor + m.monto, 'FM999G999G999'),
       m.concepto, m.monto, s.fecha_cierre + interval '2 days'
  from s
  join (values
    (1, 'Descuento por demora en entrega pactado con el cliente',        'Flete pactado', 'FLETE',       -150000::numeric),
    (2, 'Peaje adicional por desvío autorizado por cierre de vía',       'Peaje',         'PEAJE',         62000::numeric),
    (3, 'Cargue adicional por horas extra de cuadrilla',                 'Cargue',        'CARGUE',       120000::numeric),
    (4, 'Ajuste de tarifa acordado con el cliente tras renegociación',   'Flete pactado', 'FLETE',        200000::numeric),
    (5, 'Corrección de parqueadero: se pagó una noche adicional',        'Parqueadero',   'PARQUEADERO',   45000::numeric),
    (6, 'Reembolso del cliente por demora en descargue',                 'Flete pactado', 'FLETE',        180000::numeric)
  ) m(n, motivo, campo, concepto, monto) on m.n = s.n
  cross join lateral (
    select case when m.concepto = 'FLETE' then s.valor_flete
                else coalesce((select coalesce(cv.valor_real, cv.valor_estimado)
                                 from public.costo_viaje cv
                                where cv.viaje_id = s.id and cv.categoria = m.concepto limit 1), 0) end as valor
  ) cur;

insert into public.viaje_eliminado (viaje_id, remision, estado, origen, destino, valor_flete, motivo, eliminado_por, fecha_eliminacion)
values
  (gen_random_uuid(), 'REM-2026-0000', 'ASIGNADO',  'Medellín, Antioquia', 'Cartagena, Bolívar', 4170000,
   'Viaje duplicado por error de digitación al agendar', '885ff539-0afa-49e5-9bb3-3866a4e260b2', now() - interval '71 days'),
  (gen_random_uuid(), 'REM-2026-9999', 'FINALIZADO', 'Bogotá, D.C.', 'Cali, Valle del Cauca', 2740000,
   'Registrado con cliente equivocado; se creó de nuevo con el cliente correcto', '885ff539-0afa-49e5-9bb3-3866a4e260b2', now() - interval '33 days');

insert into public.pausa_activa_prueba (viaje_id, creado_por, fecha_creacion, consumida_en)
select v.id, '885ff539-0afa-49e5-9bb3-3866a4e260b2', v.t + interval '2 hours', v.t + interval '2 hours 1 minute'
  from (select vv.id, (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = vv.id and h.tipo = 'SALIDA_CON_CARGA') as t
          from public.viaje vv where vv.estado = 'CERRADO' order by vv.fecha_cierre desc limit 2) v;

-- ---------------------------------------------------------------------------
-- 11. Alertas de los procesos programados, con las fechas que habrian tenido
-- ---------------------------------------------------------------------------
select public.notificacion_generar();
select public.espera_alertas_generar();
select public.combustible_alertas_generar();
select public.calidad_alertas_generar();

-- VIAJE_COMPLETADO (trigger) y ESPERA_EXCESIVA nacieron "hoy": se fechan en su momento real.
update public.notificacion n set
  fecha_creacion = coalesce(
    (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = n.viaje_id and h.tipo = 'LLEGADA_DESTINO'), n.fecha_creacion),
  leida = coalesce(
    (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = n.viaje_id and h.tipo = 'LLEGADA_DESTINO') < now() - interval '3 days', n.leida)
where n.tipo = 'VIAJE_COMPLETADO';

update public.notificacion n set
  fecha_creacion = coalesce((select max(h.fecha_hora) from public.hito_viaje h
                              where h.viaje_id = n.viaje_id
                                and h.tipo = case when n.clave like '%:CARGUE' then 'SALIDA_CON_CARGA' else 'SALIDA_DESCARGUE' end), n.fecha_creacion),
  leida = coalesce((select max(h.fecha_hora) from public.hito_viaje h
                     where h.viaje_id = n.viaje_id
                       and h.tipo = case when n.clave like '%:CARGUE' then 'SALIDA_CON_CARGA' else 'SALIDA_DESCARGUE' end) < now() - interval '3 days', n.leida)
where n.tipo = 'ESPERA_EXCESIVA';

-- RETRASO de viajes ya terminados lo generan las demas rutas; el job solo
-- reporta lo que sigue vigente.

-- ---------------------------------------------------------------------------
-- 12. Cierre: restituir triggers de auditoria
-- ---------------------------------------------------------------------------
alter table public.viaje enable trigger viaje_set_audit;
alter table public.costo_viaje enable trigger costo_viaje_set_audit;
alter table public.hito_viaje enable trigger hito_viaje_set_audit;
alter table public.tanqueo_viaje enable trigger tanqueo_viaje_set_audit;
alter table public.mantenimiento_vehiculo enable trigger mantenimiento_vehiculo_set_audit;
alter table public.documento_vehiculo enable trigger documento_vehiculo_set_audit;
alter table public.cliente enable trigger cliente_set_audit;
alter table public.conductor enable trigger conductor_set_audit;
alter table public.vehiculo enable trigger vehiculo_set_audit;
alter table public.tarifa_combustible enable trigger tarifa_combustible_set_audit;
alter table public.plan_mantenimiento enable trigger plan_mantenimiento_set_audit;

commit;
