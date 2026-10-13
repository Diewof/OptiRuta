-- Fase 3: checklist pre-operacional del vehiculo y bloqueo al comenzar viaje.
--
-- Reglas (dueño, 2026-10-11):
--   * el conductor llena el checklist de su viaje ASIGNADO antes de comenzarlo;
--   * una falla en un item CRITICO bloquea la salida hasta que el administrador
--     la autorice con motivo; una falla no critica solo alerta al administrador;
--   * SOAT o tecnomecanica vencidos (o sin registrar) bloquean la salida.
-- Los checklists son append-only: repetirlo crea otro y vale el mas reciente;
-- la autorizacion del administrador es una fila aparte (no se edita el checklist).

-- ---------------------------------------------------------------------------
-- notificacion: tipos nuevos de la flota y clave de deduplicacion por origen
-- (el generador antiguo deduplicaba por vehiculo y perdia el segundo aviso).
-- ---------------------------------------------------------------------------
alter table public.notificacion drop constraint if exists notificacion_tipo_check;
alter table public.notificacion
  add constraint notificacion_tipo_check check (tipo in (
    'DOCUMENTO_POR_VENCER', 'DOCUMENTO_VENCIDO', 'MANTENIMIENTO_PROXIMO',
    'MANTENIMIENTO_VENCIDO', 'CHECKLIST_FALLA', 'RETRASO', 'VIAJE_COMPLETADO',
    'PEAJE_REGISTRADO', 'NOVEDAD', 'PARADA_PROLONGADA', 'DESVIO_RUTA'
  ));

alter table public.notificacion add column clave text;
create index notificacion_clave_idx on public.notificacion (clave) where clave is not null;

comment on column public.notificacion.clave is
  'Identifica el origen de la alerta (p. ej. DOC:<id>:30) para no repetirla.';

-- ---------------------------------------------------------------------------
-- Catalogo de items del checklist (solo lectura desde la app; se carga aqui)
-- ---------------------------------------------------------------------------
create table public.checklist_item (
  id          uuid primary key default gen_random_uuid(),
  codigo      text not null unique,
  grupo       text not null,
  nombre      text not null,
  critico     boolean not null default false,
  aplica_tipo text check (aplica_tipo is null or aplica_tipo in ('DOBLE_TROQUE', 'MULA')),
  orden       integer not null,
  activo      boolean not null default true
);

comment on column public.checklist_item.critico is
  'Una falla en un item critico bloquea la salida hasta que el administrador la autorice.';
comment on column public.checklist_item.aplica_tipo is 'Nulo = aplica a todo tipo de vehiculo.';

alter table public.checklist_item enable row level security;
revoke all on public.checklist_item from anon, authenticated;
grant select on public.checklist_item to authenticated;

create policy checklist_item_select_autenticado
  on public.checklist_item
  for select
  to authenticated
  using (true);

insert into public.checklist_item (codigo, grupo, nombre, critico, aplica_tipo, orden) values
  ('FRENO_SERVICIO',        'Frenos',                 'Freno de servicio responde bien',               true,  null, 10),
  ('FRENO_PARQUEO',         'Frenos',                 'Freno de parqueo o emergencia sostiene',        true,  null, 20),
  ('FUGAS_AIRE_LIQUIDO',    'Frenos',                 'Sin fugas de aire ni de líquido de frenos',     true,  null, 30),
  ('LLANTAS_ESTADO',        'Llantas',                'Presión y desgaste de las llantas',             true,  null, 40),
  ('LLANTAS_SUJECION',      'Llantas',                'Rines y tuercas bien ajustados',                true,  null, 50),
  ('LLANTA_REPUESTO',       'Llantas',                'Llanta de repuesto en buen estado',             false, null, 60),
  ('LUCES_BAJAS_ALTAS',     'Luces',                  'Luces bajas y altas',                           true,  null, 70),
  ('LUCES_STOP_DIRECC',     'Luces',                  'Stop y direccionales',                          true,  null, 80),
  ('LUCES_REVERSA_ESTAC',   'Luces',                  'Reversa y estacionarias',                       false, null, 90),
  ('DIRECCION',             'Dirección y suspensión', 'Dirección sin juego excesivo',                  true,  null, 100),
  ('SUSPENSION',            'Dirección y suspensión', 'Suspensión y muelles sin daños visibles',       false, null, 110),
  ('ACEITE_MOTOR',          'Líquidos',               'Nivel de aceite del motor',                     false, null, 120),
  ('REFRIGERANTE',          'Líquidos',               'Nivel de refrigerante',                         false, null, 130),
  ('LIQUIDO_FRENOS',        'Líquidos',               'Nivel de líquido de frenos',                    false, null, 140),
  ('COMBUSTIBLE',           'Líquidos',               'Combustible suficiente para el tramo',          false, null, 150),
  ('ESPEJOS',               'Cabina',                 'Espejos completos y ajustados',                 false, null, 160),
  ('LIMPIABRISAS',          'Cabina',                 'Limpiabrisas y parabrisas',                     false, null, 170),
  ('PITO',                  'Cabina',                 'Pito funciona',                                 false, null, 180),
  ('CINTURON',              'Cabina',                 'Cinturón de seguridad',                         false, null, 190),
  ('TABLERO',               'Cabina',                 'Tablero sin testigos de falla encendidos',      false, null, 200),
  ('CARGA_AMARRE',          'Carga',                  'Carga bien amarrada y cubierta',                true,  null, 210),
  ('QUINTA_RUEDA',          'Acople',                 'Quinta rueda y pin de acople asegurados',       true,  'MULA', 220),
  ('CONEXIONES_REMOLQUE',   'Acople',                 'Conexiones de aire y luces del remolque',       true,  'MULA', 230),
  ('EXTINTOR',              'Seguridad',              'Extintor cargado y vigente',                    false, null, 240),
  ('BOTIQUIN',              'Seguridad',              'Botiquín completo',                             false, null, 250),
  ('KIT_CARRETERA',         'Seguridad',              'Kit de carretera (triángulos, taco, linterna, herramienta)', false, null, 260);

