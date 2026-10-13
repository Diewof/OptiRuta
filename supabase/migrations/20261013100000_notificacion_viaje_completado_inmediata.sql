-- Bug: la alerta VIAJE_COMPLETADO solo la creaba el cron de notificacion_generar()
-- (cada 30 min), asi que el admin la veia con hasta 30 min de retraso y, si el
-- viaje pasaba a CERRADO antes del siguiente tick, nunca la veia.
--
-- Fix: crearla en el instante en que el viaje llega a FINALIZADO. Mismo patron
-- que viaje_finalizado_crear_encuesta: el viaje finaliza por dos RPC distintas
-- (viaje_cambiar_estado y viaje_registrar_hito), un trigger delgado evita
-- copiar la logica en ambas. notificacion_generar() conserva su bloque como red
-- de seguridad (viajes ya finalizados antes de esta migracion); ambos evitan
-- duplicados con el mismo not exists.

create or replace function public.viaje_finalizado_notificar()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notificacion (tipo, titulo, mensaje, viaje_id)
  select
    'VIAJE_COMPLETADO',
    'Viaje completado',
    format('%s → %s (viaje %s) llegó a destino.', new.origen, new.destino, new.remision),
    new.id
  where not exists (
    select 1 from public.notificacion n
    where n.tipo = 'VIAJE_COMPLETADO' and n.viaje_id = new.id
  );
  return new;
end;
$$;

revoke all on function public.viaje_finalizado_notificar() from public, anon, authenticated;

create trigger viaje_finalizado_notificar
  after update of estado on public.viaje
  for each row
  when (new.estado = 'FINALIZADO' and old.estado is distinct from 'FINALIZADO')
  execute function public.viaje_finalizado_notificar();
