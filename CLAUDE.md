# CLAUDE.md — OptiRuta

Sistema de información para empresa colombiana de transporte de carga pesada. Flota de 4 vehículos (3 doble troque, 1 mula). Digitaliza vehículos, conductores, clientes y viajes, y calcula la **rentabilidad aproximada por viaje** combinando datos estimados (distancia, ACPM, mantenimiento amortizado, peajes por correo) con datos reales confirmados por el conductor.

Documentación fuente: [Documentacion/Esquemas/](Documentacion/Esquemas/). Ante conflicto de **dominio** (reglas de viajes, rentabilidad, campos), esos documentos mandan. La sección **Stack** de este archivo **supersede** cualquier referencia a Dart Frog / MySQL en esos esquemas: el proyecto usa Supabase. Actualizar los esquemas cuando toque tocarlos; no reintroducir el stack viejo.

Trazabilidad RF/RNF → estado MVP / Fase 2: [Documentacion/Esquemas/requisitos-funcionales-y-no-funcionales.md](Documentacion/Esquemas/requisitos-funcionales-y-no-funcionales.md). Esta beta es un **MVP**, no el sistema completo del documento de requisitos original.

## Stack (obligatorio)

- **App móvil**: Flutter, Clean Architecture + BLoC/Cubit. Única interfaz (no hay web). Vistas por rol. La capa `data` habla con Supabase mediante el paquete `supabase_flutter`.
- **Backend-as-a-Service**: **Supabase**. No hay servidor de aplicación propio.
  - **BD**: PostgreSQL gestionado. Acceso siempre parametrizado (cliente Supabase / PostgREST / funciones RPC). Migraciones versionadas con **Supabase CLI**.
  - **Auth**: **Supabase Auth (GoTrue)**. Email + contraseña. JWT (~1h) + refresh token gestionados por Supabase. Sin auth propia.
  - **API de datos**: PostgREST autogenerada (tablas, vistas, funciones RPC) consumida desde la app.
  - **Lógica de servidor**: funciones **RPC en PL/pgSQL** para operaciones de dominio multi-paso y transaccionales. **Edge Functions (TypeScript / Deno)** SOLO para lo que no puede vivir en Postgres: webhook de correo GoPass y llamada a proveedor externo de rutas.
  - **Storage**: buckets de Supabase para documentos de vehículo, recibos y evidencias.
  - **Programado**: `pg_cron` para notificaciones y tareas periódicas.

Roles: `ADMINISTRADOR`, `CONDUCTOR`. Se guardan en `app_metadata.rol` del usuario de Supabase Auth, viajan en el JWT y se hacen cumplir con **políticas RLS**.

## Prioridades (ningún cambio puede violar este orden)

`simplicidad → mantenibilidad → seguridad → escalabilidad → consistencia`

No microservicios, event sourcing, CQRS, hexagonal, colas ni bus de eventos. **No usar Supabase Realtime como bus de eventos de negocio** (solo para refrescar vistas de la UI, p. ej. dashboard de viajes activos). No abstracciones para escenarios hipotéticos (multiempresa, escalado horizontal, microservicios futuros).

## Dónde vive cada cosa

| Lugar | Hace | No hace |
|---|---|---|
| App Flutter — `presentation` | Widgets reaccionan a estados de BLoC/Cubit | Llamar a Supabase directo; contener reglas de negocio |
| App Flutter — `domain` | Entidades, casos de uso, contratos de repositorio | Saber si el dato viene de red o caché |
| App Flutter — `data` | Implementa repositorios con `supabase_flutter` (PostgREST, RPC, Auth, Storage); mapea DTO↔entidad | Reglas de dominio que deban garantizarse del lado servidor |
| PostgreSQL — constraints, RLS, triggers, vistas | Integridad, acceso por rol/propietario, auditoría automática, cálculos deterministas simples (columnas generadas) | Orquestación multi-paso con lógica condicional |
| PostgreSQL — funciones RPC (PL/pgSQL) | Operaciones de dominio multi-paso y transaccionales: cerrar viaje, registrar ajuste, calcular rentabilidad, cambiar estado | Llamadas HTTP salientes arbitrarias; integraciones externas |
| Edge Functions (TS / Deno) | Solo integraciones: webhook GoPass, proveedor de rutas. Validan entrada, delegan a RPC, traducen errores | Reglas de negocio que ya estén (o puedan estar) en Postgres |

