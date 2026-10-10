-- Mapas: coordenadas de origen/destino, trazado de ruta y alertas de parada
-- prolongada / desvio de ruta.
--
-- Decisiones (CLAUDE.md "Dominio: viajes", seccion "Ubicacion en mapa"):
--   * Las coordenadas son nullable: los viajes anteriores solo tienen texto.
--   * La posicion del conductor NO se persiste. El telefono detecta parada
--     (30 min) y desvio (1 km) y envia solo un evento puntual a
--     viaje_registrar_alerta, que notifica al administrador.
--   * viaje_crear no cambia (puede haber app vieja en uso): viaje_crear_v2 lo
--     reutiliza y agrega las coordenadas, sin duplicar sus reglas.

-- ---------------------------------------------------------------------------
-- viaje: coordenadas y trazado
-- ---------------------------------------------------------------------------
alter table public.viaje
  add column origen_lat      double precision check (origen_lat between -90 and 90),
  add column origen_lng      double precision check (origen_lng between -180 and 180),
  add column destino_lat     double precision check (destino_lat between -90 and 90),
  add column destino_lng     double precision check (destino_lng between -180 and 180),
  add column ruta_polilinea  text;

alter table public.viaje
  add constraint viaje_origen_coordenadas_completas
    check ((origen_lat is null) = (origen_lng is null)),
  add constraint viaje_destino_coordenadas_completas
    check ((destino_lat is null) = (destino_lng is null));

comment on column public.viaje.ruta_polilinea is
  'Trazado de la ruta estimada (polilinea codificada, precision 5) calculado '
  'por la Edge Function rutas al agendar. La app lo usa para dibujar la ruta '
  'y detectar desvios; no se recalcula.';

-- ---------------------------------------------------------------------------
-- viaje_crear_v2
-- ---------------------------------------------------------------------------
create or replace function public.viaje_crear_v2(
  p_remision text,
  p_vehiculo_id uuid,
  p_conductor_id uuid,
  p_cliente_id uuid,
  p_origen text,
  p_destino text,
  p_origen_lat double precision,
  p_origen_lng double precision,
  p_destino_lat double precision,
  p_destino_lng double precision,
  p_ruta_polilinea text,
  p_fecha_salida_programada timestamptz,
  p_distancia_estimada numeric,
  p_tiempo_estimado_min numeric,
  p_peso_carga numeric,
  p_valor_flete numeric
)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje public.viaje;
begin
  if p_origen_lat is null or p_origen_lng is null
     or p_destino_lat is null or p_destino_lng is null then
    raise exception 'El origen y el destino deben tener una ubicacion en el mapa.'
      using errcode = 'OR117';
  end if;

  -- viaje_crear valida el rol, el vehiculo, el conductor y el cliente.
  v_viaje := public.viaje_crear(
    p_remision, p_vehiculo_id, p_conductor_id, p_cliente_id, p_origen,
    p_destino, p_fecha_salida_programada, p_distancia_estimada,
    p_tiempo_estimado_min, p_peso_carga, p_valor_flete
  );

  update public.viaje
     set origen_lat = p_origen_lat,
         origen_lng = p_origen_lng,
         destino_lat = p_destino_lat,
         destino_lng = p_destino_lng,
         ruta_polilinea = nullif(btrim(p_ruta_polilinea), '')
   where id = v_viaje.id
   returning * into v_viaje;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_crear_v2(text, uuid, uuid, uuid, text, text, double precision, double precision, double precision, double precision, text, timestamptz, numeric, numeric, numeric, numeric) from public;
