-- Catalogos del dominio: vehiculo, sus documentos y mantenimientos, conductor,
-- cliente y tarifa_combustible.
--
-- Contexto (CLAUDE.md / arquitectura-y-estandares.md seccion 8 /
-- diseno-base-de-datos-optiruta.md): primera migracion del dominio de negocio
-- (hasta ahora solo existia auth/perfil). No se borran vehiculos ni
-- conductores: baja logica con `activo = false`.

-- ---------------------------------------------------------------------------
-- vehiculo
-- ---------------------------------------------------------------------------
create table public.vehiculo (
  id                    uuid primary key default gen_random_uuid(),
  placa                 text not null unique,
  tipo                  text not null check (tipo in ('DOBLE_TROQUE', 'MULA')),
  capacidad_carga       numeric not null check (capacidad_carga > 0),
  rendimiento_km_galon  numeric not null check (rendimiento_km_galon > 0),
  activo                boolean not null default true,
  creado_por            uuid,
  fecha_creacion        timestamptz not null default now(),
  modificado_por        uuid,
  fecha_modificacion    timestamptz
);

comment on table public.vehiculo is
  'Flota de la empresa. Baja logica con activo = false, nunca se borra (FK de viaje con ON DELETE RESTRICT).';
comment on column public.vehiculo.capacidad_carga is 'Toneladas.';

create trigger vehiculo_set_audit
  before insert or update on public.vehiculo
  for each row execute function public.usuario_set_audit();

alter table public.vehiculo enable row level security;
revoke all on public.vehiculo from anon, authenticated;
grant select on public.vehiculo to authenticated;
grant insert, update (placa, tipo, capacidad_carga, rendimiento_km_galon, activo) on public.vehiculo to authenticated;

-- Lectura: cualquier usuario autenticado (admin y conductor necesitan ver el
-- vehiculo asignado a un viaje). No hay dato financiero en esta tabla.
create policy vehiculo_select_autenticado
  on public.vehiculo
  for select
  to authenticated
  using (true);

create policy vehiculo_insert_admin
  on public.vehiculo
  for insert
  to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy vehiculo_update_admin
  on public.vehiculo
  for update
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- ---------------------------------------------------------------------------
-- documento_vehiculo (SOAT, tecnomecanica; RF-26 alertas de vencimiento)
-- ---------------------------------------------------------------------------
create table public.documento_vehiculo (
  id                  uuid primary key default gen_random_uuid(),
  vehiculo_id         uuid not null references public.vehiculo (id) on delete restrict,
  tipo                text not null check (tipo in ('SOAT', 'TECNOMECANICA')),
  fecha_vencimiento   date not null,
  creado_por          uuid,
  fecha_creacion      timestamptz not null default now(),
  modificado_por      uuid,
  fecha_modificacion  timestamptz
);

create index documento_vehiculo_fecha_vencimiento_idx
  on public.documento_vehiculo (fecha_vencimiento);

create trigger documento_vehiculo_set_audit
  before insert or update on public.documento_vehiculo
  for each row execute function public.usuario_set_audit();

alter table public.documento_vehiculo enable row level security;
revoke all on public.documento_vehiculo from anon, authenticated;
grant select, insert, update, delete on public.documento_vehiculo to authenticated;

create policy documento_vehiculo_select_autenticado
  on public.documento_vehiculo
  for select
  to authenticated
  using (true);

create policy documento_vehiculo_admin
  on public.documento_vehiculo
  for all
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- ---------------------------------------------------------------------------
-- mantenimiento_vehiculo (costo real de mantenimiento; alimenta el
-- MANTENIMIENTO_AMORTIZADO prorrateado en rentabilidad_consolidada, no en la
-- marginal por viaje).
-- ---------------------------------------------------------------------------
create table public.mantenimiento_vehiculo (
  id                  uuid primary key default gen_random_uuid(),
  vehiculo_id         uuid not null references public.vehiculo (id) on delete restrict,
  tipo                text not null,
  costo               numeric not null check (costo >= 0),
  fecha               date not null,
  kilometraje         numeric,
  creado_por          uuid,
  fecha_creacion      timestamptz not null default now(),
  modificado_por      uuid,
  fecha_modificacion  timestamptz
);

create index mantenimiento_vehiculo_vehiculo_id_idx
  on public.mantenimiento_vehiculo (vehiculo_id);

create trigger mantenimiento_vehiculo_set_audit
  before insert or update on public.mantenimiento_vehiculo
  for each row execute function public.usuario_set_audit();

alter table public.mantenimiento_vehiculo enable row level security;
revoke all on public.mantenimiento_vehiculo from anon, authenticated;
grant select, insert, update, delete on public.mantenimiento_vehiculo to authenticated;

