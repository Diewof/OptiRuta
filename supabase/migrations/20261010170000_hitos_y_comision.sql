-- Revision de requisitos (RF-15, RF-18): hitos validados en el servidor y
-- comision solo para conductores que la cobran.

-- ---------------------------------------------------------------------------
-- RF-18: viaje_registrar_hito
--
-- Antes el conductor insertaba hitos directo en la tabla: sin validar el
-- orden, con duplicados posibles, y nada pasaba el viaje a FINALIZADO al
-- llegar a destino (el administrador no podia cerrarlo). Ahora:
--   * el viaje debe ser propio y estar EN_CURSO;
--   * orden: SALIDA (viaje_iniciar) -> LLEGADA_CARGUE -> SALIDA_CON_CARGA ->
--     LLEGADA_DESTINO, sin repetir;
--   * la hora no puede ser anterior a la salida ni futura (margen 5 min);
--   * LLEGADA_DESTINO deja el viaje FINALIZADO.
-- ---------------------------------------------------------------------------
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
    update public.viaje set estado = 'FINALIZADO' where id = p_viaje_id;
  end if;

  return v_hito;
end;
$$;

revoke all on function public.viaje_registrar_hito(uuid, text, timestamptz) from public;
grant execute on function public.viaje_registrar_hito(uuid, text, timestamptz) to authenticated;

-- El conductor ya no inserta hitos directo: todo pasa por las RPC.
drop policy if exists hito_viaje_insert_conductor_propio on public.hito_viaje;
revoke insert on public.hito_viaje from authenticated;

-- Viajes que ya tienen LLEGADA_DESTINO pero quedaron EN_CURSO por el defecto
-- anterior: pasan a FINALIZADO para que el administrador pueda cerrarlos.
update public.viaje v
   set estado = 'FINALIZADO'
 where v.estado = 'EN_CURSO'
   and exists (select 1 from public.hito_viaje h where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO');

-- ---------------------------------------------------------------------------
-- RF-15: un conductor con pago FIJO no genera comision en el viaje (cobra solo
-- el sueldo fijo prorrateado); antes se le calculaba el porcentaje guardado
-- (por defecto 10) y se duplicaba el costo. Misma firma.
-- ---------------------------------------------------------------------------
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
  v_sin_tarifa        boolean := false;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede crear un viaje.'
      using errcode = 'OR105';
  end if;

  select activo into v_vehiculo_activo from public.vehiculo where id = p_vehiculo_id;
  if not found or not v_vehiculo_activo then
    raise exception 'El vehiculo no existe o esta inactivo.' using errcode = 'OR111';
  end if;

  select activo,
         case when tipo_pago = 'FIJO' then 0 else porcentaje_comision end
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
    v_sin_tarifa := true;
  end;

  insert into public.viaje (
    remision, vehiculo_id, conductor_id, cliente_id, origen, destino,
    fecha_salida_programada, distancia_estimada, tiempo_estimado_min, peso_carga,
    estado, valor_flete
  )
  values (
    p_remision, p_vehiculo_id, p_conductor_id, p_cliente_id, p_origen, p_destino,
    p_fecha_salida_programada, p_distancia_estimada, p_tiempo_estimado_min, p_peso_carga,
    'ASIGNADO', p_valor_flete
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

  -- RF-11: sin tarifa de ACPM el estimado queda en 0; se avisa al admin en vez
  -- de dejarlo pasar en silencio.
  if v_sin_tarifa then
    insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
    values (
      'NOVEDAD',
      'Sin tarifa de ACPM',
      format(
        'El viaje %s (%s → %s) quedo con ACPM estimado en $0: no hay tarifa de combustible vigente para el origen. Registrela en Tarifas de ACPM.',
        p_remision, p_origen, p_destino
      ),
      v_viaje.id
    );
  end if;

  return v_viaje;
end;
$$;


-- ---------------------------------------------------------------------------
-- RF-04: actualizar un viaje. Antes solo se podian corregir costos; ahora el
-- administrador edita fecha de salida, peso y flete de un viaje no cerrado ni
-- cancelado. Si cambia el flete, se recalcula la comision ESTIMADA (la ya
-- confirmada como real no se toca). Origen, destino, vehiculo y conductor no
-- se editan: cambiarlos invalida ruta y ACPM; se cancela y se crea de nuevo.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_actualizar(
  p_viaje_id uuid,
  p_fecha_salida_programada timestamptz,
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
  v_pct   numeric;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede editar un viaje.' using errcode = 'OR105';
  end if;

  if p_valor_flete is null or p_valor_flete <= 0 then
    raise exception 'El valor del flete debe ser mayor a 0.' using errcode = 'OR130';
  end if;

  if p_peso_carga is not null and p_peso_carga < 0 then
    raise exception 'El peso de la carga no puede ser negativo.' using errcode = 'OR131';
  end if;

  select * into v_viaje from public.viaje where id = p_viaje_id for update;
  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  -- El trigger viaje_validar_transicion rechaza cerrados y cancelados.
  update public.viaje
     set fecha_salida_programada = p_fecha_salida_programada,
         peso_carga = p_peso_carga,
         valor_flete = p_valor_flete
   where id = p_viaje_id
   returning * into v_viaje;

  select case when c.tipo_pago = 'FIJO' then 0 else c.porcentaje_comision end
    into v_pct
    from public.conductor c where c.id = v_viaje.conductor_id;

  update public.costo_viaje
     set valor_estimado = round(p_valor_flete * coalesce(v_pct, 0) / 100, 2)
   where viaje_id = p_viaje_id
     and categoria = 'COMISION'
     and valor_real is null;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_actualizar(uuid, timestamptz, numeric, numeric) from public;
grant execute on function public.viaje_actualizar(uuid, timestamptz, numeric, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- RF-01: el rol efectivo es el de app_metadata (JWT); editar usuario.rol desde
-- la app lo desincronizaba. Se quita rol del UPDATE permitido.
-- ---------------------------------------------------------------------------
revoke update on public.usuario from authenticated;
grant update (nombre, activo) on public.usuario to authenticated;
