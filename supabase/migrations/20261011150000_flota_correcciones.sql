-- Correcciones de flota tras las primeras pruebas con datos demo:
--
--  1. El odometro daba 0: los viajes anteriores a la medicion por GPS no tienen
--     km_recorridos. Se usa distancia_estimada cuando falta (derivado, sin
--     tocar viajes CERRADO, que no se editan).
--  2. El documento vigente era el de mayor vencimiento, asi que registrar un
--     vencimiento MENOR (corregir un error o un vencimiento real mas corto) no
--     tenia efecto: se seguia viendo el anterior, y ni la alerta ni el bloqueo
--     lo veian. Ahora el vigente es el ultimo registrado.
--  3. La alerta de vencimiento esperaba al cron (hasta 30 min). Registrar un
--     documento pasa ahora por una RPC que genera las alertas al instante.

-- ---------------------------------------------------------------------------
-- 1. Odometro y hoja de vida con km estimados cuando no hay medicion
-- ---------------------------------------------------------------------------
create or replace function public.vehiculo_odometro_km(p_vehiculo_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select v.odometro_inicial_km + coalesce((
    select sum(coalesce(t.km_recorridos, t.distancia_estimada))
      from public.viaje t
     where t.vehiculo_id = v.id
       and t.estado in ('FINALIZADO', 'CERRADO')
  ), 0)
  from public.vehiculo v
  where v.id = p_vehiculo_id;
$$;

revoke all on function public.vehiculo_odometro_km(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Documento vigente = el ultimo registrado
-- ---------------------------------------------------------------------------
-- Dos registros del mismo vencimiento ya no son un error (volver a un valor
-- anterior es una correccion valida).
alter table public.documento_vehiculo
  drop constraint if exists documento_vehiculo_unico_vencimiento;

create or replace view public.documento_vehiculo_vigente
with (security_invoker = true) as
select distinct on (d.vehiculo_id, d.tipo)
  d.id,
  d.vehiculo_id,
  d.tipo,
  d.numero,
  d.entidad_emisora,
  d.fecha_expedicion,
  d.fecha_vencimiento,
  d.fecha_vencimiento - public.hoy_bogota() as dias_restantes,
  case
    when d.fecha_vencimiento < public.hoy_bogota() then 'VENCIDO'
    when d.fecha_vencimiento <= public.hoy_bogota() + 30 then 'POR_VENCER'
    else 'VIGENTE'
  end as estado
from public.documento_vehiculo d
order by d.vehiculo_id, d.tipo, d.fecha_creacion desc, d.fecha_vencimiento desc;

create or replace function public.vehiculo_validar_documentos(p_vehiculo_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tipo      text;
  v_nombre    text;
  v_vence     date;
  v_problemas text[] := '{}';
begin
  foreach v_tipo in array array['SOAT', 'TECNOMECANICA'] loop
    v_nombre := case v_tipo when 'SOAT' then 'SOAT' else 'la revisión técnico-mecánica' end;

    select d.fecha_vencimiento into v_vence
      from public.documento_vehiculo d
     where d.vehiculo_id = p_vehiculo_id and d.tipo = v_tipo
     order by d.fecha_creacion desc, d.fecha_vencimiento desc
     limit 1;

    if v_vence is null then
      v_problemas := v_problemas || format('no hay %s registrado', v_nombre);
    elsif v_vence < public.hoy_bogota() then
      v_problemas := v_problemas || format('%s venció el %s', v_nombre, to_char(v_vence, 'DD/MM/YYYY'));
    end if;
  end loop;

  if array_length(v_problemas, 1) > 0 then
    raise exception 'No se puede comenzar el viaje: %.', array_to_string(v_problemas, ' y ')
      using errcode = 'OR132';
  end if;
end;
$$;

revoke all on function public.vehiculo_validar_documentos(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Registrar un documento y avisar al instante
-- ---------------------------------------------------------------------------
create or replace function public.documento_vehiculo_registrar(
  p_vehiculo_id uuid,
  p_tipo text,
  p_fecha_vencimiento date,
  p_numero text default null,
  p_entidad_emisora text default null,
  p_fecha_expedicion date default null
)
returns public.documento_vehiculo
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fila public.documento_vehiculo;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede registrar documentos.' using errcode = 'OR105';
  end if;

  if not exists (select 1 from public.vehiculo where id = p_vehiculo_id) then
    raise exception 'El vehículo no existe.' using errcode = 'OR111';
  end if;

  if p_tipo not in ('SOAT', 'TECNOMECANICA') or p_fecha_vencimiento is null
     or (p_fecha_expedicion is not null and p_fecha_expedicion > p_fecha_vencimiento) then
    raise exception 'Los datos del documento no son válidos.' using errcode = 'OR140';
  end if;

  insert into public.documento_vehiculo
    (vehiculo_id, tipo, fecha_vencimiento, numero, entidad_emisora, fecha_expedicion)
  values
    (p_vehiculo_id, p_tipo, p_fecha_vencimiento,
     nullif(btrim(coalesce(p_numero, '')), ''),
     nullif(btrim(coalesce(p_entidad_emisora, '')), ''),
     p_fecha_expedicion)
  returning * into v_fila;

  -- Sin esperar al cron de 30 minutos.
  perform public.notificacion_generar();

  return v_fila;
end;
$$;

revoke all on function public.documento_vehiculo_registrar(uuid, text, date, text, text, date) from public;
grant execute on function public.documento_vehiculo_registrar(uuid, text, date, text, text, date) to authenticated;

-- La linea de tiempo tambien muestra los km estimados cuando no hay medicion.
create or replace function public.vehiculo_hoja_vida(p_vehiculo_id uuid, p_limite integer default 100)
returns table (
  fecha    timestamptz,
  tipo     text,
  titulo   text,
  detalle  text,
  km       numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede consultar la hoja de vida.' using errcode = 'OR105';
  end if;

  return query
    select x.fecha, x.tipo, x.titulo, x.detalle, x.km
      from (
        select coalesce(
                 (select max(h.fecha_hora) from public.hito_viaje h
                   where h.viaje_id = v.id and h.tipo = 'LLEGADA_DESTINO'),
                 v.fecha_creacion) as fecha,
               'VIAJE'::text as tipo,
               format('Viaje %s: %s → %s', v.remision, v.origen, v.destino) as titulo,
               case when coalesce(v.km_recorridos, v.distancia_estimada) is null then null
                    else format('%s km (%s)', round(coalesce(v.km_recorridos, v.distancia_estimada)),
                                case v.km_origen when 'GPS' then 'medido por GPS' else 'estimado' end)
               end as detalle,
               coalesce(v.km_recorridos, v.distancia_estimada) as km
          from public.viaje v
         where v.vehiculo_id = p_vehiculo_id and v.estado in ('FINALIZADO', 'CERRADO')
        union all
        select (m.fecha::timestamp at time zone 'America/Bogota'),
               'MANTENIMIENTO',
               m.tipo,
               nullif(concat_ws(' · ', initcap(lower(m.categoria)), m.taller, m.descripcion), ''),
               m.kilometraje
          from public.mantenimiento_vehiculo m
         where m.vehiculo_id = p_vehiculo_id
        union all
        select k.fecha_hora,
               'CHECKLIST',
               'Checklist pre-viaje: ' || case k.resultado
                 when 'APROBADO' then 'aprobado'
                 when 'CON_OBSERVACIONES' then 'con observaciones'
                 else 'bloqueado' end,
               coalesce((
                 select string_agg(i.nombre, ', ' order by i.orden)
                   from public.checklist_respuesta r
                   join public.checklist_item i on i.id = r.item_id
                  where r.checklist_id = k.id and r.estado = 'FALLA'
               ), 'Sin fallas'),
               null
          from public.checklist_viaje k
         where k.vehiculo_id = p_vehiculo_id
        union all
        select d.fecha_creacion,
               'DOCUMENTO',
               case d.tipo when 'SOAT' then 'SOAT registrado' else 'Revisión técnico-mecánica registrada' end,
               'Vence el ' || to_char(d.fecha_vencimiento, 'DD/MM/YYYY'),
               null
          from public.documento_vehiculo d
         where d.vehiculo_id = p_vehiculo_id
      ) x
     order by x.fecha desc
     limit greatest(1, least(coalesce(p_limite, 100), 500));
end;
$$;

revoke all on function public.vehiculo_hoja_vida(uuid, integer) from public;
grant execute on function public.vehiculo_hoja_vida(uuid, integer) to authenticated;
