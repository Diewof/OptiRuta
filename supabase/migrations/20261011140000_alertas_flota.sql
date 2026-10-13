-- Fase 5: alertas de flota en notificacion_generar().
--
-- Cambios sobre la version de 20261010130000_cierre_brechas_requisitos.sql:
--   * documentos: se evalua solo el documento VIGENTE de cada vehiculo y tipo
--     (el mas reciente) y la alerta se deduplica por documento y escalon, no
--     por vehiculo (antes un SOAT por vencer tapaba el aviso de la
--     tecnomecanica). Escalones: 30 dias, 7 dias y vencido.
--   * mantenimiento preventivo: PROXIMO y VENCIDO por plan; la clave incluye
--     la fecha del ultimo mantenimiento, asi la alerta se rearma al servir.
--   * RETRASO, VIAJE_COMPLETADO y PEAJE_REGISTRADO: sin cambios.

create or replace function public.notificacion_generar()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Documentos a 30 dias (31..8) y a 7 dias (7..0): una alerta por documento y escalon.
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, clave)
  select
    'DOCUMENTO_POR_VENCER',
    'Documento por vencer',
    format(
      'El %s de %s vence %s (%s).',
      case dv.tipo when 'SOAT' then 'SOAT' else 'la revisión técnico-mecánica' end,
      v.placa,
      case dv.dias_restantes when 0 then 'hoy' when 1 then 'mañana' else 'en ' || dv.dias_restantes || ' días' end,
      to_char(dv.fecha_vencimiento, 'DD/MM/YYYY')
    ),
    v.id,
    'DOC:' || dv.id || ':' || case when dv.dias_restantes <= 7 then '7' else '30' end
  from public.documento_vehiculo_vigente dv
  join public.vehiculo v on v.id = dv.vehiculo_id and v.activo
  where dv.dias_restantes between 0 and 30
    and not exists (
      select 1 from public.notificacion n
      where n.clave = 'DOC:' || dv.id || ':' || case when dv.dias_restantes <= 7 then '7' else '30' end
    );

  -- Documentos vencidos: una sola vez por documento.
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, clave)
  select
    'DOCUMENTO_VENCIDO',
    'Documento vencido',
    format(
      '%s de %s venció el %s. El vehículo no puede comenzar viajes hasta renovarlo.',
      case dv.tipo when 'SOAT' then 'El SOAT' else 'La revisión técnico-mecánica' end,
      v.placa,
      to_char(dv.fecha_vencimiento, 'DD/MM/YYYY')
    ),
    v.id,
    'DOC:' || dv.id || ':0'
  from public.documento_vehiculo_vigente dv
  join public.vehiculo v on v.id = dv.vehiculo_id and v.activo
  where dv.dias_restantes < 0
    and not exists (
      select 1 from public.notificacion n where n.clave = 'DOC:' || dv.id || ':0'
    );

  -- Mantenimiento preventivo proximo o vencido, por plan.
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id, clave)
  select
    case p.estado when 'VENCIDO' then 'MANTENIMIENTO_VENCIDO' else 'MANTENIMIENTO_PROXIMO' end,
    case p.estado when 'VENCIDO' then 'Mantenimiento vencido' else 'Mantenimiento próximo' end,
    format(
      '%s de %s: %s.',
      p.tipo_nombre,
      p.placa,
      array_to_string(array[
        case when p.km_restantes is null then null
             when p.km_restantes <= 0
               then 'excedido por ' || replace(to_char(abs(p.km_restantes), 'FM999,999,999'), ',', '.') || ' km'
             else 'faltan ' || replace(to_char(p.km_restantes, 'FM999,999,999'), ',', '.') || ' km' end,
        case when p.dias_restantes is null then null
             when p.dias_restantes <= 0 then 'excedido por ' || abs(p.dias_restantes) || ' días'
             else 'faltan ' || p.dias_restantes || ' días' end
      ], ' / ')
    ),
    p.vehiculo_id,
    'MANT:' || p.plan_id || ':' || p.estado || ':' || coalesce(p.ultimo_fecha::text, 'base')
  from public.plan_mantenimiento_calculo() p
  where p.estado in ('PROXIMO', 'VENCIDO')
    and not exists (
      select 1 from public.notificacion n
      where n.clave = 'MANT:' || p.plan_id || ':' || p.estado || ':' || coalesce(p.ultimo_fecha::text, 'base')
    );

  -- Viajes ASIGNADO/EN_CURSO cuya salida + tiempo estimado + margen (el mayor
  -- entre 20% del estimado y 30 min, RF-20) ya pasó, sin
  -- alerta de retraso previa para ese viaje.
  insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
  select
    'RETRASO',
    'Retraso en viaje',
    format(
      '%s → %s (viaje %s) lleva retraso sobre el tiempo estimado.',
      v.origen, v.destino, v.remision
    ),
    v.id
  from public.viaje v
  join public.hito_viaje h on h.viaje_id = v.id and h.tipo = 'SALIDA'
  where v.estado in ('ASIGNADO', 'EN_CURSO')
    and v.tiempo_estimado_min is not null
    and now() > h.fecha_hora + ((v.tiempo_estimado_min + greatest(v.tiempo_estimado_min * 0.2, 30)) || ' minutes')::interval
    and not exists (
      select 1 from public.notificacion n
      where n.tipo = 'RETRASO' and n.viaje_id = v.id
    );

  -- Viajes que llegaron a FINALIZADO y todavia no tienen la alerta de
  -- completado (una sola vez por viaje).
  insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
  select
    'VIAJE_COMPLETADO',
    'Viaje completado',
    format('%s → %s (viaje %s) llegó a destino.', v.origen, v.destino, v.remision),
    v.id
  from public.viaje v
  where v.estado = 'FINALIZADO'
    and not exists (
      select 1 from public.notificacion n
      where n.tipo = 'VIAJE_COMPLETADO' and n.viaje_id = v.id
    );

  -- Peajes capturados hoy para un viaje, resumidos en una sola alerta diaria
  -- por viaje (evita una notificacion por cada correo de GoPass).
  insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
  select
    'PEAJE_REGISTRADO',
    'Peajes registrados',
    format('GoPass: %s peaje(s) asociados al viaje %s hoy.', conteo.total, conteo.remision),
    conteo.viaje_id
  from (
    select p.viaje_id, v.remision, count(*) as total
    from public.peaje_capturado p
    join public.viaje v on v.id = p.viaje_id
    where p.viaje_id is not null
      and p.fecha_hora::date = current_date
    group by p.viaje_id, v.remision
  ) conteo
  where not exists (
    select 1 from public.notificacion n
    where n.tipo = 'PEAJE_REGISTRADO'
      and n.viaje_id = conteo.viaje_id
      and n.fecha_creacion::date = current_date
  );
end;
$$;

revoke all on function public.notificacion_generar() from public, anon, authenticated;