create policy mantenimiento_vehiculo_admin
  on public.mantenimiento_vehiculo
  for all
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- Sin politica para conductor: es informacion financiera de flota, fuera de
-- su acceso segun CLAUDE.md.

-- ---------------------------------------------------------------------------
-- conductor
-- ---------------------------------------------------------------------------
create table public.conductor (
  id                          uuid primary key default gen_random_uuid(),
  usuario_id                  uuid not null unique references public.usuario (id) on delete restrict,
  licencia                    text not null,
  fecha_vencimiento_licencia  date not null,
  tipo_pago                   text not null check (tipo_pago in ('FIJO', 'COMISION', 'MIXTO')),
  porcentaje_comision         numeric not null default 10 check (porcentaje_comision >= 0 and porcentaje_comision <= 100),
  sueldo_base                 numeric not null default 0 check (sueldo_base >= 0),
  activo                      boolean not null default true,
  creado_por                  uuid,
  fecha_creacion              timestamptz not null default now(),
  modificado_por              uuid,
  fecha_modificacion          timestamptz
);

comment on column public.conductor.porcentaje_comision is
  'Confirmado por los 87 viajes reales de la bitacora: 10% del flete siempre. Editable por si cambia a futuro.';

create trigger conductor_set_audit
  before insert or update on public.conductor
  for each row execute function public.usuario_set_audit();

alter table public.conductor enable row level security;
revoke all on public.conductor from anon, authenticated;
grant select on public.conductor to authenticated;
grant insert, update (licencia, fecha_vencimiento_licencia, tipo_pago, porcentaje_comision, sueldo_base, activo) on public.conductor to authenticated;

-- El conductor ve su propia fila; el administrador las ve todas.
create policy conductor_select_propio
  on public.conductor
  for select
  to authenticated
  using (usuario_id = (select auth.uid()));

create policy conductor_select_admin
  on public.conductor
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy conductor_insert_admin
  on public.conductor
  for insert
  to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy conductor_update_admin
  on public.conductor
  for update
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- ---------------------------------------------------------------------------
-- cliente
-- ---------------------------------------------------------------------------
create table public.cliente (
  id                  uuid primary key default gen_random_uuid(),
  nombre              text not null,
  telefono            text,
  correo              text,
  activo              boolean not null default true,
  creado_por          uuid,
  fecha_creacion      timestamptz not null default now(),
  modificado_por      uuid,
  fecha_modificacion  timestamptz
);

create trigger cliente_set_audit
  before insert or update on public.cliente
  for each row execute function public.usuario_set_audit();

alter table public.cliente enable row level security;
revoke all on public.cliente from anon, authenticated;
grant select on public.cliente to authenticated;
grant insert, update (nombre, telefono, correo, activo) on public.cliente to authenticated;

create policy cliente_select_autenticado
  on public.cliente
  for select
  to authenticated
  using (true);

create policy cliente_insert_admin
  on public.cliente
  for insert
  to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy cliente_update_admin
  on public.cliente
  for update
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- ---------------------------------------------------------------------------
-- tarifa_combustible (precio ACPM por ciudad y fecha de vigencia; RF-11/12)
-- ---------------------------------------------------------------------------
create table public.tarifa_combustible (
  id                    uuid primary key default gen_random_uuid(),
  ciudad                text not null,
  precio_galon          numeric not null check (precio_galon > 0),
  fecha_vigencia_desde  date not null,
  fuente                text not null default 'MANUAL' check (fuente in ('MANUAL', 'AUTOMATICO')),
  creado_por            uuid,
  fecha_creacion        timestamptz not null default now(),
  modificado_por        uuid,
  fecha_modificacion    timestamptz,
  unique (ciudad, fecha_vigencia_desde)
);

create index tarifa_combustible_ciudad_fecha_idx
  on public.tarifa_combustible (ciudad, fecha_vigencia_desde desc);

create trigger tarifa_combustible_set_audit
  before insert or update on public.tarifa_combustible
  for each row execute function public.usuario_set_audit();

alter table public.tarifa_combustible enable row level security;
revoke all on public.tarifa_combustible from anon, authenticated;
grant select on public.tarifa_combustible to authenticated;
grant insert, update (precio_galon, fecha_vigencia_desde, fuente) on public.tarifa_combustible to authenticated;

-- Lectura amplia: el estimado de ACPM se calcula tambien del lado del
-- conductor al ver el detalle de su viaje.
create policy tarifa_combustible_select_autenticado
  on public.tarifa_combustible
  for select
  to authenticated
  using (true);

create policy tarifa_combustible_admin_insert
  on public.tarifa_combustible
  for insert
  to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy tarifa_combustible_admin_update
  on public.tarifa_combustible
  for update
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- El scraper de la Edge Function precio-acpm-scraper escribe con
-- service_role (bypass de RLS) via la RPC tarifa_combustible_registrar_automatico.
