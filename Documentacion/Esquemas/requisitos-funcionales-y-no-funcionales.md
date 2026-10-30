# Requisitos funcionales y no funcionales — OptiRuta

Fuente: `Optiruta.docx` (sección Requisitos). Este archivo agrega la columna **Estado MVP** y **Dónde se especifica**, para que sea la referencia única de alcance en el desarrollo (reemplaza consultar el `.docx` para esto).

Leyenda de Estado MVP:
- ✅ **MVP** — entra en la beta mínima funcional, tal como está descrito.
- ⚠️ **MVP (ajustado)** — entra, pero con una simplificación respecto al `.docx` original (ver Nota).
- ⏸ **Fase 2** — pospuesto, no se implementa en esta beta.

---

## Requisitos funcionales (RF)

| ID | Requisito | Usuario | Prioridad original | Estado MVP | Dónde se especifica | Nota |
|---|---|---|---|---|---|---|
| RF-01 | Registro y autenticación con control por rol | Admin/Conductor | Alta | ✅ MVP | `Instrucciones del Proyecto.md`, `CLAUDE.md` (Supabase Auth) | Ya implementado. |
| RF-02 | Crear vehículos, conductores, clientes y viajes | Administrador | Alta | ✅ MVP | `Instrucciones del Proyecto.md` (Alcance), `arquitectura-y-estandares.md` §8 | |
| RF-03 | Consultar vehículos, conductores, clientes y viajes | Administrador | Alta | ✅ MVP | PostgREST + RLS | |
| RF-04 | Actualizar vehículos, conductores, clientes y viajes | Administrador | Alta | ✅ MVP | PostgREST/RPC + RLS | Viajes: el administrador edita fecha de salida, peso y flete de un viaje abierto (RPC `viaje_actualizar`, recalcula la comisión estimada); también puede cancelar (`viaje_cancelar`) o eliminar (`viaje_eliminar`) un viaje no cerrado, siempre con motivo. |
| RF-05 | Inhabilitar (baja lógica) vehículos, conductores y clientes | Administrador | Alta | ✅ MVP | `activo = false`, sin borrado físico | |
| RF-06 | El conductor consulta sus propios viajes (completados o no) | Conductor | Media | ✅ MVP | RLS: `conductor.usuario_id = auth.uid()` | |
| RF-07 | Cálculo automático de distancia y tiempo estimado | Admin/Conductor | Media | ✅ MVP | Edge Function `rutas`, RPC `viaje_crear` | |
| RF-08 | Analítica de costos y beneficios de la operación | Administrador | Alta | ✅ MVP | `costo_viaje`, RPC de rentabilidad | Depende de que exista `valor_flete` (ver RF-16). |
| RF-09 | Gestión de fechas de viaje mediante calendario interactivo | Administrador | Alta | ⚠️ MVP (ajustado) | `Instrucciones del Proyecto.md` | MVP: formulario + selector de fecha simple. El calendario visual (vista mensual/semanal) se pospone a Fase 2 — no bloquea probar el cálculo de rentabilidad. |
| RF-10 | Seguimiento de viajes activos y consulta de históricos | Administrador | Media | ✅ MVP | Estados de `viaje`, dashboard "viajes activos" | |
| RF-11 | Estimación de costo de ACPM (distancia, rendimiento, precio) | Sistema | Media | ✅ MVP | `tarifa_combustible`, fórmula en `Instrucciones del Proyecto.md` | Si el origen no tiene tarifa vigente el estimado queda en $0, pero `viaje_crear` registra una notificación `NOVEDAD` «Sin tarifa de ACPM» y el detalle del viaje muestra una advertencia. |
| RF-12 | Tabla de precios de ACPM editable por ciudad/fecha | Administrador | Media | ✅ MVP | `tarifa_combustible` | Pantalla «Tarifas ACPM» (sección Más del administrador): alta de tarifa por ciudad/fecha y corrección de precio. |
| RF-13 | Registro del valor real de ACPM, separado del estimado | Sistema | Media | ✅ MVP | `costo_viaje.valor_estimado` / `valor_real` | |
| RF-14 | Registro manual de costos (cargue, descargue, parqueadero, otros) | Sistema | Media | ✅ MVP | `costo_viaje.categoria` | Categorías fijas editables (valor real) + costos libres: filas `OTRO` con `costo_viaje.descripcion`, que el conductor agrega desde su planilla (siempre como valor real, política RLS `costo_viaje_conductor_agrega_otro`). |
| RF-15 | Cálculo automático de comisión del conductor | Admin/Conductor | Alta | ✅ MVP | `conductor.porcentaje_comision`, `costo_viaje` categoría `COMISION` | Un conductor con pago FIJO no genera comisión en el viaje (cobra solo sueldo fijo prorrateado). |
| RF-16 | Cálculo de rentabilidad marginal (ingreso − costos directos − comisión) | Sistema | Alta | ⚠️ MVP (ajustado) | `arquitectura-y-estandares.md` §8 | **Requiere `viaje.valor_flete`** (no existía ningún campo de ingreso). Fórmula: `flete − (ACPM + peajes + cargue + descargue + parqueadero + otros + comisión)`. Mantenimiento amortizado y sueldo fijo quedan fuera de la marginal. |
| RF-17 | Cálculo de rentabilidad consolidada por período (prorratea sueldo fijo) | Sistema | Alta | ✅ MVP | RPC `rentabilidad_consolidada` | Aquí sí entra el mantenimiento amortizado + sueldo fijo prorrateado. El mantenimiento se registra desde la hoja de vida del vehículo (Flota → vehículo → Registrar mantenimiento); ya no existe una pantalla global de Mantenimiento. |
| RF-18 | Registro de hitos del viaje (salida, cargue, salida con carga, destino) | Conductor | Baja | ✅ MVP | `hito_viaje` | Los hitos pasan por la RPC `viaje_registrar_hito`: orden obligatorio, sin repetir, y LLEGADA_DESTINO deja el viaje FINALIZADO. |
| RF-19 | Comparar hora de cada hito contra el tiempo estimado de ruta | Sistema | Baja | ✅ MVP | `Instrucciones del Proyecto.md` §Seguimiento | |
| RF-20 | Notificar al administrador ante retraso significativo | Sistema | Media | ⚠️ MVP (ajustado) | `Instrucciones del Proyecto.md` §Seguimiento | Umbral definido: 20% del tiempo estimado del tramo o 30 min, lo mayor. No estaba cuantificado en el original. Implementado en `notificacion_generar` (sobre el tiempo total del viaje). Solo notificación in-app; push (FCM) pendiente de decisión. |
| RF-21 | Registro periódico de ubicación del conductor durante el viaje | Sistema | Media | ⚠️ MVP (ajustado) | Ya excluido como "tracking GPS pasivo" en `arquitectura-y-estandares.md` / `CLAUDE.md` | Autorizado 2026-10-10. Un punto cada ~5 min, solo con consentimiento (RF-23), viaje EN_CURSO y app abierta (con servicio en primer plano de Android). Tabla `ubicacion_viaje` append-only; el admin ve la última ubicación en el mapa del viaje. |
| RF-22 | Notificación por detención prolongada sin hito registrado | Sistema | Baja | ⚠️ MVP (ajustado) | Decisión de mapas (2026-10) | El teléfono detecta parada (30 min) y desvío de ruta (1 km) con la app abierta y envía solo un evento puntual (`viaje_registrar_alerta`) que notifica al administrador. La posición NO se persiste (RF-21 sigue en Fase 2). En Android corre como servicio en primer plano (notificación fija) mientras el viaje está EN_CURSO: sigue con la pantalla bloqueada o la app minimizada, no con la app cerrada del todo. |
| RF-23 | Consentimiento informado para captura de ubicación | Sistema | Media | ✅ MVP | — | Pregunta en el mapa del conductor; se guarda en `conductor.consentimiento_ubicacion_fecha` (RPC `conductor_consentimiento_ubicacion`). Sin consentimiento la RPC de ubicación rechaza (OR122). |
| RF-24 | Dashboard de métricas de negocio (ingresos, costos, margen, costo/km) | Administrador | Alta | ✅ MVP | `Instrucciones del Proyecto.md` §Dashboard | Costo por km = costos directos ÷ km estimados de los viajes cerrados (RPC `metricas_periodo`). |
| RF-25 | Métricas de rendimiento (por ruta/cliente/conductor, cumplimiento, utilización) | Administrador | Alta | ✅ MVP | `Instrucciones del Proyecto.md` §Dashboard | Falta detallar en `arquitectura-y-estandares.md` las vistas/RPC exactas para "cumplimiento de tiempos" y "utilización de flota" — Implementado con las RPC `metricas_periodo` y `metricas_por_dimension` (ruta/cliente/conductor). Cumplimiento = viajes cuya duración real ≤ estimada + margen RF-20; utilización = días-viaje ÷ (vehículos activos × días del período). |
| RF-26 | Visualización de alertas activas (vencimientos, retrasos) | Sistema | Media | ✅ MVP | `documento_vehiculo.fecha_vencimiento`, RF-20 | El Resumen del administrador lista las notificaciones sin leer. Desde 2026-10-11 también avisa SOAT/tecnomecánica a 30 días, a 7 días y vencidos (una alerta por documento y escalón), mantenimiento preventivo próximo/vencido y fallas de checklist (RF-29 a RF-32). |
| RF-27 | Filtros de reportes (fecha, ruta, cliente, conductor, vehículo) | Sistema | Baja | ✅ MVP | No estaba en el "Alcance" de `Instrucciones del Proyecto.md` | Pantalla Reportes (Más) con selector de 10 informes (viajes cerrados, estado de resultados, rentabilidad por ruta/cliente/conductor/placa, desglose de costos, puntualidad, tiempos de espera, estado de flota, desempeño por conductor, satisfacción, calidad). Cada uno muestra solo los filtros que su RPC acepta (fecha de cierre, ruta, cliente, conductor, vehículo) y la agrupación posible. |
| RF-28 | Exportación de reportes (ej. PDF) desde la app | Sistema | Baja | ✅ MVP | Igual que RF-27 | Exportación a PDF del informe en pantalla (paquetes `pdf` + `printing`). |
| RF-29 | Documentos del vehículo (SOAT y revisión técnico-mecánica) con bloqueo al comenzar el viaje | Administrador | Alta | ✅ MVP | Decisión del dueño (2026-10-11) | Renovar o corregir = fila nueva en `documento_vehiculo` vía RPC `documento_vehiculo_registrar` (historial; vigente = el último registrado; genera las alertas al instante). `viaje_iniciar` rechaza (OR132) si falta o venció el SOAT o la tecnomecánica; vence hoy = vigente hoy (zona America/Bogota). Tarjeta de operación y pólizas quedan fuera. |
| RF-30 | Checklist pre-operacional del vehículo antes de cada viaje | Conductor | Alta | ✅ MVP | Decisión del dueño (2026-10-11) | 26 ítems en `checklist_item` (2 solo de mula). RPC `checklist_registrar` en viaje ASIGNADO; falla en ítem crítico ⇒ BLOQUEADO hasta que el administrador autorice con motivo (`checklist_autorizar_salida`); falla no crítica ⇒ solo alerta. `viaje_iniciar` exige un checklist de las últimas 12 h (OR137/OR138). Append-only, sin fotos. |
| RF-31 | Kilometraje real del viaje y odómetro del vehículo | Sistema | Media | ⚠️ MVP (ajustado) | Decisión del dueño (2026-10-11) | Solo GPS acumulado (`ubicacion_viaje`), sin lectura manual del tablero: `viaje.km_recorridos` al finalizar, con `km_origen` GPS o ESTIMADO (si el GPS cubre menos de la mitad de la distancia estimada). Odómetro = `odometro_inicial_km` + km de viajes finalizados; es aproximado. |
| RF-32 | Hoja de vida del vehículo y mantenimiento preventivo por km/tiempo | Administrador | Media | ✅ MVP | Decisión del dueño (2026-10-11) | Ficha técnica en `vehiculo`; plan por vehículo (`plan_mantenimiento`, intervalos sugeridos del catálogo `tipo_mantenimiento`, a validar con el taller); estado AL_DIA/PROXIMO/VENCIDO por RPC y alertas en `notificacion_generar`; registrar mantenimiento (`mantenimiento_registrar`) reinicia el contador. Línea de tiempo `vehiculo_hoja_vida` (viajes, mantenimientos, checklists, documentos). Solo alerta, no bloquea. |
| RF-33 | Encuesta de satisfacción del cliente al finalizar el viaje y analítica de satisfacción | Sistema / Administrador | Media | ✅ MVP | Decisión del dueño (2026-10-12), RF-24/25 | Al pasar el viaje a FINALIZADO nace `encuesta_satisfaccion` (token único, cliente/conductor/vehículo y tiempos precargados). Google Form + Apps Script envía el enlace por correo y devuelve la respuesta a la Edge Function `encuestas`. CSAT 1–5 en 4 dimensiones (entrega, servicio, atención, puntualidad) + NPS 0–10 + comentario. Pestaña «Satisfacción» del Resumen (RPC `satisfaccion_*`): CSAT, NPS, puntualidad real vs. percibida, ranking por ruta/cliente/conductor, comentarios y cobertura. Vigencia 14 días, sin recordatorio. Respuesta baja (alguna dimensión ≤ 2 o NPS ≤ 6) ⇒ alerta `SATISFACCION_BAJA`. WhatsApp: copiar mensaje con enlace desde el detalle del viaje; QR pospuesto. |

