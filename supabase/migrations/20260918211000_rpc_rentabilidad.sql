-- RPC de rentabilidad: marginal (por viaje) y consolidada (por periodo).
-- Estrategia de dos funciones separadas, no un motor generico (patron
-- Strategy permitido solo aqui segun CLAUDE.md).

-- ---------------------------------------------------------------------------
-- rentabilidad_marginal(p_viaje_id)
--
-- valor_flete - (ACPM + PEAJE + CARGUE + DESCARGUE + PARQUEADERO + COMISION +
-- ACEITE + LAVADO + ENGRASE + OTRO). MANTENIMIENTO_AMORTIZADO queda fuera
-- (diseno-base-de-datos-optiruta.md seccion 2.3). Usa el valor real cuando ya
-- fue confirmado por el conductor; si no, el estimado.
--
-- Administrador: cualquier viaje. Conductor: solo el suyo.
-- ---------------------------------------------------------------------------
create or replace function public.rentabilidad_marginal(p_viaje_id uuid)
returns table (
  valor_flete       numeric,
  costos_totales    numeric,
  rentabilidad      numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rol       text := (auth.jwt() -> 'app_metadata' ->> 'rol');
  v_es_propio boolean;
  v_flete     numeric;
begin
  select v.valor_flete, exists (
           select 1 from public.conductor c
           where c.id = v.conductor_id and c.usuario_id = (select auth.uid())
         )
    into v_flete, v_es_propio
    from public.viaje v
   where v.id = p_viaje_id;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_rol <> 'ADMINISTRADOR' and not (v_rol = 'CONDUCTOR' and v_es_propio) then
    raise exception 'No autorizado para consultar la rentabilidad de este viaje.'
      using errcode = 'OR105';
  end if;

  return query
    select
      v_flete,
      coalesce(sum(coalesce(cv.valor_real, cv.valor_estimado)), 0),
      v_flete - coalesce(sum(coalesce(cv.valor_real, cv.valor_estimado)), 0)
    from public.costo_viaje cv
    where cv.viaje_id = p_viaje_id
      and cv.categoria <> 'MANTENIMIENTO_AMORTIZADO';
end;
$$;

revoke all on function public.rentabilidad_marginal(uuid) from public;
grant execute on function public.rentabilidad_marginal(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- rentabilidad_consolidada(p_desde, p_hasta)
--
-- Suma la rentabilidad marginal de los viajes CERRADO cuyo fecha_cierre cae
-- en el periodo, y le resta MANTENIMIENTO_AMORTIZADO del periodo mas el
-- sueldo fijo de los conductores FIJO/MIXTO prorrateado sobre los dias del
-- periodo (base de 30 dias por mes, mismo criterio que la nomina mensual).
-- Solo administrador: es informacion financiera agregada de toda la flota.
-- ---------------------------------------------------------------------------
create or replace function public.rentabilidad_consolidada(p_desde date, p_hasta date)
returns table (
  total_flete               numeric,
  total_costos_directos     numeric,
  mantenimiento_amortizado  numeric,
  sueldo_fijo_prorrateado   numeric,
  rentabilidad_consolidada  numeric,
  viajes_incluidos          integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dias numeric;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la rentabilidad consolidada.'
      using errcode = 'OR105';
  end if;

  if p_desde > p_hasta then
    raise exception 'El rango de fechas es invalido: p_desde debe ser menor o igual a p_hasta.'
      using errcode = 'OR107';
  end if;

  v_dias := (p_hasta - p_desde) + 1;

  return query
    with viajes_periodo as (
      select v.id, v.valor_flete
      from public.viaje v
      where v.estado = 'CERRADO'
        and v.fecha_cierre::date between p_desde and p_hasta
    )
    select
      (select coalesce(sum(vp.valor_flete), 0) from viajes_periodo vp),
      (select coalesce(sum(coalesce(cv.valor_real, cv.valor_estimado)), 0)
         from public.costo_viaje cv
         join viajes_periodo vp on vp.id = cv.viaje_id
        where cv.categoria <> 'MANTENIMIENTO_AMORTIZADO'),
      (select coalesce(sum(mv.costo), 0)
         from public.mantenimiento_vehiculo mv
        where mv.fecha between p_desde and p_hasta),
      (select coalesce(sum(c.sueldo_base * (v_dias / 30.0)), 0)
         from public.conductor c
        where c.activo and c.tipo_pago in ('FIJO', 'MIXTO')),
      (select coalesce(sum(vp.valor_flete), 0) from viajes_periodo vp)
        - (select coalesce(sum(coalesce(cv.valor_real, cv.valor_estimado)), 0)
             from public.costo_viaje cv
             join viajes_periodo vp on vp.id = cv.viaje_id
            where cv.categoria <> 'MANTENIMIENTO_AMORTIZADO')
        - (select coalesce(sum(mv.costo), 0)
             from public.mantenimiento_vehiculo mv
            where mv.fecha between p_desde and p_hasta)
        - (select coalesce(sum(c.sueldo_base * (v_dias / 30.0)), 0)
             from public.conductor c
            where c.activo and c.tipo_pago in ('FIJO', 'MIXTO')),
      (select count(*)::int from viajes_periodo);
end;
$$;

revoke all on function public.rentabilidad_consolidada(date, date) from public;
grant execute on function public.rentabilidad_consolidada(date, date) to authenticated;
