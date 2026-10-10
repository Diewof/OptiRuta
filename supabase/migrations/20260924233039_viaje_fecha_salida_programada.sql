-- Agrega la fecha/hora de salida planeada al agendar un viaje. La tabla
-- `viaje` solo tenia `fecha_creacion` (auditoria: cuando se inserto la fila)
-- y los hitos reales que registra el conductor; ninguna de las dos sirve
-- para que Calendario/Agendar viaje muestren o capturen una fecha de salida
-- programada por el administrador (decision confirmada con el usuario).
--
-- Nullable: los viajes creados antes de esta columna (seed histórico) no la
-- tienen; viaje_crear la vuelve obligatoria de aqui en adelante.

alter table public.viaje add column fecha_salida_programada timestamptz;

comment on column public.viaje.fecha_salida_programada is
  'Fecha/hora de salida planeada por el administrador al agendar el viaje. '
  'Distinta de fecha_creacion (auditoria) y de los hitos reales del conductor.';

create index viaje_fecha_salida_programada_idx
  on public.viaje (fecha_salida_programada);

-- ---------------------------------------------------------------------------
-- viaje_crear: se recrea con el nuevo parametro obligatorio
-- p_fecha_salida_programada. Cambia la firma (se agrega un parametro), asi
-- que hay que dropear la version anterior antes del create or replace.
-- ---------------------------------------------------------------------------
drop function if exists public.viaje_crear(text, uuid, uuid, uuid, text, text, numeric, numeric, numeric, numeric);

create or replace function public.viaje_crear(
  p_remision text,
  p_vehiculo_id uuid,
  p_conductor_id uuid,
  p_cliente_id uuid,
  p_origen text,
  p_destino text,
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
  v_vehiculo_activo   boolean;
  v_conductor_activo  boolean;
  v_porcentaje_comision numeric;
  v_acpm_estimado     numeric;
  v_viaje             public.viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede crear un viaje.'
      using errcode = 'OR105';
  end if;

  select activo into v_vehiculo_activo from public.vehiculo where id = p_vehiculo_id;
  if not found or not v_vehiculo_activo then
    raise exception 'El vehiculo no existe o esta inactivo.' using errcode = 'OR111';
  end if;

  select activo, porcentaje_comision
    into v_conductor_activo, v_porcentaje_comision
    from public.conductor
   where id = p_conductor_id;
  if not found or not v_conductor_activo then
    raise exception 'El conductor no existe o esta inactivo.' using errcode = 'OR112';
  end if;

  if not exists (select 1 from public.cliente where id = p_cliente_id) then
    raise exception 'El cliente no existe.' using errcode = 'OR113';
  end if;

  if exists (
    select 1 from public.viaje
     where vehiculo_id = p_vehiculo_id
       and estado in ('ASIGNADO', 'EN_CURSO')
  ) then
    raise exception 'El vehiculo ya tiene un viaje asignado o en curso.' using errcode = 'OR114';
  end if;

  begin
    v_acpm_estimado := public.costo_acpm_estimado(p_vehiculo_id, p_distancia_estimada, btrim(p_origen));
  exception when others then
    v_acpm_estimado := 0;
  end;

  insert into public.viaje (
    remision, vehiculo_id, conductor_id, cliente_id, origen, destino,
    fecha_salida_programada, distancia_estimada, tiempo_estimado_min, peso_carga,
    estado, valor_flete
  )
  values (
    p_remision, p_vehiculo_id, p_conductor_id, p_cliente_id, p_origen, p_destino,
    p_fecha_salida_programada, p_distancia_estimada, p_tiempo_estimado_min, p_peso_carga,
    'PLANIFICADO', p_valor_flete
  )
  returning * into v_viaje;

  insert into public.costo_viaje (viaje_id, categoria, valor_estimado, fuente)
  values
    (v_viaje.id, 'ACPM', v_acpm_estimado, 'AUTOMATICO'),
    (v_viaje.id, 'COMISION', round(p_valor_flete * v_porcentaje_comision / 100, 2), 'AUTOMATICO'),
    (v_viaje.id, 'PEAJE', 0, 'MANUAL'),
    (v_viaje.id, 'CARGUE', 0, 'MANUAL'),
    (v_viaje.id, 'DESCARGUE', 0, 'MANUAL'),
    (v_viaje.id, 'PARQUEADERO', 0, 'MANUAL'),
    (v_viaje.id, 'ACEITE', 0, 'MANUAL'),
    (v_viaje.id, 'LAVADO', 0, 'MANUAL'),
    (v_viaje.id, 'ENGRASE', 0, 'MANUAL'),
    (v_viaje.id, 'OTRO', 0, 'MANUAL');

  return v_viaje;
end;
$$;

revoke all on function public.viaje_crear(text, uuid, uuid, uuid, text, text, timestamptz, numeric, numeric, numeric, numeric) from public;
grant execute on function public.viaje_crear(text, uuid, uuid, uuid, text, text, timestamptz, numeric, numeric, numeric, numeric) to authenticated;
