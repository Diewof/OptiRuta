# 2026-09-02 — Inicializacion de Supabase + flujo de login (rol ADMINISTRADOR / CONDUCTOR)

## Alcance

Autenticacion completa: login + registro + recuperar contrasena. No se
implementaron viajes, vehiculos, dashboard ni otras features.

## Iteracion 2 (2026-09-02, tarde) — registro y recuperar contrasena

Decision: registro publico; **todo usuario nuevo nace con rol CONDUCTOR**
(el rol lo fija el servidor, se ignora lo que mande el cliente). El
administrador se crea/gestiona luego por SQL (hardcodeo del admin: pendiente,
"lo crearemos luego"). Sin pantalla de cambio de rol. Confirmacion de correo
desactivada en el dashboard del proyecto.

### Supabase

- Nueva migracion `migrations/20260902203046_registro_rol_conductor.sql`:
  `create or replace` de `handle_new_user()`. Ya **no** exige ni lee `rol` del
  cliente: siempre `CONDUCTOR`. `nombre` cae en la parte local del correo si
  falta (evita que un alta sin metadata rompa el `NOT NULL`).
- `tests/auth_perfil_test.sql`: actualizado (13 asserts) — ahora verifica que
  un signup que pide `ADMINISTRADOR` termina en `CONDUCTOR`, y el alta sin
  metadata.

### App Flutter

- `domain`: `AuthRepository.registrarse(...)` y `enviarRecuperacion(...)`;
  casos de uso `RegistrarseUseCase`, `RecuperarPasswordUseCase`; nuevos
  codigos `AuthFailure` (`CORREO_YA_REGISTRADO`, `CONTRASENA_DEBIL`).
- `data`: `AuthRemoteDataSource.registrarse` (= `auth.signUp` con
  `data: {nombre}`) y `enviarRecuperacion` (= `auth.resetPasswordForEmail`);
  `AuthRepositoryImpl` traduce errores de alta y, en `_resolverSesion`, si el
  JWT recien emitido aun no trae `app_metadata.rol`, cae en la columna
  `usuario.rol` (solo escribible por el servidor).
- `presentation`: `AuthCubit.registrarse` (entra directo si hay sesion; si
  queda pendiente de confirmacion emite aviso) y `recuperarPassword`
  (passthrough, no cambia el estado de auth). `RegistroPage` y
  `RecuperarPasswordPage` conectadas al Cubit; el registro exitoso hace
  `popUntil(isFirst)` para que `AuthGate` muestre la vista por rol.
- **Pendiente anotado**: fijar la nueva contrasena *dentro de la app* requiere
  manejar el deep link de recuperacion (evento `passwordRecovery`). Por ahora
  el enlace del correo abre el flujo web de Supabase.

## Que se hizo (iteracion 1)

### Supabase (`supabase/`)