## Requisitos no funcionales (RNF)

### Usabilidad

| ID | Requisito | Prioridad original | Estado MVP | Dónde se especifica |
|---|---|---|---|---|
| RNF-01 | Interfaz exclusiva para móvil, sin cliente web | Medio | ✅ MVP (estructural) | Decisión de stack, `CLAUDE.md` |
| RNF-02 | Dashboard adaptable con tarjetas KPI | Medio | ✅ MVP | `sistema-de-diseno.md` |
| RNF-03 | Registro de hitos/costos en pocos pasos | Medio | ✅ MVP | `Instrucciones de Identidad Visual.md`, `sistema-de-diseno.md` |
| RNF-04 | Mensajes de error en lenguaje de negocio, sin jerga técnica | Medio | ✅ MVP | `arquitectura-y-estandares.md` §9, `sistema-de-diseno.md` |

### Rendimiento

| ID | Requisito | Prioridad original | Estado MVP | Dónde se especifica |
|---|---|---|---|---|
| RNF-05 | Consultas de listado con tiempo de respuesta aceptable, paginadas | Alta | ✅ MVP (mínimo) | Paginación ya exigida en `arquitectura-y-estandares.md` §10; sin metas numéricas — no son necesarias con 4 vehículos. |
| RNF-06 | Cálculo de estimados (ruta, ACPM) sin bloquear la interacción | Media | ✅ MVP (mínimo) | Se cumple por diseño (RPC síncrona simple); no requiere trabajo adicional. |