- **Ninguna regla de negocio vive únicamente en la app.** Toda regla que afecte dinero, estados de viaje o acceso a datos se garantiza en Postgres (constraints + RLS + RPC). La app valida por UX, nunca como única defensa.
- No duplicar una regla entre app y Postgres: si está en la BD, la app solo la consume.

## Estructura

**Repo**:

- `app/` — proyecto Flutter.
  - `lib/core/`, `lib/features/<feature>/{data,domain,presentation}/`. Organizar por feature, no por tipo técnico.
- `supabase/`
  - `migrations/` — SQL versionado (`<timestamp>_descripcion_snake_case.sql`, generado por Supabase CLI).
  - `functions/<nombre>/` — Edge Functions (`peajes-correo`, `rutas`, `precio-acpm-scraper`, `encuestas`).
  - `apps-script/` — script de Google Apps Script de la encuesta de satisfacción (se copia a mano al Form; no se despliega con la CLI).
  - `seed.sql` — datos base para desarrollo local.
  - `tests/` — pruebas `pgTAP`.
  - `config.toml`.
- `app/test/` — espejo de `lib/features/`.

## Dominio: viajes

- Ciclo de vida: `PLANIFICADO → ASIGNADO → EN_CURSO → FINALIZADO → CERRADO`. Estado terminal adicional `CANCELADO` (decisión del dueño, 2026-10-10): lo alcanza cualquier estado no cerrado vía la RPC `viaje_cancelar(p_viaje_id, p_motivo)` (motivo obligatorio, solo administrador); no cuenta en rentabilidad ni métricas.
- Editable hasta `CERRADO`. Transiciones validadas en la función RPC `viaje_cambiar_estado` + trigger que rechaza transiciones inválidas.
- Un viaje cerrado **no se edita ni se borra**: todo cambio se registra en `ajuste_viaje` (append-only) vía la RPC `viaje_registrar_ajuste(p_viaje_id, p_motivo, …)` con **motivo obligatorio**. `ajuste_viaje` tiene RLS solo con políticas de `INSERT` y `SELECT` (sin `UPDATE`/`DELETE`), y se revoca `UPDATE`/`DELETE` al rol de la app. Un viaje **no cerrado** sí se puede eliminar (decisión del dueño, 2026-10-10) únicamente vía la RPC `viaje_eliminar(p_viaje_id, p_motivo)` (solo administrador, motivo obligatorio), que deja una fila en la bitácora append-only `viaje_eliminado`; no hay `DELETE` directo.
- Todo dato automático se guarda como par **`valor_estimado` / `valor_real`** separados, editables y auditables. Excepción: `viaje.valor_flete` es un monto pactado con el cliente, capturado por el administrador al crear el viaje — un único valor, no un par estimado/real.
- Rentabilidad marginal: `valor_flete − (ACPM + peajes + cargue + descargue + parqueadero + otros + comisión variable)`. El mantenimiento amortizado y el sueldo fijo prorrateado **no** entran aquí, solo en la consolidada por período.
- ACPM estimado = `distancia ÷ rendimiento_km_galon × precio_galon`, con factor de ajuste simple por rango de tonelaje (no modelo estadístico). Precio en tabla `tarifa_combustible` (ciudad + fecha de vigencia). El cálculo vive en RPC o columna generada, no en la app.
- Hitos registrados por el conductor: `SALIDA`, `LLEGADA_CARGUE`, `SALIDA_CON_CARGA`, `LLEGADA_DESTINO`. Se comparan contra el tiempo estimado para detectar retrasos.
- Ubicación en mapa: origen y destino se eligen con buscador + mapa (OpenStreetMap, gratis, solo Android: `flutter_map` dibuja el mapa, limitado a Colombia; el autocompletado de lugares con Photon y la ruta con OSRM pasan por la Edge Function `rutas`, sin API key) y se guardan como texto + coordenadas (`origen_lat/lng`, `destino_lat/lng`, nullables para viajes antiguos). El mapa del conductor muestra su posición en vivo. Con el viaje `EN_CURSO` el teléfono detecta parada prolongada (30 min) y desvío de ruta (1 km) y envía un evento puntual vía la RPC `viaje_registrar_alerta`, que notifica al administrador. **Registro de ubicación (RF-21/23, autorizado 2026-10-10):** solo con consentimiento del conductor (`conductor.consentimiento_ubicacion_fecha`, RPC `conductor_consentimiento_ubicacion`), solo con el viaje `EN_CURSO` y la app abierta, la app envía un punto cada ~5 min vía `viaje_registrar_ubicacion` a `ubicacion_viaje` (append-only, el administrador lo ve en el mapa del viaje). En Android el seguimiento corre como servicio en primer plano (geolocator, notificación fija) mientras el viaje está `EN_CURSO`, por lo que continúa con la pantalla bloqueada o la app minimizada; `MonitorRutaRegistro` conserva el monitor aunque el conductor cambie de pestaña y lo libera al terminar el viaje o cerrar sesión.
- Peajes: solo vía Edge Function `peajes-correo` (webhook del correo GoPass), protegida con **clave de servicio en cabecera** (secreto de la función), **no** con JWT de Supabase Auth. Extrae placa, peaje, fecha/hora, valor e inserta vía RPC con `service_role`. Sin scraping.
- Rentabilidad **marginal** (por viaje) vs. **consolidada** (por período) — separadas, en RPC distintas (`rentabilidad_marginal(p_viaje_id)`, `rentabilidad_consolidada(p_desde, p_hasta)`). Sueldo fijo del conductor se calcula por período; la comisión se asocia al viaje.
- No borrar vehículos/conductores: `activo = false`. FK de `viaje` con `ON DELETE RESTRICT`.

