-- Retira los datos de referencia de calidad (supabase/datos-referencia-calidad.sql):
-- viajes DEMO-CAL-*, sus encuestas, el cliente demo y las alertas
-- CALIDAD_RECURRENTE (el tipo es nuevo: todas las existentes son de la demo
-- mientras no haya datos reales; si ya las hay, borra solo las del mes de la
-- demo o ajusta el filtro).

delete from public.encuesta_satisfaccion
 where viaje_id in (select id from public.viaje where remision like 'DEMO-CAL-%');

-- costo_viaje, hito_viaje y notificacion (con viaje_id) se borran en cascada.
delete from public.viaje where remision like 'DEMO-CAL-%';

delete from public.notificacion where tipo = 'CALIDAD_RECURRENTE';

delete from public.cliente
 where nombre = 'Cliente Demo Calidad'
   and not exists (select 1 from public.viaje v where v.cliente_id = cliente.id);
