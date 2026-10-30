# Auditoría de procesos clave — OptiRuta

Fecha: 2026-10-13 · Rama `master` (commit `78570b9`)

**Alcance.** Revisión estática de las 35 migraciones de `supabase/`, las Edge Functions (`encuestas`, `rutas`, `precio-acpm-scraper`), el Apps Script de la encuesta, `config.toml`, los pgTAP y los puntos de entrada de la app Flutter (`mobile/`).

**Qué NO se hizo.** No se ejecutó nada: ni `supabase start` (Docker no disponible), ni pgTAP, ni la app. Cada hallazgo sale de leer el SQL, usando siempre la **última** definición de cada función (varias se redefinen en migraciones posteriores). La UI Flutter solo se revisó donde toca una regla de dominio. Los hallazgos marcados *(verificar en prod)* dependen de configuración remota que no está en el repo.

**Procesos auditados (ejemplos; hay más):** viajes (crear → asignar → iniciar → hitos → finalizar → cerrar/ajustar/cancelar/eliminar), checklist y salida, notificaciones, mantenimiento y hoja de vida, documentos del vehículo, rentabilidad y métricas, ubicación/alertas, encuesta de satisfacción, ACPM automático, auth/roles.

---

## Estado de las correcciones (2026-10-13)

Migración nueva: `supabase/migrations/20261013110000_auditoria_correcciones.sql`, con pruebas en `supabase/tests/auditoria_correcciones_test.sql` (y ajustes a cuatro pruebas existentes). **Sin ejecutar:** Docker no está disponible, así que las migraciones y los pgTAP no se han corrido; la parte Flutter sí pasa `flutter analyze` y `flutter test`.

| # | Estado | Nota |
|---|---|---|
| 1 | Corregido | `viaje_cambiar_estado` solo para el administrador y sin `EN_CURSO`/`CERRADO`/`CANCELADO`; `CHECK` de `fecha_cierre` (`NOT VALID`) |
| 2 | Corregido | Lecturas por RLS (clientes, flota, documentos, tarifas). El registro público **no** se tocó (decisión del dueño) |
| 3 | **Falso positivo** | `20261010170000_hitos_y_comision.sql` ya revocó el `INSERT` directo de hitos (y hay una prueba que lo verifica). No requería cambios |
| 4 | Corregido | Conductor ocupado (OR146) + bloqueo por advisory lock en `viaje_crear`. No se agregaron índices únicos: varias pruebas existentes crean varios viajes activos por conductor/vehículo con `INSERT` directo |
| 5 | Corregido | `viaje_registrar_ajuste_v2` (solo viaje cerrado); rentabilidad, métricas y reporte incluyen los ajustes. La app usa la v2 |
| 6 | Corregido | Fechas en hora de Colombia en las RPC de rentabilidad/métricas/reporte, notificaciones, ACPM y scraper. Quedan con `::date` las RPC de satisfacción (alcance de encuesta, excluido) |
| 7 | Corregido | Cancelar vence la encuesta, no se envían las de viajes cancelados, eliminar borra la encuesta sin responder |
| 8 | Corregido | El plan usa el odómetro derivado a la fecha del mantenimiento; el km digitado ya no entra al cálculo; cancelar en ruta conserva los km GPS |
| 9 | Corregido | El conductor no toca su comisión y solo edita costos con el viaje `EN_CURSO`/`FINALIZADO` |
| 10 | **Pendiente** | Peajes/GoPass queda para después (decisión del dueño) |
| 11 | Corregido | `viaje_iniciar` exige conductor activo y licencia vigente; alertas de licencia (30/7 días y vencida). La sesión de un usuario desactivado sigue viva hasta que expire su JWT |
| 12 | Corregido | Métricas y reporte usan `km_recorridos` (GPS) y, si falta, la distancia estimada |
| 13 | Corregido parcial | Flete > 0, errores del ACPM ya no se tragan, el scraper no pisa tarifas manuales. **No** se rechazan fechas de salida pasadas (no hay regla definida) ni se amplió el scraper más allá de Medellín |
| 14 | Excluido | Encuesta: Apps Script (correos duplicados, HTML sin escapar) — por indicación del dueño |
| 15–20 | Sin tocar | Severidad baja / informativa |