## Dominio: flota (vehículos, checklist, mantenimiento)

Decisiones del dueño, 2026-10-11 (RF-29 a RF-32):

- **Bloqueo al comenzar** (`viaje_iniciar`): SOAT y tecnomecánica vigentes (`documento_vehiculo`, el **último registrado** por tipo —corregir un vencimiento es registrar otro—; vence hoy = vigente hoy, zona America/Bogota) y checklist del viaje de las últimas 12 h sin bloqueo pendiente. Tarjeta de operación y pólizas **no** entran. Crear/asignar un viaje no se bloquea: solo se bloquea salir.
- **Checklist** (`checklist_viaje` / `checklist_respuesta` / `checklist_autorizacion`, append-only, solo vía RPC `checklist_registrar` y `checklist_autorizar_salida`): falla en ítem crítico ⇒ BLOQUEADO hasta autorización del administrador con motivo; falla no crítica ⇒ alerta al administrador (`CHECKLIST_FALLA`). El catálogo `checklist_item` se carga por migración, sin editor.
- **Kilometraje**: solo GPS acumulado (sin lectura manual del tablero). `viaje_fijar_km` lo calcula al finalizar (`viaje.km_recorridos` + `km_origen` GPS/ESTIMADO). El odómetro del vehículo es **derivado** (`odometro_inicial_km` + km de viajes finalizados, o su distancia estimada si no hay medición), nunca una columna actualizada a mano; es aproximado.
- **Mantenimiento preventivo**: `plan_mantenimiento` por vehículo (copia de `tipo_mantenimiento` al crear el vehículo, por trigger); estado AL_DIA/PROXIMO/VENCIDO calculado en `plan_mantenimiento_calculo()` y consumido por `notificacion_generar`. Solo alerta, no bloquea. Registrar vía RPC `mantenimiento_registrar`, **desde la hoja de vida del vehículo** (Flota → vehículo → «Registrar mantenimiento»; no hay pantalla global de Mantenimiento).
- **Hoja de vida**: `vehiculo_hoja_vida` arma la línea de tiempo al vuelo desde las tablas de origen; no hay copia que mantener.
- Alertas de flota deduplicadas por `notificacion.clave` (documento+escalón, plan+ciclo), no por vehículo.

