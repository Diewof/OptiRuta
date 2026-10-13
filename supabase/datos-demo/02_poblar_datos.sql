-- Datos de demostración abundantes para probar todas las pantallas.
-- NO es una migración: se corre a mano después de 01_borrar_datos.sql con
--   npx supabase db query --linked -f supabase/datos-demo/02_poblar_datos.sql
--
-- Qué crea (coherente con el modelo actual):
--   * 4 vehículos (3 doble troque + 1 mula), 6 conductores (1 inactivo, mezcla
--     de pago COMISION / FIJO / MIXTO), 13 clientes activos + 1 inactivo.
--   * ~500 viajes CERRADOS entre 2025-11 y la primera semana de octubre de
--     2026, con costos estimado vs real, hitos (a tiempo y con retraso) y
--     peajes capturados de GoPass.
--   * Otros estados: 1 FINALIZADO (pendiente de cierre) y 7 CANCELADO. No hay
--     viajes EN_CURSO, ASIGNADO ni PLANIFICADO.
--   * Tarifas de ACPM, mantenimientos, documentos (algunos por vencer o
--     vencidos), notificaciones de todos los tipos, ajustes y viajes eliminados.
--
-- Conductores de prueba: conductor1@optiruta.test ... conductor6@optiruta.test,
-- contraseña Conductor123! (el administrador no se toca). Datos ficticios.
-- Es determinista (setseed) salvo lo que depende de now().

do $$
declare
  v_admin     uuid;
  v_ahora     timestamptz := now();
  v_limite    timestamptz := timestamptz '2026-10-06 05:00:00-05';
  v_tz        text := 'America/Bogota';

  v_ciudades  jsonb := '{
    "Medellín":[6.2442,-75.5812],"Bogotá":[4.7110,-74.0721],"Cali":[3.4516,-76.5320],
    "Barranquilla":[10.9685,-74.7813],"Cartagena":[10.3910,-75.4794],
    "Bucaramanga":[7.1193,-73.1227],"Pereira":[4.8133,-75.6961],
    "Manizales":[5.0703,-75.5138],"Cúcuta":[7.8939,-72.5078],
    "Santa Marta":[11.2408,-74.1990],"Buenaventura":[3.8801,-77.0312],
    "Montería":[8.7480,-75.8814],"Rionegro":[6.1552,-75.3737],
    "Ibagué":[4.4389,-75.2322],"Villavicencio":[4.1420,-73.6266]}';

  -- Las primeras rutas pesan más (la empresa opera sobre todo desde Medellín).
  v_rutas     jsonb := '[
    {"o":"Medellín","d":"Bogotá","km":415,"min":540},
    {"o":"Medellín","d":"Cartagena","km":640,"min":780},
    {"o":"Medellín","d":"Barranquilla","km":700,"min":840},
    {"o":"Medellín","d":"Cali","km":420,"min":570},
    {"o":"Medellín","d":"Bucaramanga","km":400,"min":600},
    {"o":"Medellín","d":"Pereira","km":215,"min":300},
    {"o":"Medellín","d":"Manizales","km":190,"min":270},
    {"o":"Medellín","d":"Montería","km":400,"min":560},
    {"o":"Medellín","d":"Rionegro","km":45,"min":70},
    {"o":"Bogotá","d":"Cali","km":460,"min":600},
    {"o":"Bogotá","d":"Barranquilla","km":1000,"min":1140},
    {"o":"Bogotá","d":"Bucaramanga","km":400,"min":540},
    {"o":"Bogotá","d":"Villavicencio","km":120,"min":180},
    {"o":"Bogotá","d":"Ibagué","km":195,"min":270},
    {"o":"Cali","d":"Buenaventura","km":115,"min":180},
    {"o":"Barranquilla","d":"Cartagena","km":120,"min":150},
    {"o":"Cartagena","d":"Santa Marta","km":220,"min":270},
    {"o":"Bucaramanga","d":"Cúcuta","km":200,"min":300},
    {"o":"Pereira","d":"Cali","km":220,"min":300}]';

  v_peajes    text[] := array['Peaje Copacabana','Peaje Papiros','Peaje Cocorná',
    'Peaje Puerto Triunfo','Peaje Villeta','Peaje Honda','Peaje Turbaco',
    'Peaje Tasajera','Peaje Rodoviario','Peaje Lisboa','Peaje La Uribe','Peaje Pipiral'];
  v_otros     text[] := array['Comida y hospedaje del conductor','Lavado de lona',
    'Reparación de llanta en ruta','Pesaje en báscula','Parqueadero nocturno',
    'Bodegaje por demora en el cargue'];
  v_motivos   text[] := array['El cliente canceló el despacho',
    'Carga no disponible en bodega','Cambio de fecha solicitado por el cliente',
    'Vehículo en mantenimiento imprevisto','Orden duplicada por error de digitación',
    'Cierre de vía por derrumbe','El cliente reprogramó para el mes siguiente'];

  v_placas    text[] := array['XEJ344','TNB574','SPQ812','WMK690'];
  v_veh       uuid[];
  v_cond      uuid[];   -- 1..6, en el orden conductor1..conductor6
  v_cli       uuid[];   -- solo clientes activos
  v_pago      text[];
  v_pct       numeric[];

  v           int;
  i           int;
  j           int;
  n           int;
  t           timestamptz;
  v_estado    text;
  v_tail      jsonb;
  v_tail_n    int;
  v_item      jsonb;
  v_hist      boolean;
  v_n         int := 1000;
  v_pc        int := 0;

  r           jsonb;
  v_o         text;
  v_d         text;
  v_km        numeric;
  v_min       numeric;
  v_peso      numeric;
  v_tipo      text;
  v_rend      numeric;
  v_ci_idx    int;
  v_cliente   uuid;
  v_viaje     uuid;
  v_flete     numeric;
  v_anticipo  numeric;
  v_factor    numeric;
  v_dur       numeric;
  v_llegada   timestamptz;
  v_precio    numeric;
  v_acpm_e    numeric;
  v_acpm_r    numeric;
  v_peaje_e   numeric;
  v_peaje_r   numeric;
  v_com       numeric;
  v_x         numeric;
  v_k         int;
  v_resto     numeric;
  v_parte     numeric;
  v_olat      double precision;
  v_olng      double precision;
  v_dlat      double precision;
  v_dlng      double precision;
  v_origen_dato text;
  v_con_real  boolean;
  v_cap       boolean;