Efecto a tener en cuenta al desplegar: la clave de las alertas de mantenimiento cambió (ahora incluye cuántos registros hay del tipo), así que las alertas `PROXIMO`/`VENCIDO` vigentes se generarán **una vez más**.

---

## Cómo se entrelazan los procesos

```
documento_vehiculo ──► vehiculo_validar_documentos ─┐
checklist_registrar ─► checklist_viaje (12 h) ──────┼─► viaje_iniciar ─► hito SALIDA + EN_CURSO
                                                    │         │
viaje_crear(_v2) ─► costo_viaje (ACPM, comisión…)   │         ▼
                                                    │   viaje_registrar_hito ─► LLEGADA_DESTINO ─► FINALIZADO
ubicacion_viaje (GPS) ─► viaje_fijar_km ◄───────────┘                                │
        │                    │                              triggers: encuesta + notificación VIAJE_COMPLETADO
        │                    ▼                                                       │
        │          viaje.km_recorridos ─► vehiculo_odometro_km ─► plan_mantenimiento_calculo ─► notificacion_generar (cron 30 min)
        │                                         │                                              ▲
        └─► vehiculo_hoja_vida ◄──────────────────┘            mantenimiento_registrar ──────────┘
                                                               documento_vehiculo_registrar ─────┘
viaje_cerrar ─► rentabilidad_marginal / consolidada / métricas / reporte_viajes   (+ mantenimiento_vehiculo.costo)
```

El eje es **`viaje.estado`**: de él dependen el odómetro (→ mantenimiento), las alertas, la encuesta y la rentabilidad. Por eso los fallos 1, 3 y 6 de abajo contaminan varios procesos a la vez.

---

## Resumen

| # | Gravedad | Hallazgo | Área |
|---|---|---|---|
| 1 | **Alta** | `viaje_cambiar_estado` permite iniciar un viaje saltándose SOAT/tecnomecánica/checklist/500 m | Viajes / Flota |
| 2 | **Alta** | Registro público abierto + lecturas `using (true)`: un extraño lee clientes y flota | Seguridad |
| 3 | ~~Alta~~ | ~~El conductor inserta hitos directo en la tabla~~ — **falso positivo, ya estaba corregido** | Viajes |
| 4 | **Alta** | Nada impide dos viajes activos para el mismo conductor; el de vehículo tiene condición de carrera | Viajes |
| 5 | **Alta** | Los ajustes de un viaje cerrado no corrigen ninguna cifra | Rentabilidad |
| 6 | Media-alta | Fechas de cierre truncadas en UTC: viajes caen en el día/mes equivocado | Rentabilidad |
| 7 | Media | Cancelar un viaje FINALIZADO deja la encuesta viva; eliminarlo falla por FK | Viajes / Encuesta |
| 8 | Media | Mantenimiento: alertas por km quedan muertas en tres casos | Mantenimiento |
| 9 | Media | El conductor puede editar el `valor_real` de su propia COMISIÓN | Rentabilidad |
| 10 | Media | Peajes: la Edge Function y la RPC de inserción no existen | Peajes |
| 11 | Media | Conductor/usuario inactivo y licencia vencida no bloquean nada | Flota |
| 12 | Media | Métricas y reporte usan km estimados, no los km reales | Métricas |
| 13 | Media | `viaje_crear`: errores tragados, flete sin validar, ACPM en 0 fuera de Medellín | Viajes / ACPM |
| 14 | Media | Encuesta: correos duplicados y HTML sin escapar en el Apps Script | Encuesta |
| 15 | Baja | `viaje_iniciar` acepta cualquier hora de salida del cliente | Viajes |
| 16 | Baja | Hoja de vida y mantenimiento editables sin rastro; fecha engañosa en viajes forzados | Flota |
| 17 | Baja | Consolidada y métricas con criterios frágiles (conductor inactivo, nombres repetidos) | Métricas |
| 18 | Baja | Higiene: notificaciones sin purga, secreto comparado sin tiempo constante, esm.sh sin fijar, sin rate limit | Varios |
| 19 | Baja | Huecos de pruebas pgTAP | Calidad |
| 20 | Info | Deriva entre CLAUDE.md y el repo | Documentación |