## Dominio: satisfacción del cliente

Decisiones del dueño, 2026-10-12 (RF-33):

- **Encuesta post-viaje** (`encuesta_satisfaccion`, una por viaje): nace sola cuando el viaje pasa a `FINALIZADO` (trigger delgado `viaje_finalizado_crear_encuesta` → `encuesta_crear_para_viaje`; el viaje finaliza por dos RPC distintas). Lleva token único, snapshot de cliente/conductor/vehículo y tiempos estimado/real. Sin correo del cliente ⇒ `SIN_CONTACTO` (se comparte a mano). Solo se escribe por RPC; RLS: solo el administrador lee.
- **Fuente externa**: Google Form + Apps Script (`supabase/apps-script/encuestas.gs`). Apps Script envía el correo (MailApp, gratis) y reenvía las respuestas a la Edge Function `encuestas` (clave de servicio en cabecera `ENCUESTAS_SECRET`, sin JWT; guarda solo ese secreto, nunca la `service_role`). La función solo valida, delega en las RPC `encuesta_pendientes_envio` / `encuesta_registrar_envio` / `encuesta_registrar_respuesta` (solo `service_role`) y traduce errores.
- **Escala**: CSAT 1–5 en entrega, servicio, atención y puntualidad percibida + NPS 0–10 + comentario. Vigencia 14 días (`encuesta_vencer`, `pg_cron` diario), sin recordatorio. Respuesta con alguna dimensión ≤ 2 o NPS ≤ 6 ⇒ notificación `SATISFACCION_BAJA`.
- **Puntualidad real vs. percibida**: la real sale de los hitos con el mismo criterio de `metricas_periodo_v2` (estimado + el mayor entre 20 % y 30 min); la percibida es la pregunta del cliente. No se mezclan.
- **Resumen** se divide en pestañas «Costos \| Satisfacción» (`AdminSection.analitica` / `satisfaccion`). Semáforo (solo presentación): CSAT verde ≥ 4,2, ámbar 3,5–4,2, rojo < 3,5; NPS verde ≥ 50, ámbar 0–50, rojo < 0; menos de 5 respuestas ⇒ «Sin datos suficientes».
- **Pospuesto**: QR (requiere paquete nuevo), WhatsApp automático (Cloud API de pago; hoy se copia el mensaje con el enlace), recordatorio de encuesta.

## Patrones

- **Un repositorio por entidad raíz** en `data`. **Un caso de uso por operación** en `domain`.
- **Funciones RPC**: una por operación de dominio multi-paso. Nombre `<agregado>_<accion>` (`viaje_cerrar`, `viaje_registrar_ajuste`, `viaje_cambiar_estado`, `rentabilidad_marginal`, `rentabilidad_consolidada`).
- **Strategy**: SOLO para rentabilidad — dos RPC separadas (marginal / consolidada), no un motor genérico.
- **Adapter**: SOLO en `supabase/functions/` — cada integración externa (rutas, procesador de peaje) detrás de un módulo con interfaz y una implementación por proveedor.
- **DI por constructor** en el código Dart (`domain`/`data`) y en los módulos de Edge Functions. Sin variables globales, sin singletons manuales.
- Triggers SOLO para auditoría, integridad y append-only. La lógica con ramas va en RPC, no en triggers.
- Prohibidos sin justificar el problema concreto: Factory, Observer, Builder, cualquier patrón nuevo. Notificaciones = job de `pg_cron` que consulta y dispara push.

## Seguridad

