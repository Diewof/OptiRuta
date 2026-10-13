-- Fase 4: mantenimiento preventivo por km/tiempo y hoja de vida del vehiculo.
--
-- Cada vehiculo tiene un plan (un renglon por tipo de mantenimiento) con
-- intervalo en km y/o dias. Lo que falta para el proximo mantenimiento se
-- calcula contra el ultimo mantenimiento registrado de ese tipo y el odometro
-- derivado del GPS (ver 20261011110000_viaje_km_odometro.sql). Los intervalos
-- del catalogo son valores sugeridos: el administrador los ajusta por vehiculo.
-- Solo alerta; no bloquea viajes.

-- ---------------------------------------------------------------------------
-- tipo_mantenimiento: catalogo de intervalos por defecto
-- ---------------------------------------------------------------------------
create table public.tipo_mantenimiento (
  id                     uuid primary key default gen_random_uuid(),
  codigo                 text not null unique,
  nombre                 text not null,
  intervalo_km           numeric check (intervalo_km is null or intervalo_km > 0),
  intervalo_dias         integer check (intervalo_dias is null or intervalo_dias > 0),
  antelacion_km          numeric check (antelacion_km is null or antelacion_km >= 0),
  antelacion_dias        integer check (antelacion_dias is null or antelacion_dias >= 0),
  orden                  integer not null,
  activo                 boolean not null default true,
  check (intervalo_km is not null or intervalo_dias is not null)
);

comment on table public.tipo_mantenimiento is
  'Catalogo de mantenimientos preventivos con intervalos sugeridos; cada vehiculo copia estos valores a su plan.';

alter table public.tipo_mantenimiento enable row level security;
revoke all on public.tipo_mantenimiento from anon, authenticated;
grant select on public.tipo_mantenimiento to authenticated;

create policy tipo_mantenimiento_select_admin
  on public.tipo_mantenimiento for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

insert into public.tipo_mantenimiento
  (codigo, nombre, intervalo_km, intervalo_dias, antelacion_km, antelacion_dias, orden) values
  ('ACEITE_MOTOR',         'Cambio de aceite y filtros de motor', 20000, 180, 1500, 15, 10),
  ('FILTROS_AIRE_COMB',    'Filtros de aire y combustible',       40000, null, 2000, null, 20),
  ('ACEITE_CAJA_DIF',      'Aceite de caja y diferencial',        60000, null, 3000, null, 30),
  ('ENGRASE',              'Engrase de chasis y quinta rueda',    10000, null, 1000, null, 40),
  ('REVISION_FRENOS',      'Revisión y ajuste de frenos',         40000, null, 2000, null, 50),
  ('ALINEACION_BALANCEO',  'Alineación y balanceo',               20000, null, 1500, null, 60),
  ('REVISION_LLANTAS',     'Revisión y rotación de llantas',      10000, null, 1000, null, 70),
  ('REFRIGERANTE_CORREAS', 'Refrigerante y correas',              null, 365, null, 30, 80),
  ('BATERIA',              'Revisión de batería',                 null, 365, null, 30, 90);

-- ---------------------------------------------------------------------------
-- plan_mantenimiento: un renglon por vehiculo y tipo
-- ---------------------------------------------------------------------------
create table public.plan_mantenimiento (
  id                     uuid primary key default gen_random_uuid(),
  vehiculo_id            uuid not null references public.vehiculo (id) on delete restrict,
  tipo_mantenimiento_id  uuid not null references public.tipo_mantenimiento (id) on delete restrict,
  intervalo_km           numeric check (intervalo_km is null or intervalo_km > 0),
  intervalo_dias         integer check (intervalo_dias is null or intervalo_dias > 0),
  antelacion_km          numeric check (antelacion_km is null or antelacion_km >= 0),
  antelacion_dias        integer check (antelacion_dias is null or antelacion_dias >= 0),
  activo                 boolean not null default true,
  creado_por             uuid,
  fecha_creacion         timestamptz not null default now(),
  modificado_por         uuid,
  fecha_modificacion     timestamptz,
  unique (vehiculo_id, tipo_mantenimiento_id),
  check (intervalo_km is not null or intervalo_dias is not null)
);

create trigger plan_mantenimiento_set_audit
  before insert or update on public.plan_mantenimiento
  for each row execute function public.usuario_set_audit();

