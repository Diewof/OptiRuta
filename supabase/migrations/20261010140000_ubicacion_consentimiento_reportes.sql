-- RF-21/23: registro periodico de ubicacion con consentimiento informado.
-- RF-27/28: reporte de viajes con filtros (la exportacion a PDF la arma la app
-- a partir de estas mismas filas).
--
-- Decision de producto (2026-10-10, autorizada por el dueño): se reabre la
-- exclusion de tracking. Alcance: la app, abierta y con el viaje EN_CURSO,
-- envia un punto cada ~5 minutos y solo si el conductor acepto el
-- consentimiento. Sin servicio en segundo plano.

-- ---------------------------------------------------------------------------
-- RF-23: consentimiento (fecha de aceptacion; null = no acepto o lo revoco)
-- ---------------------------------------------------------------------------
alter table public.conductor
  add column consentimiento_ubicacion_fecha timestamptz;

comment on column public.conductor.consentimiento_ubicacion_fecha is
  'Cuando el conductor acepto el registro de su ubicacion durante viajes en curso (RF-23). Null = sin consentimiento.';

create or replace function public.conductor_consentimiento_ubicacion(p_acepta boolean)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fecha timestamptz := case when p_acepta then now() else null end;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo un conductor puede gestionar su consentimiento.'
      using errcode = 'OR105';
  end if;

  update public.conductor
     set consentimiento_ubicacion_fecha = v_fecha
   where usuario_id = (select auth.uid());

  if not found then
    raise exception 'No existe un conductor asociado a la sesion.' using errcode = 'OR103';
  end if;

  return v_fecha;
end;
$$;

revoke all on function public.conductor_consentimiento_ubicacion(boolean) from public;
grant execute on function public.conductor_consentimiento_ubicacion(boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- RF-21: puntos de ubicacion del viaje (append-only; solo los escribe la RPC)
-- ---------------------------------------------------------------------------
create table public.ubicacion_viaje (
  id          uuid primary key default gen_random_uuid(),
  viaje_id    uuid not null references public.viaje (id) on delete cascade,
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  fecha_hora  timestamptz not null default now()
);

create index ubicacion_viaje_viaje_fecha_idx
  on public.ubicacion_viaje (viaje_id, fecha_hora desc);

alter table public.ubicacion_viaje enable row level security;
revoke all on public.ubicacion_viaje from anon, authenticated;
grant select on public.ubicacion_viaje to authenticated;

create policy ubicacion_viaje_select_admin
  on public.ubicacion_viaje
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy ubicacion_viaje_select_conductor_propio
  on public.ubicacion_viaje
  for select
  to authenticated
  using (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = ubicacion_viaje.viaje_id
        and c.usuario_id = (select auth.uid())
    )
  );

-- Sin politicas de INSERT/UPDATE/DELETE: el historial de ubicacion no se edita.

-- Devuelve true si guardo el punto; false si ya hay uno de hace menos de
-- 4 minutos (evita rafagas por reintentos).
create or replace function public.viaje_registrar_ubicacion(
  p_viaje_id uuid,
  p_lat double precision,
  p_lng double precision
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_estado         text;
  v_consentimiento timestamptz;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede registrar su ubicacion.'
      using errcode = 'OR105';
  end if;

  if p_lat is null or p_lng is null
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'La ubicacion no es valida.' using errcode = 'OR117';
  end if;

  select v.estado, c.consentimiento_ubicacion_fecha
    into v_estado, v_consentimiento
    from public.viaje v
    join public.conductor c on c.id = v.conductor_id
   where v.id = p_viaje_id
     and c.usuario_id = (select auth.uid());

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_estado <> 'EN_CURSO' then
    raise exception 'Solo se registra ubicacion en viajes en curso.' using errcode = 'OR118';
  end if;

  if v_consentimiento is null then
    raise exception 'El conductor no ha aceptado el registro de ubicacion.' using errcode = 'OR122';
  end if;

  if exists (
    select 1 from public.ubicacion_viaje u
     where u.viaje_id = p_viaje_id
       and u.fecha_hora > now() - interval '4 minutes'
  ) then
    return false;
  end if;

  insert into public.ubicacion_viaje (viaje_id, lat, lng)
  values (p_viaje_id, p_lat, p_lng);

  return true;
end;
$$;

revoke all on function public.viaje_registrar_ubicacion(uuid, double precision, double precision) from public;
grant execute on function public.viaje_registrar_ubicacion(uuid, double precision, double precision) to authenticated;

-- ---------------------------------------------------------------------------
-- RF-27/28: reporte de viajes cerrados con filtros opcionales. Un parametro
-- nulo no filtra. p_ruta busca texto dentro de "origen → destino".
-- ---------------------------------------------------------------------------
create or replace function public.reporte_viajes(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid default null,
  p_conductor_id uuid default null,
  p_vehiculo_id uuid default null,
  p_ruta text default null
)
returns table (
  viaje_id      uuid,
  remision      text,
  fecha_cierre  date,
  ruta          text,
  cliente       text,
  conductor     text,
  placa         text,
  km            numeric,
  valor_flete   numeric,
  costos        numeric,
  rentabilidad  numeric,
  a_tiempo      boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar reportes.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;

  return query
    with base as (
      select v.id, v.remision as rem, v.fecha_cierre::date as cierre,
             v.origen || ' → ' || v.destino as la_ruta,
             cl.nombre as nom_cliente, u.nombre as nom_conductor, ve.placa as la_placa,
             coalesce(v.distancia_estimada, 0) as kms, v.valor_flete as flete,
             v.tiempo_estimado_min as est,
             (select min(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'SALIDA') as salida,
             (select max(h.fecha_hora) from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO') as llegada,
             (select coalesce(sum(coalesce(cv.valor_real, cv.valor_estimado)), 0)
                from public.costo_viaje cv
               where cv.viaje_id = v.id and cv.categoria <> 'MANTENIMIENTO_AMORTIZADO') as costo_total
        from public.viaje v
        join public.cliente cl on cl.id = v.cliente_id
        join public.conductor co on co.id = v.conductor_id
        join public.usuario u on u.id = co.usuario_id
        join public.vehiculo ve on ve.id = v.vehiculo_id
       where v.estado = 'CERRADO'
         and v.fecha_cierre::date between p_desde and p_hasta
         and (p_cliente_id is null or v.cliente_id = p_cliente_id)
         and (p_conductor_id is null or v.conductor_id = p_conductor_id)
         and (p_vehiculo_id is null or v.vehiculo_id = p_vehiculo_id)
         and (p_ruta is null or btrim(p_ruta) = ''
              or position(lower(btrim(p_ruta)) in lower(v.origen || ' → ' || v.destino)) > 0)
    )
    select b.id, b.rem, b.cierre, b.la_ruta, b.nom_cliente, b.nom_conductor, b.la_placa,
           b.kms, b.flete, b.costo_total, b.flete - b.costo_total,
           case when b.salida is not null and b.llegada is not null and b.est is not null
                then extract(epoch from (b.llegada - b.salida)) / 60 <= b.est + greatest(b.est * 0.2, 30)
           end
      from base b
     order by b.cierre desc, b.rem;
end;
$$;

revoke all on function public.reporte_viajes(date, date, uuid, uuid, uuid, text) from public;
grant execute on function public.reporte_viajes(date, date, uuid, uuid, uuid, text) to authenticated;