---

## Hallazgos (de mayor a menor gravedad)

### 1. [ALTA] `viaje_cambiar_estado` permite saltarse todas las reglas de salida

**Dónde:** `20261011110000_viaje_km_odometro.sql` (`viaje_cambiar_estado`), concedida a `authenticated`.

**Qué pasa.** El conductor puede llamar `viaje_cambiar_estado(id, 'EN_CURSO')` sobre su viaje `ASIGNADO` (la RPC lo permite explícitamente), y el administrador cualquier transición válida. Ese camino **no** pasa por `viaje_iniciar`, así que no valida:
- SOAT / tecnomecánica vigentes (`vehiculo_validar_documentos`),
- checklist de las últimas 12 h ni su autorización,
- el radio de 500 m,
- y **no inserta el hito `SALIDA`**.

La app usa `viaje_iniciar`, pero la regla vive "solo en la app": quien llame la RPC con el JWT del conductor sale sin checklist ni documentos. Es justo lo que `CLAUDE.md` prohíbe (regla de dinero/estado solo en la app).

**Efectos en cascada.** Sin hito `SALIDA`: `RETRASO` nunca se genera, la puntualidad queda "no medida" en métricas/reporte/encuesta, y `utilizacion_flota_pct` lo ignora. Mismo patrón con `FINALIZADO` sin `LLEGADA_DESTINO` (también sin hitos intermedios) y con `CERRADO` vía `viaje_cambiar_estado`, que deja `fecha_cierre` en NULL: el viaje desaparece de todo reporte por período (`fecha_cierre::date between …` es NULL).

**Arreglo sugerido.** En `viaje_cambiar_estado` rechazar `EN_CURSO` (siempre `viaje_iniciar`), `CERRADO` (siempre `viaje_cerrar`) y `CANCELADO` (siempre `viaje_cancelar`); para el conductor, permitir `FINALIZADO` solo si existe `LLEGADA_DESTINO`. Añadir `CHECK ((estado = 'CERRADO') = (fecha_cierre is not null))`. Test pgTAP: el conductor no puede pasar a `EN_CURSO` sin checklist.

---

### 2. [ALTA] Registro público abierto + lectura abierta a cualquier autenticado *(verificar en prod)*

**Dónde:** `config.toml` (`enable_signup = true`, `[auth.email] enable_confirmations = false`); `handle_new_user`; políticas `using (true)` en `20260918210700_dominio_catalogos.sql` (`vehiculo`, `cliente`, `documento_vehiculo`, `tarifa_combustible`).

**Qué pasa.** La `anon key` va dentro del APK. Cualquiera puede hacer `signUp` con un correo inventado (sin confirmación), recibe `rol = CONDUCTOR` en el JWT y, con eso, `SELECT` sobre **toda** la tabla `cliente` (nombre, teléfono, correo y, tras `20260918211500`, documento y dirección), la flota con sus VIN y documentos, y las tarifas. También puede invocar la Edge Function `rutas` (solo exige JWT válido). Es un riesgo de privacidad de clientes (Ley 1581) y de competencia.

**Arreglo sugerido.** Desactivar `enable_signup` y crear usuarios desde el administrador (o una RPC/Edge Function con `service_role`); y/o restringir `cliente_select` a administrador + conductor con viaje propio, y exigir que exista una fila `conductor` activa para las lecturas de conductor. Confirmar cuál es el valor real en el proyecto remoto.

