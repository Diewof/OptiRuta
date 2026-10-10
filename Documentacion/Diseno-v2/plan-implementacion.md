# Plan de implementación del rediseño v2 (Entregable 2)

> Ajustado al estado real de la app: el brief asumía que solo existían las pantallas de autenticación, pero ya hay conductor, viajes, calendario, seguimiento, flota, personas, clientes, notificaciones y analítica. El rediseño es **re-vestir y reorganizar**, no construir desde cero. Cada fase termina con `flutter analyze` limpio y `flutter test` en verde.

| Fase | Contenido | Estado |
|---|---|---|
| **1 · Sistema** | Tokens (color, radios 6/12/16/24/pill, 2 elevaciones, tipografía `hero`, `AppMotion`); 52 iconos propios en SVG (`MarcaIcon`); vehículos e ilustraciones de marca; widgets nuevos (`SemaforoBadge`, `BaseCalculoChip`, `EstadoViajeBadge`, `DatoMarca`, `FiguraRuta`, `VehiculoThumb`, `IlustracionEstadoView`, `SkeletonBlock`, `HojaInferior`); botones planos (sin degradado); `StatusBadge` pill; docs vigentes actualizadas | ✅ |
| **2 · Conductor** | Navegación de 4 destinos con iconos propios; **Inicio** nuevo (cabecera cercana, figura de ruta, miniatura, hilo de hitos animado, hoja de confirmación en 2 toques, costos con estimado → real); Planilla fusionada en Inicio; cierre de sesión en Perfil; chips del historial y tarjeta de viaje renovadas; `ViajeResumen.tipoVehiculo` (embed `vehiculo(placa, tipo)`) | ✅ |
| **3 · Administrador: estructura + control** | Menú lateral reemplazado por **barra inferior de 5** (Resumen · Viajes · Flota · Personas · Más) con sub-navegación entre pantallas hermanas (Calendario↔Seguimiento, Conductores↔Clientes, Perfil↔Notificaciones); **Resumen** nuevo: rentabilidad **consolidada** con cifra animada y base «Confirmada», margen, flota en ruta con pictogramas, viajes en curso (abren su detalle) y desglose de costos; Seguimiento con franja y badge de retraso (RF-20); cierre de sesión en Perfil | ✅ |
| **4 · Administrador: operación** | Flota (miniaturas de marca), Personas (conductores y clientes), Calendario, Seguimiento y Notificaciones con los componentes nuevos (tarjeta de viaje, esqueletos de carga, estados vacío/error con ilustración, chips pill de 48, FAB y radios del sistema). Agendar viaje y formularios heredan tokens y botones; su rediseño de fondo queda para una segunda pasada | ✅ (parcial en formularios) |
| **5 · Detalle de viaje, cierre y pulido** | **Detalle** con rentabilidad **marginal** (flete pactado, sin mantenimiento ni sueldo), estimado vs. real que **se apila al 130 %**, tiempos de hitos, **cierre con confirmación explícita** y éxito con ilustración, **ajustes con motivo obligatorio** (RPC `viaje_registrar_ajuste`, listado de ajustes registrados). Nuevo `AjusteViajeRepository` | ✅ |

Nota de dominio descubierta en la fase 5: `ajuste_viaje` es un **registro append-only**; no cambia los costos de un viaje cerrado (el trigger los congela). El detalle por eso lista los ajustes y no recalcula la rentabilidad.

Falta (fuera de diseño): auditoría con TalkBack y rendimiento en un celular real, semáforo (depende de los umbrales), cola local sin conexión (RNF-07) y rediseño de fondo del formulario de agendar viaje.

## Dependencias con el backend (no se inventan; hay que decidirlas)

| Pendiente | Efecto en la UI |
|---|---|
| **Umbrales y etiquetas del semáforo** | La RPC debe devolver el estado (`ok/warn/bad/none`). Hoy `SemaforoBadge` solo lo dibuja |
| **Qué cuenta como «real»** | Define cuándo la base pasa a «Confirmada» |
| **Corrección de un hito** | No hay «Deshacer»: la hoja avisa «no se puede deshacer» |
| **Quién finaliza el viaje** | Tras el 4.º hito Inicio solo dice «Todos los pasos registrados» |
| **Cierre con costos aún estimados** | El detalle (fase 5) lo avisará; falta definir si se bloquea |
| **Cola local sin conexión (RNF-07)** | **No existe en la app**: no hay almacenamiento local. Por eso no se dibuja el indicador de sincronización ni se promete «se guarda en tu celular». Es trabajo de datos/dominio, no de diseño; el componente y los textos están listos en el prototipo |

## Criterio de cierre de cada fase

`flutter analyze` sin hallazgos · `flutter test` en verde con pruebas de la lógica y de la interacción nueva · revisión visual con la fuente Inter al 100 % y al 130 % de texto · sin dependencias nuevas.
