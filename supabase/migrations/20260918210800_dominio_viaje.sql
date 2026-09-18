-- Dominio de viajes: viaje, hito_viaje, costo_viaje, peaje_capturado,
-- ajuste_viaje. Ciclo de vida, append-only tras el cierre y RLS.
--
-- Contexto: CLAUDE.md seccion "Dominio: viajes",
-- arquitectura-y-estandares.md seccion 8, diseno-base-de-datos-optiruta.md.

-- ---------------------------------------------------------------------------
-- viaje
-- ---------------------------------------------------------------------------
create table public.viaje (
  id                    uuid primary key default gen_random_uuid(),
  remision              text not null unique,
  vehiculo_id           uuid not null references public.vehiculo (id) on delete restrict,
  conductor_id          uuid not null references public.conductor (id) on delete restrict,
  cliente_id            uuid not null references public.cliente (id) on delete restrict,
  origen                text not null,
  destino               text not null,
  distancia_estimada    numeric,
  tiempo_estimado_min   numeric,
  peso_carga            numeric,
  estado                text not null default 'PLANIFICADO'
                          check (estado in ('PLANIFICADO', 'ASIGNADO', 'EN_CURSO', 'FINALIZADO', 'CERRADO')),
  valor_flete           numeric not null default 0 check (valor_flete >= 0),
  valor_anticipo        numeric not null default 0 check (valor_anticipo >= 0),
  saldo_pendiente       numeric generated always as (valor_flete - valor_anticipo) stored,
  fecha_cierre          timestamptz,
  creado_por            uuid,
  fecha_creacion        timestamptz not null default now(),
  modificado_por        uuid,
  fecha_modificacion    timestamptz
);

comment on column public.viaje.valor_flete is
  'Monto pactado con el cliente, capturado por el administrador al crear el viaje. Valor unico, no par estimado/real.';
comment on column public.viaje.valor_anticipo is
  'Adelanto ya pagado por el cliente. Informativo (cartera), no participa en rentabilidad_marginal.';

create index viaje_estado_idx on public.viaje (estado);
create index viaje_vehiculo_estado_idx on public.viaje (vehiculo_id, estado);
create index viaje_conductor_id_idx on public.viaje (conductor_id);

create trigger viaje_set_audit
  before insert or update on public.viaje
  for each row execute function public.usuario_set_audit();

-- ---------------------------------------------------------------------------
-- Trigger: valida transiciones de estado y bloquea cualquier UPDATE sobre un
-- viaje ya CERRADO (todo cambio posterior va por ajuste_viaje). La logica con
-- ramas vive aqui y en viaje_cambiar_estado, nunca en la app.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_validar_transicion()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.estado = 'CERRADO' then
    raise exception 'Un viaje cerrado no se puede modificar; use ajuste_viaje.'
      using errcode = 'OR100';
  end if;

  if new.estado <> old.estado then
    if not (
      (old.estado = 'PLANIFICADO' and new.estado = 'ASIGNADO') or
      (old.estado = 'ASIGNADO' and new.estado = 'EN_CURSO') or
      (old.estado = 'EN_CURSO' and new.estado = 'FINALIZADO') or
      (old.estado = 'FINALIZADO' and new.estado = 'CERRADO')
    ) then
      raise exception 'Transicion de estado invalida: % -> %.', old.estado, new.estado
        using errcode = 'OR101';
    end if;

    if new.estado = 'CERRADO' and new.valor_flete = 0 then
      raise exception 'No se puede cerrar un viaje sin valor_flete registrado.'
        using errcode = 'OR102';
    end if;
  end if;

  return new;
end;
$$;

create trigger viaje_validar_transicion
  before update on public.viaje
  for each row execute function public.viaje_validar_transicion();

alter table public.viaje enable row level security;
revoke all on public.viaje from anon, authenticated;
grant select on public.viaje to authenticated;
-- Sin grant de INSERT/UPDATE directo: crear un viaje es una operacion
-- multi-paso (valida vehiculo/conductor activos, sin doble asignacion,
-- calcula ACPM estimado) y cambiar su estado tambien -- ambas viven en RPC
-- SECURITY DEFINER (viaje_crear, viaje_cambiar_estado, viaje_cerrar), que no
-- necesitan grant de tabla porque corren con los permisos del dueno.

