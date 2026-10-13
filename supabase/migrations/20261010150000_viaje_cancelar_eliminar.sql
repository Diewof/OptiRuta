-- Cancelar y eliminar viajes (decision del dueño, 2026-10-10: reabre la regla
-- "no existe borrado de viajes").
--
-- * Cancelar: estado terminal CANCELADO con motivo obligatorio. Libera el
--   vehiculo y el conductor, queda en el historial y no cuenta en rentabilidad.
-- * Eliminar: borra un viaje que NO esta CERRADO. Un viaje cerrado sigue siendo
--   inmutable (se corrige con ajuste_viaje). Antes de borrar se guarda una
--   copia minima en viaje_eliminado (append-only) con motivo y autor.

-- ---------------------------------------------------------------------------
-- Estado CANCELADO
-- ---------------------------------------------------------------------------
alter table public.viaje drop constraint if exists viaje_estado_check;
alter table public.viaje
  add constraint viaje_estado_check check (estado in (
    'PLANIFICADO', 'ASIGNADO', 'EN_CURSO', 'FINALIZADO', 'CERRADO', 'CANCELADO'
  )),
  add column motivo_cancelacion text,
  add column fecha_cancelacion timestamptz,
  add constraint viaje_cancelacion_completa check (
    (estado = 'CANCELADO') = (motivo_cancelacion is not null)
  );

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

  if old.estado = 'CANCELADO' then
    raise exception 'Un viaje cancelado no se puede modificar.'
      using errcode = 'OR100';
  end if;

  if new.estado <> old.estado then
    if not (
      (old.estado = 'PLANIFICADO' and new.estado = 'ASIGNADO') or
      (old.estado = 'ASIGNADO' and new.estado = 'EN_CURSO') or
      (old.estado = 'EN_CURSO' and new.estado = 'FINALIZADO') or
      (old.estado = 'FINALIZADO' and new.estado = 'CERRADO') or
      (old.estado in ('PLANIFICADO', 'ASIGNADO', 'EN_CURSO', 'FINALIZADO')
         and new.estado = 'CANCELADO')
    ) then
      raise exception 'Transicion de estado invalida: % -> %.', old.estado, new.estado
        using errcode = 'OR101';
    end if;

    if new.estado = 'CERRADO' and new.valor_flete = 0 then
      raise exception 'No se puede cerrar un viaje sin valor_flete registrado.'
        using errcode = 'OR102';
    end if;

    if new.estado = 'CANCELADO' and new.motivo_cancelacion is null then
      raise exception 'Cancelar un viaje exige un motivo; use viaje_cancelar.'
        using errcode = 'OR123';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.viaje_cancelar(p_viaje_id uuid, p_motivo text)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje public.viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede cancelar un viaje.' using errcode = 'OR105';
  end if;

  if p_motivo is null or char_length(btrim(p_motivo)) < 5 then
    raise exception 'El motivo de la cancelacion es obligatorio (minimo 5 caracteres).'
      using errcode = 'OR124';
  end if;

  select * into v_viaje from public.viaje where id = p_viaje_id for update;
  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado in ('CERRADO', 'CANCELADO') then
    raise exception 'Un viaje % no se puede cancelar.', lower(v_viaje.estado)
      using errcode = 'OR125';
  end if;

  update public.viaje
     set estado = 'CANCELADO',
         motivo_cancelacion = btrim(p_motivo),
         fecha_cancelacion = now()
   where id = p_viaje_id
   returning * into v_viaje;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_cancelar(uuid, text) from public;
grant execute on function public.viaje_cancelar(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Eliminar
-- ---------------------------------------------------------------------------
create table public.viaje_eliminado (
  id              uuid primary key default gen_random_uuid(),
  viaje_id        uuid not null,
  remision        text not null,
  estado          text not null,
  origen          text not null,
  destino         text not null,
  valor_flete     numeric not null,
  motivo          text not null,
  eliminado_por   uuid,
  fecha_eliminacion timestamptz not null default now()
);

comment on table public.viaje_eliminado is
  'Bitacora append-only de viajes borrados (quien, cuando y por que). No guarda el detalle del viaje.';

alter table public.viaje_eliminado enable row level security;
revoke all on public.viaje_eliminado from anon, authenticated;
grant select on public.viaje_eliminado to authenticated;

create policy viaje_eliminado_select_admin
  on public.viaje_eliminado
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create or replace function public.viaje_eliminar(p_viaje_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje public.viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede eliminar un viaje.' using errcode = 'OR105';
  end if;

  if p_motivo is null or char_length(btrim(p_motivo)) < 5 then
    raise exception 'El motivo de la eliminacion es obligatorio (minimo 5 caracteres).'
      using errcode = 'OR124';
  end if;

  select * into v_viaje from public.viaje where id = p_viaje_id for update;
  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado = 'CERRADO' then
    raise exception 'Un viaje cerrado no se elimina; registre un ajuste.' using errcode = 'OR100';
  end if;

  insert into public.viaje_eliminado (
    viaje_id, remision, estado, origen, destino, valor_flete, motivo, eliminado_por
  )
  values (
    v_viaje.id, v_viaje.remision, v_viaje.estado, v_viaje.origen, v_viaje.destino,
    v_viaje.valor_flete, btrim(p_motivo), (select auth.uid())
  );

  delete from public.viaje where id = p_viaje_id;
end;
$$;

revoke all on function public.viaje_eliminar(uuid, text) from public;
grant execute on function public.viaje_eliminar(uuid, text) to authenticated;
