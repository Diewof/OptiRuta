-- Notificaciones del Administrador: tabla append-ish (solo se actualiza
-- `leida`), RLS y generacion automatica via pg_cron.
--
-- Contexto: CLAUDE.md "Programado: pg_cron para notificaciones..." y
-- Patrones: "Notificaciones = job de pg_cron que consulta y dispara push".
--
-- Alcance real de esta migracion (no se inventan fuentes de datos que no
-- existen en el esquema):
--   * DOCUMENTO_POR_VENCER: se genera desde documento_vehiculo.fecha_vencimiento.
--   * RETRASO: se genera comparando el hito SALIDA + viaje.tiempo_estimado_min
--     contra la hora actual, para viajes ASIGNADO/EN_CURSO.
--   * VIAJE_COMPLETADO: se genera cuando un viaje pasa a FINALIZADO.
--   * PEAJE_REGISTRADO: se genera cuando hay peajes nuevos en peaje_capturado
--     asociados a un viaje.
--   * NOVEDAD: el tipo queda declarado en el CHECK para uso futuro (RF de
--     reporte de novedades por el conductor), pero el generador NO la crea
--     todavia: no existe ninguna tabla de "novedad"/incidente en el dominio
--     actual. Inventar el origen del dato aqui violaria la regla "ante
--     informacion faltante, no inventes" de CLAUDE.md.
--   * VIAJE_FALLIDO (mostrado en el mockup de Historial): NO se implementa.
--     `viaje.estado` no tiene un valor FALLIDO en su CHECK (solo
--     PLANIFICADO/ASIGNADO/EN_CURSO/FINALIZADO/CERRADO); agregarlo cambiaria
--     el ciclo de vida de viaje documentado en CLAUDE.md y requiere una
--     decision de producto explicita, no una tabla de notificaciones.
--
-- La entrega de push real (FCM/APNs) queda fuera de esta migracion: aqui solo
-- se generan las filas que la pantalla in-app lista y pagina.

-- ---------------------------------------------------------------------------
-- Tabla
-- ---------------------------------------------------------------------------
create table public.notificacion (
  id              uuid primary key default gen_random_uuid(),
  tipo            text not null check (tipo in (
                    'DOCUMENTO_POR_VENCER', 'RETRASO', 'VIAJE_COMPLETADO',
                    'PEAJE_REGISTRADO', 'NOVEDAD'
                  )),
  titulo          text not null,
  mensaje         text not null,
  viaje_id        uuid references public.viaje (id) on delete cascade,
  vehiculo_id     uuid references public.vehiculo (id) on delete cascade,
  leida           boolean not null default false,
  fecha_creacion  timestamptz not null default now()
);

comment on table public.notificacion is
  'Alertas para el Administrador (documentos por vencer, retrasos, viajes '
  'completados, peajes). Solo se actualiza la columna leida; el resto nace '
  'y muere con la fila (sin edicion de contenido).';

create index notificacion_leida_fecha_idx
  on public.notificacion (leida, fecha_creacion desc);
create index notificacion_viaje_id_idx on public.notificacion (viaje_id);
create index notificacion_vehiculo_id_idx on public.notificacion (vehiculo_id);

-- ---------------------------------------------------------------------------
-- RLS: solo ADMINISTRADOR. Esta pantalla es exclusiva del rol admin (ver
-- Documentacion/Diseno-Admin); el conductor no tiene destinatario aqui.
-- ---------------------------------------------------------------------------
alter table public.notificacion enable row level security;
revoke all on public.notificacion from anon, authenticated;
grant select on public.notificacion to authenticated;
-- Marcar leida/no leida es la unica escritura permitida desde el cliente; el
-- resto de columnas las pobla solo notificacion_generar (SECURITY DEFINER).
grant update (leida) on public.notificacion to authenticated;

create policy notificacion_select_admin
  on public.notificacion
  for select
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

create policy notificacion_update_admin
  on public.notificacion
  for update
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR')
  with check ((auth.jwt() -> 'app_metadata' ->> 'rol') = 'ADMINISTRADOR');

-- Sin politica de INSERT/DELETE para anon/authenticated: las filas solo las
-- crea notificacion_generar (dueño del esquema, sin necesidad de grant) y no
-- se borran (si algun dia hace falta purgar historico, sera un job aparte).

-- ---------------------------------------------------------------------------
-- notificacion_generar(): consulta las fuentes de datos reales y inserta las
-- notificaciones que falten. Idempotente: cada bloque evita duplicar una
-- alerta ya existente para el mismo viaje/vehiculo antes de insertar.
-- ---------------------------------------------------------------------------
create or replace function public.notificacion_generar()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Documentos (SOAT/tecnomecanica) que vencen en 30 dias o menos y todavia
  -- no tienen una alerta sin leer de los ultimos 7 dias para ese vehiculo.
  insert into public.notificacion (tipo, titulo, mensaje, vehiculo_id)
  select
    'DOCUMENTO_POR_VENCER',
    'Documento por vencer',
    format(
      'El %s de %s vence el %s.',
      dv.tipo, v.placa, to_char(dv.fecha_vencimiento, 'DD/MM/YYYY')
    ),
    v.id
  from public.documento_vehiculo dv
  join public.vehiculo v on v.id = dv.vehiculo_id
  where dv.fecha_vencimiento between current_date and current_date + interval '30 days'
    and not exists (
      select 1 from public.notificacion n
      where n.tipo = 'DOCUMENTO_POR_VENCER'
        and n.vehiculo_id = dv.vehiculo_id
        and n.fecha_creacion > now() - interval '7 days'
    );

  -- Viajes ASIGNADO/EN_CURSO cuya salida + tiempo estimado ya pasó, sin
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
    and now() > h.fecha_hora + (v.tiempo_estimado_min || ' minutes')::interval
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

-- ---------------------------------------------------------------------------
-- pg_cron: genera notificaciones cada 30 minutos. Reutiliza la extension
-- pg_cron ya habilitada en 20260918211300_cron_precio_acpm.sql.
-- ---------------------------------------------------------------------------
select cron.schedule(
  'notificacion-generar-cada-30-min',
  '*/30 * * * *',
  $$select public.notificacion_generar();$$
);
