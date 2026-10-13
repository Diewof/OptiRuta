-- Satisfaccion del cliente: encuesta post-viaje (Google Forms + Apps Script,
-- fuera de la app) y metricas para la pestaña «Satisfaccion» del Resumen.
--
-- Flujo: el viaje pasa a FINALIZADO -> nace una fila PENDIENTE con token unico
-- y el contexto precargado (cliente, conductor, vehiculo, tiempos) -> Apps
-- Script la envia por correo y guarda el enlace -> el cliente responde el Form
-- -> Apps Script reenvia la respuesta a la Edge Function `encuestas`, que
-- llama a encuesta_registrar_respuesta (service_role).
--
-- Escala (decision del dueño, 2026-10-12): CSAT 1-5 en 4 dimensiones
-- (entrega, servicio, atencion, puntualidad percibida) + NPS 0-10 + comentario.
-- Vigencia: 14 dias, sin recordatorio en el MVP.

-- ---------------------------------------------------------------------------
-- notificacion: alerta por respuesta de baja satisfaccion
-- ---------------------------------------------------------------------------
alter table public.notificacion drop constraint if exists notificacion_tipo_check;
alter table public.notificacion
  add constraint notificacion_tipo_check check (tipo in (
    'DOCUMENTO_POR_VENCER', 'DOCUMENTO_VENCIDO', 'MANTENIMIENTO_PROXIMO',
    'MANTENIMIENTO_VENCIDO', 'CHECKLIST_FALLA', 'RETRASO', 'VIAJE_COMPLETADO',
    'PEAJE_REGISTRADO', 'NOVEDAD', 'PARADA_PROLONGADA', 'DESVIO_RUTA',
    'SATISFACCION_BAJA'
  ));

-- ---------------------------------------------------------------------------
-- Tabla
-- ---------------------------------------------------------------------------
create table public.encuesta_satisfaccion (
  id                   uuid primary key default gen_random_uuid(),
  viaje_id             uuid not null unique references public.viaje (id) on delete restrict,
  -- Snapshot del contexto para consultas de BI sin depender de joins.
  cliente_id           uuid not null references public.cliente (id) on delete restrict,
  conductor_id         uuid not null references public.conductor (id) on delete restrict,
  vehiculo_id          uuid not null references public.vehiculo (id) on delete restrict,
  token                uuid not null unique default gen_random_uuid(),
  estado               text not null default 'PENDIENTE'
                         check (estado in ('PENDIENTE', 'ENVIADA', 'RESPONDIDA', 'VENCIDA', 'SIN_CONTACTO')),
  canal                text check (canal is null or canal in ('CORREO', 'WHATSAPP', 'QR')),
  destinatario         text,
  enlace               text,
  intentos_envio       smallint not null default 0,
  fecha_creacion       timestamptz not null default now(),
  fecha_envio          timestamptz,
  fecha_respuesta      timestamptz,
  vence_en             timestamptz not null default (now() + interval '14 days'),
  csat_entrega         smallint check (csat_entrega between 1 and 5),
  csat_servicio        smallint check (csat_servicio between 1 and 5),
  csat_atencion        smallint check (csat_atencion between 1 and 5),
  csat_puntualidad     smallint check (csat_puntualidad between 1 and 5),
  nps                  smallint check (nps between 0 and 10),
  comentario           text check (comentario is null or char_length(comentario) <= 1000),
  -- Tiempos objetivos del viaje, para comparar puntualidad real vs percibida.
  tiempo_estimado_min  numeric,
  tiempo_real_min      numeric,
  minutos_retraso      numeric,
  constraint encuesta_respondida_completa check (
    estado <> 'RESPONDIDA' or (
      csat_entrega is not null and csat_servicio is not null
      and csat_atencion is not null and csat_puntualidad is not null
      and nps is not null and fecha_respuesta is not null
    )
  )
);

comment on table public.encuesta_satisfaccion is
  'Encuesta post-viaje. Una por viaje. Se crea al FINALIZAR el viaje; la respuesta llega desde el Google Form via la Edge Function encuestas. Solo se escribe por RPC.';
comment on column public.encuesta_satisfaccion.token is
  'Identificador opaco de un solo uso que viaja en el enlace del formulario.';
comment on column public.encuesta_satisfaccion.enlace is
  'Enlace prellenado del Form; lo calcula y guarda Apps Script (la app solo lo lee).';