create policy viaje_select_admin
  on public.viaje
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy viaje_select_conductor_propio
  on public.viaje
  for select
  to authenticated
  using (
    exists (
      select 1 from public.conductor c
      where c.id = viaje.conductor_id
        and c.usuario_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- hito_viaje
-- ---------------------------------------------------------------------------
create table public.hito_viaje (
  id              uuid primary key default gen_random_uuid(),
  viaje_id        uuid not null references public.viaje (id) on delete cascade,
  tipo            text not null check (tipo in ('SALIDA', 'LLEGADA_CARGUE', 'SALIDA_CON_CARGA', 'LLEGADA_DESTINO')),
  fecha_hora      timestamptz not null,
  origen_dato     text not null default 'APP' check (origen_dato in ('APP', 'MANUAL')),
  creado_por      uuid,
  fecha_creacion  timestamptz not null default now()
);

create index hito_viaje_viaje_id_idx on public.hito_viaje (viaje_id);

create trigger hito_viaje_set_audit
  before insert on public.hito_viaje
  for each row execute function public.usuario_set_audit();

-- ---------------------------------------------------------------------------
-- costo_viaje
-- ---------------------------------------------------------------------------
create table public.costo_viaje (
  id              uuid primary key default gen_random_uuid(),
  viaje_id        uuid not null references public.viaje (id) on delete cascade,
  categoria       text not null check (categoria in (
                    'ACPM', 'PEAJE', 'CARGUE', 'DESCARGUE', 'PARQUEADERO', 'COMISION',
                    'ACEITE', 'LAVADO', 'ENGRASE', 'MANTENIMIENTO_AMORTIZADO', 'OTRO'
                  )),
  valor_estimado  numeric not null default 0 check (valor_estimado >= 0),
  valor_real      numeric check (valor_real is null or valor_real >= 0),
  fuente          text not null default 'MANUAL' check (fuente in ('AUTOMATICO', 'MANUAL')),
  creado_por      uuid,
  fecha_creacion  timestamptz not null default now(),
  modificado_por  uuid,
  fecha_modificacion timestamptz
);

create index costo_viaje_viaje_id_idx on public.costo_viaje (viaje_id);

create trigger costo_viaje_set_audit
  before insert or update on public.costo_viaje
  for each row execute function public.usuario_set_audit();

-- ---------------------------------------------------------------------------
-- Trigger reutilizable: bloquea INSERT/UPDATE/DELETE sobre hito_viaje y
-- costo_viaje cuando el viaje padre ya esta CERRADO (append-only vive en
-- ajuste_viaje, no aqui).
-- ---------------------------------------------------------------------------
create or replace function public.viaje_bloquear_si_cerrado()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_viaje_id uuid := coalesce(new.viaje_id, old.viaje_id);
  v_estado   text;
begin
  select estado into v_estado from public.viaje where id = v_viaje_id;

  if v_estado = 'CERRADO' then
    raise exception 'El viaje esta cerrado; registre el cambio con viaje_registrar_ajuste.'
      using errcode = 'OR100';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger hito_viaje_bloquear_si_cerrado
  before insert or update or delete on public.hito_viaje
  for each row execute function public.viaje_bloquear_si_cerrado();

create trigger costo_viaje_bloquear_si_cerrado
  before insert or update or delete on public.costo_viaje
  for each row execute function public.viaje_bloquear_si_cerrado();

alter table public.hito_viaje enable row level security;
revoke all on public.hito_viaje from anon, authenticated;
grant select, insert on public.hito_viaje to authenticated;

create policy hito_viaje_admin
  on public.hito_viaje
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy hito_viaje_select_conductor_propio
  on public.hito_viaje
  for select
  to authenticated
  using (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = hito_viaje.viaje_id
        and c.usuario_id = (select auth.uid())
    )
  );

create policy hito_viaje_insert_conductor_propio
  on public.hito_viaje
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = hito_viaje.viaje_id
        and c.usuario_id = (select auth.uid())
    )
  );

alter table public.costo_viaje enable row level security;
revoke all on public.costo_viaje from anon, authenticated;
grant select on public.costo_viaje to authenticated;
grant insert, update on public.costo_viaje to authenticated;

create policy costo_viaje_select_admin
  on public.costo_viaje
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy costo_viaje_select_conductor_propio
  on public.costo_viaje
  for select
  to authenticated
  using (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = costo_viaje.viaje_id
        and c.usuario_id = (select auth.uid())
    )
  );

