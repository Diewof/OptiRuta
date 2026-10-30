-- Datos de referencia para ver la calidad del viaje funcionando.
-- NO es una migracion ni forma parte de seed.sql: se corre a mano (una vez)
-- despues de aplicar 20261014100000_calidad_viaje.sql y se retira con
-- supabase/datos-referencia-calidad-limpiar.sql.
--
-- Crea 6 viajes FINALIZADOS (remision DEMO-CAL-1..6) con el primer conductor y
-- el primer vehiculo activos, y un cliente «Cliente Demo Calidad» SIN correo
-- (asi la encuesta nace SIN_CONTACTO y no se envia ningun correo real).
--
--   DEMO-CAL-1/2/3  ruta Demo Origen → Demo Destino: 3 h tarde y costos +50 %
--                   (puntualidad y rentabilidad rojas)  => disparan la alerta
--                   recurrente (retrasos y sobrecostos) por ruta, conductor y placa
--   DEMO-CAL-4      a tiempo y costos iguales a lo estimado => Conforme
--   DEMO-CAL-5      +20 min de retraso y costos +17 %         => Con mejoras
--   DEMO-CAL-6      a tiempo, costos exactos, 3 desvios de ruta
--                   (incidencias rojas)                      => Con mejoras
--
-- Idempotente: si DEMO-CAL-1 ya existe no hace nada.

do $$
declare
  v_veh   uuid;
  v_cond  uuid;
  v_cli   uuid;
  v_id    uuid;
  v_n     integer;
  -- n, minutos reales, acpm real, desvios en ruta
  v_caso  record;
begin
  if exists (select 1 from public.viaje where remision = 'DEMO-CAL-1') then
    raise notice 'Los datos de referencia de calidad ya existen; no se hace nada.';
    return;
  end if;

  select id into v_veh from public.vehiculo where activo order by fecha_creacion limit 1;
  select id into v_cond from public.conductor where activo order by fecha_creacion limit 1;
  if v_veh is null or v_cond is null then
    raise exception 'Se necesita al menos un vehiculo y un conductor activos.';
  end if;

  select id into v_cli from public.cliente where nombre = 'Cliente Demo Calidad';
  if v_cli is null then
    insert into public.cliente (nombre, correo, activo)
    values ('Cliente Demo Calidad', null, true)
    returning id into v_cli;
  end if;

  for v_caso in
    select * from (values
      (1, 240, 160000, 0),
      (2, 240, 160000, 0),
      (3, 240, 160000, 0),
      (4,  55, 100000, 0),
      (5,  80, 120000, 0),
      (6,  58, 100000, 3)
    ) as t(n, minutos, acpm_real, desvios)
  loop
    insert into public.viaje (
      remision, vehiculo_id, conductor_id, cliente_id, origen, destino,
      distancia_estimada, tiempo_estimado_min, valor_flete, estado
    )
    values (
      'DEMO-CAL-' || v_caso.n, v_veh, v_cond, v_cli, 'Demo Origen', 'Demo Destino',
      300, 60, 1000000, 'ASIGNADO'
    )
    returning id into v_id;

    -- Estimado 100.000 de ACPM y 20.000 de peajes; el real solo cambia el ACPM.
    insert into public.costo_viaje (viaje_id, categoria, valor_estimado, valor_real, fuente)
    values
      (v_id, 'ACPM', 100000, v_caso.acpm_real, 'AUTOMATICO'),
      (v_id, 'PEAJE', 20000, 20000, 'MANUAL');

    update public.viaje set estado = 'EN_CURSO' where id = v_id;

    insert into public.hito_viaje (viaje_id, tipo, fecha_hora)
    values
      (v_id, 'SALIDA', now() - make_interval(mins => v_caso.minutos + 30)),
      (v_id, 'LLEGADA_DESTINO', now() - interval '30 minutes');

    for v_n in 1..v_caso.desvios loop
      insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
      values ('DESVIO_RUTA', 'Desvío de ruta', 'Dato de referencia: se desvió de la ruta planificada.', v_id);
    end loop;

    update public.viaje set estado = 'FINALIZADO' where id = v_id;
  end loop;

  -- Genera ya las alertas recurrentes (el job lo hace una vez al dia).
  perform public.calidad_alertas_generar();
end;
$$;