---

### 3. [ALTA — FALSO POSITIVO] INSERT directo de hitos: se salta orden, estado y hora

> **Corrección posterior:** este hallazgo es incorrecto. Lo escribí leyendo `20261010120000`, pero `20261010170000_hitos_y_comision.sql` ya elimina la política y revoca el `INSERT` del conductor sobre `hito_viaje`, y `hitos_comision_actualizar_test.sql` lo comprueba (`42501`). Lo que sigue se conserva solo como registro de lo que se creyó.

**Dónde:** `20260918210800_dominio_viaje.sql` (`grant insert` + política `hito_viaje_insert_conductor_propio`), reescrita en `20261010120000` solo para excluir `tipo = 'SALIDA'`.

**Qué pasa.** Para `LLEGADA_CARGUE`, `SALIDA_CON_CARGA` y `LLEGADA_DESTINO` la política solo exige "viaje propio". Por PostgREST directo el conductor puede insertar esos hitos en cualquier estado (incluido `ASIGNADO`), fuera de orden, duplicados y con cualquier `fecha_hora`. `viaje_registrar_hito` valida todo eso (OR118/127/128/129), pero es opcional. Consecuencias: puntualidad y encuesta (`max(LLEGADA_DESTINO)`) manipulables, y un `LLEGADA_DESTINO` falso hace que `viaje_registrar_hito` responda "ya registrado" (OR128) y el viaje no se pueda finalizar con el flujo normal.

**Arreglo sugerido.** Quitar el `INSERT` del conductor sobre `hito_viaje` (revocar el grant y la política): la RPC es `SECURITY DEFINER` y no lo necesita. Añadir `UNIQUE (viaje_id, tipo)`.

---

### 4. [ALTA] Doble asignación: no se valida el conductor y la del vehículo tiene carrera

**Dónde:** `20261010170000_hitos_y_comision.sql` (`viaje_crear`).

**Qué pasa.** Solo se comprueba `exists(viaje del vehículo en ASIGNADO/EN_CURSO)`. El **mismo conductor** puede tener varios viajes `ASIGNADO`/`EN_CURSO` con vehículos distintos. La app lo asume imposible (`ConductorViajeCubit` toma `viajes.first` y comenta "no debería"), así que el resto de viajes queda invisible para el conductor. Además la verificación es *check-then-insert* sin bloqueo ni índice único: dos `viaje_crear` simultáneos para el mismo vehículo pasan ambos.

**Arreglo sugerido.** Índices únicos parciales: `unique (vehiculo_id) where estado in ('ASIGNADO','EN_CURSO')` y lo mismo por `conductor_id`; el mensaje de dominio sigue saliendo del chequeo previo, el índice es la red de seguridad.

---

### 5. [ALTA] Los ajustes de viajes cerrados no corrigen ninguna cifra

**Dónde:** `20260918210900_rpc_viaje.sql` (`viaje_registrar_ajuste`), `rentabilidad_*`, `metricas_*`, `reporte_viajes`.

**Qué pasa.** `viaje_registrar_ajuste` solo inserta una fila de texto (`campo_modificado`, `valor_anterior`, `valor_nuevo`). Ninguna RPC de rentabilidad/métricas/reporte lee `ajuste_viaje`, y `costo_viaje`/`viaje` están bloqueados por trigger. Es decir: si el administrador descubre que el flete o un costo de un viaje cerrado estaba mal, el "ajuste" queda registrado pero la rentabilidad consolidada sigue mostrando el valor erróneo para siempre. Tampoco exige que el viaje esté `CERRADO` (acepta ajustes sobre viajes abiertos o cancelados) y bloquea `viaje_eliminar` por la FK `RESTRICT` sin mensaje claro.

**Decisión pendiente (no inventar).** Definir qué ajustes son numéricos (flete, costo por categoría) y hacer que las RPC de rentabilidad los apliquen (p. ej. `valor_nuevo - valor_anterior` por categoría), o documentar que son solo bitácora.

