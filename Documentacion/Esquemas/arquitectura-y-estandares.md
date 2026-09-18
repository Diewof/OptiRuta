# Arquitectura y estándares de desarrollo

## 1. Contexto del proyecto

- Sistema de información para empresa de transporte de carga pesada (Colombia). Flota: 4 vehículos (3 doble troque, 1 mula). Roles: administrador, conductor.
- Toda la interacción del usuario se hace desde una única app móvil (sin cliente web separado), con vistas diferenciadas por rol.
- El sistema digitaliza vehículos, conductores, clientes y viajes, y calcula la rentabilidad aproximada por viaje combinando datos automáticos (distancia, consumo estimado de combustible, mantenimiento amortizado, peajes capturados por correo) con datos confirmados manualmente por el conductor.
- Stack obligatorio:
  - **App móvil**: Flutter, Clean Architecture + BLoC/Cubit. La capa `data` habla con Supabase mediante el paquete `supabase_flutter`.
  - **Backend-as-a-Service**: **Supabase**. No hay servidor de aplicación propio.
    - **Base de datos**: PostgreSQL gestionado por Supabase.
    - **Autenticación**: Supabase Auth (GoTrue).
    - **API de datos**: PostgREST autogenerada (tablas, vistas, funciones RPC).
    - **Lógica de servidor**: funciones **RPC en PL/pgSQL** para operaciones de dominio multi-paso; **Edge Functions (TypeScript / Deno)** solo para integraciones externas (webhook de correo GoPass, proveedor de rutas).
    - **Storage**: buckets de Supabase para documentos, recibos y evidencias.
    - **Programado**: `pg_cron` para notificaciones y tareas periódicas.
- Orden de prioridades del proyecto: simplicidad → mantenibilidad → seguridad → escalabilidad → consistencia. Ninguna decisión puede violar este orden.

> Nota de migración: una versión anterior de este documento definía un backend propio en Dart Frog sobre MySQL. Ese stack quedó descartado. Donde el resto de la documentación aún mencione Dart Frog, MySQL, "Controller/Service/Repository de backend" o `dart_jsonwebtoken`, prevalece lo definido aquí.

## 2. Principios arquitectónicos

1. No usar microservicios, event sourcing, CQRS ni hexagonal architecture completa.
2. Separar responsabilidades: presentación y estado en la app; integridad, acceso y cálculos deterministas en Postgres; orquestación multi-paso en funciones RPC; integraciones externas en Edge Functions.
3. Las reglas de negocio (ciclo de vida del viaje, cálculo de rentabilidad, estimación de ACPM) no dependen de Flutter ni del canal de entrada (app, job programado, webhook de correo): viven en Postgres (constraints + RLS + RPC).
4. Todo dato automático debe quedar como campo "estimado" y campo "real" separados, editables y auditables.
5. Los viajes cerrados no se editan ni se borran directamente: cualquier cambio se registra como un ajuste enlazado (ver sección 8).
6. No construir abstracciones para escenarios hipotéticos de escalabilidad o multiempresa fuera del alcance actual.
7. No usar Supabase Realtime como bus de eventos de negocio; solo para refrescar vistas de la UI (p. ej. dashboard de viajes activos).

## 3. Arquitectura seleccionada

### Dónde vive cada cosa

| Lugar | Responsabilidad | No hace |
|---|---|---|
| **App Flutter — `presentation`** | Widgets + BLoC/Cubit. Los widgets reaccionan a estados; no llaman a Supabase directo. | Lógica de negocio |
| **App Flutter — `domain`** | Entidades del dominio (independientes de Flutter y de la fuente de datos) + casos de uso. | Saber si el dato viene de red o de caché local |
| **App Flutter — `data`** | Repositorios y datasources sobre `supabase_flutter` (PostgREST, RPC, Auth, Storage) + almacenamiento local para modo offline. Mapea DTO↔entidad. | Reglas de dominio que deban garantizarse del lado servidor |
| **PostgreSQL — constraints, RLS, triggers, vistas** | Integridad referencial, acceso por rol/propietario, auditoría automática, cálculos deterministas simples (columnas generadas). | Orquestación multi-paso con lógica condicional |
| **PostgreSQL — funciones RPC (PL/pgSQL)** | Operaciones de dominio multi-paso y transaccionales: crear viaje, cambiar estado, cerrar viaje, registrar ajuste, calcular rentabilidad. | Llamadas HTTP salientes arbitrarias; integraciones externas |
| **Edge Functions (TS / Deno)** | Solo integraciones: webhook GoPass, proveedor de rutas. Validan entrada, delegan a RPC, traducen errores. | Reglas de negocio que ya estén (o puedan estar) en Postgres |

