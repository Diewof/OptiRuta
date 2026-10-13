-- Fase 2: kilometraje real del viaje (GPS) y odometro derivado del vehiculo.
--
-- Decision (dueño, 2026-10-11): el kilometraje sale solo del GPS acumulado
-- (ubicacion_viaje), no de una lectura manual del tablero. Con eso:
--   * viaje.km_recorridos es el par "real" de distancia_estimada;
--   * si el GPS no cubre el viaje (sin consentimiento, app cerrada) se usa la
--     distancia estimada y se marca km_origen = 'ESTIMADO' para que la UI lo
--     diga y no se confunda con un dato medido;
--   * el odometro del vehiculo no se guarda: es odometro_inicial_km mas los km
--     de los viajes FINALIZADO/CERRADO, asi nunca se desincroniza.

alter table public.viaje
  add column km_recorridos numeric check (km_recorridos is null or km_recorridos >= 0),
  add column km_origen text check (km_origen is null or km_origen in ('GPS', 'ESTIMADO'));

comment on column public.viaje.km_recorridos is
  'Km del viaje al finalizar: suma haversine de ubicacion_viaje (GPS) o, si el GPS no lo cubre, distancia_estimada.';

-- Distancia entre dos coordenadas en metros (haversine, radio 6371000 m).
create or replace function public.distancia_haversine_m(
  p_lat1 double precision, p_lng1 double precision,
  p_lat2 double precision, p_lng2 double precision
)
returns double precision
language sql
immutable
set search_path = ''
as $$
  select 2 * 6371000 * asin(sqrt(
    power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2))
      * power(sin(radians(p_lng2 - p_lng1) / 2), 2)
  ));
$$;

