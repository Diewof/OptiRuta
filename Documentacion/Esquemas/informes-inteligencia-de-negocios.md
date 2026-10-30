# Informes de inteligencia de negocios

Origen: propuesta del stakeholder «Inteligencia de negocios / informes personalizados» (3 informes). Este documento fija el alcance acordado y el estado de implementación. Decisiones del dueño: 2026-10-27.

**Alcance acordado**
- Tanqueo registrado por el conductor (galones + valor). **Sin foto de factura**: no hay Storage ni dependencias nuevas.
- Combustible: solo rendimiento km/galón. No se mide ralentí ni extracción.
- Nuevo hito `SALIDA_DESCARGUE` para medir la espera de descargue.
- La espera solo se informa y alerta; el cobro de standby se negocia fuera de la app.
- Umbrales aprobados: caída de rendimiento ≥ 15 %, espera larga > 3 h.
- Viáticos entran como categoría `OTRO`. Los informes cuentan viajes `FINALIZADO` y `CERRADO`.
- Sin indicador de «calidad del dato»: el stakeholder no lo pidió. Cada informe indica cuántos viajes pudo medir (p. ej. «3 medidos»).

**Estado: implementado, aplicado en remoto y probado.**

---

## Informe 2 — Rentabilidad por ruta y cliente

Pestaña **Costos** del Resumen, tarjeta «Rendimiento». Se agrupa por ruta, cliente, conductor o placa y se ordena por margen promedio por viaje.

| Dato | Fuente |
|---|---|
| Rentabilidad total, margen promedio por viaje, margen % sobre flete | `metricas_por_dimension_v3` |
| Marca «Bajo margen» (margen negativo o < 10 %) | `bajo_margen`, calculado en el servidor |
| Puntualidad, km | iguales a la `_v2` |

Decisión que habilita: renegociar la tarifa de la ruta o cliente con margen bajo, o reasignar vehículos a la ruta con mejor margen. La app no cambia tarifas.

Límite: usa la rentabilidad **marginal**. El mantenimiento amortizado y el sueldo fijo solo entran en la consolidada por período.

---

## Informe 3 — Tiempos muertos en cargue y descargue

Pestaña **Esperas** del Resumen: por cliente, espera promedio de cargue y de descargue, total acumulado, espera más larga y cuántos viajes superaron 3 h.

| Dato | Cálculo |
|---|---|
| Espera de cargue | `SALIDA_CON_CARGA − LLEGADA_CARGUE` |
| Espera de descargue | `SALIDA_DESCARGUE − LLEGADA_DESTINO` |
| Alerta `ESPERA_EXCESIVA` | job `espera-alertas` cada 30 min; también avisa una espera en curso (últimas 24 h) |

**Flujo del conductor:** `LLEGADA_DESTINO` sigue dejando el viaje `FINALIZADO`. Después, Inicio le ofrece «¿Ya terminaste de descargar?» durante 24 h (`viaje_descargue_pendiente`). Es opcional: si no lo registra, esa espera no se mide.

Decisión que habilita: negociar una tarifa por espera con el cliente o reprogramar la hora de llegada del vehículo.

Límites: depende de que el conductor registre los hitos a tiempo. No se usan geocercas (el GPS guarda un punto cada ~5 min). La app no calcula ni cobra standby.

---

## Informe 1 — Control de combustible

Pestaña **Combustible** del Resumen: por vehículo o por ruta, km/galón del mes contra los 3 meses anteriores, variación y rendimiento de referencia del vehículo.

| Dato | Fuente |
|---|---|
| Galones y valor de cada compra | `tanqueo_viaje`, vía `viaje_registrar_tanqueo` (conductor, viaje `EN_CURSO`) |
| Kilómetros | `viaje.km_recorridos` solo con `km_origen = 'GPS'` |
| Rendimiento y variación | `combustible_rendimiento` |
| Alerta `RENDIMIENTO_BAJO` | job `combustible-alertas-diario`: caída ≥ 15 %, mínimo 2 viajes medidos en el mes y en el histórico; una por vehículo y mes |

El valor de los tanqueos se suma al costo **ACPM real** del viaje, así no se captura dos veces. Si el conductor ya había confirmado el ACPM a mano, el siguiente tanqueo lo reemplaza por la suma de los tanqueos.

Decisión que habilita: enviar el vehículo a mantenimiento preventivo antes de una falla en carretera.

Límites: la app **no afirma la causa**. Una caída de rendimiento se muestra como «consumo anómalo, revisar vehículo»; puede ser ralentí, extracción o falla mecánica. Distinguirlas requiere sensores o telemetría (Fase 2). El rendimiento por viaje aislado es poco fiable, por eso se calcula por mes.

---

## Archivos

| Pieza | Ubicación |
|---|---|
| Rentabilidad v3 | `supabase/migrations/20261027100000_rentabilidad_ruta_cliente_v3.sql` |
| Esperas, hito, alerta | `supabase/migrations/20261027110000_tiempos_espera.sql` |
| Combustible, tanqueos, alerta | `supabase/migrations/20261027120000_control_combustible.sql` |
| Pruebas pgTAP | `supabase/tests/informes_negocio_test.sql` |
| Flutter | `mobile/lib/features/combustible/`, `mobile/lib/features/esperas/`, cambios en `dashboard/` y `viajes/` |

## Pendiente

- Ya aplicadas en remoto (2026-10-27) y pgTAP 24/24 pasando.
- Fase 2: ralentí y extracción medidos, geocercas en bodegas, standby calculado, categoría `VIATICO` propia.
