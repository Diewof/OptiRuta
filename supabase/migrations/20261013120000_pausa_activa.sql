-- Pausa activa: aviso al conductor tras 4 h de conduccion continua y alerta al
-- administrador si lo ignora.
--
-- Decisiones (2026-10-13):
--   * La deteccion (4 h al volante, parada >= 15 min reinicia, 15 min de gracia)
--     la hace el telefono con el GPS, igual que parada/desvio: el servidor solo
--     recibe el evento puntual de "ignorada" (viaje_registrar_pausa_ignorada).
--   * Modo prueba: el administrador dispara el aviso en el telefono del
--     conductor con viaje_probar_pausa_activa. La app del conductor lo
--     consulta con viaje_consumir_pausa_prueba (se entrega una sola vez).
--   * Sin tablas de eventos: la alerta ignorada queda en `notificacion`.

-- ---------------------------------------------------------------------------
-- notificacion: tipo nuevo
-- ---------------------------------------------------------------------------
alter table public.notificacion drop constraint if exists notificacion_tipo_check;
alter table public.notificacion
  add constraint notificacion_tipo_check check (tipo in (
    'DOCUMENTO_POR_VENCER', 'DOCUMENTO_VENCIDO', 'MANTENIMIENTO_PROXIMO',
    'MANTENIMIENTO_VENCIDO', 'CHECKLIST_FALLA', 'RETRASO', 'VIAJE_COMPLETADO',
    'PEAJE_REGISTRADO', 'NOVEDAD', 'PARADA_PROLONGADA', 'DESVIO_RUTA',
    'SATISFACCION_BAJA', 'PAUSA_ACTIVA_IGNORADA'
  ));

-- ---------------------------------------------------------------------------
-- pausa_activa_prueba: ordenes de prueba del administrador
-- ---------------------------------------------------------------------------
create table public.pausa_activa_prueba (
  id              uuid primary key default gen_random_uuid(),
  viaje_id        uuid not null references public.viaje (id) on delete cascade,
  creado_por      uuid default auth.uid(),
  fecha_creacion  timestamptz not null default now(),
  consumida_en    timestamptz
);

comment on table public.pausa_activa_prueba is
  'Orden de prueba del administrador para mostrar el aviso de pausa activa en '
  'el telefono del conductor. Se entrega una sola vez (consumida_en) y caduca '
  'a los 10 minutos.';

create index pausa_activa_prueba_viaje_idx
  on public.pausa_activa_prueba (viaje_id, fecha_creacion desc);

alter table public.pausa_activa_prueba enable row level security;
revoke all on public.pausa_activa_prueba from anon, authenticated;
grant select on public.pausa_activa_prueba to authenticated;

create policy pausa_activa_prueba_select_admin
  on public.pausa_activa_prueba
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- ---------------------------------------------------------------------------
-- viaje_probar_pausa_activa (administrador)
-- ---------------------------------------------------------------------------
create or replace function public.viaje_probar_pausa_activa(p_viaje_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_estado text;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo el administrador puede probar la pausa activa.'
      using errcode = 'OR105';
  end if;

  select estado into v_estado from public.viaje where id = p_viaje_id;
  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;
  if v_estado <> 'EN_CURSO' then
    raise exception 'Solo se prueba la pausa activa en viajes en curso.'
      using errcode = 'OR118';
  end if;

  -- Una orden pendiente por viaje: repetir el toque no apila avisos.
  delete from public.pausa_activa_prueba
   where viaje_id = p_viaje_id and consumida_en is null;

  insert into public.pausa_activa_prueba (viaje_id) values (p_viaje_id);
end;
$$;

revoke all on function public.viaje_probar_pausa_activa(uuid) from public, anon;
grant execute on function public.viaje_probar_pausa_activa(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- viaje_consumir_pausa_prueba (conductor)
-- Devuelve true una sola vez por orden de prueba vigente (< 10 min).
-- ---------------------------------------------------------------------------
create or replace function public.viaje_consumir_pausa_prueba(p_viaje_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje consulta la pausa activa.'
      using errcode = 'OR105';
  end if;

  if not exists (
    select 1
      from public.viaje v
      join public.conductor c on c.id = v.conductor_id
     where v.id = p_viaje_id
       and v.estado = 'EN_CURSO'
       and c.usuario_id = (select auth.uid())
  ) then
    return false;
  end if;

  update public.pausa_activa_prueba
     set consumida_en = now()
   where id = (
     select p.id
       from public.pausa_activa_prueba p
      where p.viaje_id = p_viaje_id
        and p.consumida_en is null
        and p.fecha_creacion > now() - interval '10 minutes'
      order by p.fecha_creacion desc
      limit 1
      for update skip locked
   )
   returning id into v_id;

  return v_id is not null;
end;
$$;

revoke all on function public.viaje_consumir_pausa_prueba(uuid) from public, anon;
grant execute on function public.viaje_consumir_pausa_prueba(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- viaje_registrar_pausa_ignorada (conductor)
-- El telefono la envia cuando, pasados 15 min del aviso, el conductor sigue
-- en movimiento. Idempotente en 60 min por viaje. true si notifico.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_registrar_pausa_ignorada(
  p_viaje_id uuid,
  p_minutos_conduccion integer,
  p_minutos_ignorada integer,
  p_prueba boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje   public.viaje;
  v_nombre  text;
  v_mensaje text;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede registrar la pausa activa.'
      using errcode = 'OR105';
  end if;

  if p_minutos_conduccion is null or p_minutos_conduccion < 0
     or p_minutos_ignorada is null or p_minutos_ignorada < 0 then
    raise exception 'Los minutos de la alerta no son validos.'
      using errcode = 'OR116';
  end if;

  select v.* into v_viaje
    from public.viaje v
    join public.conductor c on c.id = v.conductor_id
   where v.id = p_viaje_id
     and c.usuario_id = (select auth.uid());

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  select nombre into v_nombre from public.usuario where id = (select auth.uid());

  if v_viaje.estado <> 'EN_CURSO' then
    raise exception 'Solo se registran alertas en viajes en curso.' using errcode = 'OR118';
  end if;

  if exists (
    select 1 from public.notificacion n
     where n.viaje_id = p_viaje_id
       and n.tipo = 'PAUSA_ACTIVA_IGNORADA'
       and n.fecha_creacion > now() - interval '60 minutes'
  ) then
    return false;
  end if;

  v_mensaje := format(
    '%s (viaje %s, %s → %s) recibió el aviso de pausa activa tras %s h %s min '
    'al volante y siguió conduciendo %s min sin detenerse.',
    v_nombre, v_viaje.remision, v_viaje.origen, v_viaje.destino,
    p_minutos_conduccion / 60, lpad((p_minutos_conduccion % 60)::text, 2, '0'),
    p_minutos_ignorada
  );
  if p_prueba then
    v_mensaje := v_mensaje || ' (Prueba lanzada por el administrador.)';
  end if;

  insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
  values ('PAUSA_ACTIVA_IGNORADA', 'Pausa activa ignorada', v_mensaje, p_viaje_id);

  return true;
end;
$$;

revoke all on function public.viaje_registrar_pausa_ignorada(uuid, integer, integer, boolean) from public, anon;
grant execute on function public.viaje_registrar_pausa_ignorada(uuid, integer, integer, boolean) to authenticated;