- **Ninguna regla de negocio vive únicamente en la app.** Toda regla que afecte dinero, estados de viaje o acceso a datos se garantiza en Postgres. La app valida por UX, nunca como única defensa.
- No duplicar una regla entre app y Postgres: si está en la BD, la app solo la consume.

**Flujo de una operación típica (crear y asignar viaje):**

1. La app (rol administrador) pide estimación de ruta a la Edge Function `POST /functions/v1/rutas` con origen y destino; recibe `distancia_estimada` y `tiempo_estimado`.
2. La app invoca la RPC `viaje_crear(p_remision, p_vehiculo_id, p_conductor_id, p_cliente_id, p_origen, p_destino, p_distancia_estimada, p_tiempo_estimado_min, p_peso_carga, p_valor_flete)`.
3. La RPC (PL/pgSQL, ejecución atómica) valida que el vehículo y el conductor existan y estén activos, que el vehículo no tenga otro viaje en `EN_CURSO`/`ASIGNADO`, calcula el ACPM estimado con `tarifa_combustible` + `rendimiento_km_galon` + factor por rango de tonelaje, inserta el `viaje` en estado `PLANIFICADO` y los `costo_viaje` estimados, y devuelve el id.
4. Las políticas **RLS** garantizan que solo un usuario con `app_metadata.rol = 'ADMINISTRADOR'` puede ejecutar esa operación.
5. Ante una regla incumplida, la RPC lanza `RAISE EXCEPTION` con un `ERRCODE` propio; la app lo traduce a mensaje de dominio en español.
6. Un trigger `AFTER INSERT` puebla las columnas de auditoría (`creado_por = auth.uid()`, `fecha_creacion`).

**Manejo de errores**: las RPC lanzan excepciones con `ERRCODE` propio por caso de negocio relevante. Las Edge Functions capturan errores de Postgres y los traducen a un cuerpo de error consistente (secciones 9 y 10). Nunca exponer `SQLSTATE`, nombres de tablas/columnas ni mensajes crudos de la base de datos.

**Validación**: en dos niveles:
- (a) formato de entrada: en la app (validadores por campo) y en la firma de la RPC / el handler de la Edge Function (tipos, requeridos, rango);
- (b) reglas de negocio: dentro de la RPC o en constraints/RLS (ej. "un vehículo no puede tener dos viajes activos simultáneos").

**Autenticación y autorización**: Supabase Auth (GoTrue) emite el JWT (~1h) y el refresh token en el login. El rol (`ADMINISTRADOR`, `CONDUCTOR`) se guarda en `app_metadata.rol`, viaja en el JWT y se hace cumplir con **políticas RLS** en cada tabla, más comprobaciones dentro de las RPC. Nunca solo ocultando opciones en el frontend.

**Configuración y variables de entorno**: `SUPABASE_URL` y `SUPABASE_ANON_KEY` en la app (la `anon key` es pública por diseño; la seguridad la da RLS). La `SERVICE_ROLE_KEY` y los secretos de integraciones (clave del webhook GoPass, credenciales del proveedor de rutas) viven solo como secretos de Edge Functions / del proyecto Supabase. Nunca commitear `.env` con valores reales; mantener `.env.example` con los nombres de las claves.

**Persistencia de datos**: PostgreSQL vía cliente Supabase / PostgREST y funciones RPC, siempre parametrizado, con migraciones versionadas gestionadas por Supabase CLI (ver sección 8).