- **Contraseñas y tokens los gestiona Supabase Auth** (bcrypt internamente; JWT ~1h + refresh token). Logout = `supabase.auth.signOut()`, que revoca el refresh token.
- **RLS obligatorio en TODAS las tablas.** Sin RLS habilitado = tabla inaccesible. Ninguna política permisiva sin comprobación explícita de rol y/o propietario.
- **Denegar por defecto**: la `anon key` solo permite lo que las políticas RLS autoricen; todo requiere sesión salvo el flujo de login. El rol se lee de `auth.jwt() -> 'app_metadata' ->> 'rol'` en las políticas.
- Conductor: políticas RLS que lo limitan a `SELECT`/`INSERT`/`UPDATE` de sus propios `viaje` e `hito`; sin acceso a datos financieros de otros ni a configuración administrativa.
- La `service_role key` **NUNCA** se incluye en la app; solo en Edge Functions / secretos del proyecto. La `anon key` sí va en la app (es pública por diseño; la seguridad la da RLS).
- SQL siempre parametrizado: el cliente Supabase y PostgREST parametrizan; en PL/pgSQL usar parámetros, `USING` y `format(%L/%I)`, **nunca concatenar**.
- Secretos por variables de entorno / secretos de Edge Functions y del proyecto Supabase; `.env` nunca se commitea, mantener `.env.example` con `SUPABASE_URL`, `SUPABASE_ANON_KEY` y los nombres de los secretos de funciones.
- Errores: las Edge Functions nunca devuelven errores crudos de Postgres, `SQLSTATE` ni nombres de tablas/columnas; traducen a códigos de dominio. Las RPC lanzan `RAISE EXCEPTION` con `ERRCODE` propio mapeado a mensaje de dominio en español.
- Auditar creación, asignación, modificación, cierre y ajustes: columnas `creado_por`, `fecha_creacion`, `modificado_por`, `fecha_modificacion` pobladas por trigger (`auth.uid()`), más `ajuste_viaje`.
- Migraciones en prod vía Supabase CLI en CI (no a mano en la consola). El proceso de despliegue es el único que aplica `DROP`/`ALTER`.

## APIs / contratos

Dos superficies:

1. **PostgREST autogenerada** (tablas, vistas, RPC) consumida con `supabase_flutter`.
   - Tablas/columnas: `snake_case`, singular. Vistas para listados de lectura con joins.
   - Funciones RPC: `snake_case`, nombre `<agregado>_<accion>`; parámetros `p_<nombre>`.
   - Paginación: `.range(from, to)` de PostgREST, o parámetros `p_page` / `p_size` en RPC. Filtros/orden explícitos por parámetro, nunca construidos como string en la app.
   - El cliente que consume PostgREST no lleva lógica de negocio: solo lee/escribe datos ya validados por constraints/RLS/triggers.
2. **Edge Functions** (solo integraciones), rutas estables con prefijo `v1`:
   - `POST /functions/v1/peajes-correo` — webhook GoPass, auth por clave de servicio en cabecera.
   - `POST /functions/v1/rutas` — estimación de distancia/tiempo vía proveedor externo.
   - `POST /functions/v1/encuestas` — puente con el Google Form de satisfacción; operación en el cuerpo (`accion`: `PENDIENTES`, `ENVIO`, `RESPUESTA`), auth por clave de servicio en cabecera.
   - Cuerpo de error consistente: `{ timestamp, status, error (CODIGO_MAYUS_GUION), message (español), path }`.
   - Códigos: `200/201/204/400/401/403/404/409`; `422` para reglas de negocio; `500` solo no controlados.

- Cambios incompatibles en una RPC = nueva función `_v2`; no romper la existente mientras haya app vieja en uso.

## Testing

- **Unitario** (sin BD): casos de uso de `domain` en Flutter (mocks de repositorio); lógica pura de Edge Functions (mocks del cliente Supabase y del proveedor externo). Cálculo de ACPM estimado, validaciones de reglas.
- **Integración** (Supabase local vía `supabase start`, Docker):
  - `pgTAP` para constraints, políticas RLS (conductor no ve viajes ajenos), triggers de auditoría, append-only de `ajuste_viaje`, y funciones RPC (transiciones de estado, rentabilidad marginal vs. consolidada).
  - `deno test` para Edge Functions contra el stack local.
