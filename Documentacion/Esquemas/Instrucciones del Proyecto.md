# Instrucciones del Proyecto

## Objetivo

Desarrollar una aplicación móvil para gestionar viajes y calcular la rentabilidad aproximada de una empresa colombiana de transporte de carga pesada.

La aplicación debe funcionar para dos roles:
- Administrador
- Conductor

No desarrollar una interfaz web separada.

## Alcance

Implementar:

- Autenticación por rol.
- Gestión de vehículos, conductores y clientes.
- Creación y asignación de viajes.
- Planilla digital de viaje.
- Cálculo de distancia y tiempo de ruta.
- Estimación de consumo y costo de ACPM.
- Registro de costos reales.
- Captura automática de peajes mediante correos de GoPass.
- Seguimiento del viaje mediante hitos.
- Detección de retrasos.
- Gestión de mantenimiento y documentos.
- Alertas de vencimientos.
- Dashboard ejecutivo.
- Historial de viajes.
- Sistema de ajustes para viajes cerrados.

## Reglas de negocio

El viaje debe seguir este ciclo:

`Planificado → Asignado → En curso → Finalizado → Cerrado`

- Permitir editar viajes hasta que estén cerrados.
- No permitir editar ni eliminar directamente un viaje cerrado.
- Registrar cualquier corrección como un ajuste con motivo, usuario, fecha y valores anterior/nuevo.
- Separar la rentabilidad marginal por viaje de la rentabilidad consolidada por período.
- El sueldo fijo del conductor debe calcularse por período.
- La comisión variable debe asociarse al viaje.

## Combustible

Calcular el ACPM estimado mediante:

`Distancia ÷ Rendimiento × Precio por galón`

- Mantener el precio del ACPM en una tabla editable.
- Asociar el precio a ciudad y fecha de vigencia.
- Considerar el peso de la carga en el consumo.
- Mostrar siempre el valor estimado y permitir registrar el valor real.

## Peajes

No obtener los peajes mediante el servicio de mapas.

Usar las notificaciones de correo de GoPass:

`Correo GoPass → Webhook (Edge Function) → RPC → Peaje → Viaje`

Extraer:
- Placa.
- Peaje.
- Fecha y hora.
- Valor.

No implementar scraping con credenciales de GoPass.

## Seguimiento

Usar hitos registrados por el conductor:

- Salida.
- Llegada a cargue.
- Salida con carga.
- Llegada a destino.

Comparar los tiempos registrados con el tiempo estimado de la ruta.

El tracking GPS continuo queda fuera del MVP.

## Conectividad

La aplicación debe funcionar con conectividad intermitente.

Permitir:
- Guardar datos localmente.
- Registrar hitos sin conexión.
- Sincronizar automáticamente cuando vuelva la conexión.

## Seguridad

Aplicar permisos por rol también del lado servidor, mediante políticas RLS (Row Level Security) en la base de datos, no solo ocultando opciones en la app.

El conductor no debe poder:
- Consultar información financiera de otros conductores.
- Modificar configuraciones administrativas.
- Acceder a información no autorizada.

Registrar en auditoría las acciones importantes:
- Creación.
- Asignación.
- Modificación.
- Cierre.
- Ajustes.

## Dashboard

El administrador debe poder consultar:

- Ingresos.
- Costos.
- Rentabilidad.
- Costo por kilómetro.
- Rentabilidad por ruta.
- Rentabilidad por cliente.
- Rendimiento de conductores.
- Rendimiento de vehículos.
- Cumplimiento de tiempos.
- Utilización de la flota.
- Alertas activas.

Diseñar el dashboard para móvil mediante tarjetas KPI y navegación hacia el detalle.

## Fuera del MVP

No implementar:

- Tracking GPS continuo.
- Detección automática de paradas prolongadas.
- Actualización automática del precio del ACPM.
- Analítica predictiva.
- Integración RNDC.
- Facturación electrónica DIAN.
- Multiempresa.
- Otros operadores de peaje diferentes a GoPass.

## Arquitectura

Stack: app móvil Flutter (Clean Architecture + BLoC) sobre **Supabase** como backend-as-a-service (PostgreSQL, Auth, PostgREST/RPC, Storage, Edge Functions). No hay servidor de aplicación propio. Detalle en [arquitectura-y-estandares.md](arquitectura-y-estandares.md).

Mantener separación clara entre:

- Aplicación móvil (Flutter).
- Base de datos relacional (PostgreSQL en Supabase): integridad, RLS, funciones RPC.
- Autenticación (Supabase Auth).
- Servicio de rutas (Edge Function `rutas`).
- Correo/webhook de peajes (Edge Function `peajes-correo`).
- Notificaciones (job `pg_cron` + push).

Centralizar la lógica de negocio en la base de datos (constraints + RLS + funciones RPC), no en la app.

No duplicar reglas de negocio entre la app y la base de datos.