**Comunicación entre partes**: la app llama a RPC y a Edge Functions por invocación directa (`supabase.rpc(...)`, `supabase.functions.invoke(...)`), no por eventos ni colas. El webhook de correo de peajes es una Edge Function dedicada que inserta vía RPC con `service_role`.

**Escalabilidad**: la que ofrece el plan de Supabase más buenas prácticas de base de datos (índices, paginación, vistas). No diseñar para escalado horizontal ni particionamiento.

### App móvil: Flutter con Clean Architecture + BLoC

- **Presentation**: widgets + BLoC/Cubit. Los widgets no contienen lógica de negocio ni llaman directamente al cliente Supabase; solo reaccionan a estados emitidos por el BLoC.
- **Domain**: entidades del dominio (independientes de Flutter y de la fuente de datos) + casos de uso (`CrearViajeUseCase`, `RegistrarHitoUseCase`, etc.).
- **Data**: repositorios (deciden si los datos vienen de Supabase o de caché local) + datasources (cliente Supabase hacia PostgREST/RPC/Auth/Storage, y almacenamiento local para modo offline).
- El caso de uso no debe saber si el dato viene de red o de almacenamiento local; esa decisión vive en el repositorio de datos.

## 4. Estructura del proyecto

### Repositorio

```
app/                          # Proyecto Flutter (ver estructura abajo)
supabase/
├── migrations/               # SQL versionado: <timestamp>_descripcion_snake_case.sql (Supabase CLI)
├── functions/                # Edge Functions
│   ├── peajes-correo/
│   └── rutas/
├── tests/                    # Pruebas pgTAP
├── seed.sql                  # Datos base para desarrollo local
└── config.toml
```

No crear una Edge Function para lógica que pueda vivir en una RPC. No crear funciones RPC para CRUD simple que PostgREST + RLS ya resuelven.

### App (Flutter)

```
lib/
├── core/                  # Cliente Supabase, manejo de errores, tema visual, constantes
├── features/
│   ├── autenticacion/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── viajes/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── vehiculos/
│   ├── conductores/
│   ├── mantenimiento/
│   └── dashboard/
└── main.dart
```

Organizar por feature, no por tipo técnico a nivel raíz. Dentro de cada feature, mantener la separación data/domain/presentation.

## 5. Patrones de diseño

### Repository (en la capa `data` de la app)
- Una clase de repositorio por entidad raíz (`ViajeRepository`, `VehiculoRepository`, `ConductorRepository`, etc.).
- Encapsula las llamadas a PostgREST / RPC / Storage y el mapeo a entidades de `domain`. Los widgets y los casos de uso nunca tocan el cliente Supabase directamente.

### Funciones RPC (en Postgres)
- Una función RPC por operación de dominio multi-paso. Nombre `<agregado>_<accion>`: `viaje_crear`, `viaje_cambiar_estado`, `viaje_cerrar`, `viaje_registrar_ajuste`, `rentabilidad_marginal`, `rentabilidad_consolidada`.
- Ejemplo: `viaje_cerrar(p_viaje_id)` valida que todos los hitos estén registrados, consolida `costo_viaje` con ACPM real, comisión y mantenimiento amortizado, y transiciona el estado a `CERRADO`, todo en una sola función atómica.

### Strategy
- Aplicar únicamente al cálculo de rentabilidad: dos funciones RPC separadas (`rentabilidad_marginal`, `rentabilidad_consolidada`), no un motor genérico ni una jerarquía de clases.
- No usar Strategy en ningún otro punto del proyecto.

### Adapter
- Usar solo en `supabase/functions/`, una implementación concreta por proveedor externo.
- Definir la interfaz del puerto (`ProveedorRutasPort`, `ProcesadorPeajePort`) en TypeScript, con implementación concreta por proveedor (proveedor de rutas, GoPass).

### Dependency Injection
- Inyectar dependencias por constructor tanto en el código Dart (`domain`/`data`) como en los módulos de Edge Functions. Nunca acceder a servicios como variables globales.

### Triggers
- Usar triggers solo para auditoría (poblar `creado_por`/`fecha_creacion`/`modificado_por`/`fecha_modificacion`), integridad y append-only. La lógica con ramas condicionales va en RPC, no en triggers.