- **E2E**: solo flujos críticos (login, crear/asignar viaje, registrar hitos, cerrar viaje).
- No testear getters/setters, mappers triviales, DTOs sin lógica, config base.
- Prioridad de cobertura: reglas de negocio y RLS > auth > integraciones externas > CRUD simple.

## Convenciones

- **Idioma del código**: decisión única del equipo (inglés o español), no mezclar. Español siempre para textos visibles al usuario y documentación de negocio.
- Archivos Dart: `snake_case` (`viaje_repository.dart`). Clases: `PascalCase`. Variables/funciones: `camelCase`.
- Edge Functions: carpeta y archivos `kebab-case`; símbolos TS `camelCase` / `PascalCase`.
- Tablas / columnas / funciones SQL: `snake_case`, singular.
- Migraciones: generadas por Supabase CLI (`<timestamp>_descripcion_snake_case.sql`). **Nunca editar una migración ya mergeada a `main`**: crear una nueva.
- `dart format` obligatorio; `deno fmt` para Edge Functions (no se discute formato en review). Logs estructurados, nunca `print()` / `console.log` suelto. Propagar `x-request-id` en Edge Functions.
- Comentarios: solo para decisiones no obvias, en el idioma del código.

## Git

- `main` siempre estable. Ramas cortas `feature/…`, `fix/…`, `chore/…`. Conventional Commits.
- No merge a `main` sin review y sin build/tests en verde (incluye: migraciones aplican en un stack local limpio y `pgTAP` pasa). `rebase` sobre `main` antes del PR. Merge vía PR aprobado con **squash**.

## Identidad visual (app)

- Concepto (v2): **herramienta profesional con trato cercano y moderno**. Función sobre decoración. Spec completa en `Documentacion/Diseno-v2/sistema-de-diseno-v2.md`.
- Prioridad: `legibilidad → jerarquía → eficiencia → consistencia → estética`.
- Paleta única, alineada al logo (azul oscuro, rojo oscuro, gris, blanco). Principales (dominan la UI): azul marino `#14273F`, gris pizarra `#333A45`, gris claro `#F3F4F6`, blanco `#FFFFFF`. Acción principal: azul de acción `#1E3A5F` (botón primario, texto blanco). Acento de marca: rojo `#A62C2C` (logo, franja lateral de card, indicador activo de navegación, anillo de foco, botón destructivo) — nunca como fondo completo. Estados: verde éxito `#2E7D52`, ámbar advertencia `#C6871B` (texto oscuro encima), rojo error `#C43D2E`. Colores de estado solo para estados/badges, siempre con icono + label, nunca como fondo completo ni decoración. El primario nunca es rojo: acción y peligro no se confunden.
- Tipografía: una sola sans-serif (Inter o IBM Plex Sans). Números tabulares para cantidades, costos, distancias, porcentajes.
- Botones rectangulares con esquinas de 12 (no pill). Radios: 6 / 12 / 16 (cards) / 24 (hojas); pill solo en badges y chips. Dos niveles de elevación. Un único primario por pantalla, en azul de acción `#1E3A5F`; secundarios outline; destructivos en rojo de marca.
- Formularios: borde definido, fondo blanco, labels siempre visibles (no solo placeholder). **Diferenciar visualmente valores automáticos de los ingresados manualmente.** Minimizar escritura: selectores y valores precargados.
- Tablas: separadores finos, encabezado fijo en scroll, numéricos a la derecha, estados con badges (no filas coloreadas).
- Tarjetas: fondo blanco, sombra sutil, borde definido; franja lateral/superior para estado. Uso: dashboard, viajes activos, vehículos, conductores, resúmenes.
- Navegación inferior fija, 4–5 opciones por rol, ícono + texto.
- Iconos outline, trazo uniforme, simples. Set de iconos: paquete `lucide_icons_flutter` (clase `LucideIcons`), un solo peso/estilo en toda la app — no mezclar con `Icons` de Material. Única excepción admitida: `Icons.g_mobiledata` como marcador de marca de Google en `GoogleButton` (Lucide no incluye logos de terceros; no usar `Icons.*` para nada más). `MarcaIconos.dobleTroque` / `mula` representan vehículos. Sin usar transporte como decoración repetitiva. Sin fotos de stock decorativas; imágenes solo con función (vehículos, recibos, evidencias, documentos). Ilustraciones de línea propias (SVG, vía `flutter_svg`, bajo `assets/illustrations/`) están permitidas como uso secundario y únicamente funcional en estados vacíos/de error destacados (p. ej. `ErrorState(destacado: true)`) — mismos colores de la paleta, nunca decorativas ni de stock. **v2:** los iconos de dominio (doble troque, mula, ruta, hitos, ACPM, peaje, sincronización, estimado/real...) son una familia propia en SVG (`MarcaIcon` / `MarcaIconos`, `assets/icons/`, trazo 1,75, nodo de ruta como rasgo, variante rellena solo en el destino activo de navegación); los genéricos de interfaz siguen siendo `LucideIcons`. Ilustraciones de marca (carretera en S del logo) permitidas en vacío, éxito de cierre y error, una por pantalla; foto de vehículo con imagen de reemplazo de marca. Antes de agregar un ícono nuevo: usar `MarcaIconos` o `LucideIcons`; si no existe, evaluarlo contra este criterio antes de introducir otra fuente.
- Fuente única de verdad para colores, tipografía, espaciado, bordes, radios y componentes reutilizables (botones, inputs, selectores, cards, badges, tablas, alertas, encabezados, navegación). Sin estilos por módulo.

