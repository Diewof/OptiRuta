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
| RF-04 | Actualizar vehículos, conductores, clientes y viajes | Administrador | Alta | ✅ MVP | PostgREST/RPC + RLS | |
| RF-05 | Inhabilitar (baja lógica) vehículos, conductores y clientes | Administrador | Alta | ✅ MVP | `activo = false`, sin borrado físico | |
| RF-06 | El conductor consulta sus propios viajes (completados o no) | Conductor | Media | ✅ MVP | RLS: `conductor.usuario_id = auth.uid()` | |
| RF-07 | Cálculo automático de distancia y tiempo estimado | Admin/Conductor | Media | ✅ MVP | Edge Function `rutas`, RPC `viaje_crear` | |
| RF-08 | Analítica de costos y beneficios de la operación | Administrador | Alta | ✅ MVP | `costo_viaje`, RPC de rentabilidad | Depende de que exista `valor_flete` (ver RF-16). |
| RF-09 | Gestión de fechas de viaje mediante calendario interactivo | Administrador | Alta | ⚠️ MVP (ajustado) | `Instrucciones del Proyecto.md` | MVP: formulario + selector de fecha simple. El calendario visual (vista mensual/semanal) se pospone a Fase 2 — no bloquea probar el cálculo de rentabilidad. |
| RF-10 | Seguimiento de viajes activos y consulta de históricos | Administrador | Media | ✅ MVP | Estados de `viaje`, dashboard "viajes activos" | |
| RF-11 | Estimación de costo de ACPM (distancia, rendimiento, precio) | Sistema | Media | ✅ MVP | `tarifa_combustible`, fórmula en `Instrucciones del Proyecto.md` | |
| RF-12 | Tabla de precios de ACPM editable por ciudad/fecha | Administrador | Media | ✅ MVP | `tarifa_combustible` | |
| RF-13 | Registro del valor real de ACPM, separado del estimado | Sistema | Media | ✅ MVP | `costo_viaje.valor_estimado` / `valor_real` | |
| RF-14 | Registro manual de costos (cargue, descargue, parqueadero, otros) | Sistema | Media | ✅ MVP | `costo_viaje.categoria` | |
| RF-15 | Cálculo automático de comisión del conductor | Admin/Conductor | Alta | ✅ MVP | `conductor.porcentaje_comision`, `costo_viaje` categoría `COMISION` | |
| RF-16 | Cálculo de rentabilidad marginal (ingreso − costos directos − comisión) | Sistema | Alta | ⚠️ MVP (ajustado) | `arquitectura-y-estandares.md` §8 | **Requiere `viaje.valor_flete`** (no existía ningún campo de ingreso). Fórmula: `flete − (ACPM + peajes + cargue + descargue + parqueadero + otros + comisión)`. Mantenimiento amortizado y sueldo fijo quedan fuera de la marginal. |
| RF-17 | Cálculo de rentabilidad consolidada por período (prorratea sueldo fijo) | Sistema | Alta | ✅ MVP | RPC `rentabilidad_consolidada` | Aquí sí entra el mantenimiento amortizado + sueldo fijo prorrateado. |
| RF-18 | Registro de hitos del viaje (salida, cargue, salida con carga, destino) | Conductor | Baja | ✅ MVP | `hito_viaje` | |
| RF-19 | Comparar hora de cada hito contra el tiempo estimado de ruta | Sistema | Baja | ✅ MVP | `Instrucciones del Proyecto.md` §Seguimiento | |
| RF-20 | Notificar al administrador ante retraso significativo | Sistema | Media | ⚠️ MVP (ajustado) | `Instrucciones del Proyecto.md` §Seguimiento | Umbral definido: 20% del tiempo estimado del tramo o 30 min, lo mayor. No estaba cuantificado en el original. |
| RF-21 | Registro periódico de ubicación del conductor durante el viaje | Sistema | Media | ⏸ Fase 2 | Ya excluido como "tracking GPS pasivo" en `arquitectura-y-estandares.md` / `CLAUDE.md` | Se mantiene la exclusión ya existente; se deja explícita. |
| RF-22 | Notificación por detención prolongada sin hito registrado | Sistema | Baja | ⏸ Fase 2 | Ya excluido como "detección de paradas" | Depende de RF-21. |
| RF-23 | Consentimiento informado para captura de ubicación | Sistema | Media | ⏸ Fase 2 | — | Solo aplica si se activa RF-21. |
| RF-24 | Dashboard de métricas de negocio (ingresos, costos, margen, costo/km) | Administrador | Alta | ✅ MVP | `Instrucciones del Proyecto.md` §Dashboard | |
| RF-25 | Métricas de rendimiento (por ruta/cliente/conductor, cumplimiento, utilización) | Administrador | Alta | ✅ MVP | `Instrucciones del Proyecto.md` §Dashboard | Falta detallar en `arquitectura-y-estandares.md` las vistas/RPC exactas para "cumplimiento de tiempos" y "utilización de flota" — se deja como detalle técnico para cuando se implemente el dashboard, no bloquea este plan. |
| RF-26 | Visualización de alertas activas (vencimientos, retrasos) | Sistema | Media | ✅ MVP | `documento_vehiculo.fecha_vencimiento`, RF-20 | |
| RF-27 | Filtros de reportes (fecha, ruta, cliente, conductor, vehículo) | Sistema | Baja | ⏸ Fase 2 | No estaba en el "Alcance" de `Instrucciones del Proyecto.md` | No es un recorte: nunca estuvo prometido en los esquemas actuales. |
| RF-28 | Exportación de reportes (ej. PDF) desde la app | Sistema | Baja | ⏸ Fase 2 | Igual que RF-27 | |

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