### Patrones prohibidos sin justificación explícita
- No usar Factory, Observer, Builder ni Singleton manual salvo que se justifique explícitamente el problema concreto que resuelven.
- Las notificaciones (alertas de vencimiento, retraso) se implementan como job de `pg_cron` que consulta y dispara notificaciones push, no como bus de eventos.
- Si un DTO de creación tiene muchos campos opcionales, usar constructores nombrados o clases inmutables (ej. `freezed`), no una clase `Builder` dedicada.

## 6. Buenas prácticas de programación

- Nombres descriptivos, en el idioma consistente definido en la sección 13.
- Si un caso de uso o una función RPC supera ~40 líneas o mezcla más de una razón de cambio, dividirlo.
- Extraer helpers compartidos solo después de la tercera repetición real de una lógica (no antes).
- Eliminar código muerto de inmediato.
- Comentarios solo para explicar decisiones no obvias, nunca para explicar qué hace una línea ya legible.
- No construir en este momento: soporte multiempresa, integración RNDC, facturación electrónica, tracking GPS pasivo, servidor de aplicación propio, ni abstracciones para microservicios futuros.
- El ajuste de ACPM por peso de carga se implementa como un factor simple por rango de tonelaje, no como modelo estadístico.

## 7. Principios SOLID

- Cada función RPC tiene una única responsabilidad de negocio (`viaje_cerrar` no calcula reportes de rentabilidad consolidada ni mantiene tarifas de combustible).
- Un widget nunca contiene lógica de negocio; un repositorio de `data` nunca contiene reglas de dominio.
- Aplicar Open/Closed solo en el cálculo de rentabilidad (dos RPC) y en las integraciones externas (Adapter en Edge Functions): agregar nueva variante o nuevo proveedor sin modificar lo existente.
- No forzar Open/Closed en zonas sin variabilidad real (ej. CRUD simple de clientes vía PostgREST).
- Cualquier implementación de una interfaz de dominio (repositorio en `domain`, puerto de integración) debe poder sustituir a la actual sin romper a sus consumidores (Liskov).
- Las interfaces de repositorio y de integración exponen solo los métodos que sus consumidores realmente usan (Interface Segregation).
- Los casos de uso de `domain` dependen de interfaces de repositorio, no de implementaciones concretas de `data` (Dependency Inversion).

## 8. Base de datos

### Entidades principales

- `usuario` (id = referencia a `auth.users.id`, nombre, documento, rol; el rol también se refleja en `app_metadata.rol` para RLS). Credenciales y sesiones las gestiona Supabase Auth, no esta tabla.
- `vehiculo` (id, placa, tipo, capacidad_carga, rendimiento_km_galon, activo)
- `documento_vehiculo` (id, vehiculo_id FK, tipo [SOAT/TECNOMECANICA], fecha_vencimiento)
- `mantenimiento_vehiculo` (id, vehiculo_id FK, tipo, costo, fecha, kilometraje)
- `conductor` (id, usuario_id FK, licencia, fecha_vencimiento_licencia, tipo_pago [FIJO/COMISION/MIXTO], porcentaje_comision, sueldo_base, activo)
- `cliente` (id, nombre, datos de contacto)
- `tarifa_combustible` (id, ciudad, precio_galon, fecha_vigencia_desde)
- `viaje` (id, remision unique, vehiculo_id FK, conductor_id FK, cliente_id FK, origen, destino, distancia_estimada, tiempo_estimado, estado, peso_carga, valor_flete, valor_anticipo, saldo_pendiente [generado = valor_flete − valor_anticipo], fecha_creacion, fecha_cierre)
- `hito_viaje` (id, viaje_id FK, tipo [SALIDA/LLEGADA_CARGUE/SALIDA_CON_CARGA/LLEGADA_DESTINO], fecha_hora, origen_dato [APP/MANUAL])
- `costo_viaje` (id, viaje_id FK, categoria [ACPM, PEAJE, CARGUE, DESCARGUE, PARQUEADERO, COMISION, ACEITE, LAVADO, ENGRASE, MANTENIMIENTO_AMORTIZADO, OTRO], valor_estimado, valor_real, fuente [AUTOMATICO/MANUAL])
- `peaje_capturado` (id, viaje_id FK nullable hasta asociarse, placa, monto, fecha_hora, punto_peaje, correo_origen_id)
- `ajuste_viaje` (id, viaje_id FK, usuario_id FK, motivo, campo_modificado, valor_anterior, valor_nuevo, fecha)