alter table public.plan_mantenimiento enable row level security;
revoke all on public.plan_mantenimiento from anon, authenticated;
grant select, insert on public.plan_mantenimiento to authenticated;
grant update (intervalo_km, intervalo_dias, antelacion_km, antelacion_dias, activo)
  on public.plan_mantenimiento to authenticated;

create policy plan_mantenimiento_select_admin
  on public.plan_mantenimiento for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy plan_mantenimiento_insert_admin
  on public.plan_mantenimiento for insert to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy plan_mantenimiento_update_admin
  on public.plan_mantenimiento for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- Un vehiculo nuevo nace con el plan del catalogo. Es una copia sin ramas, por
-- eso vive en un trigger y no depende de que la app se acuerde de llamarla.
create or replace function public.vehiculo_crear_plan_mantenimiento()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.plan_mantenimiento
    (vehiculo_id, tipo_mantenimiento_id, intervalo_km, intervalo_dias, antelacion_km, antelacion_dias)
  select new.id, t.id, t.intervalo_km, t.intervalo_dias, t.antelacion_km, t.antelacion_dias
    from public.tipo_mantenimiento t
   where t.activo;
  return new;
end;
$$;

create trigger vehiculo_crear_plan_mantenimiento
  after insert on public.vehiculo
  for each row execute function public.vehiculo_crear_plan_mantenimiento();

-- Vehiculos que ya existian.
insert into public.plan_mantenimiento
  (vehiculo_id, tipo_mantenimiento_id, intervalo_km, intervalo_dias, antelacion_km, antelacion_dias)
select v.id, t.id, t.intervalo_km, t.intervalo_dias, t.antelacion_km, t.antelacion_dias
  from public.vehiculo v
  cross join public.tipo_mantenimiento t
 where t.activo
on conflict (vehiculo_id, tipo_mantenimiento_id) do nothing;

-- ---------------------------------------------------------------------------
-- mantenimiento_vehiculo: clasificacion y datos del taller
-- ---------------------------------------------------------------------------
alter table public.mantenimiento_vehiculo
  add column tipo_mantenimiento_id uuid references public.tipo_mantenimiento (id) on delete restrict,
  add column categoria text check (categoria is null or categoria in ('PREVENTIVO', 'CORRECTIVO')),
  add column taller text check (taller is null or char_length(btrim(taller)) between 1 and 80),
  add column descripcion text check (descripcion is null or char_length(btrim(descripcion)) between 1 and 300);

create index mantenimiento_vehiculo_tipo_idx
  on public.mantenimiento_vehiculo (vehiculo_id, tipo_mantenimiento_id, fecha desc);

comment on column public.mantenimiento_vehiculo.tipo_mantenimiento_id is
  'Tipo del catalogo; reinicia el contador del plan. Nulo en filas antiguas o mantenimientos correctivos libres.';

-- ---------------------------------------------------------------------------
-- mantenimiento_registrar: unico camino de la app para registrar. Si es de
-- hoy y no trae kilometraje, usa el odometro actual del vehiculo; uno de fecha
-- pasada sin km queda sin km (no se puede saber) y solo cuenta por dias.
-- ---------------------------------------------------------------------------
create or replace function public.mantenimiento_registrar(
  p_vehiculo_id uuid,
  p_tipo text,
  p_costo numeric,
  p_fecha date,
  p_kilometraje numeric default null,
  p_tipo_mantenimiento_id uuid default null,
  p_categoria text default 'PREVENTIVO',
  p_taller text default null,
  p_descripcion text default null
)
returns public.mantenimiento_vehiculo
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tipo    text := btrim(coalesce(p_tipo, ''));
  v_catalogo text;
  v_km      numeric := p_kilometraje;
  v_fila public.mantenimiento_vehiculo;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede registrar mantenimientos.' using errcode = 'OR105';
  end if;

  if not exists (select 1 from public.vehiculo where id = p_vehiculo_id) then
    raise exception 'El vehículo no existe.' using errcode = 'OR111';
  end if;

  if p_categoria not in ('PREVENTIVO', 'CORRECTIVO') then
    raise exception 'La categoría del mantenimiento no es válida.' using errcode = 'OR139';
  end if;

  if p_costo is null or p_costo <= 0 or (v_km is not null and v_km < 0) then
    raise exception 'El costo debe ser mayor a 0 y el kilometraje no puede ser negativo.' using errcode = 'OR139';
  end if;

  if p_fecha is null or p_fecha > public.hoy_bogota() then
    raise exception 'La fecha del mantenimiento no puede ser futura.' using errcode = 'OR139';
  end if;

  if p_tipo_mantenimiento_id is not null then
    select t.nombre into v_catalogo
      from public.tipo_mantenimiento t
     where t.id = p_tipo_mantenimiento_id;
    if not found then
      raise exception 'El tipo de mantenimiento no existe.' using errcode = 'OR139';
    end if;
    if v_tipo = '' then
      v_tipo := v_catalogo;
    end if;
  end if;

  if v_tipo = '' then
    raise exception 'El tipo de mantenimiento es obligatorio.' using errcode = 'OR139';
  end if;

  if v_km is null and p_fecha = public.hoy_bogota() then
    v_km := round(public.vehiculo_odometro_km(p_vehiculo_id));
  end if;

  insert into public.mantenimiento_vehiculo
    (vehiculo_id, tipo, costo, fecha, kilometraje, tipo_mantenimiento_id, categoria, taller, descripcion)
  values
    (p_vehiculo_id, v_tipo, p_costo, p_fecha, v_km, p_tipo_mantenimiento_id, p_categoria,
     nullif(btrim(coalesce(p_taller, '')), ''), nullif(btrim(coalesce(p_descripcion, '')), ''))
  returning * into v_fila;

  return v_fila;
