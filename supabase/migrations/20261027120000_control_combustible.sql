-- Control de combustible (inteligencia de negocios, informe 1).
--
-- Decisiones del dueño (2026-10-27):
--   * El conductor registra cada tanqueo (galones + valor) con el viaje EN_CURSO.
--     Sin foto de factura: no hay Storage ni dependencias nuevas.
--   * El informe mide solo rendimiento km/galon (km GPS / galones comprados).
--     No afirma ralenti ni extraccion: una caida sostenida se alerta como
--     «consumo anomalo, revisar vehiculo» (el GPS no trae velocidad ni motor).
--   * Alerta RENDIMIENTO_BAJO: el rendimiento del mes cae >= 15 % contra el
--     promedio de los 3 meses anteriores (c_caida_pct), con al menos 2 viajes
--     medidos en cada ventana. Umbrales solo en estas funciones.
--   * Solo cuentan viajes FINALIZADOS/CERRADOS con km medidos por GPS
--     (`km_origen = 'GPS'`) y al menos un tanqueo. Los km ESTIMADOS no sirven
--     para medir rendimiento real.
--   * El valor de los tanqueos alimenta el costo ACPM real del viaje (suma),
--     para no capturar el mismo dato dos veces.

-- ---------------------------------------------------------------------------
-- notificacion: tipo nuevo
-- ---------------------------------------------------------------------------
alter table public.notificacion drop constraint if exists notificacion_tipo_check;
alter table public.notificacion
  add constraint notificacion_tipo_check check (tipo in (
    'DOCUMENTO_POR_VENCER', 'DOCUMENTO_VENCIDO', 'MANTENIMIENTO_PROXIMO',
    'MANTENIMIENTO_VENCIDO', 'CHECKLIST_FALLA', 'RETRASO', 'VIAJE_COMPLETADO',
    'PEAJE_REGISTRADO', 'NOVEDAD', 'PARADA_PROLONGADA', 'DESVIO_RUTA',
    'SATISFACCION_BAJA', 'PAUSA_ACTIVA_IGNORADA', 'CALIDAD_RECURRENTE',
    'ESPERA_EXCESIVA', 'RENDIMIENTO_BAJO'
  ));

-- ---------------------------------------------------------------------------
-- tanqueo_viaje: append-only. Solo se escribe por viaje_registrar_tanqueo.
-- ---------------------------------------------------------------------------
create table public.tanqueo_viaje (
  id              uuid primary key default gen_random_uuid(),
  viaje_id        uuid not null references public.viaje (id) on delete cascade,
  galones         numeric not null check (galones > 0),
  valor           numeric not null check (valor > 0),
  fecha_hora      timestamptz not null default now(),
  creado_por      uuid,
  fecha_creacion  timestamptz not null default now()
);

comment on table public.tanqueo_viaje is
  'Combustible comprado durante un viaje (galones y valor), registrado por el conductor. Insumo del rendimiento km/galon.';

create index tanqueo_viaje_viaje_id_idx on public.tanqueo_viaje (viaje_id);

create trigger tanqueo_viaje_set_audit
  before insert on public.tanqueo_viaje
  for each row execute function public.usuario_set_audit();

alter table public.tanqueo_viaje enable row level security;
revoke all on public.tanqueo_viaje from anon, authenticated;
grant select on public.tanqueo_viaje to authenticated;