`viaje.remision` es el número de remisión física de la empresa (trazabilidad con el papeleo existente); `viaje.valor_flete` es un monto pactado con el cliente, capturado por el administrador al crear el viaje: **no** sigue el patrón de par `valor_estimado`/`valor_real` que usa el resto de datos automáticos, porque no es algo que el sistema estime. `valor_anticipo` es el adelanto ya pagado por el cliente — informativo (cartera), no participa en `rentabilidad_marginal`. `ACEITE`, `LAVADO` y `ENGRASE` son costo real por viaje (distinto de `MANTENIMIENTO_AMORTIZADO`, que es el costo fijo prorrateado sin fuente por viaje). Detalle completo en `diseno-base-de-datos-optiruta.md`.

### Rentabilidad: qué costos entran en cada RPC

- `rentabilidad_marginal(p_viaje_id)`: `valor_flete − (ACPM + peajes + cargue + descargue + parqueadero + comisión variable + aceite + lavado + engrase + otros)`. Todas las categorías de `costo_viaje` excepto `MANTENIMIENTO_AMORTIZADO`.
- `rentabilidad_consolidada(p_desde, p_hasta)`: agrega la rentabilidad marginal de todos los viajes del período y le resta el `MANTENIMIENTO_AMORTIZADO` de `costo_viaje` más el sueldo fijo del conductor prorrateado por período (`conductor.sueldo_base`, tipo de pago `FIJO`/`MIXTO`).

### Relaciones e integridad referencial

- Todas las FK entre `viaje` y `vehiculo`/`conductor`/`cliente` son `NOT NULL` con `ON DELETE RESTRICT`.
- No borrar físicamente vehículos o conductores: modelar la baja como `activo = false`.
- `costo_viaje` y `hito_viaje` dependen de `viaje` con `ON DELETE CASCADE` solo mientras el viaje esté en estados previos a `CERRADO`.
- `ajuste_viaje` es append-only: RLS solo con políticas de `INSERT` y `SELECT` (sin `UPDATE`/`DELETE`), y se revoca `UPDATE`/`DELETE` a los roles `anon` y `authenticated`.

### Row Level Security (RLS)

- **RLS habilitado en todas las tablas.** Sin RLS = tabla inaccesible desde la app.
- Ninguna política permisiva sin comprobación explícita de rol y/o propietario. El rol se lee de `auth.jwt() -> 'app_metadata' ->> 'rol'`.
- Conductor: políticas que lo limitan a `SELECT`/`INSERT`/`UPDATE` de sus propios `viaje` e `hito_viaje` (join por `conductor.usuario_id = auth.uid()`); sin acceso a datos financieros de otros ni a configuración administrativa.
- Administrador: lectura amplia; escritura acotada por el ciclo de vida del viaje (un viaje `CERRADO` no admite `UPDATE`, solo `ajuste_viaje`).
- Toda tabla nueva nace con RLS habilitado y políticas explícitas **en la misma migración** que la crea.

### Normalización, índices y consultas

- Modelo normalizado a 3FN. No desnormalizar salvo problema de rendimiento medido.
- Crear índices sobre: `viaje.estado`; `viaje.vehiculo_id` + `viaje.estado` (compuesto); `documento_vehiculo.fecha_vencimiento`; `peaje_capturado.placa` + `fecha_hora`.
- Implementar reportes de rentabilidad (por ruta/cliente/conductor) como vistas o funciones RPC con consultas agregadas (`GROUP BY`) en la base de datos, no trayendo todos los registros a la app.

### Migraciones

- Gestionar el esquema con **Supabase CLI**: migraciones SQL versionadas en `supabase/migrations/` (`<timestamp>_descripcion_snake_case.sql`), aplicadas con `supabase db push` / en CI. Nunca modificar el esquema a mano en la consola de Supabase, ni en desarrollo. Nunca editar una migración ya mergeada a `main`: crear una nueva.