grant execute on function public.viaje_crear_v2(text, uuid, uuid, uuid, text, text, double precision, double precision, double precision, double precision, text, timestamptz, numeric, numeric, numeric, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- costo_acpm_estimado: la tarifa se busca por ciudad contenida en el nombre
-- del lugar. Antes el origen era texto libre escrito como "Medellín"; ahora
-- viene del mapa ("Terminal de carga, Medellín, Antioquia") y la igualdad
-- exacta nunca coincidiria. Misma firma y misma formula; solo cambia el
-- filtro (gana la ciudad mas especifica, luego la vigencia mas reciente).
-- ---------------------------------------------------------------------------
create or replace function public.costo_acpm_estimado(
  p_vehiculo_id uuid,
  p_distancia_km numeric,
  p_ciudad text,
  p_fecha date default current_date
)
returns numeric
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_rendimiento numeric;
  v_capacidad   numeric;
  v_precio      numeric;
  v_factor      numeric;
begin
  select rendimiento_km_galon, capacidad_carga
    into v_rendimiento, v_capacidad
    from public.vehiculo
   where id = p_vehiculo_id;

  if not found then
    raise exception 'El vehiculo no existe.' using errcode = 'OR108';
  end if;

  select precio_galon
    into v_precio
    from public.tarifa_combustible
   where position(lower(ciudad) in lower(p_ciudad)) > 0
     and fecha_vigencia_desde <= p_fecha
   order by length(ciudad) desc, fecha_vigencia_desde desc
   limit 1;

  if not found then
    raise exception 'No hay tarifa de combustible vigente para % en %.', p_ciudad, p_fecha
      using errcode = 'OR109';
  end if;

  v_factor := case
    when v_capacidad <= 17 then 1.0
    when v_capacidad <= 25 then 1.1
    else 1.2
  end;

  return round((p_distancia_km / v_rendimiento) * v_precio * v_factor, 2);
end;
$$;

-- ---------------------------------------------------------------------------
-- notificacion: tipos nuevos y ubicacion del evento
-- lat/lng son nullables: solo las alertas de parada/desvio llevan ubicacion
-- (el punto donde el telefono detecto la situacion, no un rastreo).
-- ---------------------------------------------------------------------------
alter table public.notificacion
  add column lat double precision check (lat between -90 and 90),
  add column lng double precision check (lng between -180 and 180),
  add constraint notificacion_ubicacion_completa
    check ((lat is null) = (lng is null));

alter table public.notificacion drop constraint if exists notificacion_tipo_check;
alter table public.notificacion
  add constraint notificacion_tipo_check check (tipo in (
    'DOCUMENTO_POR_VENCER', 'RETRASO', 'VIAJE_COMPLETADO',
    'PEAJE_REGISTRADO', 'NOVEDAD', 'PARADA_PROLONGADA', 'DESVIO_RUTA'
  ));

-- ---------------------------------------------------------------------------
-- viaje_registrar_alerta
--
-- Lo invoca el telefono del conductor cuando detecta una parada prolongada o
-- un desvio de ruta. Recibe un evento puntual (tipo + coordenada), nunca un
-- flujo de posiciones. Idempotente en una ventana de 60 minutos por viaje y
-- tipo, para que un conductor detenido no genere una alerta por reintento.
-- Devuelve true si creo la notificacion, false si ya existia una reciente.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_registrar_alerta(
  p_viaje_id uuid,
  p_tipo text,
  p_lat double precision,
  p_lng double precision,
  p_detalle text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje   public.viaje;
  v_titulo  text;
  v_mensaje text;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede registrar alertas.'
      using errcode = 'OR105';
  end if;

  if p_tipo not in ('PARADA_PROLONGADA', 'DESVIO_RUTA') then
    raise exception 'Tipo de alerta no valido.' using errcode = 'OR116';
  end if;

  if p_lat is null or p_lng is null
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'La ubicacion de la alerta no es valida.' using errcode = 'OR117';
  end if;

  select v.* into v_viaje
    from public.viaje v
    join public.conductor c on c.id = v.conductor_id
   where v.id = p_viaje_id
     and c.usuario_id = (select auth.uid());

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado <> 'EN_CURSO' then
    raise exception 'Solo se registran alertas en viajes en curso.' using errcode = 'OR118';
  end if;

  if exists (
    select 1 from public.notificacion n
     where n.viaje_id = p_viaje_id
       and n.tipo = p_tipo
       and n.fecha_creacion > now() - interval '60 minutes'
  ) then
    return false;
  end if;

  if p_tipo = 'PARADA_PROLONGADA' then
    v_titulo := 'Parada prolongada';
    v_mensaje := format(
      '%s → %s (viaje %s): el conductor lleva mucho tiempo detenido.',
      v_viaje.origen, v_viaje.destino, v_viaje.remision
    );
  else
    v_titulo := 'Desvío de ruta';
    v_mensaje := format(
      '%s → %s (viaje %s): el conductor se desvió de la ruta estimada.',
      v_viaje.origen, v_viaje.destino, v_viaje.remision
    );
  end if;

  if p_detalle is not null and btrim(p_detalle) <> '' then
    v_mensaje := v_mensaje || ' ' || left(btrim(p_detalle), 200);
  end if;

  insert into public.notificacion (tipo, titulo, mensaje, viaje_id, lat, lng)
  values (p_tipo, v_titulo, v_mensaje, p_viaje_id, p_lat, p_lng);

  return true;
end;
$$;

revoke all on function public.viaje_registrar_alerta(uuid, text, double precision, double precision, text) from public;
grant execute on function public.viaje_registrar_alerta(uuid, text, double precision, double precision, text) to authenticated;