---

### 6. [MEDIA-ALTA] Fechas truncadas en zona horaria UTC

**Dónde:** `rentabilidad_consolidada_v2/v3`, `metricas_periodo_v2`, `metricas_por_dimension_v2`, `reporte_viajes` (`v.fecha_cierre::date`); `notificacion_generar` (`p.fecha_hora::date = current_date`, `n.fecha_creacion::date = current_date`); `costo_acpm_estimado` (`p_fecha default current_date`); `precio-acpm-scraper` (`toISOString().slice(0,10)`).

**Qué pasa.** Un `timestamptz::date` usa la zona de la sesión (UTC en Supabase). Un viaje cerrado a las 8:30 p. m. hora Colombia cuenta como del día siguiente; los cierres del último día del mes después de las 7 p. m. caen en el mes siguiente. El proyecto ya tiene `hoy_bogota()` para esto y lo usa en documentos y mantenimiento, pero no aquí.

**Arreglo sugerido.** `(v.fecha_cierre at time zone 'America/Bogota')::date` en todas esas RPC (y `public.hoy_bogota()` en lugar de `current_date`).

---

### 7. [MEDIA] Cancelar/eliminar un viaje FINALIZADO choca con la encuesta

**Dónde:** `20261012100000_encuesta_satisfaccion.sql` (`viaje_id … on delete restrict`, `encuesta_pendientes_envio`), `20261010150000_viaje_cancelar_eliminar.sql`.

**Qué pasa.**
- La encuesta nace al pasar a `FINALIZADO`. Si el administrador **cancela** ese viaje, la encuesta sigue `PENDIENTE` y `encuesta_pendientes_envio` no filtra por estado del viaje: el cliente recibe por correo la encuesta de un servicio cancelado.
- Si lo **elimina** (regla de `CLAUDE.md`: "un viaje no cerrado sí se puede eliminar"), la FK `ON DELETE RESTRICT` aborta la operación con un error crudo de Postgres (23503) en vez de un mensaje de dominio. En la práctica un viaje `FINALIZADO` ya no es eliminable.

**Arreglo sugerido.** `encuesta_pendientes_envio` con `v.estado <> 'CANCELADO'`; `viaje_cancelar` marca la encuesta como `VENCIDA`; decidir si `viaje_eliminar` borra la encuesta sin respuesta (y rechaza con mensaje claro si ya fue respondida).

---

### 8. [MEDIA] Mantenimiento: las alertas por km se apagan en tres casos

**Dónde:** `20261011130000_mantenimiento_preventivo.sql` (`plan_mantenimiento_calculo`, `mantenimiento_registrar`), `20261011150000` (`vehiculo_odometro_km`).

- **8a. Km nulo = plan sin alerta.** `base_km` es `u.kilometraje` si hay un mantenimiento previo. `mantenimiento_registrar` solo completa el km si la fecha es *hoy*; un mantenimiento con fecha pasada sin km deja `base_km = NULL` → `km_restantes = NULL` → ni `PROXIMO` ni `VENCIDO`. Seis de los nueve tipos del catálogo son solo por km (filtros, caja/diferencial, engrase, frenos, alineación, llantas): quedan **mudos de forma permanente** y sin ningún aviso.
- **8b. Dos escalas de km mezcladas.** Si el administrador captura el km del tablero (p. ej. 350 000) pero el odómetro derivado vale `odometro_inicial_km + GPS` (p. ej. 12 000), `greatest(odo - base, 0)` da 0 y el plan aparece "al día" hasta que el derivado alcance el valor digitado. Al revés (km digitado menor), sale `VENCIDO` al instante. No hay validación contra el odómetro.
- **8c. Km que no suman.** `vehiculo_odometro_km` cuenta solo viajes `FINALIZADO/CERRADO`. Un viaje `EN_CURSO` cancelado a mitad de camino no suma sus km (ni se ejecuta `viaje_fijar_km` al cancelar). Un viaje sin GPS ni `distancia_estimada` suma 0.