### Transacciones

- Toda operación que modifique más de una tabla de forma atómica (ej. cerrar un viaje: cambia estado, consolida `costo_viaje`, puede generar notificación) se implementa como una **función RPC en PL/pgSQL**, que es atómica por sí misma. No orquestar transacciones multi-llamada desde la app.

### Datos históricos y auditoría

- No archivar el histórico de viajes cerrados: es la fuente de reportes, optimizada con índices.
- Registrar auditoría de cambios sensibles (creación, cierre, ajuste) en columnas estándar (`creado_por`, `fecha_creacion`, `modificado_por`, `fecha_modificacion`) pobladas por trigger con `auth.uid()`, más la tabla `ajuste_viaje` para cambios posteriores al cierre.

## 9. Seguridad

- **Contraseñas y tokens los gestiona Supabase Auth**: hash con bcrypt internamente, JWT de expiración corta (~1h) + refresh token. Logout = `supabase.auth.signOut()`, que revoca el refresh token. No implementar hashing ni emisión de JWT propios.
- **RLS obligatorio en todas las tablas.** Denegar por defecto: la `anon key` solo permite lo que las políticas RLS autoricen; todo requiere sesión salvo el flujo de login.
- Declarar el/los rol(es) permitido(s) en cada tabla mediante políticas RLS y en cada RPC mediante comprobación explícita de `auth.jwt()`.
- La `service_role key` **nunca** se incluye en la app: solo en Edge Functions / secretos del proyecto. La `anon key` sí va en la app.
- Validar tipo, rango y formato de toda entrada en la app y en la firma de RPC / handler de Edge Function. No confiar en datos del cliente sin validar.
- Usar siempre acceso parametrizado a Postgres (cliente Supabase, PostgREST, `USING`/`format(%L/%I)` en PL/pgSQL). Nunca concatenar SQL.
- No commitear ninguna credencial. Inyectar por variables de entorno de la app y secretos de Supabase.
- Restringir al conductor a leer/escribir solo sobre sus propios viajes e hitos vía RLS. El administrador tiene lectura amplia, escritura restringida por el ciclo de vida del viaje.
- Las migraciones en producción se aplican por el proceso de despliegue (Supabase CLI en CI), no manualmente.
- Nunca incluir stack traces, `SQLSTATE`, nombres de tablas/columnas ni mensajes crudos de base de datos en respuestas de error; traducir siempre a códigos y mensajes de negocio controlados (sección 10).

## 10. Diseño de APIs / contratos

Hay dos superficies:

### A. PostgREST autogenerada (tablas, vistas, RPC) — consumida con `supabase_flutter`

- Tablas/columnas y funciones RPC en `snake_case`, singular. Parámetros de RPC con prefijo `p_`.
- Vistas para listados de lectura con joins; funciones RPC para operaciones de dominio multi-paso.
- Un viaje cerrado no se modifica con `UPDATE` sobre `viaje`; solo con la RPC `viaje_registrar_ajuste`. No existe borrado de viajes.
- Paginar todos los listados: `.range(from, to)` de PostgREST, o parámetros `p_page` / `p_size` en RPC. Nunca retornar una colección completa sin límite.
- Filtrar y ordenar por parámetros explícitos (`.eq('estado', 'EN_CURSO').order('fecha_creacion', ascending: false)`), nunca construyendo strings de consulta en la app.
- El código de la app que consume PostgREST no lleva lógica de negocio: solo lee/escribe datos ya validados por constraints/RLS/triggers.

### B. Edge Functions (solo integraciones), prefijo `v1`