begin
  perform setseed(0.37);

  select id into v_admin from auth.users where email = 'jdgutierrezotalvaro04@gmail.com';
  if v_admin is null then
    raise exception 'No existe el administrador jdgutierrezotalvaro04@gmail.com.';
  end if;
  if exists (select 1 from public.viaje) or exists (select 1 from public.vehiculo) then
    raise exception 'Ya hay datos de negocio: corre primero 01_borrar_datos.sql.';
  end if;

  -- ---------------------------------------------------------------- usuarios
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, email_change,
    email_change_token_new, recovery_token)
  select '00000000-0000-0000-0000-000000000000',
         ('c0000000-0000-0000-0000-00000000000' || u.n)::uuid,
         'authenticated', 'authenticated', 'conductor' || u.n || '@optiruta.test',
         extensions.crypt('Conductor123!', extensions.gen_salt('bf')),
         now(), now(), '{"provider":"email","providers":["email"]}',
         jsonb_build_object('nombre', u.nombre, 'documento', u.doc, 'rol', 'CONDUCTOR'),
         now(), now(), '', '', '', ''
    from (values
      (1, 'Carlos Andrés Restrepo', '71654321'),
      (2, 'Jhon Fredy Zapata',      '98765432'),
      (3, 'Luis Alberto Giraldo',   '70123456'),
      (4, 'Mauricio Henao Vélez',   '15432109'),
      (5, 'Édgar Darío Montoya',    '71987654'),
      (6, 'Fabio Nelson Cárdenas',  '8123456')
    ) u (n, nombre, doc);

  insert into auth.identities (provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at)
  select id::text, id,
         jsonb_build_object('sub', id::text, 'email', email,
                            'email_verified', true, 'phone_verified', false),
         'email', now(), now(), now()
    from auth.users where email ~ '^conductor[1-6]@optiruta\.test$';

  -- ------------------------------------------------------------- catálogos
  insert into public.vehiculo (placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
  values ('XEJ344', 'DOBLE_TROQUE', 17, 9, true),
         ('TNB574', 'DOBLE_TROQUE', 17, 9.5, true),
         ('SPQ812', 'DOBLE_TROQUE', 16, 8.8, true),
         ('WMK690', 'MULA', 32, 6.5, true);
  select array_agg(id order by array_position(v_placas, placa)) into v_veh
    from public.vehiculo;

  insert into public.conductor (usuario_id, licencia, fecha_vencimiento_licencia,
    tipo_pago, porcentaje_comision, sueldo_base, activo,
    consentimiento_ubicacion_fecha)
  values
    ('c0000000-0000-0000-0000-000000000001', 'C3-71654321', date '2028-05-14', 'COMISION', 10, 0,       true,  v_ahora - interval '40 days'),
    ('c0000000-0000-0000-0000-000000000002', 'C3-98765432', date '2027-11-30', 'COMISION', 12, 0,       true,  v_ahora - interval '35 days'),
    ('c0000000-0000-0000-0000-000000000003', 'C3-70123456', date '2029-02-02', 'FIJO',      0, 2800000, true,  v_ahora - interval '30 days'),
    ('c0000000-0000-0000-0000-000000000004', 'C3-15432109', date '2026-12-15', 'MIXTO',     5, 1500000, true,  v_ahora - interval '25 days'),
    ('c0000000-0000-0000-0000-000000000005', 'C3-71987654', date '2028-09-09', 'COMISION', 10, 0,       true,  null),
    ('c0000000-0000-0000-0000-000000000006', 'C3-08123456', date '2027-03-21', 'COMISION', 10, 0,       false, null);
  select array_agg(c.id order by u.email),
         array_agg(c.tipo_pago order by u.email),
         array_agg(c.porcentaje_comision order by u.email)
    into v_cond, v_pago, v_pct
    from public.conductor c join auth.users u on u.id = c.usuario_id;

  insert into public.cliente (nombre, documento, telefono, correo, direccion, activo)
  values
    ('Cementos Argos Antioquia',        '890900266-1', '3105551201', 'logistica@argos-demo.co',    'Cra 43A # 1-50, Medellín', true),
    ('Postobón Distribución',           '890903939-5', '3105551202', 'despachos@postobon-demo.co', 'Cl 30 # 55-10, Medellín', true),
    ('Alimentos Cárnicos del Norte',    '890900608-9', '3105551203', 'carga@carnicos-demo.co',     'Autopista Norte km 8, Bello', true),
    ('Textiles Fabricato',              '890900120-6', '3105551204', 'trafico@fabricato-demo.co',  'Cl 38 # 50-22, Bello', true),
    ('Distribuidora Andina de Bebidas', '900123456-2', '3105551205', 'compras@andina-demo.co',     'Cra 65 # 12-80, Bogotá', true),
    ('Agroinsumos del Valle',           '900234567-3', '3105551206', 'bodega@agrovalle-demo.co',   'Cl 15 # 30-45, Cali', true),
    ('Ferretería Industrial Caribe',    '900345678-4', '3105551207', 'ventas@ferricaribe-demo.co', 'Vía 40 # 75-20, Barranquilla', true),
    ('Papeles y Cartones S.A.S.',       '900456789-5', '3105551208', 'logistica@papeles-demo.co',  'Cra 50 # 8-31, Medellín', true),
    ('Aceites y Grasas Santander',      '900567890-6', '3105551209', 'despacho@aceites-demo.co',   'Cl 45 # 27-15, Bucaramanga', true),
    ('Constructora Horizonte',          '900678901-7', '3105551210', 'obras@horizonte-demo.co',    'Cl 10 # 4-33, Pereira', true),
    ('Lácteos La Pradera',              '900789012-8', '3105551211', 'logistica@pradera-demo.co',  'Km 3 Vía Rionegro', true),
    ('Plásticos del Pacífico',          '900890123-9', '3105551212', 'trafico@plasticos-demo.co',  'Zona Franca, Buenaventura', true),
    ('Grupo Comercial Montería',        '901001234-0', '3105551213', 'compras@gcm-demo.co',        'Cra 3 # 25-60, Montería', true),
    ('Transportes Aliados (inactivo)',  '901112345-1', '3105551214', 'info@aliados-demo.co',       'Cl 80 # 20-10, Bogotá', false);
  select array_agg(id order by nombre) into v_cli from public.cliente where activo;

  -- ACPM: precio mensual en Medellín y una lectura reciente en otras ciudades
  insert into public.tarifa_combustible (ciudad, precio_galon, fecha_vigencia_desde, fuente)
  select 'Medellin', x.p, (date '2025-10-01' + ((x.k - 1) * interval '1 month'))::date,
         case when x.k in (4, 9) then 'MANUAL' else 'AUTOMATICO' end
    from unnest(array[10150,10300,10420,10380,10520,10650,10810,10900,11050,
                      11200,11320,11480,11560]) with ordinality as x (p, k);
  insert into public.tarifa_combustible (ciudad, precio_galon, fecha_vigencia_desde, fuente)
  values ('Bogota', 11620, date '2026-10-01', 'MANUAL'),
         ('Cali', 11540, date '2026-10-01', 'MANUAL'),
         ('Barranquilla', 11410, date '2026-10-01', 'MANUAL'),
         ('Cartagena', 11430, date '2026-09-01', 'MANUAL'),
         ('Bucaramanga', 11490, date '2026-09-01', 'MANUAL');

  -- Mantenimientos: ~9 por vehículo, un servicio cada ~38 días
  insert into public.mantenimiento_vehiculo (vehiculo_id, tipo, costo, fecha, kilometraje)
  select v_veh[g.v],
         (array['Cambio de aceite y filtros','Cambio de llantas','Revisión de frenos',
                'Alineación y balanceo','Revisión de suspensión','Cambio de batería',
                'Sincronización del motor','Cambio de correas',
                'Revisión del sistema eléctrico'])[1 + ((g.v + m.n) % 9)],
         round((case (g.v + m.n) % 9
                  when 0 then 650000 when 1 then 4200000 when 2 then 1350000
                  when 3 then 280000 when 4 then 1900000 when 5 then 780000
                  when 6 then 920000 when 7 then 540000 else 460000 end)
               * (0.9 + 0.2 * ((g.v * 7 + m.n * 3) % 10) / 10.0) / 1000) * 1000,
         date '2025-11-05' + (m.n * 38 + g.v * 6),
         180000 + g.v * 22000 + m.n * 11500
    from generate_series(1, 4) g (v)
   cross join generate_series(0, 9) m (n)
   where date '2025-11-05' + (m.n * 38 + g.v * 6) <= date '2026-10-05';

  insert into public.documento_vehiculo (vehiculo_id, tipo, fecha_vencimiento)
  values
    (v_veh[1], 'SOAT',          current_date + 12),   -- por vencer
    (v_veh[1], 'TECNOMECANICA', date '2027-03-15'),
    (v_veh[2], 'SOAT',          date '2027-01-10'),
    (v_veh[2], 'TECNOMECANICA', current_date + 8),    -- por vencer
    (v_veh[3], 'SOAT',          date '2026-12-05'),
    (v_veh[3], 'TECNOMECANICA', current_date - 5),    -- vencida
    (v_veh[4], 'SOAT',          date '2027-04-20'),
    (v_veh[4], 'TECNOMECANICA', date '2027-05-02');

  -- ----------------------------------------------------------------- viajes
  for v in 1..4 loop
    -- Cada vehículo arranca desfasado unas horas para no coincidir.
    t := timestamptz '2025-11-03 05:00:00-05' + (v * interval '7 hours');
    -- Sin viajes EN_CURSO, ASIGNADO ni PLANIFICADO (decisión del dueño):
    -- solo uno FINALIZADO esperando cierre del administrador.
    v_tail := (case v
      when 2 then '[{"e":"FINALIZADO","h":-12,"o":"Medellín","d":"Pereira"}]'
      else '[]'
    end)::jsonb;
    v_tail_n := 0;
    v_hist := true;

    loop
      if v_hist and t > v_limite then v_hist := false; end if;

      if v_hist then
        v_estado := 'CERRADO';
        i := 1 + floor(power(random()::numeric, 1.6) * 19)::int;
        r := v_rutas -> (i - 1);
        if random()::numeric < 0.5 then
          v_o := r ->> 'o'; v_d := r ->> 'd';
        else
          v_o := r ->> 'd'; v_d := r ->> 'o';
        end if;
      else
        exit when v_tail_n >= jsonb_array_length(v_tail);
        v_item := v_tail -> v_tail_n;
        v_tail_n := v_tail_n + 1;
        v_estado := v_item ->> 'e';
        t := v_ahora + ((v_item ->> 'h')::numeric * interval '1 hour');
        v_o := v_item ->> 'o';
        v_d := v_item ->> 'd';
        select x into r from jsonb_array_elements(v_rutas) x
         where (x ->> 'o' = v_o and x ->> 'd' = v_d)
            or (x ->> 'o' = v_d and x ->> 'd' = v_o)
         limit 1;
      end if;

      v_con_real := v_estado in ('CERRADO', 'FINALIZADO');
      v_km  := round((r ->> 'km')::numeric * (0.98 + random()::numeric * 0.05), 1);
      v_min := (r ->> 'min')::numeric + 120;      -- incluye cargue
      select tipo, rendimiento_km_galon into v_tipo, v_rend
        from public.vehiculo where id = v_veh[v];
      v_peso := case when v_tipo = 'MULA'
                     then 24 + round((random()::numeric * 8)::numeric, 1)
                     else 11 + round((random()::numeric * 6)::numeric, 1) end;

      v_ci_idx := v;
      if v_hist then
        if t < timestamptz '2026-02-01' and random()::numeric < 0.12 then v_ci_idx := 6;
        elsif random()::numeric < 0.15 then v_ci_idx := 5; end if;
      end if;
      v_cliente := v_cli[1 + floor(random()::numeric * array_length(v_cli, 1))::int];

      v_olat := (v_ciudades -> v_o ->> 0)::double precision;
      v_olng := (v_ciudades -> v_o ->> 1)::double precision;
      v_dlat := (v_ciudades -> v_d ->> 0)::double precision;
      v_dlng := (v_ciudades -> v_d ->> 1)::double precision;

      v_x := 5200 + random()::numeric * 3000;                       -- COP por km
      if random()::numeric < 0.06 then v_x := v_x * 0.6; end if;    -- fletes flojos
      v_flete := greatest(1200000, round(v_km * v_x
                   * (case when v_tipo = 'MULA' then 1.35 else 1 end) / 10000) * 10000);
      v_anticipo := case when random()::numeric < 0.2 then 0
                         else round(v_flete * (0.2 + random()::numeric * 0.3) / 10000) * 10000 end;

      select precio_galon into v_precio from public.tarifa_combustible
       where ciudad = 'Medellin'
         and fecha_vigencia_desde <= (t at time zone v_tz)::date
       order by fecha_vigencia_desde desc limit 1;
      v_precio := coalesce(v_precio, 10150);
      v_acpm_e := round(v_km / v_rend * v_precio * (1 + (v_peso - 10) * 0.004) / 1000) * 1000;
      v_acpm_r := round(v_acpm_e * (0.9 + random()::numeric * 0.25) / 1000) * 1000;
      v_peaje_e := round(v_km * (case when v_tipo = 'MULA' then 190 else 140 end
                                 + random()::numeric * 40) / 1000) * 1000;
      v_peaje_r := round(v_peaje_e * (0.9 + random()::numeric * 0.2) / 1000) * 1000;
      v_com := case when v_pago[v_ci_idx] in ('COMISION', 'MIXTO')
                    then round(v_flete * v_pct[v_ci_idx] / 100 / 1000) * 1000 else 0 end;

      v_factor := case when v_hist and random()::numeric >= 0.78
                       then 1.3 + random()::numeric * 0.4 else 0.85 + random()::numeric * 0.3 end;
      if not v_hist then v_factor := 1; end if;
      v_dur := round(v_min * v_factor);
      v_llegada := t + v_dur * interval '1 minute';

      n := v_n;
      v_n := v_n + 1;
      insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id,
        origen, destino, distancia_estimada, tiempo_estimado_min, peso_carga,
        estado, valor_flete, valor_anticipo, fecha_salida_programada,
        origen_lat, origen_lng, destino_lat, destino_lng)
      values (n::text, v_veh[v], v_cond[v_ci_idx], v_cliente, v_o, v_d, v_km, v_min,
        v_peso, case when v_estado = 'CERRADO' then 'FINALIZADO' else v_estado end,
        v_flete, v_anticipo, t, v_olat, v_olng, v_dlat, v_dlng)
      returning id into v_viaje;

      -- 85 % de los peajes llegan por el correo de GoPass
      v_cap := v_con_real and random()::numeric < 0.85;

      -- Costos: estimado siempre; real solo si el viaje ya terminó.
      insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
      values
        (v_viaje, 'ACPM', v_acpm_e, case when v_con_real then v_acpm_r end, 'AUTOMATICO'),
        (v_viaje, 'PEAJE', v_peaje_e, case when v_con_real then v_peaje_r end,
           case when v_cap then 'AUTOMATICO' else 'MANUAL' end);
      if v_com > 0 then
        insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
        values (v_viaje, 'COMISION', v_com, case when v_con_real then v_com end, 'MANUAL');
      end if;
      if v_con_real then
        insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
        values
          (v_viaje, 'CARGUE', 150000,
             (array[0,120000,150000,180000,250000])[1 + floor(random()::numeric * 5)::int], 'MANUAL'),
          (v_viaje, 'DESCARGUE', 120000,
             (array[0,100000,120000,150000,200000])[1 + floor(random()::numeric * 5)::int], 'MANUAL'),
          (v_viaje, 'PARQUEADERO', 40000,
             case when v_dur > 1200 then 40000 + floor(random()::numeric * 6)::int * 10000 else 0 end, 'MANUAL');
        if random()::numeric < 0.30 then
          insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente, descripcion)
          values (v_viaje, 'OTRO', 0, 30000 + floor(random()::numeric * 12)::int * 10000, 'MANUAL',
                  v_otros[1 + floor(random()::numeric * 6)::int]);
        end if;
        if random()::numeric < 0.08 then
          insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
          values (v_viaje, 'ACEITE', 0, 60000 + floor(random()::numeric * 5)::int * 10000, 'MANUAL');
        end if;
        if random()::numeric < 0.10 then
          insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
          values (v_viaje, 'LAVADO', 0, 30000 + floor(random()::numeric * 3)::int * 10000, 'MANUAL');
        end if;
        if random()::numeric < 0.10 then
          insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
          values (v_viaje, 'ENGRASE', 0, 25000 + floor(random()::numeric * 3)::int * 10000, 'MANUAL');
        end if;

        if v_cap then
          v_k := 2 + floor(random()::numeric * 3)::int;
          v_resto := v_peaje_r;
          for j in 1..v_k loop
            v_parte := case when j = v_k then v_resto
                            else round(v_peaje_r / v_k / 100) * 100 end;
            v_resto := v_resto - v_parte;
            v_pc := v_pc + 1;
            insert into public.peaje_capturado (viaje_id, placa, monto, fecha_hora,
              punto_peaje, correo_origen_id)
            values (v_viaje, v_placas[v], greatest(v_parte, 0),
              t + (v_dur * j / (v_k + 1.0)) * interval '1 minute',
              v_peajes[1 + floor(random()::numeric * 12)::int],
              'gopass-' || lpad(v_pc::text, 6, '0'));
          end loop;
        end if;

        -- Hitos: la bitácora histórica se cargó a mano; lo reciente por la app
        v_origen_dato := case when t < timestamptz '2026-03-01' then 'MANUAL' else 'APP' end;
        insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
        values
          (v_viaje, 'SALIDA', t, v_origen_dato),
          (v_viaje, 'LLEGADA_CARGUE', t + (v_dur * 0.06) * interval '1 minute', v_origen_dato),
          (v_viaje, 'SALIDA_CON_CARGA', t + (v_dur * 0.16) * interval '1 minute', v_origen_dato),
          (v_viaje, 'LLEGADA_DESTINO', v_llegada, v_origen_dato);
      elsif v_estado = 'EN_CURSO' then
        insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
        values
          (v_viaje, 'SALIDA', t, 'APP'),
          (v_viaje, 'LLEGADA_CARGUE', t + (v_min * 0.06) * interval '1 minute', 'APP'),
          (v_viaje, 'SALIDA_CON_CARGA', t + (v_min * 0.16) * interval '1 minute', 'APP');

        -- Un punto cada 5 minutos desde la salida hasta ahora
        insert into public.ubicacion_viaje (viaje_id, lat, lng, fecha_hora)
        select v_viaje,
               v_olat + (v_dlat - v_olat) * q.f + (random()::numeric - 0.5) * 0.004,
               v_olng + (v_dlng - v_olng) * q.f + (random()::numeric - 0.5) * 0.004,
               g
          from generate_series(t, v_ahora, interval '5 minutes') g
         cross join lateral (select least(0.97,
                 (extract(epoch from (g - t)) / 60.0 / v_min)::double precision) as f) q;
      end if;

      if v_estado = 'CERRADO' then
        update public.viaje
           set estado = 'CERRADO',
               fecha_cierre = least(v_llegada + (1 + random()::numeric * 35) * interval '1 hour',
                                    v_ahora - interval '2 hours')
         where id = v_viaje;

        -- Siguiente salida: 36–84 h después de llegar, a las 5–8 a. m.
        t := v_llegada + (36 + random()::numeric * 48) * interval '1 hour';
        t := (date_trunc('day', t at time zone v_tz) + interval '5 hours'
              + random()::numeric * interval '3 hours') at time zone v_tz;
      end if;
    end loop;
  end loop;

  -- Viajes cancelados repartidos en el año (no cuentan en rentabilidad)
  for n in 1..7 loop
    v := 1 + (n % 4);
    t := (timestamptz '2025-11-20 06:00:00-05') + (n * 44 * interval '1 day');
    r := v_rutas -> (floor(random()::numeric * 10))::int;
    v_o := r ->> 'o'; v_d := r ->> 'd';
    v_km := (r ->> 'km')::numeric;
    insert into public.viaje (remision, vehiculo_id, conductor_id, cliente_id,
      origen, destino, distancia_estimada, tiempo_estimado_min, peso_carga, estado,
      valor_flete, valor_anticipo, fecha_salida_programada, origen_lat, origen_lng,
      destino_lat, destino_lng, motivo_cancelacion, fecha_cancelacion)
    values ((v_n)::text, v_veh[v], v_cond[v], v_cli[1 + (n * 3) % array_length(v_cli, 1)],
      v_o, v_d, v_km, (r ->> 'min')::numeric + 120, 12 + n, 'CANCELADO',
      round(v_km * 6200 / 10000) * 10000, 0, t,
      (v_ciudades -> v_o ->> 0)::double precision, (v_ciudades -> v_o ->> 1)::double precision,
      (v_ciudades -> v_d ->> 0)::double precision, (v_ciudades -> v_d ->> 1)::double precision,
      v_motivos[n], t - interval '1 day');
    v_n := v_n + 1;
  end loop;

  -- Recorrido GPS (cada ~1/14 del viaje) de los 8 últimos viajes cerrados
  insert into public.ubicacion_viaje (viaje_id, lat, lng, fecha_hora)
  select s.id,
         s.olat + (s.dlat - s.olat) * (k / 14.0) + (random()::numeric - 0.5) * 0.003,
         s.olng + (s.dlng - s.olng) * (k / 14.0) + (random()::numeric - 0.5) * 0.003,
         s.salida + (s.llegada - s.salida) * (k / 14.0)
    from (select v.id, v.origen_lat as olat, v.origen_lng as olng,
                 v.destino_lat as dlat, v.destino_lng as dlng,
                 (select min(h.fecha_hora) from public.hito_viaje h
                   where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
                 (select max(h.fecha_hora) from public.hito_viaje h
                   where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada
            from public.viaje v where v.estado = 'CERRADO'
           order by v.fecha_cierre desc limit 8) s
   cross join generate_series(0, 14) k;

  -- ---------------------------------------------------------- notificaciones
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, fecha_creacion, leida)
  select 'DOCUMENTO_POR_VENCER',
         case when d.fecha_vencimiento < current_date
              then d.tipo || ' vencido · ' || ve.placa
              else d.tipo || ' por vencer · ' || ve.placa end,
         'El ' || d.tipo || ' del vehículo ' || ve.placa
           || case when d.fecha_vencimiento < current_date then ' venció el ' else ' vence el ' end
           || to_char(d.fecha_vencimiento, 'DD/MM/YYYY') || '.',
         ve.id, v_ahora - interval '3 hours', false
    from public.documento_vehiculo d join public.vehiculo ve on ve.id = d.vehiculo_id
   where d.fecha_vencimiento <= current_date + 30;

  insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, fecha_creacion, leida)
  select 'VIAJE_COMPLETADO', 'Viaje completado · ' || q.remision,
         q.origen || ' → ' || q.destino || ' entregado por ' || q.nombre || '.',
         q.id, q.vehiculo_id, q.fecha_cierre, q.rn > 6
    from (select v.*, u.nombre, row_number() over (order by v.fecha_cierre desc) rn
            from public.viaje v
            join public.conductor c on c.id = v.conductor_id
            join public.usuario u on u.id = c.usuario_id
           where v.estado = 'CERRADO') q
   where q.rn <= 14;

  insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, fecha_creacion, leida)
  select 'RETRASO', 'Retraso en viaje ' || q.remision,
         q.origen || ' → ' || q.destino || ': llegó con '
           || round((q.min_real - q.tiempo_estimado_min) / 60.0, 1)
           || ' h más de lo estimado.',
         q.id, q.vehiculo_id, q.llegada, q.rn > 3
    from (select v.*, extract(epoch from (l.llegada - l.salida)) / 60 as min_real,
                 l.llegada, row_number() over (order by v.fecha_cierre desc) rn
            from public.viaje v
            join lateral (select
                   (select min(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
                   (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada) l on true
           where v.estado = 'CERRADO'
             and extract(epoch from (l.llegada - l.salida)) / 60
                 > v.tiempo_estimado_min + greatest(v.tiempo_estimado_min * 0.2, 30)) q
   where q.rn <= 6;

  insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, fecha_creacion, leida)
  select 'PEAJE_REGISTRADO', 'Peaje registrado · ' || p.punto_peaje,
         'GoPass cobró $' || to_char(p.monto, 'FM999G999G999') || ' a la placa ' || p.placa || '.',
         p.viaje_id, ve.id, p.fecha_hora, true
    from (select * from public.peaje_capturado where viaje_id is not null
           order by fecha_hora desc limit 8) p
    join public.vehiculo ve on ve.placa = p.placa;

  insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, fecha_creacion, leida, lat, lng)
  select case when ve.placa = 'XEJ344' then 'DESVIO_RUTA' else 'PARADA_PROLONGADA' end,
         case when ve.placa = 'XEJ344' then 'Desvío de ruta · ' else 'Parada prolongada · ' end || ve.placa,
         case when ve.placa = 'XEJ344'
              then 'El vehículo se alejó más de 1 km de la ruta del viaje ' || v.remision || '.'
              else 'El vehículo lleva más de 30 minutos detenido en el viaje ' || v.remision || '.' end,
         v.id, ve.id, v_ahora - interval '20 minutes', false,
         (select u.lat from public.ubicacion_viaje u where u.viaje_id = v.id order by u.fecha_hora desc limit 1),
         (select u.lng from public.ubicacion_viaje u where u.viaje_id = v.id order by u.fecha_hora desc limit 1)
    from public.viaje v join public.vehiculo ve on ve.id = v.vehiculo_id
   where v.estado = 'EN_CURSO';

  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, fecha_creacion, leida)
  values
    ('NOVEDAD', 'Llantas desgastadas', 'El conductor reporta desgaste en las llantas traseras.', v_veh[3], v_ahora - interval '2 days', false),
    ('NOVEDAD', 'Cierre vial en la autopista', 'Derrumbe en el km 112 vía Bogotá; se recomienda salir temprano.', null, v_ahora - interval '5 days', true),
    ('NOVEDAD', 'Nueva tarifa de ACPM', 'Se actualizó el precio del galón para octubre.', null, v_ahora - interval '9 days', true);

  -- Peajes de GoPass que llegaron sin viaje asociado
  insert into public.peaje_capturado (viaje_id, placa, monto, fecha_hora, punto_peaje, correo_origen_id)
  values (null, 'SPQ812', 14500, v_ahora - interval '6 hours', 'Peaje Papiros', 'gopass-sin-viaje-1'),
         (null, 'WMK690', 21000, v_ahora - interval '30 hours', 'Peaje Villeta', 'gopass-sin-viaje-2'),
         (null, 'TNB574', 9800, v_ahora - interval '52 hours', 'Peaje Lisboa', 'gopass-sin-viaje-3');

  -- Ajustes sobre viajes cerrados (append-only) y bitácora de eliminados
  insert into public.ajuste_viaje (viaje_id, usuario_id, motivo, campo_modificado, valor_anterior, valor_nuevo, fecha)
  select q.id, v_admin,
         (array['Corrección de flete acordado con el cliente',
                'Ajuste por recibo de peaje no capturado',
                'Cambio de descargue autorizado por el cliente',
                'Error de digitación en el ACPM'])[q.rn - 20],
         (array['valor_flete','peaje','descargue','acpm'])[q.rn - 20],
         (array['2400000','180000','120000','410000'])[q.rn - 20],
         (array['2550000','195000','150000','385000'])[q.rn - 20],
         q.fecha_cierre + interval '2 days'
    from (select v.id, v.fecha_cierre, row_number() over (order by v.fecha_cierre desc) rn
            from public.viaje v where v.estado = 'CERRADO' offset 20 limit 4) q;

  insert into public.viaje_eliminado (viaje_id, remision, estado, origen, destino,
    valor_flete, motivo, eliminado_por, fecha_eliminacion)
  values (gen_random_uuid(), '995', 'PLANIFICADO', 'Medellín', 'Bogotá', 2600000,
          'Viaje creado por error', v_admin, v_ahora - interval '12 days'),
         (gen_random_uuid(), '996', 'ASIGNADO', 'Bogotá', 'Cali', 3100000,
          'Orden duplicada', v_admin, v_ahora - interval '4 days');
end $$;
