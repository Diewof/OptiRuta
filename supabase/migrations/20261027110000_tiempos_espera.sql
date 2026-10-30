-- Tiempos muertos en cargue y descargue (inteligencia de negocios, informe 3).
--
-- Decisiones del dueño (2026-10-27):
--   * Nuevo hito SALIDA_DESCARGUE, registrado por el conductor al terminar de
--     descargar. Espera de cargue = SALIDA_CON_CARGA - LLEGADA_CARGUE; espera de
--     descargue = SALIDA_DESCARGUE - LLEGADA_DESTINO.
--   * LLEGADA_DESTINO sigue dejando el viaje FINALIZADO (no cambia el ciclo de
--     vida): el hito de salida del descargue se registra con el viaje ya
--     FINALIZADO y es opcional; si no llega, esa espera no se mide.
--   * El sistema solo informa y alerta: no calcula ni cobra standby. Umbral de
--     alerta: 3 horas (c_umbral_h), solo aqui.

-- ---------------------------------------------------------------------------
-- hito_viaje: tipo nuevo
-- ---------------------------------------------------------------------------
alter table public.hito_viaje drop constraint if exists hito_viaje_tipo_check;
alter table public.hito_viaje
  add constraint hito_viaje_tipo_check check (tipo in (
    'SALIDA', 'LLEGADA_CARGUE', 'SALIDA_CON_CARGA', 'LLEGADA_DESTINO', 'SALIDA_DESCARGUE'
  ));

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
    'ESPERA_EXCESIVA'
  ));