- `POST /functions/v1/peajes-correo` — webhook que recibe el correo procesado de GoPass. Protegido con clave de servicio en cabecera, **no** con JWT de usuario.
- `POST /functions/v1/rutas` — estimación de distancia y tiempo vía proveedor externo de rutas.
- Códigos de estado: `200`, `201`, `204`, `400` (validación), `401` (no autenticado), `403` (sin permiso), `404`, `409` (conflicto de negocio), `422` opcional para reglas de negocio, `500` reservado a errores no controlados.
- Estructura de respuesta de error, consistente:
  ```json
  {
    "timestamp": "2026-09-02T10:00:00Z",
    "status": 409,
    "error": "ESTADO_VIAJE_INVALIDO",
    "message": "No se puede cerrar el viaje: faltan hitos por registrar",
    "path": "/functions/v1/..."
  }
  ```

### Operaciones de referencia

- `supabase.rpc('viaje_crear', { ..., p_valor_flete })` — crear y asignar viaje, incluye el ingreso pactado con el cliente (RLS: solo administrador).
- `supabase.from('viaje').select(...).eq('id', id)` — consultar detalle de viaje (RLS filtra por rol/propietario).
- `supabase.rpc('hito_registrar', { p_viaje_id, p_tipo, p_fecha_hora })` — registrar hito (RLS: solo el conductor asignado).
- `supabase.rpc('viaje_cerrar', { p_viaje_id })` — cerrar viaje y consolidar rentabilidad (RLS: solo administrador).
- `supabase.rpc('viaje_registrar_ajuste', { p_viaje_id, p_motivo, ... })` — ajuste sobre viaje cerrado (RLS: solo administrador, motivo obligatorio).
- `supabase.from('mantenimiento_vehiculo').select(...).eq('vehiculo_id', id)` — historial de mantenimiento.
- `POST /functions/v1/peajes-correo` — webhook GoPass (clave de servicio).
- `supabase.rpc('rentabilidad_consolidada', { p_desde, p_hasta, p_agrupado_por })` — reporte agregado para el dashboard.

- Cambios incompatibles en una RPC = nueva función `_v2`; no romper la existente mientras haya app vieja en uso.
- Documentar las Edge Functions y las RPC en este repositorio; PostgREST expone su propio esquema.

## 11. Testing

- **Unitario** (sin base de datos): casos de uso de `domain` en Flutter con mocks de repositorio; lógica pura de Edge Functions con mocks del cliente Supabase y del proveedor externo. Cubrir cálculo de ACPM estimado y validaciones de reglas.
- **Integración** (Supabase local vía `supabase start`, Docker):
  - `pgTAP` para constraints, políticas RLS (un conductor no ve viajes ajenos), triggers de auditoría, append-only de `ajuste_viaje`, y funciones RPC (transiciones de estado, cierre con hitos incompletos, rentabilidad marginal vs. consolidada).
  - `deno test` para Edge Functions contra el stack local.
- **End-to-end**: solo los flujos críticos desde la app: login, crear y asignar viaje, registrar hitos, cerrar viaje.
- No escribir pruebas exhaustivas para: getters/setters, mappers triviales campo a campo, configuración base, DTOs simples sin lógica.
- Priorizar cobertura en este orden: reglas de negocio y RLS > autenticación/autorización > integraciones externas (correo, rutas, vía mocks) > CRUD simple.

## 12. Git y control de versiones