-- ---------------------------------------------------------------------------
-- checklist_viaje / checklist_respuesta / checklist_autorizacion
-- ---------------------------------------------------------------------------
create table public.checklist_viaje (
  id             uuid primary key default gen_random_uuid(),
  viaje_id       uuid not null references public.viaje (id) on delete cascade,
  vehiculo_id    uuid not null references public.vehiculo (id) on delete restrict,
  conductor_id   uuid not null references public.conductor (id) on delete restrict,
  fecha_hora     timestamptz not null default now(),
  resultado      text not null check (resultado in ('APROBADO', 'CON_OBSERVACIONES', 'BLOQUEADO')),
  observaciones  text check (observaciones is null or char_length(observaciones) <= 500)
);

create index checklist_viaje_viaje_fecha_idx on public.checklist_viaje (viaje_id, fecha_hora desc);
create index checklist_viaje_vehiculo_fecha_idx on public.checklist_viaje (vehiculo_id, fecha_hora desc);

create table public.checklist_respuesta (
  id            uuid primary key default gen_random_uuid(),
  checklist_id  uuid not null references public.checklist_viaje (id) on delete cascade,
  item_id       uuid not null references public.checklist_item (id) on delete restrict,
  estado        text not null check (estado in ('OK', 'FALLA')),
  critico       boolean not null,
  observacion   text check (observacion is null or char_length(observacion) <= 300),
  unique (checklist_id, item_id),
  check (estado = 'OK' or observacion is not null)
);

comment on column public.checklist_respuesta.critico is
  'Copia de checklist_item.critico al momento de responder: cambiar el catalogo no reescribe el historial.';

create table public.checklist_autorizacion (
  id            uuid primary key default gen_random_uuid(),
  checklist_id  uuid not null unique references public.checklist_viaje (id) on delete cascade,
  usuario_id    uuid not null,
  motivo        text not null check (char_length(btrim(motivo)) between 1 and 300),
  fecha_hora    timestamptz not null default now()
);

alter table public.checklist_viaje enable row level security;
alter table public.checklist_respuesta enable row level security;
alter table public.checklist_autorizacion enable row level security;

revoke all on public.checklist_viaje, public.checklist_respuesta, public.checklist_autorizacion
  from anon, authenticated;
grant select on public.checklist_viaje, public.checklist_respuesta, public.checklist_autorizacion
  to authenticated;

-- Solo SELECT: las filas las crean checklist_registrar / checklist_autorizar_salida
-- (SECURITY DEFINER) y no se editan ni se borran.
create policy checklist_viaje_select_admin
  on public.checklist_viaje for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy checklist_viaje_select_conductor_propio
  on public.checklist_viaje for select to authenticated
  using (
    exists (
      select 1 from public.conductor c
      where c.id = checklist_viaje.conductor_id
        and c.usuario_id = (select auth.uid())
    )
  );

create policy checklist_respuesta_select_admin
  on public.checklist_respuesta for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy checklist_respuesta_select_conductor_propio
  on public.checklist_respuesta for select to authenticated
  using (
    exists (
      select 1 from public.checklist_viaje k
      join public.conductor c on c.id = k.conductor_id
      where k.id = checklist_respuesta.checklist_id
        and c.usuario_id = (select auth.uid())
    )
  );

