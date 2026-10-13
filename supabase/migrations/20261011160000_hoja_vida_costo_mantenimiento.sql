-- La hoja de vida es ahora el unico lugar donde se ve el mantenimiento de un
-- vehiculo (se retira la pantalla global de Mantenimiento): el costo debe
-- verse en su linea de tiempo.

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
               concat_ws(
                 ' · ',
                 '$ ' || replace(to_char(m.costo, 'FM999,999,999,999'), ',', '.'),
                 initcap(lower(m.categoria)), m.taller, m.descripcion
               ),
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