-- ---------------------------------------------------------------------------
-- viaje_fijar_km: calcula y guarda los km del viaje. Uso interno: lo llaman
-- las RPC que dejan el viaje FINALIZADO.
--
-- Cobertura minima: si el GPS suma menos de la mitad de la distancia estimada
-- se considera que faltan puntos (un viaje completado no recorre menos de la
-- mitad de lo estimado) y se usa la estimada. Con menos de 2 puntos tampoco
-- hay trayecto que medir.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_fijar_km(p_viaje_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_cobertura_min constant numeric := 0.5;
  v_estimada numeric;
  v_puntos   integer;
  v_gps_km   numeric;
begin
  select v.distancia_estimada into v_estimada
    from public.viaje v where v.id = p_viaje_id;

  select count(*)::int,
         coalesce(sum(public.distancia_haversine_m(t.lat0, t.lng0, t.lat, t.lng)), 0) / 1000
    into v_puntos, v_gps_km
    from (
      select u.lat, u.lng,
             lag(u.lat) over (order by u.fecha_hora) as lat0,
             lag(u.lng) over (order by u.fecha_hora) as lng0
        from public.ubicacion_viaje u
       where u.viaje_id = p_viaje_id
    ) t;

  if v_puntos >= 2 and v_gps_km > 0
     and (v_estimada is null or v_gps_km >= v_estimada * c_cobertura_min) then
    update public.viaje
       set km_recorridos = round(v_gps_km, 1), km_origen = 'GPS'
     where id = p_viaje_id;
  elsif v_estimada is not null then
    update public.viaje
       set km_recorridos = v_estimada, km_origen = 'ESTIMADO'
     where id = p_viaje_id;
  end if;
end;
$$;

revoke all on function public.viaje_fijar_km(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Las dos RPC que finalizan un viaje fijan los km antes de cambiar el estado.
-- Mismas firmas; solo se agrega la llamada a viaje_fijar_km.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_cambiar_estado(p_viaje_id uuid, p_nuevo_estado text)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rol         text := (auth.jwt() -> 'app_metadata' ->> 'rol');
  v_es_propio   boolean;
  v_estado_actual text;
  v_viaje       public.viaje;
begin
  select v.estado, exists (
           select 1 from public.conductor c
           where c.id = v.conductor_id and c.usuario_id = (select auth.uid())
         )
    into v_estado_actual, v_es_propio
    from public.viaje v
   where v.id = p_viaje_id
   for update;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_rol = 'ADMINISTRADOR' then
    null; -- autorizado para cualquier transicion valida
  elsif v_rol = 'CONDUCTOR' and v_es_propio then
    if not (
      (v_estado_actual = 'ASIGNADO' and p_nuevo_estado = 'EN_CURSO') or
      (v_estado_actual = 'EN_CURSO' and p_nuevo_estado = 'FINALIZADO')
    ) then
      raise exception 'El conductor no puede realizar esta transicion de estado.'
        using errcode = 'OR104';
    end if;
  else
    raise exception 'No autorizado para cambiar el estado de este viaje.'
      using errcode = 'OR105';
  end if;

  if p_nuevo_estado = 'FINALIZADO' and v_estado_actual = 'EN_CURSO' then
    perform public.viaje_fijar_km(p_viaje_id);
  end if;

  update public.viaje
     set estado = p_nuevo_estado
   where id = p_viaje_id
   returning * into v_viaje;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_cambiar_estado(uuid, text) from public;
grant execute on function public.viaje_cambiar_estado(uuid, text) to authenticated;

create or replace function public.viaje_registrar_hito(
  p_viaje_id uuid,
  p_tipo text,
  p_fecha_hora timestamptz default now()
)
returns public.hito_viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_estado    text;
  v_salida    timestamptz;
  v_previo    text;
  v_hito      public.hito_viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede registrar hitos.' using errcode = 'OR105';
  end if;

  if p_tipo not in ('LLEGADA_CARGUE', 'SALIDA_CON_CARGA', 'LLEGADA_DESTINO') then
    raise exception 'Tipo de hito no valido; la salida se registra al comenzar el viaje.'
      using errcode = 'OR126';
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
    raise exception 'Solo se registran hitos en un viaje en curso.' using errcode = 'OR118';
  end if;

  v_previo := case p_tipo
    when 'LLEGADA_CARGUE' then 'SALIDA'
    when 'SALIDA_CON_CARGA' then 'LLEGADA_CARGUE'
    else 'SALIDA_CON_CARGA'
  end;

  if not exists (select 1 from public.hito_viaje h where h.viaje_id = p_viaje_id and h.tipo = v_previo) then
    raise exception 'Primero registra el hito anterior.' using errcode = 'OR127';
  end if;

  if exists (select 1 from public.hito_viaje h where h.viaje_id = p_viaje_id and h.tipo = p_tipo) then
    raise exception 'Ese hito ya fue registrado.' using errcode = 'OR128';
  end if;

  select min(h.fecha_hora) into v_salida
    from public.hito_viaje h where h.viaje_id = p_viaje_id and h.tipo = 'SALIDA';

  if p_fecha_hora is null or p_fecha_hora > now() + interval '5 minutes'
     or (v_salida is not null and p_fecha_hora < v_salida) then
    raise exception 'La hora del hito no es valida.' using errcode = 'OR129';
  end if;

  insert into public.hito_viaje (viaje_id, tipo, fecha_hora, origen_dato)
  values (p_viaje_id, p_tipo, p_fecha_hora, 'APP')
  returning * into v_hito;

  if p_tipo = 'LLEGADA_DESTINO' then
    perform public.viaje_fijar_km(p_viaje_id);
    update public.viaje set estado = 'FINALIZADO' where id = p_viaje_id;
  end if;

  return v_hito;
end;
$$;

revoke all on function public.viaje_registrar_hito(uuid, text, timestamptz) from public;
grant execute on function public.viaje_registrar_hito(uuid, text, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- Odometro derivado. Uso interno (alertas de mantenimiento, resumen).
-- ---------------------------------------------------------------------------
create or replace function public.vehiculo_odometro_km(p_vehiculo_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select v.odometro_inicial_km + coalesce((
    select sum(t.km_recorridos)
      from public.viaje t
     where t.vehiculo_id = v.id
       and t.estado in ('FINALIZADO', 'CERRADO')
  ), 0)
  from public.vehiculo v
  where v.id = p_vehiculo_id;
$$;

revoke all on function public.vehiculo_odometro_km(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- vehiculo_resumen: odometro y estado documental por vehiculo (solo admin).
-- Con p_vehiculo_id nulo devuelve toda la flota.
-- ---------------------------------------------------------------------------
create or replace function public.vehiculo_resumen(p_vehiculo_id uuid default null)
returns table (
  vehiculo_id     uuid,
  odometro_km     numeric,
  soat_vence      date,
  soat_estado     text,
  rtm_vence       date,
  rtm_estado      text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la hoja de vida.' using errcode = 'OR105';
  end if;

  return query
    select v.id,
           public.vehiculo_odometro_km(v.id),
           s.fecha_vencimiento, s.estado,
           r.fecha_vencimiento, r.estado
      from public.vehiculo v
      left join public.documento_vehiculo_vigente s
             on s.vehiculo_id = v.id and s.tipo = 'SOAT'
      left join public.documento_vehiculo_vigente r
             on r.vehiculo_id = v.id and r.tipo = 'TECNOMECANICA'
     where p_vehiculo_id is null or v.id = p_vehiculo_id;
end;
$$;

revoke all on function public.vehiculo_resumen(uuid) from public;
grant execute on function public.vehiculo_resumen(uuid) to authenticated;