create policy checklist_autorizacion_select_admin
  on public.checklist_autorizacion for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy checklist_autorizacion_select_conductor_propio
  on public.checklist_autorizacion for select to authenticated
  using (
    exists (
      select 1 from public.checklist_viaje k
      join public.conductor c on c.id = k.conductor_id
      where k.id = checklist_autorizacion.checklist_id
        and c.usuario_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- checklist_registrar
--
-- p_respuestas: arreglo JSON [{"item_id": uuid, "estado": "OK"|"FALLA",
-- "observacion": text}]. Deben venir todos los items activos que aplican al
-- tipo del vehiculo, ni uno mas ni uno menos. Una falla exige observacion.
-- ---------------------------------------------------------------------------
create or replace function public.checklist_registrar(
  p_viaje_id uuid,
  p_respuestas jsonb,
  p_observaciones text default null
)
returns public.checklist_viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje     public.viaje;
  v_tipo      text;
  v_placa     text;
  v_critica   boolean;
  v_falla     boolean;
  v_fallas    text;
  v_resultado text;
  v_check     public.checklist_viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede registrar el checklist.'
      using errcode = 'OR105';
  end if;

  select v.* into v_viaje
    from public.viaje v
    join public.conductor c on c.id = v.conductor_id
   where v.id = p_viaje_id
     and c.usuario_id = (select auth.uid())
   for update of v;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado <> 'ASIGNADO' then
    raise exception 'El checklist se llena antes de comenzar un viaje asignado.'
      using errcode = 'OR133';
  end if;

  select ve.tipo, ve.placa into v_tipo, v_placa
    from public.vehiculo ve where ve.id = v_viaje.vehiculo_id;

  if p_respuestas is null or jsonb_typeof(p_respuestas) <> 'array' then
    raise exception 'El checklist no es válido.' using errcode = 'OR134';
  end if;

  -- Debe responderse exactamente el conjunto de items aplicables, sin repetir.
  if (select count(*) <> count(distinct r.item_id)
        from jsonb_to_recordset(p_respuestas) as r(item_id uuid, estado text, observacion text))
     or exists (
       select 1 from public.checklist_item i
        where i.activo and (i.aplica_tipo is null or i.aplica_tipo = v_tipo)
          and not exists (
            select 1 from jsonb_to_recordset(p_respuestas) as r(item_id uuid, estado text, observacion text)
             where r.item_id = i.id)
     )
     or exists (
       select 1 from jsonb_to_recordset(p_respuestas) as r(item_id uuid, estado text, observacion text)
        where r.estado is null or r.estado not in ('OK', 'FALLA')
           or not exists (
             select 1 from public.checklist_item i
              where i.id = r.item_id and i.activo
                and (i.aplica_tipo is null or i.aplica_tipo = v_tipo))
     ) then
    raise exception 'Faltan ítems por responder en el checklist.' using errcode = 'OR134';
  end if;

  if exists (
    select 1 from jsonb_to_recordset(p_respuestas) as r(item_id uuid, estado text, observacion text)
     where r.estado = 'FALLA' and btrim(coalesce(r.observacion, '')) = ''
  ) then
    raise exception 'Describe cada falla que marcaste.' using errcode = 'OR135';
  end if;

  select coalesce(bool_or(r.estado = 'FALLA' and i.critico), false),
         coalesce(bool_or(r.estado = 'FALLA'), false),
         string_agg(i.nombre, ', ' order by i.orden) filter (where r.estado = 'FALLA')
    into v_critica, v_falla, v_fallas
    from jsonb_to_recordset(p_respuestas) as r(item_id uuid, estado text, observacion text)
    join public.checklist_item i on i.id = r.item_id;

  v_resultado := case
    when v_critica then 'BLOQUEADO'
    when v_falla then 'CON_OBSERVACIONES'
    else 'APROBADO'
  end;

  insert into public.checklist_viaje (viaje_id, vehiculo_id, conductor_id, resultado, observaciones)
  values (p_viaje_id, v_viaje.vehiculo_id, v_viaje.conductor_id, v_resultado,
          nullif(btrim(coalesce(p_observaciones, '')), ''))
  returning * into v_check;

  insert into public.checklist_respuesta (checklist_id, item_id, estado, critico, observacion)
  select v_check.id, r.item_id, r.estado, i.critico, nullif(btrim(coalesce(r.observacion, '')), '')
    from jsonb_to_recordset(p_respuestas) as r(item_id uuid, estado text, observacion text)
    join public.checklist_item i on i.id = r.item_id;

  if v_falla then
    insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, clave)
    values (
      'CHECKLIST_FALLA',
      case when v_critica then 'Checklist con falla crítica' else 'Checklist con observaciones' end,
      format(
        '%s (viaje %s): %s%s.',
        v_placa, v_viaje.remision, v_fallas,
        case when v_critica then '. El vehículo no puede salir sin tu autorización' else '' end
      ),
      p_viaje_id, v_viaje.vehiculo_id, 'CHECKLIST:' || v_check.id
    );
  end if;

  return v_check;
end;
$$;

revoke all on function public.checklist_registrar(uuid, jsonb, text) from public;
grant execute on function public.checklist_registrar(uuid, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------------
-- checklist_autorizar_salida: el administrador permite salir con una falla
-- critica. Aplica al checklist mas reciente del viaje; motivo obligatorio.
-- ---------------------------------------------------------------------------
create or replace function public.checklist_autorizar_salida(
  p_viaje_id uuid,
  p_motivo text
)
returns public.checklist_autorizacion
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_check public.checklist_viaje;
  v_aut   public.checklist_autorizacion;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede autorizar la salida.' using errcode = 'OR105';
  end if;

  if btrim(coalesce(p_motivo, '')) = '' then
    raise exception 'El motivo de la autorización es obligatorio.' using errcode = 'OR106';
  end if;

  select k.* into v_check
    from public.checklist_viaje k
   where k.viaje_id = p_viaje_id
   order by k.fecha_hora desc
   limit 1;

  if not found then
    raise exception 'El viaje no tiene checklist.' using errcode = 'OR136';
  end if;

  if v_check.resultado <> 'BLOQUEADO' then
    raise exception 'Este checklist no requiere autorización.' using errcode = 'OR136';
  end if;

  insert into public.checklist_autorizacion (checklist_id, usuario_id, motivo)
  values (v_check.id, (select auth.uid()), btrim(p_motivo))
  on conflict (checklist_id) do nothing
  returning * into v_aut;

  if v_aut.id is null then
    select a.* into v_aut from public.checklist_autorizacion a where a.checklist_id = v_check.id;
  end if;

  return v_aut;
end;
$$;

revoke all on function public.checklist_autorizar_salida(uuid, text) from public;
grant execute on function public.checklist_autorizar_salida(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- viaje_iniciar: misma firma; ahora exige documentos vigentes y un checklist
-- reciente (12 h) sin bloqueo pendiente, antes de validar el radio de 500 m.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_iniciar(
  p_viaje_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_fecha_hora timestamptz default now()
)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_radio_max_m  constant numeric := 500;
  c_checklist_h  constant integer := 12;
  v_viaje        public.viaje;
  v_distancia_m  numeric;
  v_check        public.checklist_viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede comenzarlo.'
      using errcode = 'OR105';
  end if;

  if p_lat is null or p_lng is null
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'No se pudo leer tu ubicacion. Activa el GPS e intenta de nuevo.'
      using errcode = 'OR117';
  end if;

  select v.* into v_viaje
    from public.viaje v
    join public.conductor c on c.id = v.conductor_id
   where v.id = p_viaje_id
     and c.usuario_id = (select auth.uid())
   for update of v;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado <> 'ASIGNADO' then
    raise exception 'Solo se puede comenzar un viaje asignado.' using errcode = 'OR119';
  end if;

  -- SOAT y tecnomecanica vigentes (OR132).
  perform public.vehiculo_validar_documentos(v_viaje.vehiculo_id);

  -- Checklist reciente y sin bloqueo pendiente.
  select k.* into v_check
    from public.checklist_viaje k
   where k.viaje_id = p_viaje_id
   order by k.fecha_hora desc
   limit 1;

  if not found or v_check.fecha_hora < now() - make_interval(hours => c_checklist_h) then
    raise exception 'Antes de comenzar debes completar el checklist del vehículo (vale % horas).', c_checklist_h
      using errcode = 'OR137';
  end if;

  if v_check.resultado = 'BLOQUEADO'
     and not exists (select 1 from public.checklist_autorizacion a where a.checklist_id = v_check.id) then
    raise exception 'El checklist tiene fallas críticas. Espera la autorización del administrador para salir.'
      using errcode = 'OR138';
  end if;

  if v_viaje.origen_lat is not null then
    v_distancia_m := public.distancia_haversine_m(
      v_viaje.origen_lat, v_viaje.origen_lng, p_lat, p_lng
    );

    if v_distancia_m > c_radio_max_m then
      raise exception
        'Debes estar a menos de % m del punto de inicio para comenzar el viaje (estas a % m).',
        c_radio_max_m, round(v_distancia_m)
        using errcode = 'OR120';
    end if;
  end if;

  insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
  values (p_viaje_id, 'SALIDA', p_fecha_hora);

  update public.viaje
     set estado = 'EN_CURSO'
   where id = p_viaje_id
   returning * into v_viaje;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_iniciar(uuid, double precision, double precision, timestamptz) from public;
grant execute on function public.viaje_iniciar(uuid, double precision, double precision, timestamptz) to authenticated;