end;
$$;

revoke all on function public.mantenimiento_registrar(uuid, text, numeric, date, numeric, uuid, text, text, text) from public;
grant execute on function public.mantenimiento_registrar(uuid, text, numeric, date, numeric, uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Estado del plan: que falta para el proximo mantenimiento de cada tipo.
--
-- Referencia = ultimo mantenimiento de ese tipo; si nunca se hizo, el alta del
-- vehiculo en el sistema (por eso conviene registrar el ultimo mantenimiento
-- conocido al dar de alta un vehiculo usado).
--   VENCIDO  : km o dias restantes <= 0
--   PROXIMO  : km o dias restantes <= la antelacion del plan
--   AL_DIA   : lo demas
-- ---------------------------------------------------------------------------
create type public.plan_mantenimiento_item as (
  plan_id                uuid,
  vehiculo_id            uuid,
  placa                  text,
  tipo_mantenimiento_id  uuid,
  tipo_nombre            text,
  intervalo_km           numeric,
  intervalo_dias         integer,
  ultimo_fecha           date,
  ultimo_km              numeric,
  odometro_km            numeric,
  km_restantes           numeric,
  dias_restantes         integer,
  estado                 text
);

-- Uso interno: lo consumen la RPC de abajo y notificacion_generar (cron, sin JWT).
create or replace function public.plan_mantenimiento_calculo()
returns setof public.plan_mantenimiento_item
language sql
stable
security definer
set search_path = ''
as $$
  with base as (
    select p.id as plan_id, p.vehiculo_id, v.placa, p.tipo_mantenimiento_id,
           t.nombre as tipo_nombre, p.intervalo_km, p.intervalo_dias,
           p.antelacion_km, p.antelacion_dias,
           u.fecha as ultimo_fecha, u.kilometraje as ultimo_km,
           o.km as odometro_km,
           coalesce(u.fecha, (v.fecha_creacion at time zone 'America/Bogota')::date) as base_fecha,
           case when u.fecha is not null then u.kilometraje else v.odometro_inicial_km end as base_km
      from public.plan_mantenimiento p
      join public.vehiculo v on v.id = p.vehiculo_id and v.activo
      join public.tipo_mantenimiento t on t.id = p.tipo_mantenimiento_id
      left join lateral (
        select m.fecha, m.kilometraje
          from public.mantenimiento_vehiculo m
         where m.vehiculo_id = p.vehiculo_id
           and m.tipo_mantenimiento_id = p.tipo_mantenimiento_id
         order by m.fecha desc, m.fecha_creacion desc
         limit 1
      ) u on true
      cross join lateral (select public.vehiculo_odometro_km(v.id) as km) o
     where p.activo
  ),
  calc as (
    select b.*,
           case when b.intervalo_km is not null and b.base_km is not null
                then b.intervalo_km - greatest(b.odometro_km - b.base_km, 0) end as km_restantes,
           case when b.intervalo_dias is not null
                then b.intervalo_dias - (public.hoy_bogota() - b.base_fecha) end as dias_restantes
      from base b
  )
  select c.plan_id, c.vehiculo_id, c.placa, c.tipo_mantenimiento_id, c.tipo_nombre,
         c.intervalo_km, c.intervalo_dias, c.ultimo_fecha, c.ultimo_km,
         round(c.odometro_km), round(c.km_restantes), c.dias_restantes,
         case
           when coalesce(c.km_restantes <= 0, false) or coalesce(c.dias_restantes <= 0, false)
             then 'VENCIDO'
           when coalesce(c.km_restantes <= c.antelacion_km, false)
                or coalesce(c.dias_restantes <= c.antelacion_dias, false)
             then 'PROXIMO'
           else 'AL_DIA'
         end
    from calc c;
$$;

revoke all on function public.plan_mantenimiento_calculo() from public, anon, authenticated;

create or replace function public.plan_mantenimiento_estado(p_vehiculo_id uuid default null)
returns setof public.plan_mantenimiento_item
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar el plan de mantenimiento.' using errcode = 'OR105';
  end if;

  return query
    select c.*
      from public.plan_mantenimiento_calculo() c
     where p_vehiculo_id is null or c.vehiculo_id = p_vehiculo_id
     order by case c.estado when 'VENCIDO' then 0 when 'PROXIMO' then 1 else 2 end,
              c.tipo_nombre;
end;
$$;

revoke all on function public.plan_mantenimiento_estado(uuid) from public;
grant execute on function public.plan_mantenimiento_estado(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- vehiculo_hoja_vida: linea de tiempo del vehiculo (viajes con km,
-- mantenimientos, checklists y documentos), mas reciente primero. Se arma al
-- vuelo de las tablas de origen: no hay una copia que mantener.
-- ---------------------------------------------------------------------------
create or replace function public.vehiculo_hoja_vida(p_vehiculo_id uuid, p_limite integer default 100)
returns table (
  fecha    timestamptz,
  tipo     text,
  titulo   text,
  detalle  text,
  km       numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la hoja de vida.' using errcode = 'OR105';
  end if;

  return query
    select x.fecha, x.tipo, x.titulo, x.detalle, x.km
      from (
        select coalesce(
                 (select max(h.fecha_hora) from public.hito_viaje h
                   where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO'),
                 v.fecha_creacion) as fecha,
               'VIAJE'::text as tipo,
               format('Viaje %s: %s → %s', v.remision, v.origen, v.destino) as titulo,
               case when v.km_recorridos is null then null
                    else format('%s km (%s)', round(v.km_recorridos),
                                case v.km_origen when 'GPS' then 'medido por GPS' else 'estimado' end)
               end as detalle,
               v.km_recorridos as km
          from public.viaje v
         where v.vehiculo_id = p_vehiculo_id and v.estado in ('FINALIZADO', 'CERRADO')
        union all
        select (m.fecha::timestamp at time zone 'America/Bogota'),
               'MANTENIMIENTO',
               m.tipo,
               nullif(concat_ws(' · ', initcap(lower(m.categoria)), m.taller, m.descripcion), ''),
               m.kilometraje
          from public.mantenimiento_vehiculo m
         where m.vehiculo_id = p_vehiculo_id
        union all
        select k.fecha_hora,
               'CHECKLIST',
               'Checklist pre-viaje: ' || case k.resultado
                 when 'APROBADO' then 'aprobado'
                 when 'CON_OBSERVACIONES' then 'con observaciones'
                 else 'bloqueado' end,
               coalesce((
                 select string_agg(i.nombre, ', ' order by i.orden)
                   from public.checklist_respuesta r
                   join public.checklist_item i on i.id = r.item_id
                  where r.checklist_id = k.id and r.estado = 'FALLA'
               ), 'Sin fallas'),
               null
          from public.checklist_viaje k
         where k.vehiculo_id = p_vehiculo_id
        union all
        select d.fecha_creacion,
               'DOCUMENTO',
               case d.tipo when 'SOAT' then 'SOAT registrado' else 'Revisión técnico-mecánica registrada' end,
               'Vence el ' || to_char(d.fecha_vencimiento, 'DD/MM/YYYY'),
               null
          from public.documento_vehiculo d
         where d.vehiculo_id = p_vehiculo_id
      ) x
     order by x.fecha desc
     limit greatest(1, least(coalesce(p_limite, 100), 500));
end;
$$;

revoke all on function public.vehiculo_hoja_vida(uuid, integer) from public;
grant execute on function public.vehiculo_hoja_vida(uuid, integer) to authenticated;
