# Sistema de Diseño — OptiRuta

Fuente única de verdad para color, tipografía, espaciado, bordes, radios, sombras,
componentes y accesibilidad de la app Flutter. Consolida:

1. **`Instrucciones de Identidad Visual.md`** y la sección *Identidad visual* de `CLAUDE.md` — **autoridad**. Ante conflicto, mandan estos documentos.
2. Skills de estándar de diseño móvil instaladas en `.agents/skills/` (`mobile-app-ui-design`, `mobile-app-design-standards`) — **complemento** en lo que no contradiga a (1): grilla de espaciado, tamaños de *touch target*, contraste WCAG, diseño atómico de componentes, estados de pantalla, rendimiento percibido, accesibilidad.
3. Lo que las skills recomiendan y **no se adopta** por chocar con el concepto *centro de control logístico* está en la sección [No adoptar](#no-adoptar).

Prioridad de decisión (de `CLAUDE.md`): **legibilidad → jerarquía → eficiencia → consistencia → estética**.

---

## 1. Color

Paleta cerrada, derivada del logo de la empresa (azul oscuro, rojo oscuro, gris, blanco). No se introducen colores nuevos. Los neutros de texto/borde se derivan por **opacidad** del gris pizarra, no como hex adicionales.

### Tokens base

| Token | Hex | Uso |
|---|---|---|
| `color.brand.navy` | `#14273F` | Azul marino. Encabezados, nav inferior, texto de título, superficies oscuras. Domina la UI junto con el gris pizarra. |
| `color.brand.slate` | `#333A45` | Gris pizarra. Texto de cuerpo, iconos, base de los neutros. |
| `color.surface.canvas` | `#F3F4F6` | Fondo de pantalla. |
| `color.surface.card` | `#FFFFFF` | Fondo de tarjetas, formularios, tablas, hojas. |
| `color.action.primary` | `#1E3A5F` | Azul de acción. **Única acción principal por pantalla.** Solo botón primario. Texto blanco. |
| `color.brand.red` | `#A62C2C` | Rojo de marca. Acento de identidad: logo, franja lateral de card, indicador activo de navegación, anillo de foco de input, botón destructivo. Nunca relleno de pantalla ni decoración. |
| `color.state.success` | `#2E7D52` | Verde. Éxito / normalidad. Solo badges, iconos, bordes, texto de estado. |
| `color.state.warning` | `#C6871B` | Ámbar advertencia. Solo estados/alertas. Texto oscuro encima. |
| `color.state.error` | `#C43D2E` | Rojo error. Error / urgencia. Estados, validación, alertas. |

`color.action.primary` (azul de acción) y `color.brand.red` (rojo de marca) son distintos a propósito: **la acción principal nunca es roja**, así que acción y peligro no se confunden. El rojo de marca solo aparece como acento puntual o como acción destructiva.

### Neutros derivados (opacidad de `#333A45`)

| Token | Definición | Aproximado sobre blanco |
|---|---|---|
| `color.text.primary` | `#14273F` 100% | — |
| `color.text.body` | `#333A45` 100% | — |
| `color.text.secondary` | `#333A45` @ ~68% | `#5C6470` |
| `color.text.disabled` | `#333A45` @ ~44% | `#9AA0A9` |
| `color.border.input` | `#333A45` @ ~32% | `#B4B8BF` |
| `color.border.card` | `#333A45` @ ~16% | `#D9DBDF` |
| `color.divider.table` | `#333A45` @ ~10% | `#E6E7EA` |

### Contraste (WCAG 2.1 AA) — verificado con `scripts/check-contrast.py` del skill

| Combinación | Ratio | Veredicto | Regla |
|---|---|---|---|
| `#FFFFFF` sobre `#14273F` | 15.1:1 | ✅ AAA | Texto sobre azul marino: libre. |
| `#FFFFFF` sobre `#333A45` | 11.5:1 | ✅ AAA | Texto sobre gris pizarra: libre. |
| `#FFFFFF` sobre `#1E3A5F` (primario) | 11.5:1 | ✅ AAA | Label del botón primario: libre. |
| `#14273F` / `#333A45` sobre `#F3F4F6` | 13.7:1 / 10.4:1 | ✅ AAA | Texto de contenido: libre. |
| `#5C6470` sobre `#FFFFFF` / `#F3F4F6` | 6.0:1 / 5.4:1 | ✅ AA | Texto secundario: normal y grande. |
| `#FFFFFF` sobre `#A62C2C` (rojo de marca) | 7.0:1 | ✅ AA | Texto blanco en botón destructivo: libre. |
| `#A62C2C` sobre `#FFFFFF` / `#F3F4F6` | 7.0:1 / 6.3:1 | ✅ AA | Rojo de marca como texto/icono/borde: permitido a cualquier tamaño. |
| `#FFFFFF` sobre `#C43D2E` (error) | 5.2:1 | ✅ AA | Texto blanco permitido en superficies de error. |
| `#FFFFFF` sobre `#2E7D52` (éxito) | 5.0:1 | ✅ AA | Texto blanco permitido en badges de éxito. |
| `#FFFFFF` sobre `#C6871B` (advertencia) | 3.05:1 | ❌ Falla texto normal | **Nunca** texto blanco pequeño sobre ámbar. Texto `#14273F`. |

**Regla operativa de estado:** los colores de estado se usan como **relleno de badge, borde o icono**. Sobre ámbar de advertencia el texto es oscuro (`#14273F`); sobre verde, error y rojo de marca se permite texto blanco. No colorear filas ni fondos completos con colores de estado ni con el rojo de marca (regla de Identidad Visual).

No depender solo del color para transmitir información: acompañar siempre con icono y/o etiqueta de texto (badge con label).

### Diferenciadores de marca (sobrios, con función)

Recursos de identidad permitidos; refuerzan la marca sin saturar. No añadir otros.

- **Icono guía en input**: icono outline `color.brand.slate` a la izquierda del campo (correo, candado, persona) para escaneo rápido. No decorativo. En autenticación va dentro de un chip `color.canvas` de 36 dp con `radius.sm`.
- **Anillo de foco** 2 px `color.brand.red` (ver sección 3).

#### Autenticación: formulario integrado en la pantalla (decisión 2026-09-01, revisada)

Las pantallas de autenticación **no llevan tarjeta**: el formulario (título
`type.display` + subtítulo + campos) va directo sobre `color.canvas`, alineado
**arriba** — el espacio sobrante queda al pie, no repartido. Volver atrás se
resuelve con una `AppBar` plana solo con la flecha.

Las tres pantallas usan la misma **ilustración a sangre** en la franja superior
(`AuthHero`): arte vectorial plano de rutas, camiones y pines en la paleta
cerrada, sobre `color.canvas`. Se integra en la pantalla, sin borde ni recuadro
(no es un banner): el tercio inferior de la imagen se difumina con un
`ShaderMask` y encima un fundido largo de ~96 dp remata la unión con el fondo,
de modo que el formulario continúa sin corte visible. Asset:
`assets/decor/auth_hero.png`, lienzo 1080 × 1920 px, dibujo en el tercio
superior y resto en `#F3F4F6`. Mientras el asset no exista, cae en
`BrandRouteHeader`.

Alto de la banda (más el inset de estado):

| Pantalla | Alto |
|---|---|
| Login y recuperar contraseña | `30 %` de la pantalla, acotado a 220–320 dp |
| Registro | `20 %`, acotado a 140–180 dp — la checklist de validación en vivo alarga la vista; la banda baja la mantiene visible con menos scroll |

`BrandRouteHeader` queda solo como reserva de `AuthHero` cuando falta el asset.
Sin uso `assets/decor/truck.png` y `BrandMasthead` (masthead grande descartado;
`AuthHero` no lo reintroduce).

- **Botón primario con degradado** `authGradientStart → authGradientMid → authGradientEnd` (navy → azul de acción → azul claro), alto 52, `radius.lg`, icono de flecha opcional a la derecha. **Solo en auth**; el primario de la app operativa sigue siendo `color.action` plano.
- **"Continuar con Google"** (solo en login): acceso federado fuera del MVP. Se muestra **deshabilitado** con tooltip "Disponible próximamente" hasta que se habilite el proveedor OAuth de Google en Supabase Auth.

---

## 2. Tipografía

Una sola familia sans-serif: **Inter** (fallback: IBM Plex Sans → sans-serif del sistema).
Cifras: usar **variante tabular** (`fontFeatures: [FontFeature.tabularFigures()]`) en cantidades, costos, distancias, porcentajes, fechas en tabla.

Pesos (de Identidad Visual): **SemiBold/Bold** títulos · **Medium** etiquetas y subtítulos · **Regular** contenido y formularios. No usar más de estos tres.

### Escala

| Token | Tamaño / línea | Peso | Uso |
|---|---|---|---|
| `type.display` | 28 / 34 | Bold | Cifra clave única de dashboard (KPI grande). Uso escaso. |
| `type.title` | 20 / 26 | SemiBold | Título de pantalla, encabezado de sección. |
| `type.subtitle` | 16 / 22 | Medium | Encabezado de card, subtítulos. |
| `type.body` | 14 / 20 | Regular | Contenido, valores de formulario, celdas de tabla. |
| `type.label` | 12 / 16 | Medium | Labels de campo, encabezados de tabla, texto de badge. |
| `type.caption` | 11 / 14 | Regular | Metadatos, ayudas, timestamps. Mínimo absoluto. |

Reconciliación con el skill (`máx. 4 tamaños`): un centro de control con datos densos justifica 6 escalones; **no más de 6**, y nunca crear tamaños fuera de esta tabla. Cuerpo mínimo 14 (14 = mínimo absoluto del skill); preferir 16 para lectura primaria prolongada. Jerarquía por tamaño + peso + `color.text.secondary`, no poniendo todo en negrita.

Soportar escalado de fuente del sistema (Flutter respeta `MediaQuery.textScaler`): no fijar alturas de fila/botón en píxeles rígidos que corten texto al 130 %.

---

## 3. Espaciado, radios, bordes, sombra

### Espaciado — grilla de 4 / 8

`space.1 = 4` · `space.2 = 8` · `space.3 = 12` · `space.4 = 16` · `space.6 = 24` · `space.8 = 32` · `space.12 = 48`

- Todo margen/padding es uno de estos valores. Sin números arbitrarios.
- Espaciado por relación: elementos relacionados más juntos; salto al siguiente grupo ≈ 2×.
- Padding interno de card: **16** (densidad de control); **12** en variante compacta. Gap entre cards: **12**.
- Padding horizontal de pantalla: **16**.
- Separación mínima entre *touch targets*: **8**.

### Radios — "ligeramente redondeado, no pill"

`radius.sm = 4` (badges, chips) · `radius.md = 6` (botones, inputs) · `radius.lg = 8` (cards, hojas, diálogos).
**Máximo 8.** No usar radios tipo `rounded-2xl/3xl` del skill (estética de consumo) — ver [No adoptar](#no-adoptar).

### Bordes

- Card: 1 px `color.border.card` + sombra sutil.
- Input: 1 px `color.border.input`; foco: 2 px `color.brand.red` (anillo de foco de marca); error: 2 px `color.state.error`.
- Tabla: solo `color.divider.table` de 1 px entre filas. Sin bordes exteriores pesados.
- Franja de estado en card: barra lateral (izquierda) o superior de 3–4 px con el color de estado.

### Sombra — un solo token

`elevation.card`: `y=1, blur=3, spread=0, color=#14273F @ 8%`.
`elevation.overlay` (hojas, menús, diálogos): `y=4, blur=12, color=#14273F @ 12%`.
Nada más. Sin *glow*, sin *inner shadow* decorativa, sin sombras de color neón.

---

## 4. Accesibilidad (obligatorio)

Base: `references/accessibility-checklist.md` del skill (WCAG 2.1 AA).

- **Touch targets:** mínimo **48 × 48 dp** (Material; la app es Flutter/Material). Acción primaria y FAB-equivalentes más grandes. Separación ≥ 8 dp.
- **Contraste:** cumplir la tabla de la sección 1. Texto normal 4.5:1, texto grande / componentes 3:1.
- **Labels accesibles:** todo control interactivo con `Semantics(label:)` / `tooltip`. Iconos-botón sin texto visible → label obligatorio.
- **Orden de foco:** arriba→abajo, izquierda→derecha. Anunciar cambios de pantalla y contenido dinámico (`SemanticsService.sendAnnouncement` / `liveRegion` para resultados de acción, errores de guardado).
- **Formularios:** label siempre visible (no solo placeholder); error asociado al campo con texto de recuperación ("Reintentar", "Formato: 000-000"), no solo color.
- **Estados de foco visibles:** borde de foco de 2 px `color.brand.red` en navegación por teclado/switch access.
- **No transmitir estado solo por color** (repetido de sección 1): badge = color + icono + texto.

Verificación antes de cerrar una feature de UI:
```
python .agents/skills/mobile-app-design-standards/scripts/check-contrast.py "#TEXTO" "#FONDO"
bash   .agents/skills/mobile-app-design-standards/scripts/validate-touch-targets.sh <dir>
bash   .agents/skills/mobile-app-design-standards/scripts/accessibility-audit.sh   <dir>
```
(En Windows, ejecutar los `.py` con `PYTHONIOENCODING=utf-8`.)

---

## 5. Componentes (diseño atómico)

Organización: **átomos → moléculas → organismos**, presentacional vs. contenedor. Los widgets solo reaccionan a estados del BLoC/Cubit; nunca llaman red directo (regla de `CLAUDE.md`). Una única implementación por componente en `lib/core/`; **sin estilos por módulo**.

### Átomos

| Componente | Especificación |
|---|---|
| **Botón primario** | Relleno `color.action.primary`, texto `#FFFFFF` ≥ 14 pt SemiBold, `radius.md`, alto 48. **Uno por pantalla.** Pressed: overlay `#14273F @ 20%`. Disabled: opacidad 38 %, sin sombra. |
| **Botón secundario** | Outline 1 px `color.border.input`, texto `color.text.primary`, fondo `color.surface.card`, misma métrica. |
| **Botón destructivo** | Relleno o outline `color.brand.red`, texto blanco (relleno) o rojo (outline). Solo cuando la acción borra/cierra. Requiere confirmación. |
| **Input de texto** | Fondo blanco, borde `color.border.input`, label `type.label` siempre visible arriba, alto ≥ 48, `radius.md`. Estado error: borde `color.state.error` + texto de error `type.caption` en rojo debajo. |
| **Valor automático vs. manual** | Campo con **valor estimado/automático**: fondo `color.surface.canvas`, icono de "calculado" y label "Estimado", editable pero visualmente distinto. Campo **ingresado por el usuario / valor real**: fondo blanco, borde pleno. Nunca deben verse iguales (regla de dominio: pares `valor_estimado` / `valor_real`). `viaje.valor_flete` usa siempre el estilo de **valor ingresado por el usuario** (fondo blanco, borde pleno): es un monto pactado con el cliente, no un par estimado/real. |
| **Selector / dropdown** | Preferir sobre escritura libre. Muestra valor precargado por defecto. Icono chevron outline. |
| **Badge de estado** | `radius.sm`, `type.label`, relleno del color de estado al 12–16 % con **texto e icono del color de estado a intensidad plena** o texto `#14273F`. Sobre ámbar de advertencia, texto oscuro; blanco solo sobre verde o rojo de error. |
| **Icono** | Outline, trazo uniforme, 24 dp. Camión para vehículo/módulo de vehículos y como marcador animado del banner de autenticación. Set: vehículo, ruta, conductor, carga, mantenimiento, documento, ubicación, reporte, alerta, ACPM, peaje. |

### Moléculas / organismos

| Componente | Especificación |
|---|---|
| **Card** | Fondo blanco, `radius.lg`, 1 px `color.border.card`, `elevation.card`, padding 16. Franja lateral/superior de estado cuando aplique. Uso: dashboard, viajes activos, vehículos, conductores, resúmenes. |
| **Tabla** | Encabezado fijo en scroll (`type.label`, fondo `color.surface.canvas`). Filas separadas por `color.divider.table`. Numéricos a la derecha con cifras tabulares. Estado = badge en celda, **no** fila coloreada. Paginada (`page`, `size`). |
| **Encabezado de pantalla** | Fondo `color.brand.steel`, título `type.title` blanco, back arriba-izquierda, acción contextual arriba-derecha (máx. 1). |
| **Navegación inferior** | Fija, 4–5 destinos por rol, **icono outline + texto** (`type.caption`), activo en `color.brand.red` (icono + label + franja superior de 2 px), resto `color.text.secondary`. Consistente entre pantallas. |
| **Alerta / banner** | Borde izquierdo 3 px del color de estado, fondo blanco, icono + título `type.label` + cuerpo `type.body`. No ocupa fondo completo. No oculta contenido clave. |

---

## 6. Estados de pantalla (siempre diseñar los cuatro)

De `references/common-mistakes.md` y `performance-patterns.md` del skill, filtrado por el tono profesional de OptiRuta:

- **Carga:** *skeleton* de la estructura real (cards/filas en gris `color.surface.canvas`) para contenido; spinner solo en operaciones > 1 s sin estructura previsible. Feedback táctil < 100 ms en cada tap. Sin *layout shift* al resolver.
- **Vacío:** ilustración lineal simple **o** solo texto claro (sin flat-art colorido). Explica qué falta y ofrece la acción concreta ("Aún no hay viajes planificados. Crear viaje").
- **Error:** mensaje en español, sin jerga técnica ni datos de BD/stack (coincide con la regla de errores de `CLAUDE.md`). Siempre una acción de recuperación ("Reintentar").
- **Éxito:** confirmación sobria — check + texto + resumen del resultado (p. ej. "Viaje ASIGNADO a Juan Pérez"). **Sin** animaciones celebratorias, confeti ni "sparkles".

Listas largas (viajes, peajes, hitos): virtualizar (`ListView.builder` / paginación), `const` en ítems, evitar reconstrucciones; *pull-to-refresh* estándar.

Actualización optimista solo donde el backend confirma rápido y el rollback es trivial; en cambios sobre viajes (transiciones de estado, cierre, ajustes) **esperar confirmación del servidor** — la lógica vive del lado servidor (funciones RPC / RLS en la base de datos).

---

## 7. Mapeo a Flutter

- Tokens en `lib/core/theme/` como una sola fuente: `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_radius.dart`, `app_elevation.dart`; ensamblados en `app_theme.dart` (`ThemeData` claro). No hay tema oscuro en el MVP salvo que Identidad Visual lo pida.
- Componentes reutilizables en `lib/core/widgets/` (o `lib/core/design/`): `PrimaryButton`, `SecondaryButton`, `AppTextField`, `EstimatedValueField`, `AppSelect`, `StatusBadge`, `AppCard`, `AppDataTable`, `ScreenHeader`, `BottomNav`, `AppAlert`, `EmptyState`, `ErrorState`, `LoadingSkeleton`.
- Prohibido definir colores/paddings/estilos inline en features. Un lint/PR review rechaza hex crudos fuera de `app_colors.dart`.
- `features/<feature>/presentation/` consume estos widgets; nada de `Color(0x...)` ni `EdgeInsets` mágicos ahí.

---

## No adoptar

Recomendaciones presentes en las skills que **contradicen** el concepto *centro de control logístico* (`herramienta profesional, no app de consumo`) y por tanto **no se aplican** en OptiRuta:

| Recomendación del skill | Motivo de descarte |
|---|---|
| Gradientes suaves, `backdrop-blur` / glassmorphism, *glow* detrás de elementos, *inner shadows* decorativas | "Función sobre decoración"; paleta plana y sombra única. |
| `rounded-2xl` / `rounded-3xl`, estética "moderna" de cards | Identidad Visual exige esquinas *ligeramente* redondeadas; máx. `radius.lg = 8`. |
| Peak-End Rule emocional, "holy dang moment", micro-animaciones celebratorias, badges de logro, sparkles | App operativa; el éxito se comunica con confirmación sobria. |
| Gamificación, streaks, "Vanity Mirror" / insights identitarios para compartir | Fuera del dominio; no hay componente social. |
| Emojis junto a opciones para "dar personalidad" | Iconografía outline uniforme, sin decoración. |
| Paletas por industria (neón cripto, colores brillantes de salud, etc.), acentos "etéreos" | Paleta cerrada y única. |
| Fotografía de producto de alta calidad, visuales generados por IA con paletas variadas | Imágenes solo con función (vehículos, recibos, evidencias, documentos). |
| Convenciones específicas de iOS HIG que difieren de Material (FAB vs. barra, large titles, gestos de sistema) | Interfaz única Flutter/Material; no se mantienen dos lenguajes de plataforma. |
| Librerías UI de React Native (Paper, Tamagui, NativeBase) de `references/ui-libraries.md` | Stack es Flutter; se construyen los componentes en `lib/core/`. |

Lo que **sí** se toma de las skills: grilla 4/8, `touch targets` 48 dp, umbrales de contraste WCGA AA y el validador, escala tipográfica acotada con mínimos legibles, diseño atómico + separación presentacional/contenedor, los cuatro estados de pantalla, *skeletons*, virtualización de listas y feedback < 100 ms, y el checklist de accesibilidad.

---

## Fuera de alcance (MVP)

Componentes de UI que **no** se diseñan ni se construyen en esta beta (ver [requisitos-funcionales-y-no-funcionales.md](requisitos-funcionales-y-no-funcionales.md)):

- Vista de calendario interactivo (mensual/semanal) para gestión de fechas de viaje — el MVP usa formulario + selector de fecha simple, ya cubierto por los átomos de esta sección.
- Mapa de tracking en vivo / cualquier visualización de ubicación en tiempo real.
- Filtros avanzados de reportes y exportación de reportes (PDF u otro formato).