-- ---------------------------------------------------------------------------
-- viaje_registrar_hito: acepta SALIDA_DESCARGUE con el viaje FINALIZADO. El
-- resto de hitos sigue exigiendo el viaje EN_CURSO (misma logica de antes).
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
  v_llegada   timestamptz;
  v_previo    text;
  v_hito      public.hito_viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor del viaje puede registrar hitos.' using errcode = 'OR105';
  end if;

  if p_tipo not in ('LLEGADA_CARGUE', 'SALIDA_CON_CARGA', 'LLEGADA_DESTINO', 'SALIDA_DESCARGUE') then
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

  if p_tipo = 'SALIDA_DESCARGUE' then
    if v_estado <> 'FINALIZADO' then
      raise exception 'La salida del descargue se registra al llegar a destino, antes de que el viaje se cierre.'
        using errcode = 'OR118';
    end if;
  elsif v_estado <> 'EN_CURSO' then
    raise exception 'Solo se registran hitos en un viaje en curso.' using errcode = 'OR118';
  end if;

  v_previo := case p_tipo
    when 'LLEGADA_CARGUE' then 'SALIDA'
    when 'SALIDA_CON_CARGA' then 'LLEGADA_CARGUE'
    when 'LLEGADA_DESTINO' then 'SALIDA_CON_CARGA'
    else 'LLEGADA_DESTINO'
  end;

  if not exists (select 1 from public.hito_viaje h where h.viaje_id = p_viaje_id and h.tipo = v_previo) then
    raise exception 'Primero registra el hito anterior.' using errcode = 'OR127';
  end if;

  if exists (select 1 from public.hito_viaje h where h.viaje_id = p_viaje_id and h.tipo = p_tipo) then
    raise exception 'Ese hito ya fue registrado.' using errcode = 'OR128';
  end if;

  select min(h.fecha_hora) filter (where h.tipo = 'SALIDA'),
         max(h.fecha_hora) filter (where h.tipo = 'LLEGADA_DESTINO')
    into v_salida, v_llegada
    from public.hito_viaje h where h.viaje_id = p_viaje_id;

  if p_fecha_hora is null or p_fecha_hora > now() + interval '5 minutes'
     or (v_salida is not null and p_fecha_hora < v_salida)
     or (p_tipo = 'SALIDA_DESCARGUE' and v_llegada is not null and p_fecha_hora < v_llegada) then
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
-- viaje_descargue_pendiente: el viaje FINALIZADO del conductor (ultimas 24 h)
-- al que aun le falta registrar la salida del descargue. La app lo usa para
-- ofrecer el boton cuando ya no hay viaje activo.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_descargue_pendiente()
returns table (
  viaje_id  uuid,
  destino   text,
  cliente   text,
  llegada   timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'CONDUCTOR' then
    raise exception 'Solo el conductor puede consultar sus descargues pendientes.' using errcode = 'OR105';
  end if;

  return query
    select v.id, v.destino, cl.nombre, ld.fecha_hora
      from public.viaje v
      join public.conductor c on c.id = v.conductor_id
      join public.cliente cl on cl.id = v.cliente_id
      cross join lateral (
        select max(h.fecha_hora) as fecha_hora
          from public.hito_viaje h
         where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO'
      ) ld
     where c.usuario_id = (select auth.uid())
       and v.estado = 'FINALIZADO'
       and ld.fecha_hora is not null
       and ld.fecha_hora > now() - interval '24 hours'
       and not exists (
         select 1 from public.hito_viaje h
          where h.viaje_id = v.id and h.tipo = 'SALIDA_DESCARGUE'
       )
     order by ld.fecha_hora desc
     limit 1;
end;
$$;

revoke all on function public.viaje_descargue_pendiente() from public;
grant execute on function public.viaje_descargue_pendiente() to authenticated;

-- ---------------------------------------------------------------------------
-- tiempos_espera: espera promedio de cargue y descargue por cliente. Solo
-- cuentan esperas completas (con hito de llegada y de salida).
-- ---------------------------------------------------------------------------
create or replace function public.tiempos_espera(
  p_desde date,
  p_hasta date,
  p_cliente_id uuid default null
)
returns table (
  cliente                  text,
  viajes                   integer,
  cargues_medidos          integer,
  espera_cargue_h          numeric,
  descargues_medidos       integer,
  espera_descargue_h       numeric,
  espera_total_h           numeric,
  espera_maxima_h          numeric,
  viajes_sobre_umbral      integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_umbral_h constant numeric := 3;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar los tiempos de espera.' using errcode = 'OR105';
  end if;
  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.' using errcode = 'OR107';
  end if;

  return query
    with h as (
      select v.id, cl.nombre as nom_cliente,
             max(x.fecha_hora) filter (where x.tipo = 'LLEGADA_CARGUE') as lc,
             max(x.fecha_hora) filter (where x.tipo = 'SALIDA_CON_CARGA') as sc,
             max(x.fecha_hora) filter (where x.tipo = 'LLEGADA_DESTINO') as ld,
             max(x.fecha_hora) filter (where x.tipo = 'SALIDA_DESCARGUE') as sd
        from public.viaje v
        join public.cliente cl on cl.id = v.cliente_id
        left join public.hito_viaje x on x.viaje_id = v.id
       where v.estado in ('FINALIZADO', 'CERRADO')
         and public.viaje_fecha_informe(v.id) between p_desde and p_hasta
         and (p_cliente_id is null or v.cliente_id = p_cliente_id)
       group by v.id, cl.nombre
    ), e as (
      select h.id, h.nom_cliente,
             case when h.lc is not null and h.sc is not null
                  then extract(epoch from (h.sc - h.lc)) / 3600 end as cargue,
             case when h.ld is not null and h.sd is not null
                  then extract(epoch from (h.sd - h.ld)) / 3600 end as descargue
        from h
    )
    select e.nom_cliente,
           count(*)::int,
           (count(e.cargue))::int,
           round(avg(e.cargue), 1),
           (count(e.descargue))::int,
           round(avg(e.descargue), 1),
           round(coalesce(sum(e.cargue), 0) + coalesce(sum(e.descargue), 0), 1),
           round(max(greatest(coalesce(e.cargue, 0), coalesce(e.descargue, 0))), 1),
           (count(*) filter (where e.cargue > c_umbral_h or e.descargue > c_umbral_h))::int
      from e
     group by e.nom_cliente
     order by coalesce(sum(e.cargue), 0) + coalesce(sum(e.descargue), 0) desc;
end;
$$;

revoke all on function public.tiempos_espera(date, date, uuid) from public;
grant execute on function public.tiempos_espera(date, date, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- espera_alertas_generar: job de pg_cron cada 30 min. Una notificacion por
-- viaje y etapa cuando la espera (terminada, o en curso en las ultimas 24 h)
-- supera el umbral. La clave evita repetirla.
-- ---------------------------------------------------------------------------
create or replace function public.espera_alertas_generar()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_umbral_h constant numeric := 3;
  v_n integer;
begin
  with h as (
    select v.id as viaje_id, v.vehiculo_id, v.remision, cl.nombre as nom_cliente,
           max(x.fecha_hora) filter (where x.tipo = 'LLEGADA_CARGUE') as lc,
           max(x.fecha_hora) filter (where x.tipo = 'SALIDA_CON_CARGA') as sc,
           max(x.fecha_hora) filter (where x.tipo = 'LLEGADA_DESTINO') as ld,
           max(x.fecha_hora) filter (where x.tipo = 'SALIDA_DESCARGUE') as sd
      from public.viaje v
      join public.cliente cl on cl.id = v.cliente_id
      join public.hito_viaje x on x.viaje_id = v.id
     where v.estado in ('EN_CURSO', 'FINALIZADO', 'CERRADO')
       and v.fecha_creacion > now() - interval '30 days'
     group by v.id, v.vehiculo_id, v.remision, cl.nombre
  ), e as (
    select h.viaje_id, h.vehiculo_id, h.remision, h.nom_cliente, 'CARGUE' as etapa, h.lc as ini, h.sc as fin
      from h where h.lc is not null
    union all
    select h.viaje_id, h.vehiculo_id, h.remision, h.nom_cliente, 'DESCARGUE', h.ld, h.sd
      from h where h.ld is not null
  )
  insert into public.notificacion (tipo, titulo, mensaje, viaje_id, vehiculo_id, clave)
  select 'ESPERA_EXCESIVA',
         'Espera excesiva en ' || lower(e.etapa) || ' · ' || e.nom_cliente,
         format('Remisión %s: %s h %s en %s.',
           e.remision,
           round(extract(epoch from (coalesce(e.fin, now()) - e.ini)) / 3600, 1),
           case when e.fin is null then 'esperando' else 'de espera' end,
           lower(e.etapa)),
         e.viaje_id, e.vehiculo_id,
         'ESP:' || e.viaje_id || ':' || e.etapa
    from e
   where extract(epoch from (coalesce(e.fin, now()) - e.ini)) / 3600 > c_umbral_h
     and (e.fin is not null or e.ini > now() - interval '24 hours')
     and not exists (
       select 1 from public.notificacion n
        where n.clave = 'ESP:' || e.viaje_id || ':' || e.etapa
     );
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.espera_alertas_generar() from public, anon, authenticated;

select cron.schedule(
  'espera-alertas',
  '*/30 * * * *',
  $$select public.espera_alertas_generar();$$
);