## Fuera del MVP (no implementar)

Seguimiento de ubicación cuando la app fue cerrada del todo (solo funciona mientras el proceso vive; el servicio en primer plano lo mantiene con la pantalla bloqueada o minimizada), push FCM, analítica predictiva, integración RNDC, facturación electrónica DIAN, multiempresa, operadores de peaje distintos de GoPass, soporte web, calendario interactivo (mensual/semanal) para fechas de viaje. (Entraron al alcance el 2026-10-10 por decisión del dueño: registro de ubicación con consentimiento, y filtros + exportación PDF de reportes vía `reporte_viajes`.) Tampoco: servidor de aplicación propio, Supabase Realtime para lógica de negocio, mover a Edge Functions reglas que puedan ir en Postgres.

La actualización automática del precio de ACPM **sí entra en el MVP** (decisión confirmada en `diseno-base-de-datos-optiruta.md` sección 6, que reabrió y cerró esta exclusión): Edge Function `precio-acpm-scraper` + RPC `tarifa_combustible_registrar_automatico` + `pg_cron` mensual, acotada a una sola ciudad de referencia (Medellín) con validación de variación ±15% antes de sobrescribir `tarifa_combustible`.

## Reglas para agentes

1. Verifica la estructura y los archivos existentes antes de crear; no asumas.
2. Reutiliza casos de uso, repositorios, DTOs, mappers, widgets, funciones RPC y Edge Functions existentes; no dupliques lógica de negocio.
3. No agregues dependencias (paquetes Flutter, libs de Edge Functions, extensiones de Postgres) sin justificarlo explícitamente en la tarea/commit.
4. No modifiques archivos fuera del alcance de la tarea; reporta mejoras en vez de aplicarlas. Sin refactors ni cambios de formato masivos no solicitados.
5. Respeta la tabla **Dónde vive cada cosa** y los patrones de la sección Patrones.
6. Cambios sobre viajes cerrados → siempre `ajuste_viaje` vía RPC, nunca `UPDATE`/`DELETE` directo.
7. Toda tabla nueva nace con RLS habilitado y políticas explícitas en la misma migración.
8. Antes de dar por terminada una tarea: la app compila, las migraciones aplican en un stack local limpio, los tests existentes pasan, y hay tests para la lógica nueva (RPC / RLS / casos de uso).
9. Si una tarea implica cambiar la arquitectura definida (servidor propio, otra BD, Realtime como bus, patrón nuevo general), no la implementes: informa la implicación y espera confirmación.
10. Ante información faltante (config, regla no definida), no inventes: señala qué falta y propón una opción concreta.