comment on column public.encuesta_satisfaccion.minutos_retraso is
  'tiempo_real_min - tiempo_estimado_min; negativo = llego antes. Nulo sin hitos de salida/llegada.';

create index encuesta_satisfaccion_fecha_idx on public.encuesta_satisfaccion (fecha_creacion);
create index encuesta_satisfaccion_estado_idx on public.encuesta_satisfaccion (estado);
create index encuesta_satisfaccion_cliente_idx on public.encuesta_satisfaccion (cliente_id);
create index encuesta_satisfaccion_conductor_idx on public.encuesta_satisfaccion (conductor_id);
create index encuesta_satisfaccion_vehiculo_idx on public.encuesta_satisfaccion (vehiculo_id);

-- ---------------------------------------------------------------------------
-- RLS: solo el administrador lee; nadie escribe directo (solo las RPC).
-- ---------------------------------------------------------------------------
alter table public.encuesta_satisfaccion enable row level security;
revoke all on public.encuesta_satisfaccion from anon, authenticated;
grant select on public.encuesta_satisfaccion to authenticated;

create policy encuesta_satisfaccion_select_admin
  on public.encuesta_satisfaccion
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- ---------------------------------------------------------------------------
-- encuesta_crear_para_viaje: interna. Idempotente (viaje_id es unico).
-- Sin correo del cliente la encuesta nace SIN_CONTACTO: se ve en el dashboard
-- y se puede compartir por WhatsApp/QR con el mismo enlace.
-- ---------------------------------------------------------------------------
create or replace function public.encuesta_crear_para_viaje(p_viaje_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje   public.viaje;
  v_correo  text;
  v_salida  timestamptz;
  v_llegada timestamptz;
  v_real    numeric;
begin
  select * into v_viaje from public.viaje where id = p_viaje_id;
  if not found then
    return;
  end if;

  select nullif(btrim(c.correo), '') into v_correo
    from public.cliente c where c.id = v_viaje.cliente_id;

  select min(h.fecha_hora) filter (where h.tipo = 'SALIDA'),
         max(h.fecha_hora) filter (where h.tipo = 'LLEGADA_DESTINO')
    into v_salida, v_llegada
    from public.hito_viaje h where h.viaje_id = p_viaje_id;

  if v_salida is not null and v_llegada is not null and v_llegada >= v_salida then
    v_real := round(extract(epoch from (v_llegada - v_salida)) / 60, 1);
  end if;

  insert into public.encuesta_satisfaccion (
    viaje_id, cliente_id, conductor_id, vehiculo_id, estado, destinatario,
    tiempo_estimado_min, tiempo_real_min, minutos_retraso
  )
  values (
    p_viaje_id, v_viaje.cliente_id, v_viaje.conductor_id, v_viaje.vehiculo_id,
    case when v_correo is null then 'SIN_CONTACTO' else 'PENDIENTE' end,
    v_correo,
    v_viaje.tiempo_estimado_min,
    v_real,
    case when v_real is not null and v_viaje.tiempo_estimado_min is not null
         then round(v_real - v_viaje.tiempo_estimado_min, 1) end
  )
  on conflict (viaje_id) do nothing;
end;
$$;

revoke all on function public.encuesta_crear_para_viaje(uuid) from public, anon, authenticated;

-- Trigger delgado: el viaje llega a FINALIZADO por dos RPC distintas
-- (viaje_cambiar_estado y viaje_registrar_hito); un punto unico evita copiar
-- ambas. Sin ramas de negocio: solo delega en la funcion de arriba.
create or replace function public.viaje_finalizado_crear_encuesta()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.encuesta_crear_para_viaje(new.id);
  return new;
end;
$$;

revoke all on function public.viaje_finalizado_crear_encuesta() from public, anon, authenticated;

create trigger viaje_finalizado_crear_encuesta
  after update of estado on public.viaje
  for each row
  when (new.estado = 'FINALIZADO' and old.estado is distinct from 'FINALIZADO')
  execute function public.viaje_finalizado_crear_encuesta();

-- ---------------------------------------------------------------------------
-- RPC para Apps Script (service_role, via la Edge Function `encuestas`)
-- ---------------------------------------------------------------------------
create or replace function public.encuesta_pendientes_envio()
returns table (
  id            uuid,
  token         uuid,
  destinatario  text,
  cliente       text,
  origen        text,
  destino       text,
  remision      text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Solo el proceso de encuestas (service_role) puede consultar los envios pendientes.'
      using errcode = 'OR105';
  end if;

  -- Hay que enviar (PENDIENTE con correo, hasta 3 intentos) o falta guardar el
  -- enlace (SIN_CONTACTO) para que el administrador pueda compartirlo.
  return query
    select e.id, e.token, e.destinatario, cl.nombre, v.origen, v.destino, v.remision
      from public.encuesta_satisfaccion e
      join public.viaje v on v.id = e.viaje_id
      join public.cliente cl on cl.id = e.cliente_id
     where e.vence_en > now()
       and (
         (e.estado = 'PENDIENTE' and e.destinatario is not null and e.intentos_envio < 3)
         or (e.estado = 'SIN_CONTACTO' and e.enlace is null)
       )
     order by e.fecha_creacion
     limit 50;
end;
$$;

revoke all on function public.encuesta_pendientes_envio() from public, anon, authenticated;
grant execute on function public.encuesta_pendientes_envio() to service_role;

create or replace function public.encuesta_registrar_envio(
  p_id uuid,
  p_enlace text,
  p_enviada boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Solo el proceso de encuestas (service_role) puede registrar envios.'
      using errcode = 'OR105';
  end if;
  if p_enlace is null or btrim(p_enlace) = '' then
    raise exception 'El enlace de la encuesta es obligatorio.' using errcode = 'OR144';
  end if;

  update public.encuesta_satisfaccion
     set enlace = p_enlace,
         intentos_envio = case when p_enviada then intentos_envio else intentos_envio + 1 end,
         estado = case when p_enviada then 'ENVIADA' else estado end,
         canal = case when p_enviada then 'CORREO' else canal end,
         fecha_envio = case when p_enviada then now() else fecha_envio end
   where id = p_id
     and estado in ('PENDIENTE', 'SIN_CONTACTO');

  if not found then
    raise exception 'La encuesta no existe o ya no admite envio.' using errcode = 'OR141';
  end if;
end;
$$;

revoke all on function public.encuesta_registrar_envio(uuid, text, boolean) from public, anon, authenticated;
grant execute on function public.encuesta_registrar_envio(uuid, text, boolean) to service_role;

create or replace function public.encuesta_registrar_respuesta(
  p_token uuid,
  p_csat_entrega integer,
  p_csat_servicio integer,
  p_csat_atencion integer,
  p_csat_puntualidad integer,
  p_nps integer,
  p_comentario text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_enc       public.encuesta_satisfaccion;
  v_ruta      text;
  v_cliente   text;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Solo el proceso de encuestas (service_role) puede registrar respuestas.'
      using errcode = 'OR105';
  end if;

  if p_csat_entrega is null or p_csat_entrega not between 1 and 5
     or p_csat_servicio is null or p_csat_servicio not between 1 and 5
     or p_csat_atencion is null or p_csat_atencion not between 1 and 5
     or p_csat_puntualidad is null or p_csat_puntualidad not between 1 and 5
     or p_nps is null or p_nps not between 0 and 10 then
    raise exception 'Las calificaciones deben ir de 1 a 5 y la recomendacion de 0 a 10.'
      using errcode = 'OR144';
  end if;

  select * into v_enc from public.encuesta_satisfaccion where token = p_token for update;
  if not found then
    raise exception 'El codigo de la encuesta no es valido.' using errcode = 'OR141';
  end if;
  if v_enc.estado = 'RESPONDIDA' then
    raise exception 'Esta encuesta ya fue respondida.' using errcode = 'OR142';
  end if;
  if v_enc.estado = 'VENCIDA' or v_enc.vence_en <= now() then
    raise exception 'Esta encuesta ya vencio.' using errcode = 'OR143';
  end if;

  update public.encuesta_satisfaccion
     set estado = 'RESPONDIDA',
         fecha_respuesta = now(),
         csat_entrega = p_csat_entrega,
         csat_servicio = p_csat_servicio,
         csat_atencion = p_csat_atencion,
         csat_puntualidad = p_csat_puntualidad,
         nps = p_nps,
         comentario = nullif(left(btrim(coalesce(p_comentario, '')), 1000), '')
   where id = v_enc.id;

  -- Alerta al administrador si alguna dimension es <= 2 o el cliente es
  -- detractor (NPS <= 6). Deduplicada por clave: una por encuesta.
  if least(p_csat_entrega, p_csat_servicio, p_csat_atencion, p_csat_puntualidad) <= 2
     or p_nps <= 6 then
    select v.origen || ' → ' || v.destino, cl.nombre into v_ruta, v_cliente
      from public.viaje v join public.cliente cl on cl.id = v.cliente_id
     where v.id = v_enc.viaje_id;

    insert into public.notificacion (tipo, titulo, mensaje, viaje_id, clave)
    select 'SATISFACCION_BAJA',
           'Satisfacción baja de un cliente',
           format('%s calificó %s con una puntuación baja (recomendación %s/10).', v_cliente, v_ruta, p_nps),
           v_enc.viaje_id,
           'ENC:' || v_enc.id::text
     where not exists (
       select 1 from public.notificacion n where n.clave = 'ENC:' || v_enc.id::text
     );
  end if;
end;
$$;

revoke all on function public.encuesta_registrar_respuesta(uuid, integer, integer, integer, integer, integer, text) from public, anon, authenticated;
grant execute on function public.encuesta_registrar_respuesta(uuid, integer, integer, integer, integer, integer, text) to service_role;

-- ---------------------------------------------------------------------------
-- Vencimiento diario: sin respuesta pasados 14 dias -> VENCIDA.
-- ---------------------------------------------------------------------------
create or replace function public.encuesta_vencer()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  update public.encuesta_satisfaccion
     set estado = 'VENCIDA'
   where estado in ('PENDIENTE', 'ENVIADA', 'SIN_CONTACTO')
     and vence_en <= now();
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.encuesta_vencer() from public, anon, authenticated;

select cron.schedule(
  'encuesta-vencer-diario',
  '0 7 * * *',
  $$select public.encuesta_vencer();$$
);

-- ---------------------------------------------------------------------------
-- Consultas del dashboard (solo administrador)
-- ---------------------------------------------------------------------------

-- Filas del periodo con los filtros de la pantalla. Interna: cada RPC publica
-- valida el rol antes de llamarla.
create or replace function public.satisfaccion_base(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid,
  p_conductor_id uuid,
  p_vehiculo_id uuid,
  p_ruta text
)
returns setof public.encuesta_satisfaccion
language sql
stable
security definer
set search_path = ''
as $$
  select e.*
    from public.encuesta_satisfaccion e
    join public.viaje v on v.id = e.viaje_id
   where (e.fecha_creacion at time zone 'America/Bogota')::date between p_desde and p_hasta
     and (p_cliente_id is null or e.cliente_id = p_cliente_id)
     and (p_conductor_id is null or e.conductor_id = p_conductor_id)
     and (p_vehiculo_id is null or e.vehiculo_id = p_vehiculo_id)
     and (p_ruta is null or btrim(p_ruta) = ''
          or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0);
$$;

revoke all on function public.satisfaccion_base(date, date, uuid, uuid, uuid, text) from public, anon, authenticated;

create or replace function public.satisfaccion_resumen(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  encuestas_total         integer,
  respondidas             integer,
  pendientes              integer,
  sin_contacto            integer,
  vencidas                integer,
  csat_entrega            numeric,
  csat_servicio           numeric,
  csat_atencion           numeric,
  csat_puntualidad        numeric,
  csat_global             numeric,
  nps                     numeric,
  promotores              integer,
  pasivos                 integer,
  detractores             integer,
  viajes_medidos          integer,
  viajes_a_tiempo         integer,
  puntualidad_percibida   integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la satisfaccion.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;

  return query
    with b as (
      select * from public.satisfaccion_base(p_desde, p_hasta, p_cliente_id, p_conductor_id, p_vehiculo_id, p_ruta)
    ),
    r as (select * from b where b.estado = 'RESPONDIDA'),
    m as (
      -- Mismo criterio de «a tiempo» que metricas_periodo_v2: tiempo estimado
      -- mas el mayor entre 20 % y 30 minutos de margen.
      select * from r
       where r.tiempo_real_min is not null and r.tiempo_estimado_min is not null
    )
    select
      (select count(*)::int from b),
      (select count(*)::int from r),
      (select count(*)::int from b where b.estado in ('PENDIENTE', 'ENVIADA')),
      (select count(*)::int from b where b.estado = 'SIN_CONTACTO'),
      (select count(*)::int from b where b.estado = 'VENCIDA'),
      (select round(avg(r.csat_entrega), 2) from r),
      (select round(avg(r.csat_servicio), 2) from r),
      (select round(avg(r.csat_atencion), 2) from r),
      (select round(avg(r.csat_puntualidad), 2) from r),
      (select round(avg((r.csat_entrega + r.csat_servicio + r.csat_atencion + r.csat_puntualidad) / 4.0), 2) from r),
      (select round((count(*) filter (where r.nps >= 9) - count(*) filter (where r.nps <= 6))::numeric
                    / nullif(count(*), 0) * 100, 0) from r),
      (select (count(*) filter (where r.nps >= 9))::int from r),
      (select (count(*) filter (where r.nps between 7 and 8))::int from r),
      (select (count(*) filter (where r.nps <= 6))::int from r),
      (select count(*)::int from m),
      (select (count(*) filter (
         where m.tiempo_real_min <= m.tiempo_estimado_min + greatest(m.tiempo_estimado_min * 0.2, 30)
       ))::int from m),
      (select (count(*) filter (where r.csat_puntualidad >= 4))::int from r);
end;
$$;

revoke all on function public.satisfaccion_resumen(date, date, uuid, uuid, uuid, text) from public;
grant execute on function public.satisfaccion_resumen(date, date, uuid, uuid, uuid, text) to authenticated;

create or replace function public.satisfaccion_por_dimension(
  p_desde date,
  p_hasta date,
  p_dimension text,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  clave        text,
  respondidas  integer,
  csat_global  numeric,
  nps          numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la satisfaccion.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;
  if p_dimension not in ('RUTA', 'CLIENTE', 'CONDUCTOR') then
    raise exception 'Dimension de metricas no valida.' using errcode = 'OR121';
  end if;

  return query
    select
      case p_dimension
        when 'RUTA' then v.origen || ' → ' || v.destino
        when 'CLIENTE' then cl.nombre
        else u.nombre
      end as clave,
      count(*)::int,
      round(avg((e.csat_entrega + e.csat_servicio + e.csat_atencion + e.csat_puntualidad) / 4.0), 2),
      round((count(*) filter (where e.nps >= 9) - count(*) filter (where e.nps <= 6))::numeric
            / count(*) * 100, 0)
      from public.satisfaccion_base(p_desde, p_hasta, p_cliente_id, p_conductor_id, p_vehiculo_id, p_ruta) e
      join public.viaje v on v.id = e.viaje_id
      join public.cliente cl on cl.id = e.cliente_id
      join public.conductor co on co.id = e.conductor_id
      join public.usuario u on u.id = co.usuario_id
     where e.estado = 'RESPONDIDA'
     group by 1
     order by avg((e.csat_entrega + e.csat_servicio + e.csat_atencion + e.csat_puntualidad) / 4.0) asc, 1;
end;
$$;

revoke all on function public.satisfaccion_por_dimension(date, date, text, uuid, uuid, uuid, text) from public;
grant execute on function public.satisfaccion_por_dimension(date, date, text, uuid, uuid, uuid, text) to authenticated;

create or replace function public.satisfaccion_comentarios(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null,
  p_limite integer default 20
)
returns table (
  fecha_respuesta  timestamptz,
  cliente          text,
  conductor        text,
  ruta             text,
  csat_global      numeric,
  nps              smallint,
  comentario       text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la satisfaccion.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;

  return query
    select e.fecha_respuesta, cl.nombre, u.nombre, v.origen || ' → ' || v.destino,
           round((e.csat_entrega + e.csat_servicio + e.csat_atencion + e.csat_puntualidad) / 4.0, 2),
           e.nps, e.comentario
      from public.satisfaccion_base(p_desde, p_hasta, p_cliente_id, p_conductor_id, p_vehiculo_id, p_ruta) e
      join public.viaje v on v.id = e.viaje_id
      join public.cliente cl on cl.id = e.cliente_id
      join public.conductor co on co.id = e.conductor_id
      join public.usuario u on u.id = co.usuario_id
     where e.estado = 'RESPONDIDA' and e.comentario is not null
     order by e.fecha_respuesta desc
     limit greatest(1, least(coalesce(p_limite, 20), 100));
end;
$$;

revoke all on function public.satisfaccion_comentarios(date, date, uuid, uuid, uuid, text, integer) from public;
grant execute on function public.satisfaccion_comentarios(date, date, uuid, uuid, uuid, text, integer) to authenticated;
