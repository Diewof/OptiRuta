# Instrucciones del Proyecto

## Objetivo

Desarrollar una aplicación móvil para gestionar viajes y calcular la rentabilidad aproximada de una empresa colombiana de transporte de carga pesada.

La aplicación debe funcionar para dos roles:
- Administrador
- Conductor

No desarrollar una interfaz web separada.

## Alcance

Esta es una **beta mínima funcional (MVP)**, no el sistema completo del documento de requisitos original. Trazabilidad completa RF/RNF → MVP / Fase 2 en [requisitos-funcionales-y-no-funcionales.md](requisitos-funcionales-y-no-funcionales.md).

### MVP

Implementar:

- Autenticación por rol.
- Gestión de vehículos, conductores y clientes.
- Creación y asignación de viajes, con fecha mediante formulario + selector de fecha simple (sin calendario visual mensual/semanal).
- Registro del ingreso del viaje (`valor_flete`, ver sección "Ingresos").
- Planilla digital de viaje.
- Cálculo de distancia y tiempo de ruta.
- Estimación de consumo y costo de ACPM.
- Registro de costos reales.
- Captura automática de peajes mediante correos de GoPass.
- Seguimiento del viaje mediante hitos.
- Detección de retrasos, con umbral cuantificado (ver "Seguimiento").
- Gestión de mantenimiento y documentos.
- Alertas de vencimientos.
- Dashboard ejecutivo.
- Historial de viajes.
- Sistema de ajustes para viajes cerrados.
- Guardado local acotado (hitos y costos manuales) con sincronización al recuperar conexión (ver "Conectividad").

### Fase 2 (pospuesto)

No entra en esta beta:

- Calendario interactivo con vista mensual/semanal (el MVP resuelve la fecha con formulario simple).
- Tracking GPS continuo (persistir la posición) y consentimiento de ubicación asociado (RF-21, RF-23). La detección de parada/desvío en el teléfono con evento puntual al administrador (RF-22) sí entra en el MVP.
- Filtros de reportes (fecha, ruta, cliente, conductor, vehículo) y exportación de reportes (ej. PDF).
- Offline-first más allá de hitos y costos manuales (no se navega ni consulta histórico sin conexión).

## Reglas de negocio

El viaje debe seguir este ciclo:

`Planificado → Asignado → En curso → Finalizado → Cerrado`

- Permitir editar viajes hasta que estén cerrados.
- No permitir editar ni eliminar directamente un viaje cerrado.
- Registrar cualquier corrección como un ajuste con motivo, usuario, fecha y valores anterior/nuevo.
- Separar la rentabilidad marginal por viaje de la rentabilidad consolidada por período.
- El sueldo fijo del conductor debe calcularse por período.
- La comisión variable debe asociarse al viaje.

## Ingresos (flete)

- El administrador captura `valor_flete` al crear el viaje: es un monto pactado con el cliente, no un valor estimado por el sistema — se guarda como un único valor, no como par `valor_estimado`/`valor_real`.
- `valor_flete` es el ingreso que alimenta la rentabilidad marginal por viaje: `flete − (ACPM + peajes + cargue + descargue + parqueadero + otros + comisión)`.
- El mantenimiento amortizado y el sueldo fijo prorrateado **no** entran en la rentabilidad marginal; solo en la rentabilidad consolidada por período.

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

Notificar al administrador cuando el retraso sea significativo: **20% del tiempo estimado del tramo entre hitos, o 30 minutos, lo que sea mayor**. Umbral inicial, ajustable con datos reales de operación.

El tracking GPS continuo (guardar o transmitir la posición) queda fuera del MVP. El mapa del conductor muestra su posición en vivo solo en el teléfono, y la app envía únicamente eventos puntuales de parada prolongada o desvío de ruta.

## Conectividad

La aplicación debe funcionar con conectividad intermitente, acotado a lo siguiente (no es offline-first completo):

Permitir:
- Guardar localmente y encolar solo **hitos** y **costos manuales** del viaje en curso.
- Registrar hitos sin conexión.
- Sincronizar automáticamente cuando vuelva la conexión.

No incluye navegar ni consultar histórico de viajes sin conexión.

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

- Tracking GPS continuo (guardar o transmitir la posición periódicamente).
- Servicio de ubicación en segundo plano (la detección de parada/desvío solo opera con la app abierta).
- Consentimiento informado de ubicación (solo aplica si se activa tracking).
- Analítica predictiva.
- Integración RNDC.
- Facturación electrónica DIAN.
- Multiempresa.
- Otros operadores de peaje diferentes a GoPass.
- Calendario interactivo (vista mensual/semanal) para gestión de fechas de viaje.
- Filtros de reportes y exportación de reportes (ej. PDF).
- Offline-first completo (más allá de la cola de hitos y costos manuales, ver "Conectividad").

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