-- Comenzar un viaje exige estar a 500 m o menos del punto de inicio.
--
-- La posicion del telefono viaja UNA sola vez, como parametro de esta RPC
-- (evento puntual, igual que viaje_registrar_alerta): no se guarda en ninguna
-- tabla. Hasta ahora registrar el hito SALIDA era un INSERT directo y nada
-- pasaba el viaje a EN_CURSO; viaje_iniciar hace las dos cosas en una
-- transaccion y la politica de INSERT deja de aceptar SALIDA directo, para
-- que la regla no se pueda saltar desde el cliente.
--
-- Viajes sin coordenadas de origen (anteriores a los mapas) no tienen contra
-- que medir: se inician sin validacion de distancia.

create or replace function public.viaje_iniciar(
  p_viaje_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_fecha_hora timestamptz default now()
)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_radio_max_m constant numeric := 500;
  v_viaje       public.viaje;
  v_distancia_m numeric;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede comenzarlo.'
      using errcode = 'OR105';
  end if;

  if p_lat is null or p_lng is null
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'No se pudo leer tu ubicacion. Activa el GPS e intenta de nuevo.'
      using errcode = 'OR117';
  end if;

  select v.* into v_viaje
    from public.viaje v
    join public.conductor c on c.id = v.conductor_id
   where v.id = p_viaje_id
     and c.usuario_id = (select auth.uid())
   for update of v;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_viaje.estado <> 'ASIGNADO' then
    raise exception 'Solo se puede comenzar un viaje asignado.' using errcode = 'OR119';
  end if;

  if v_viaje.origen_lat is not null then
    -- Haversine, radio terrestre 6371000 m.
    v_distancia_m := 2 * 6371000 * asin(sqrt(
      power(sin(radians(p_lat - v_viaje.origen_lat) / 2), 2)
      + cos(radians(v_viaje.origen_lat)) * cos(radians(p_lat))
        * power(sin(radians(p_lng - v_viaje.origen_lng) / 2), 2)
    ));

    if v_distancia_m > c_radio_max_m then
      raise exception
        'Debes estar a menos de % m del punto de inicio para comenzar el viaje (estas a % m).',
        c_radio_max_m, round(v_distancia_m)
        using errcode = 'OR120';
    end if;
  end if;

  insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
  values (p_viaje_id, 'SALIDA', p_fecha_hora);

  update public.viaje
     set estado = 'EN_CURSO'
   where id = p_viaje_id
   returning * into v_viaje;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_iniciar(uuid, double precision, double precision, timestamptz) from public;
grant execute on function public.viaje_iniciar(uuid, double precision, double precision, timestamptz) to authenticated;

-- El conductor ya no inserta SALIDA directo: pasa por viaje_iniciar.
drop policy hito_viaje_insert_conductor_propio on public.hito_viaje;

create policy hito_viaje_insert_conductor_propio
  on public.hito_viaje
  for insert
  to authenticated
  with check (
    tipo <> 'SALIDA'
    and exists (
      select 1 from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      where v.id = hito_viaje.viaje_id
        and c.usuario_id = (select auth.uid())
    )
  );