- `supabase init` (config.toml con defaults; `enable_confirmations = false` y

## Que se hizo

### Supabase (`supabase/`)

- `supabase init` (config.toml con defaults; `enable_confirmations = false` y
  `[db.seed]` -> `./seed.sql` ya venian bien). Se crearon `migrations/`,
  `functions/`, `tests/`, `seed.sql`, `.gitignore`.
- Migracion `migrations/20260902195223_auth_perfil.sql`:
  - Tabla `public.usuario` (`id` = FK a `auth.users` `ON DELETE CASCADE`,
    `nombre`, `documento`, `rol` con CHECK, `activo`, columnas de auditoria).
  - Trigger `on_auth_user_created` (`AFTER INSERT ON auth.users`,
    `SECURITY DEFINER`): crea la fila de perfil desde `raw_user_meta_data` y
    escribe `rol` en `raw_app_meta_data` para que viaje en el JWT.
    - **Alternativa considerada y descartada**: Edge Function con `service_role`
      llamando `auth.admin.updateUserById`. Se elige la via SQL por la prioridad
      #1 (simplicidad): sin salto de red ni funcion desplegable. No hay
      recursion (no existe trigger `AFTER UPDATE` sobre `auth.users`).
  - Trigger `usuario_set_audit` (`BEFORE INSERT/UPDATE`): pobla
    `creado_por/fecha_creacion/modificado_por/fecha_modificacion`.
  - RLS habilitado en la misma migracion:
    - `REVOKE ALL` a `anon`/`authenticated`; `GRANT SELECT`; `GRANT UPDATE
      (nombre, rol, activo)` (acotamiento por columna porque RLS no filtra
      columnas).
    - `usuario_select_propio` (`id = auth.uid()`), `usuario_select_admin` y
      `usuario_update_admin` (leen `auth.jwt() -> 'app_metadata' ->> 'rol'`).
    - Sin politicas de INSERT/DELETE (las filas nacen por trigger).
- `seed.sql`: `admin@optiruta.test` / `Admin123!` (ADMINISTRADOR) y
  `conductor@optiruta.test` / `Conductor123!` (CONDUCTOR). Solo desarrollo local.
- `tests/auth_perfil_test.sql` (pgTAP, 12 asserts): estructura + RLS activo,
  trigger crea perfil y setea `app_metadata`, aislamiento entre perfiles
  (un conductor solo ve el suyo), INSERT/DELETE denegados a `authenticated`.
  pgTAP se habilita dentro de la transaccion y el `rollback` lo deshace: no
  llega a produccion.

### App Flutter (`mobile/`)

- `core/config/supabase_config.dart` + `core/supabase/supabase_init.dart`:
  lee `SUPABASE_URL` / `SUPABASE_ANON_KEY` por `--dart-define`; `Supabase.initialize`.
- `core/widgets/app_alert.dart`: componente `AppAlert` del sistema de diseno
  (banner con borde de estado) para el error de login.
- `features/autenticacion/domain/`: entidades `RolUsuario`, `Usuario`, `Sesion`;
  `AuthFailure` (codigos de dominio); contrato `AuthRepository`; casos de uso
  `IniciarSesionUseCase`, `CerrarSesionUseCase`, `ObservarSesionUseCase`.
- `features/autenticacion/data/`: `AuthRemoteDataSource` (envuelve
  `supabase.auth` + lectura de `usuario`), `UsuarioModel`, `AuthRepositoryImpl`
  (traduce errores del proveedor a `AuthFailure`; el **rol se toma del JWT**
  `app_metadata.rol`, no de la columna; si `activo == false` -> cierra sesion).
- `features/autenticacion/presentation/`: `AuthCubit` + estados
  (`AuthDesconocido/Autenticando/Autenticado/NoAutenticado/Error`);
  `AuthGate` (widget raiz que enruta por estado y rol); `SesionIniciadaPage`
  (placeholder por rol con "Cerrar sesion"); `LoginPage` reconectado al Cubit.
- `main.dart`: `OptiRutaApp` recibe `AuthRepository` por constructor (DI,
  testeable); `BlocProvider<AuthCubit>`; `home: AuthGate()`. Pantalla de aviso
  si falta configuracion.
- `AndroidManifest.xml` (main): permiso `INTERNET`.
- `.env.example` (nuevo) y `.env` anadido a `.gitignore`.

### Dependencias anadidas (`mobile/pubspec.yaml`) — justificacion

| Paquete | Motivo |
|---|---|
| `supabase_flutter` | Obligatorio por arquitectura: la capa `data` habla con Supabase solo por este paquete. |
| `flutter_bloc` | Obligatorio por CLAUDE.md (Clean Architecture + BLoC/Cubit). |
| `equatable` | Igualdad por valor en entidades de dominio y estados de BLoC. |
| `mocktail` (dev) | Dobles de prueba para casos de uso y repositorio. |
| `bloc_test` (dev) | Pruebas de transiciones del Cubit. |

No se anadieron extensiones de Postgres (pgTAP solo en el archivo de test, con rollback).

## Como correr (proyecto Supabase hosted — sin Docker)

Decision (2026-09-02): para el prototipo se usa un proyecto **hosted** en
supabase.com. No se usa el stack local (Docker). `supabase/config.toml`,
`supabase/seed.sql` y `supabase/tests/` quedan en el repo para uso futuro
(local / CI); no son necesarios para correr el prototipo.

### 1. Crear el proyecto

1. supabase.com -> New project. Elegir organizacion, nombre, **DB password**
   (guardarla) y region (ej. `South America (Sao Paulo)`).
2. Esperar a que aprovisione (~2 min).

### 2. Aplicar el esquema

`SQL Editor` -> ejecutar **en orden** el contenido de:
1. `supabase/migrations/20260902195223_auth_perfil.sql`
2. `supabase/migrations/20260902203046_registro_rol_conductor.sql`

(Alternativa con CLI: `npx supabase link --project-ref <ref>` y luego
`npx supabase db push`, que aplica ambas.)

### 3. Crear los usuarios de prueba

`SQL Editor` -> pegar el contenido de `supabase/seed.sql` -> **Run**. Crea
`admin@optiruta.test` / `Admin123!` (ADMINISTRADOR) y
`conductor@optiruta.test` / `Conductor123!` (CONDUCTOR); el trigger completa
el perfil y el `app_metadata.rol`.

(Alternativa por UI: `Authentication` -> `Add user` con **Auto Confirm**
activado y `User Metadata` = `{ "nombre": "...", "rol": "ADMINISTRADOR" }`.
Sin ese metadata el trigger rechaza la creacion: es denegar por defecto.)

### 4. Configurar la app

`Settings` -> `API`: copiar **Project URL** y la clave **anon / public**.
Ponerlas en `mobile/.env` (ver `mobile/.env.example`) y correr:

```bash
cd mobile
flutter run \
  --dart-define=SUPABASE_URL=<Project URL> \
  --dart-define=SUPABASE_ANON_KEY=<anon public key>
```

## Estado de verificacion

- `dart format` + `flutter analyze`: sin issues.
- `flutter test`: 15/15 en verde (incluye `widget_test.dart` ajustado).
- Proyecto hosted `nsfexxdepoeufnfuosys` (migracion + seed aplicados desde el
  SQL Editor). Verificado en vivo contra la API el 2026-09-02:
  - `anon` sobre `/rest/v1/usuario` -> `401 permission denied` (denegar por defecto). OK.
  - Login `admin@optiruta.test` y `conductor@optiruta.test` -> `access_token`
    con `app_metadata.rol` = `ADMINISTRADOR` / `CONDUCTOR` (trigger OK, rol en el JWT).
  - RLS: con token de admin, `select` sobre `usuario` devuelve las 2 filas;
    con token de conductor, solo su propia fila.
  - `DELETE` sobre `usuario` con token de conductor -> `403 / 42501` (sin grant).
- `flutter test`: 28/28 en verde tras la iteracion 2 (casos de registro y
  recuperacion anadidos).
- Migracion `20260902203046_registro_rol_conductor.sql` aplicada en el proyecto
  hosted + "Confirm email" desactivado. Verificado en vivo el 2026-09-02:
  - `POST /auth/v1/signup` con `data:{nombre}` -> `200`, sesion inmediata,
    `app_metadata.rol = CONDUCTOR`, fila creada en `public.usuario`
    (`nombre` = el enviado, `activo = true`); con token del nuevo usuario, RLS
    devuelve solo su propia fila.
  - Login del usuario recien registrado -> OK.
  - `POST /auth/v1/recover` -> `200` y cuerpo vacio (no revela si el correo
    existe). Nota: Supabase rechaza (`email_address_invalid`) direcciones con
    TLD de prueba tipo `.test`; el repo traga ese `AuthException` y la pantalla
    muestra igual el mensaje neutro, asi que no afecta a la UX. El envio real
    del correo depende de configurar SMTP en el proyecto.
- Falta ejecutar la app en un dispositivo/emulador para ver el enrutamiento
  por rol en pantalla (la logica esta cubierta por los tests del Cubit/AuthGate
  y por la verificacion de API).
- pgTAP (`supabase/tests/`): solo corre contra un stack local o en CI; fuera
  del alcance del prototipo. Sus escenarios quedaron validados a mano contra
  el proyecto hosted (ver puntos anteriores).

## Mejoras detectadas (no aplicadas — fuera de alcance)

- `mobile/lib/core/routing/app_routes.dart` mantiene la ruta con nombre
  `login` que ya no se usa (el login lo monta `AuthGate`). Se puede limpiar
  cuando se aborde el routing definitivo.
- `registro_page.dart` y `recuperar_password_page.dart` siguen siendo solo
  diseno (navegan a "Trabajo en progreso"); conectarlas a Supabase Auth es
  trabajo aparte.
- `GoogleButton` ya esta deshabilitado con tooltip; habilitar OAuth de Google
  queda para cuando se configure el proveedor en Supabase.