create policy costo_viaje_admin_escribe
  on public.costo_viaje
  for all
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- El conductor solo confirma el valor real de los costos de su propio viaje;
-- no crea categorias nuevas ni toca el estimado (esas filas ya las crea el
-- administrador/las RPC al planear el viaje).
create policy costo_viaje_conductor_actualiza_real
  on public.costo_viaje
  for update
  to authenticated
  using (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = costo_viaje.viaje_id
        and c.usuario_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = costo_viaje.viaje_id
        and c.usuario_id = (select auth.uid())
    )
  );

-- GRANT/REVOKE de columnas no distingue administrador de conductor (ambos
-- son el mismo rol de Postgres `authenticated`; el rol de negocio solo vive
-- en el JWT). La restriccion de que el conductor solo toque valor_real va
-- entonces en un trigger, no en un GRANT de columnas.
create or replace function public.costo_viaje_restringir_conductor()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    if new.categoria is distinct from old.categoria
       or new.valor_estimado is distinct from old.valor_estimado
       or new.fuente is distinct from old.fuente
       or new.viaje_id is distinct from old.viaje_id
    then
      raise exception 'El conductor solo puede actualizar el valor real del costo.'
        using errcode = 'OR115';
    end if;
  end if;
  return new;
end;
$$;

create trigger costo_viaje_restringir_conductor
  before update on public.costo_viaje
  for each row execute function public.costo_viaje_restringir_conductor();

-- ---------------------------------------------------------------------------
-- peaje_capturado (solo lo escribe la Edge Function peajes-correo con
-- service_role; ver seccion "Dominio: viajes" de CLAUDE.md).
-- ---------------------------------------------------------------------------
create table public.peaje_capturado (
  id                  uuid primary key default gen_random_uuid(),
  viaje_id            uuid references public.viaje (id) on delete set null,
  placa               text not null,
  monto               numeric not null check (monto >= 0),
  fecha_hora          timestamptz not null,
  punto_peaje         text,
  correo_origen_id    text not null unique,
  fecha_creacion      timestamptz not null default now()
);

create index peaje_capturado_placa_fecha_idx on public.peaje_capturado (placa, fecha_hora);

alter table public.peaje_capturado enable row level security;
revoke all on public.peaje_capturado from anon, authenticated;
grant select on public.peaje_capturado to authenticated;

create policy peaje_capturado_select_admin
  on public.peaje_capturado
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- Sin politicas de INSERT/UPDATE/DELETE para anon/authenticated: solo
-- service_role (Edge Function peajes-correo) escribe aqui, y service_role
-- ignora RLS por diseno de Supabase.

-- ---------------------------------------------------------------------------
-- ajuste_viaje (append-only; unico camino para modificar un viaje CERRADO)
-- ---------------------------------------------------------------------------
create table public.ajuste_viaje (
  id                  uuid primary key default gen_random_uuid(),
  viaje_id            uuid not null references public.viaje (id) on delete restrict,
  usuario_id          uuid not null references public.usuario (id) on delete restrict,
  motivo              text not null check (btrim(motivo) <> ''),
  campo_modificado    text,
  valor_anterior      text,
  valor_nuevo         text,
  fecha               timestamptz not null default now()
);

create index ajuste_viaje_viaje_id_idx on public.ajuste_viaje (viaje_id);

alter table public.ajuste_viaje enable row level security;
-- Denegar por defecto y, ademas, revocar explicitamente UPDATE/DELETE: nadie
-- (ni un futuro grant accidental de "all") puede editar o borrar un ajuste.
revoke all on public.ajuste_viaje from anon, authenticated;
grant select, insert on public.ajuste_viaje to authenticated;

create policy ajuste_viaje_select_admin
  on public.ajuste_viaje
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy ajuste_viaje_select_conductor_propio
  on public.ajuste_viaje
  for select
  to authenticated
  using (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = ajuste_viaje.viaje_id
        and c.usuario_id = (select auth.uid())
    )
  );

-- El INSERT real solo ocurre dentro de viaje_registrar_ajuste (SECURITY
-- DEFINER); esta politica exige ademas que quien llegue por PostgREST directo
-- solo pueda insertar a su propio nombre.
create policy ajuste_viaje_insert_admin
  on public.ajuste_viaje
  for insert
  to authenticated
  with check (
    (auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR'
    and usuario_id = (select auth.uid())
  );