create policy tanqueo_viaje_select_admin
  on public.tanqueo_viaje
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy tanqueo_viaje_select_conductor_propio
  on public.tanqueo_viaje
  for select
  to authenticated
  using (
    exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = tanqueo_viaje.viaje_id
        and c.usuario_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- viaje_registrar_tanqueo
-- ---------------------------------------------------------------------------
create or replace function public.viaje_registrar_tanqueo(
  p_viaje_id uuid,
  p_galones numeric,
  p_valor numeric
)
returns public.tanqueo_viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_galones_max constant numeric := 500;
  v_estado  text;
  v_total   numeric;
  v_tanqueo public.tanqueo_viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede registrar tanqueos.' using errcode = 'OR105';
  end if;

  if p_galones is null or p_galones <= 0 or p_galones > c_galones_max then
    raise exception 'Los galones deben ser mayores que 0 y no superar %.', c_galones_max
      using errcode = 'OR151';
  end if;
  if p_valor is null or p_valor <= 0 then
    raise exception 'El valor del tanqueo debe ser mayor que 0.' using errcode = 'OR152';
  end if;

  select v.estado into v_estado
    from public.viaje v
    join public.conductor c on c.id = v.conductor_id
   where v.id = p_viaje_id and c.usuario_id = (select auth.uid())
   for update of v;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;
  if v_estado <> 'EN_CURSO' then
    raise exception 'Solo se registran tanqueos en un viaje en curso.' using errcode = 'OR118';
  end if;

  insert into public.tanqueo_viaje (viaje_id, galones, valor)
  values (p_viaje_id, p_galones, p_valor)
  returning * into v_tanqueo;

  select sum(t.valor) into v_total from public.tanqueo_viaje t where t.viaje_id = p_viaje_id;

  update public.costo_viaje
     set valor_real = v_total
   where viaje_id = p_viaje_id and categoria = 'ACPM';
  if not found then
    insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
    values (p_viaje_id, 'ACPM', 0, v_total, 'MANUAL');
  end if;

  return v_tanqueo;
end;
$$;

revoke all on function public.viaje_registrar_tanqueo(uuid, numeric, numeric) from public;
grant execute on function public.viaje_registrar_tanqueo(uuid, numeric, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- combustible_viajes: interna. Un renglon por viaje medible del periodo.
-- ---------------------------------------------------------------------------
create or replace function public.combustible_viajes(p_desde date, p_hasta date)
returns table (
  viaje_id     uuid,
  vehiculo_id  uuid,
  placa        text,
  ruta         text,
  referencia   numeric,
  km           numeric,
  galones      numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select v.id, v.vehiculo_id, ve.placa, v.origen || ' → ' || v.destino,
         ve.rendimiento_km_galon, v.km_recorridos, t.galones
    from public.viaje v
    join public.vehiculo ve on ve.id = v.vehiculo_id
    join lateral (
      select sum(x.galones) as galones
        from public.tanqueo_viaje x where x.viaje_id = v.id
    ) t on t.galones > 0
   where v.estado in ('FINALIZADO', 'CERRADO')
     and v.km_origen = 'GPS'
     and v.km_recorridos > 0
     and public.viaje_fecha_informe(v.id) between p_desde and p_hasta;
$$;

revoke all on function public.combustible_viajes(date, date) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- combustible_rendimiento_base: interna. Rendimiento del periodo contra el
-- de los 3 meses anteriores, por placa o por ruta.
-- ---------------------------------------------------------------------------
create or replace function public.combustible_rendimiento_base(
  p_desde date,
  p_hasta date,
  p_dimension text,
  p_vehiculo_id uuid default null
)
returns table (
  clave               text,
  vehiculo_id         uuid,
  viajes              integer,
  km                  numeric,
  galones             numeric,
  km_por_galon        numeric,
  km_por_galon_previo numeric,
  variacion_pct       numeric,
  referencia_km_galon numeric,
  alerta              boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with actual as (
    select case p_dimension when 'RUTA' then c.ruta else c.placa end as la_clave,
           case when p_dimension = 'VEHICULO' then min(c.vehiculo_id::text)::uuid end as veh,
           count(*)::int as n,
           sum(c.km) as km,
           sum(c.galones) as gal,
           min(c.referencia) as ref
      from public.combustible_viajes(p_desde, p_hasta) c
     where p_vehiculo_id is null or c.vehiculo_id = p_vehiculo_id
     group by 1
  ), previo as (
    select case p_dimension when 'RUTA' then c.ruta else c.placa end as la_clave,
           count(*)::int as n,
           sum(c.km) / nullif(sum(c.galones), 0) as rend
      from public.combustible_viajes((p_desde - interval '3 months')::date, p_desde - 1) c
     where p_vehiculo_id is null or c.vehiculo_id = p_vehiculo_id
     group by 1
  )
  select a.la_clave, a.veh, a.n,
         round(a.km, 1),
         round(a.gal, 1),
         round(a.km / a.gal, 2),
         round(p.rend, 2),
         case when p.rend > 0 then round((a.km / a.gal - p.rend) / p.rend * 100, 1) end,
         case when p_dimension = 'VEHICULO' then a.ref end,
         coalesce(
           a.n >= 2 and p.n >= 2 and p.rend > 0
           and (a.km / a.gal - p.rend) / p.rend * 100 <= -15,
           false)
    from actual a
    left join previo p on p.la_clave = a.la_clave
   order by 8 nulls last, 1;
$$;

revoke all on function public.combustible_rendimiento_base(date, date, text, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- combustible_rendimiento: pestaña «Combustible» (solo administrador).
-- p_dimension: 'VEHICULO' (por placa) o 'RUTA'.
-- ---------------------------------------------------------------------------
create or replace function public.combustible_rendimiento(
  p_desde date,
  p_hasta date,
  p_dimension text default 'VEHICULO',
  p_vehiculo_id uuid default null
)
returns table (
  clave               text,
  viajes              integer,
  km                  numeric,
  galones             numeric,
  km_por_galon        numeric,
  km_por_galon_previo numeric,
  variacion_pct       numeric,
  referencia_km_galon numeric,
  alerta              boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar el combustible.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;
  if p_dimension not in ('VEHICULO', 'RUTA') then
    raise exception 'Dimension de combustible no valida.' using errcode = 'OR121';
  end if;

  return query
    select b.clave, b.viajes, b.km, b.galones, b.km_por_galon, b.km_por_galon_previo,
           b.variacion_pct, b.referencia_km_galon, b.alerta
      from public.combustible_rendimiento_base(p_desde, p_hasta, p_dimension, p_vehiculo_id) b;
end;
$$;

revoke all on function public.combustible_rendimiento(date, date, text, uuid) from public;
grant execute on function public.combustible_rendimiento(date, date, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- combustible_alertas_generar: job diario de pg_cron. Una notificacion por
-- vehiculo y mes (la clave evita repetirla en cada corrida).
-- ---------------------------------------------------------------------------
create or replace function public.combustible_alertas_generar()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_desde date := date_trunc('month', (now() at time zone 'America/Bogota'))::date;
  v_hasta date := (date_trunc('month', (now() at time zone 'America/Bogota')) + interval '1 month' - interval '1 day')::date;
  v_mes   text := to_char(v_desde, 'YYYY-MM');
  v_n     integer;
begin
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, clave)
  select 'RENDIMIENTO_BAJO',
         'Consumo anómalo de combustible · ' || b.clave,
         format('Rinde %s km/gal este mes contra %s km/gal en los 3 meses previos (%s %%). Conviene revisar el vehículo.',
                b.km_por_galon, b.km_por_galon_previo, b.variacion_pct),
         b.vehiculo_id,
         'COMB:' || b.vehiculo_id || ':' || v_mes
    from public.combustible_rendimiento_base(v_desde, v_hasta, 'VEHICULO') b
   where b.alerta
     and not exists (
       select 1 from public.notificacion n
        where n.clave = 'COMB:' || b.vehiculo_id || ':' || v_mes
     );
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.combustible_alertas_generar() from public, anon, authenticated;

select cron.schedule(
  'combustible-alertas-diario',
  '0 13 * * *',
  $$select public.combustible_alertas_generar();$$
);