**Extra:** la clave de deduplicación `MANT:<plan>:<estado>:<ultimo_fecha>` colisiona si se registran dos mantenimientos del mismo tipo el mismo día (la alerta no se rearma).

**Arreglo sugerido.** En `mantenimiento_registrar`, si no hay km usar siempre el odómetro (o exigirlo); advertir si el km digitado difiere mucho del derivado; tratar `base_km IS NULL` con el odómetro al momento del registro; llamar `viaje_fijar_km` en `viaje_cancelar` cuando el viaje estaba `EN_CURSO`.

---

### 9. [MEDIA] El conductor puede cambiar el `valor_real` de su propia COMISIÓN

**Dónde:** `20260918210800_dominio_viaje.sql` (`costo_viaje_conductor_actualiza_real` + trigger `costo_viaje_restringir_conductor`).

**Qué pasa.** El conductor puede hacer `UPDATE costo_viaje SET valor_real = …` en **cualquier categoría** de su viaje y en cualquier estado no cerrado (incluso `ASIGNADO` y `FINALIZADO`). El trigger solo protege `categoria`, `valor_estimado`, `fuente` y `viaje_id`. Como `rentabilidad_*` usa `coalesce(valor_real, valor_estimado)`, el conductor puede fijarse su propia `COMISION` real (su pago) o bajar el ACPM. Además puede insertar costos `OTRO` sin tope (`costo_viaje_conductor_agrega_otro`).

**Arreglo sugerido.** El conductor solo actualiza categorías de gasto en ruta (ACPM, PEAJE, PARQUEADERO, CARGUE, DESCARGUE…), nunca `COMISION`; y solo con el viaje `EN_CURSO`/`FINALIZADO`.

---

### 10. [MEDIA] Peajes: la función y la RPC de inserción no existen

**Dónde:** `supabase/functions/` (solo hay `encuestas`, `rutas`, `precio-acpm-scraper`); `peaje_capturado` solo se lee.

**Qué pasa.** `CLAUDE.md` describe `peajes-correo` (webhook GoPass → RPC con `service_role`) y la carpeta lo lista, pero no está en el repo, y ninguna migración define una RPC que inserte en `peaje_capturado`. Resultado: `peaje_capturado` siempre está vacía, el costo `PEAJE` es 100 % manual (creado en 0) y la notificación `PEAJE_REGISTRADO` es código muerto. Si se implementa, el bloque actual de `notificacion_generar` tendría dos defectos: el resumen diario se crea una vez y no se actualiza (el conteo queda congelado en el primer valor del día) y usa `current_date` UTC (ver hallazgo 6). Tampoco se asignaría `viaje_id` automáticamente.

**Acción.** Confirmar si es Fase 2; si es MVP, implementarlo; si no, quitarlo de `CLAUDE.md` y de los tipos de notificación.

---

### 11. [MEDIA] Conductor/usuario inactivo y licencia vencida no bloquean nada

**Dónde:** políticas RLS y RPC (`viaje_iniciar`, `checklist_registrar`, `viaje_registrar_*`); `conductor.fecha_vencimiento_licencia`.

**Qué pasa.** `activo` solo se valida al crear el viaje. Un conductor o usuario desactivado conserva su sesión (JWT ~1 h, refresh token vigente) y sigue operando sus viajes ya asignados; ninguna política mira `usuario.activo` ni `conductor.activo`. `fecha_vencimiento_licencia` se guarda y se muestra, pero ni `notificacion_generar` la avisa ni `viaje_crear`/`viaje_iniciar` la comprueban: un conductor con licencia vencida puede ser asignado y salir. (`CLAUDE.md` deja fuera tarjeta de operación y pólizas, pero no menciona la licencia: **decisión del dueño**.)