- Usar `main` como rama siempre estable. Ramas de feature cortas con prefijo por tipo: `feature/...`, `fix/...`, `chore/...`.
- Mensajes de commit en formato Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`), en el idioma elegido para el código (sección 13).
- No mergear ninguna rama a `main` sin al menos una revisión y sin que build/tests pasen, incluyendo: las migraciones aplican en un stack local limpio y `pgTAP` pasa.
- En code review, verificar: (a) la regla de negocio está en la capa correcta (Postgres, no la app), (b) toda tabla nueva trae RLS y políticas en la misma migración, (c) hay pruebas para la lógica nueva relevante, (d) no se tocó código fuera del alcance.
- Hacer `rebase` de la rama de feature sobre `main` antes de abrir el PR.
- Mergear a `main` solo vía PR aprobado, usando "squash merge".

## 13. Convenciones de desarrollo

- Definir como primera decisión del equipo: código en inglés o código en español. No mezclar ambos en el mismo proyecto. Español se reserva siempre para textos visibles al usuario y documentación de negocio.
- Archivos Dart/Flutter: `snake_case` (`viaje_repository.dart`). Clases Dart: `PascalCase`. Variables y funciones Dart: `camelCase`.
- Edge Functions: carpeta y archivos en `kebab-case`; símbolos TypeScript en `camelCase` / `PascalCase`.
- Migraciones: generadas por Supabase CLI, `<timestamp>_descripcion_snake_case.sql`.
- Tablas, columnas y funciones SQL en `snake_case`, en singular, consistentemente en todo el esquema.
- Rutas de Edge Functions en minúsculas, `kebab-case` si tienen más de una palabra.
- Código de error en mayúsculas con guion bajo (`ESTADO_VIAJE_INVALIDO`), mensaje legible en español.
- Logs siempre estructurados, nunca `print()` / `console.log` suelto.
- Comentarios en el idioma elegido para el código; explican decisión, no mecánica.
- Aplicar formateadores automáticos de forma obligatoria: `dart format` para la app, `deno fmt` para Edge Functions. No discutir formato en code review.

## 14. Observabilidad y logging

- En Edge Functions, usar logging estructurado con niveles: `ERROR`, `WARN`, `INFO` (eventos de negocio: viaje creado, viaje cerrado, peaje asociado), `DEBUG` (deshabilitado en producción).
- En Postgres, `RAISE LOG`/`RAISE WARNING` en las RPC para eventos relevantes y errores de negocio.
- Nunca loggear: contraseñas, tokens JWT completos, `service_role key`, datos de tarjetas o cuentas, contenido crudo de correos de terceros más allá de lo necesario para depurar el parsing.
- Propagar un identificador de correlación (`x-request-id`) en los logs de cada invocación de Edge Function.
- Usar el panel y los health checks propios de Supabase para disponibilidad; no exponer un `/health` propio (no hay servidor de aplicación).
- Mantener separadas las alertas de negocio (vencimiento de documentos, retraso de viaje) de las alertas técnicas (fallo de una Edge Function, error recurrente en una RPC).

## 15. Reglas para agentes de desarrollo

1. Antes de escribir o modificar código, revisa la estructura de carpetas (`app/`, `supabase/`) y los archivos ya existentes relacionados con la tarea. No asumas la estructura, verifícala.
2. Reutiliza casos de uso, repositorios, DTOs, mappers, widgets, funciones RPC y Edge Functions ya existentes en lugar de crear equivalentes.
3. No dupliques lógica de negocio: si una regla ya está en una RPC/constraint/RLS, la app solo la consume; no la reimplementes.
4. No introduzcas una dependencia (paquete Flutter, librería de Edge Function, extensión de Postgres) sin justificarla explícitamente en la tarea o el commit.
5. No modifiques archivos no relacionados con la tarea actual, aunque detectes mejoras. Repórtalas en lugar de aplicarlas.
6. Respeta dónde vive cada cosa (sección 3): no pongas reglas de negocio en un widget ni en un repositorio de `data`; no pongas en una Edge Function lógica que pueda vivir en una RPC.
7. Respeta los patrones de la sección 5. No introduzcas un patrón nuevo sin justificar qué problema concreto resuelve.
8. Toda tabla nueva se crea con RLS habilitado y políticas explícitas en la misma migración.
9. Al modificar lógica de viajes cerrados, respeta siempre la regla de no editar ni borrar directamente: cualquier cambio se implementa como `ajuste_viaje` vía RPC, nunca como `UPDATE`/`DELETE` directo.
10. Antes de dar una tarea por terminada, valida que la app compile, que las migraciones apliquen en un stack local limpio, que las pruebas existentes sigan pasando, y que haya pruebas para la lógica nueva (RPC / RLS / casos de uso).
11. No realices refactorizaciones no solicitadas ni cambios de formato masivos fuera del alcance de la tarea.
12. Si una tarea requiere una decisión que cambia la arquitectura definida (introducir un servidor de aplicación propio, otra base de datos, Realtime como bus de eventos, un patrón nuevo general), no la implementes: informa la implicación y espera confirmación.
13. Ante información faltante (valor de configuración, regla de negocio no definida), no inventes el comportamiento: señala qué falta y, si es razonable, propone una opción concreta.