### Disponibilidad y conectividad

| ID | Requisito | Prioridad original | Estado MVP | Dónde se especifica |
|---|---|---|---|---|
| RNF-07 | Operación con conectividad intermitente (guardado local + sync) | Alta | ⚠️ MVP (acotado — confirmado) | `Instrucciones del Proyecto.md` §Conectividad | Acotado a cola local de hitos y costos manuales del viaje en curso, con sincronización automática al recuperar señal. No es offline-first completo: no se navega ni consulta histórico sin conexión. Confirmado por el usuario. |
| RNF-09 | Distinguir pérdida de señal de una detención real | (sin prioridad) | ⏸ Fase 2 | Solo aplica junto con RF-21/22 (tracking). |

### Seguridad

| ID | Requisito | Prioridad original | Estado MVP |
|---|---|---|---|
| RNF-10 | Autenticación con token de expiración | Alta | ✅ MVP (estructural — ya implementado, Supabase Auth) |
| RNF-11 | Control de acceso por rol también del lado servidor | (sin prioridad) | ✅ MVP (estructural — RLS) |
| RNF-12 | Contraseñas con hash seguro, nunca en texto plano | (sin prioridad) | ✅ MVP (estructural — Supabase Auth/bcrypt) |
| RNF-13 | Ninguna credencial en el código fuente | (sin prioridad) | ✅ MVP (estructural — ya documentado en `.env.example`) |
| RNF-14 | Validar y sanear toda entrada de datos del cliente | (sin prioridad) | ✅ MVP (estructural) |
| RNF-15 | Principio de mínimo privilegio por conductor | (sin prioridad) | ✅ MVP (estructural — RLS) |

*(No existe RNF-08 en el documento original; la numeración salta de RNF-07 a RNF-09.)*

### Legalidad y privacidad

| ID | Requisito | Prioridad original | Estado MVP |
|---|---|---|---|
| RNF-16 | Autorización de tratamiento de datos de ubicación (habeas data) | (sin prioridad) | ⏸ Fase 2 — solo aplica si se activa RF-21 |
| RNF-17 | Uso de datos de ubicación limitado a fines operativos | (sin prioridad) | ⏸ Fase 2 — igual que RNF-16 |

---

## Resumen para Fase 2 (pospuesto, no se documenta como MVP)

- Tracking de ubicación del conductor y sus dependientes: RF-21, RF-22, RF-23, RNF-09, RNF-16, RNF-17.
- Calendario interactivo completo (RF-09 se resuelve en MVP con formulario simple).
- Filtros y exportación de reportes (RF-27, RF-28).
- Offline-first completo más allá de hitos/costos manuales (alcance de RNF-07 confirmado y acotado; ver tabla de Disponibilidad y conectividad).