**Arreglo sugerido.** Función `es_conductor_activo()` usada en las RPC del conductor; al desactivar un usuario, revocar sesiones con `service_role`. Alerta de licencia por escalones igual que documentos.

---

### 12. [MEDIA] Métricas y reporte usan km estimados

**Dónde:** `metricas_periodo_v2` (`km_total`, `costo_por_km`), `metricas_por_dimension_v2`, `reporte_viajes` (`km`): todos suman `distancia_estimada`.

**Qué pasa.** La decisión del 2026-10-11 introdujo `viaje.km_recorridos` (GPS) y el odómetro ya lo usa, pero el costo por km y el reporte PDF siguen con la distancia estimada: dos "verdades" distintas de km en la misma app.

**Arreglo sugerido.** `coalesce(km_recorridos, distancia_estimada)` (como `vehiculo_odometro_km`) y rotular el origen en el reporte.

---

### 13. [MEDIA] `viaje_crear`: errores tragados y validaciones faltantes

**Dónde:** `20261010170000_hitos_y_comision.sql` (`viaje_crear`), `precio-acpm-scraper`.

- El `exception when others` que envuelve `costo_acpm_estimado` convierte **cualquier** error (rendimiento 0 → división por cero, `p_distancia_estimada` nula, vehículo sin capacidad) en "sin tarifa de ACPM" y deja ACPM en 0 con un mensaje engañoso.
- `p_valor_flete` no se valida al crear (acepta 0, negativo o nulo); `viaje_actualizar` sí exige > 0 y el cierre exige > 0, así que se pueden crear viajes que luego no se pueden cerrar sin editarlos.
- `fecha_salida_programada` en el pasado no se rechaza.
- El scraper solo registra **Medellín**: un viaje que sale de otra ciudad queda con ACPM estimado en 0 (con notificación `NOVEDAD`) y la rentabilidad marginal sale inflada hasta que alguien cargue la tarifa manual.
- `tarifa_combustible_registrar_automatico` hace `ON CONFLICT … DO UPDATE` y puede **sobrescribir una tarifa manual** del mismo día sin dejar aviso.

---

### 14. [MEDIA] Encuesta: correos duplicados y HTML sin escapar

**Dónde:** `supabase/apps-script/encuestas.gs` (`enviarPendientes`).

- El correo se envía **antes** de registrar el envío. Si la llamada `ENVIO` falla (red, 5xx), la encuesta sigue `PENDIENTE` con `intentos_envio = 0` y el trigger de 5 min la reenvía una y otra vez durante los 14 días de vigencia. El tope de 3 intentos solo cuenta fallos de *correo*.
- `enc.cliente`, `enc.origen`, `enc.destino` y `enc.remision` se concatenan en `htmlBody` sin escapar (los nombres de lugar vienen de OpenStreetMap/Photon).
- `x-service-secret` se compara con `!==` (no tiempo constante) en `encuestas` y `precio-acpm-scraper`.

---

### 15. [BAJA] `viaje_iniciar` acepta cualquier hora de salida

`p_fecha_hora` del cliente se inserta tal cual como hito `SALIDA` (sin la validación de ±5 min y orden que sí tiene `viaje_registrar_hito`). Un conductor puede declarar una salida en el pasado/futuro y alterar puntualidad y retraso. Además `viaje_registrar_hito` compara la hora solo contra `SALIDA`, no contra el hito anterior (puede registrar `LLEGADA_DESTINO` antes que `SALIDA_CON_CARGA`).

---

### 16. [BAJA] Hoja de vida y mantenimiento: historial editable sin rastro

- `mantenimiento_vehiculo` tiene `grant select, insert, update, delete` con política `for all` para administrador: se puede editar o borrar un mantenimiento antiguo directo, sin `mantenimiento_registrar`, cambiando la hoja de vida, el estado del plan y el costo consolidado de períodos pasados (solo queda `modificado_por`). Un INSERT directo salta las validaciones (fecha futura, km, tipo).
- `documento_vehiculo`: se revocó `DELETE` pero `UPDATE` sigue concedido; se puede reescribir un vencimiento viejo sin crear registro nuevo (rompe la idea de "corregir = registrar otro").
- `vehiculo_hoja_vida`: para un viaje que el administrador finalizó a mano (sin `LLEGADA_DESTINO`), la fecha mostrada es `fecha_creacion` del viaje (no la de finalización) y queda mal ordenado en la línea de tiempo.

---

### 17. [BAJA] Consolidada y métricas con criterios frágiles

- `rentabilidad_consolidada_v2` suma el sueldo fijo de los conductores `activo` **hoy**: desactivar un conductor cambia retroactivamente la rentabilidad de períodos ya cerrados; tampoco considera desde cuándo existía cada conductor.
- `metricas_por_dimension_v2` agrupa por nombre (`cliente.nombre`, `usuario.nombre`): dos clientes homónimos se fusionan.
- `utilizacion_flota_pct` suma días enteros por viaje sin recortar al período y excluye los viajes sin hitos (ver hallazgo 1).

---

### 18. [BAJA] Higiene y operación

- `notificacion` no tiene política ni job de purga: crece sin límite, y `notificacion_generar` (cron cada 30 min **y** en cada `documento_vehiculo_registrar`) recorre las tablas completas; sin índices específicos para sus `not exists` por `tipo`/`viaje_id`.
- `ubicacion_viaje`: revocar el consentimiento detiene el registro pero no borra ni limita la retención de los puntos ya guardados (relevante para habeas data).
- `rutas`: sin rate limit ni verificación de rol; se puede usar de proxy gratuito a Photon/OSRM.
- `esm.sh/@supabase/supabase-js@2` sin versión fija en las Edge Functions (build no reproducible).
- `viaje_registrar_alerta` / `viaje_registrar_ubicacion` no validan que la ubicación esté cerca de la ruta ni acotan frecuencia por usuario más allá de la ventana por viaje.

---

### 19. [BAJA] Huecos de pruebas

No hay pgTAP para: `plan_mantenimiento_calculo` (km nulo, escalas de km, deduplicación), `mantenimiento_registrar`, `vehiculo_hoja_vida`, el bloque de alertas de flota de `notificacion_generar`, ni los bypass de los hallazgos 1, 3 y 9 (el conductor **no** debería poder pasar a `EN_CURSO` sin checklist ni insertar hitos directos). Sí existen pruebas de `viaje_iniciar`, checklist/documentos (`flota_salida_test.sql`), encuesta y cancelar/eliminar. Prioridad `CLAUDE.md`: reglas de negocio y RLS primero.

---

### 20. [INFO] Deriva entre CLAUDE.md y el repo

- `CLAUDE.md` dice `app/`; el proyecto Flutter vive en `mobile/`.
- Lista `peajes-correo` como Edge Function existente (hallazgo 10).
- El comentario de `20261010140000` dice "Sin servicio en segundo plano", pero `CLAUDE.md` describe ya un servicio en primer plano.
- `PLANIFICADO` ya no se usa: `viaje_crear` nace `ASIGNADO` (decisión vigente en `20261008150000`), pero el ciclo y la validación de transición lo siguen listando.

---

## Orden sugerido de corrección

1. **Hallazgos 1, 3 y 9** (cierran bypass en SQL, cambios pequeños, un solo PR + pgTAP).
2. **Hallazgo 2** (confirmar la configuración real de Auth en prod primero).
3. **Hallazgos 4 y 6** (dos índices únicos y un reemplazo mecánico de `::date`).
4. **Hallazgos 5, 10 y 11**: requieren decisión del dueño antes de programar.
5. Resto por valor/esfuerzo; **8** y **7** son los siguientes en impacto operativo.

Conforme a `CLAUDE.md`, cada corrección va en una **migración nueva** (no se editan las ya mergeadas) y, si cambia la firma de una RPC con app vieja en uso, como `_v2`.
