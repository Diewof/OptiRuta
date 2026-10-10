# OptiRuta · Sistema de diseño v2 — Entregable 1

> **Estado:** PROPUESTA para aprobación. No se ha tocado código de la app ni los documentos vigentes. Todo lo de esta carpeta es nuevo.
> **Fuente de dominio:** `CLAUDE.md` y `requisitos-funcionales-y-no-funcionales.md`. **Fuente de diseño:** `brief-rediseno-visual.md` (manda), con `Instrucciones de Identidad Visual.md` y `sistema-de-diseno.md` como punto de partida.

## 0. Qué hay en esta carpeta y cómo verlo

Abre los HTML con doble clic (Chrome/Edge). Las tres pantallas son interactivas y traen un panel lateral con interruptores.

| Archivo | Qué es |
|---|---|
| [pantallas/1-conductor-inicio.html](pantallas/1-conductor-inicio.html) | Conductor · Inicio. Registrar hito (con y sin señal), estimado → real del ACPM, estados vacío/carga/error. |
| [pantallas/2-administrador-dashboard.html](pantallas/2-administrador-dashboard.html) | Administrador · Dashboard. Rentabilidad consolidada con conteo y semáforo (cambia de mes), viajes en curso, alerta nueva. |
| [pantallas/3-administrador-detalle-viaje.html](pantallas/3-administrador-detalle-viaje.html) | Administrador · Detalle de viaje. Rentabilidad marginal, estimado vs. real, llegada del correo GoPass, cierre y ajuste con motivo. |
| [pantallas/componentes.html](pantallas/componentes.html) | Galería del sistema: tokens, 52 iconos, todos los componentes con sus estados, catálogo de movimiento. |
| `pantallas/assets/` | `optiruta.css` (tokens + componentes), `icons.js` (set de iconos), `app.js` (utilidades), imágenes de vehículo e ilustraciones SVG. |

Atajos para revisar: añade al final de la URL `#ts=1` (texto al 130 %), `#rm=1` (reducir movimiento), `#state=loading|empty|error`. Los mismos interruptores están en el panel de cada pantalla.

**Cómo se verificó:** capturas con Edge sin cabeza al 100 % y al 130 % de texto, recorrido automatizado de las interacciones (sin errores de consola) y contraste calculado en la galería. **No se verificó** en un celular real ni con TalkBack/VoiceOver, y no se escribió código Flutter.

---

## 1. Idea de diseño: «el hilo de ruta»

La esencia sale del logo real (`mobile/assets/branding/logo.png`): una **carretera en S** con dos **pines rojos**. No es decoración: es el mismo gesto, repetido donde tiene función.

| Dónde aparece el hilo | Para qué sirve |
|---|---|
| **Línea de progreso de hitos** (Inicio del conductor): nodos unidos por un hilo que se rellena | Mostrar qué ya pasó y qué sigue |
| **Figura de ruta** (tarjeta y detalle de viaje): la S del logo, anillo de origen, pin rojo de destino | Orientar origen → destino. Es **estática y estimada** (sin camión sobre la línea, no es seguimiento) |
| **Ilustraciones** (vacío, éxito de cierre, error): la misma carretera con sus nodos | Explicar y ofrecer una acción; una por pantalla |
| **Iconos de ruta**: anillo / punto / pin con hueco | Identidad consistente (§4) |
| **Navegación**: indicador y icono activo en rojo de marca | Orientación |

El rojo de marca queda como acento: pin, indicador activo, foco, línea bajo la barra de detalle y botón destructivo. Nunca como fondo.

---

## 2. Tokens

### 2.1 Color — sin colores nuevos

Los 9 colores de la marca no cambian. Se **derivan** tintes por mezcla con blanco (no son colores nuevos):

| Token | Hex | Uso |
|---|---|---|
| `navy` / `slate` / `canvas` / `card` | `#14273F` `#333A45` `#F3F4F6` `#FFFFFF` | Igual que hoy |
| `action` | `#1E3A5F` | Único primario. Nunca rojo |
| `red` (rojo de marca) | `#A62C2C` | Acento de identidad (ver §1) |
| `success` / `warning` / `error` | `#2E7D52` `#C6871B` `#C43D2E` | Solo estados, siempre con icono y texto |
| `navy-06` *(nuevo, derivado)* | `#EDEFF3` | Fondo suave: miniatura, fila «siguiente», badge neutro |
| `navy-12` *(nuevo, derivado)* | `#E3E5E8` | Hilo sin recorrer, esqueleto, badge «Finalizado» |
| `success-tint` / `error-tint` / `warning-tint` | `#E7F1EC` `#F8E9E7` `#FBF1DC` | Fondo del semáforo (ya existían los dos primeros) |
| Neutros de texto y borde | `#5C6470` `#9AA0A9` `#B4B8BF` `#D9DBDF` `#E6E7EA` | Igual que hoy |

**Contraste (calculado en la galería).** Texto del botón primario 11,5:1 · título sobre lienzo 13,7:1 · texto secundario 6,0:1 · texto navy sobre tinte ámbar 13,4:1 · badge de retraso (navy sobre ámbar) 4,9:1 · blanco sobre rojo de marca 7,0:1 · rojo de marca como texto 7,0:1 · blanco sobre hero navy 15,1:1. Iconos verde/rojo sobre su tinte: 4,4:1 (el mínimo para elementos gráficos es 3:1).

> **Hallazgo:** un icono ámbar sobre el tinte ámbar da 2,7:1 y **no pasa** 3:1. Por eso el semáforo no usa «icono del color sobre tinte»: usa **glifos de color pleno con forma propia** (§6.2).

### 2.2 Tipografía — Inter, cifras tabulares

Se mantiene la escala vigente y se **añade un escalón**: `hero 36/42 · 700`, solo para la cifra de rentabilidad.

| Token | Tamaño / línea | Peso | Uso |
|---|---|---|---|
| `hero` *(nuevo)* | 36 / 42 | 700 | Número de rentabilidad |
| `display` | 28 / 34 | 700 | Cifra clave, saludo |
| `title` | 20 / 26 | 600 | Título de pantalla |
| `subtitle` | 16 / 22 | 600 | Encabezado de tarjeta *(hoy 500; la jerarquía pedía más peso)* |
| `body` | 14 / 20 | 400 | Contenido |
| `label` | 12 / 16 | 500 | Etiquetas, encabezado de tabla |
| `caption` | 11 / 14 | 400 | Metadatos, hora estimada/real. Mínimo |

Regla de escala: las alturas nunca son fijas; al 130 % todo se reacomoda. Donde no cabe (tabla estimado vs. real) el componente cambia de forma (§7).

### 2.3 Espaciado, radios, elevación

| Token | Valores |
|---|---|
| Espaciado (grilla 4/8, sin cambios) | 4 · 8 · 12 · 16 · 24 · 32 · 48 |
| Radios | `sm 6` barras y marcas · `md 12` botón, campo, miniatura, ficha de icono · `lg 16` tarjeta · `xl 24` hoja inferior y cabecera del conductor · `pill` badge, chip, semáforo |
| Elevación (dos niveles) | `card`: `0 1 2 / 0 4 14` navy 6–7 % · `float`: `0 8 28` navy 22 % (hoja, aviso, tarjeta de rentabilidad del dashboard) |

Se elimina la sombra de color del botón primario que traía la muestra.

### 2.4 Movimiento

| Token | Valor | Uso |
|---|---|---|
| `motion.fast` | 120 ms | Pulsación, salida del valor que se reemplaza |
| `motion.base` | 200 ms | Fundidos, check que se dibuja, semáforo, entrada de un valor |
| `motion.slow` | 300 ms | Hoja inferior, tramo del hilo, entrada de tarjetas |
| `motion.count` | 600 ms | Solo el conteo de rentabilidad, una vez por carga |
| `ease.out` | `cubic-bezier(.2,.8,.2,1)` | Casi todo |
| `ease.inOut` | `cubic-bezier(.4,0,.2,1)` | Rellenos y cambios de color |
| `stagger` | 40 ms, máx. 5 | Listas |

Con **reducir movimiento** todo vale 0 ms: aparece el estado final. Ninguna animación es el único aviso de algo.

---

## 3. Imágenes e ilustración

| Elemento | Regla |
|---|---|
| **Foto del vehículo** | Miniatura 4:3, esquinas 12, mismo recorte. Aparece en tarjeta de viaje, detalle y (fase 3) flota. Sin foto → **imagen de reemplazo de marca** (`vehiculo-doble-troque.svg`, `vehiculo-mula.svg`): vista lateral con la franja roja de marca. Sin ninguna → marcador «Sin foto». Nunca un hueco |
| **Figura de ruta** | S del logo, anillo navy de origen, pin rojo de destino. Estática, marcada «estimada» (`≈`). Si el proveedor no entrega geometría (pendiente #18) sigue valiendo: es un esquema, no el trazado real |
| **Ilustración de marca** | Lenguaje del logo: carretera slate con guiones, anillo, pin rojo; el verde solo en el check de éxito. **Máx. una por pantalla**, solo en vacío, éxito de cierre y error. Nunca en pantallas de trabajo denso. Entregadas: `ilustracion-sin-viaje`, `ilustracion-viaje-cerrado`, `ilustracion-ruta-interrumpida` |
| **Evidencias** (recibos, documentos) | Miniatura + vista ampliada. Fuera de las 3 pantallas de muestra; el botón «Foto del recibo» está en la hoja de costo |
| **Prohibido** | Foto de stock, imagen sin función, ilustración con paleta ajena |

---

## 4. Iconos

**Una familia:** cuadrícula 24, trazo 1,75, terminales redondeados; contorno por defecto, **relleno** solo en el destino activo de navegación. Rasgo de marca: el **nodo** (anillo, punto o pin con hueco del logo) en la familia de ruta: ruta, origen, destino, salida, hito de llegada, rentabilidad. Los iconos de estado nunca llevan rojo de marca.

Cobertura de la lista mínima del brief (§3.4-B), todo en [componentes.html](pantallas/componentes.html): doble troque, mula, ruta, origen, destino, carga, cliente, conductor, ACPM, peaje, mantenimiento, documento, vencimiento, retraso, rentabilidad · **4 hitos** (salida, llegada a cargue, salida con carga, llegada a destino) · **sincronización** (en línea, pendiente, sin señal, sincronizando) · **dato** (estimado, real, parcial, ajustado) · navegación (inicio, resumen, personas, más, perfil) · semáforo (4 formas) · interfaz.

| Opción de origen | Pro | Contra |
|---|---|---|
| **A. Lucide (ya instalado) para genéricos + SVG propios para dominio** *(recomendada)* | Cero dependencias nuevas (`flutter_svg` ya está); identidad donde importa; los genéricos (chevron, x, plus, campana, info, candado, calendario, cámara) no merecen dibujo propio | Dos fuentes: hay que fijar que los propios usen el mismo trazo (1,75) |
| B. Todo propio | Máxima coherencia | Más tiempo; los 16 genéricos casi no ganan identidad |
| C. Solo Lucide | Nada que mantener | Es lo que hace ver la app genérica; no hay doble troque ni mula |

En el prototipo los genéricos están redibujados en el mismo estilo para que se vea como una familia; en Flutter los genéricos serían `LucideIcons`. **Los dibujos son originales de este entregable;** conviene que un diseñador los revise antes de la fase 1 (decisión #15 del brief).

---

## 5. Componentes (brief §6) y sus estados

| Componente | Estados diseñados | Dónde verlo |
|---|---|---|
| Botón primario / secundario / terciario / destructivo | normal · presionado · foco · deshabilitado · cargando | galería §3 |
| Campo de texto | normal · foco · **automático (estimado)** · confirmado por el usuario · error · deshabilitado | galería; hoja «costo real» |
| Chip de selección | normal · seleccionado | hoja de costo, hoja de ajuste |
| Badge de ciclo del viaje | planificado · asignado · en curso · finalizado · cerrado (+ retraso) | pantallas 1–3 |
| **Indicador de rentabilidad** (número + semáforo + base) | `ok` · `warn` · `bad` · `none`; base proyectada · parcial · confirmada · ajustada | pantallas 2 y 3 |
| **Marca de dato estimado/real/ajustado** | estimado · real · ajustado · pendiente | pantallas 1 y 3 |
| **Línea de progreso de hitos** | hecho · siguiente · pendiente; sincronizado · en el equipo | pantalla 1 |
| **Indicador de sincronización** | sincronizado · sincronizando · por enviar · sin señal | pantalla 1 |
| Tarjeta de viaje | con franja de atención / sin franja; con retraso | pantalla 2 |
| Tarjeta KPI | normal · pulso de alerta nueva | pantalla 2 |
| Tabla estimado vs. real | normal · **apilada con texto grande** · pendiente · parcial · ajustada | pantalla 3 |
| **Hoja inferior** | cerrada · abierta · con validación · botón deshabilitado hasta completar motivo | pantallas 1 y 3 |
| Aviso temporal (con «Deshacer») | oculto · visible | pantalla 1 |
| Alerta / banner | info · atención · error | galería |
| **Miniatura de vehículo** | foto de reemplazo doble troque · mula · «Sin foto» | galería, pantallas 1–3 |
| **Ilustración de estado** | vacío · éxito · error | pantallas 1–3 |
| **Figura de ruta** | estática, estimada | pantallas 1 y 3 |
| Estados de pantalla | carga (esqueleto) · vacío · error · éxito (hoja con ilustración) | interruptores del panel |
| Navegación inferior | activo (rojo, icono relleno) · inactivo; con contador | pantallas 1 y 2 |

---

## 6. Reglas de uso

### 6.1 Estimado / real / ajustado — opción C del brief (implementada)

| Opción | Pro | Contra |
|---|---|---|
| A. Marca por valor | Ocupa poco | No permite comparar |
| B. Columnas lado a lado | Ideal para desviaciones | Pesada en listas |
| **C. Combinada** *(recomendada y usada)* | Marca en listas y tarjetas, columnas en el detalle, tercer estado «Ajustado» | Hay que fijar bien los tres estados |

| Estado | Cómo se ve (sin depender del color) |
|---|---|
| **Estimado** | Prefijo `≈`, gris azulado, peso normal, chip «Est.» |
| **Real** | Check, texto pleno en seminegrita, chip «Real». La **fuente** va como texto («Conductor», «GoPass», «Calculada») para que no haya que decidir ahora qué cuenta como real |
| **Ajustado** | Icono de historial, chip «Ajustado»; el motivo queda visible bajo el concepto |
| **Pendiente** | «Pendiente» en gris + texto de qué se espera («Esperando GoPass») |
| **Campo con valor automático** | Borde punteado, fondo lienzo, chip «Est.», ayuda «Estimado por el sistema…». Al editarlo pasa a campo normal con «Este valor quedará como real» |

El **flete no es un par**: es un monto pactado, un solo valor (`CLAUDE.md`). Se muestra con el chip «Pactado» y sin columna estimada.

### 6.2 Semáforo y base de cálculo

- El **semáforo** tiene 4 estados con **forma distinta**, no solo color: verde = círculo con check · ámbar = triángulo con «!» (glifo oscuro sobre ámbar) · rojo = círculo con ✕ · gris = círculo discontinuo con guion («Sin datos suficientes»).
- La app **no calcula** el estado: lo entrega el servidor (RPC) y la app solo dibuja `ok · warn · bad · none`. Los **umbrales, y las etiquetas «Rentable / Margen bajo / Pérdida», quedan configurables y sin definir** (§10). En el prototipo el estado es dato de ejemplo.
- **Base de cálculo** bajo o junto al número: *Proyectada* (todo estimado) → *Parcial* → *Confirmada* → *Ajustada* (tras cierre con ajustes). Es lo que dice qué tan firme es el número.
- **Marginal y consolidada nunca se mezclan.** El hero del dashboard dice «Rentabilidad **consolidada**» (mantenimiento + sueldo fijo prorrateado). Cada viaje dice «marginal». El detalle de viaje explica con una nota qué no entra.
- El rojo de marca **no** aparece dentro del indicador de rentabilidad (se parece al rojo de error).
- **Franja lateral de tarjeta = viaje con retraso** (RF-20: 20 % del tiempo estimado del tramo o 30 min, lo mayor). No indica rentabilidad: eso lo hace el semáforo. Esto evita que dos señales distintas usen el mismo color.
- **Badges del ciclo del viaje** usan neutros y el azul de acción, no los colores del semáforo.
- La lista de viajes en curso se ordena **por atención** (retraso y pérdida primero).

### 6.3 Tono

Tuteo, frases cortas, sin jerga: «Hola, Andrés», «Siguiente: salir con carga», «Hoy no tienes viaje asignado», «Lo que ya registraste sigue guardado». Pendiente de confirmar tuteo vs. «usted» (§10, #7).

---

## 7. Qué cambió en las pantallas respecto a las muestras

**Errores de dominio encontrados en la muestra 3 (corregidos):**
1. Mostraba el **flete como par estimado/real** (≈ 9.800 y ✓ 9.800). `CLAUDE.md` dice que es un único monto pactado.
2. **Restaba el mantenimiento amortizado** dentro de la rentabilidad marginal («Margen ≈ 3.090 = … − 900»). `CLAUDE.md`: el mantenimiento y el sueldo fijo **no** entran en la marginal, solo en la consolidada. Ahora la fila no está y hay una nota que remite a la consolidada.

**Mejoras de diseño:**

| Pantalla | De la muestra | Ahora |
|---|---|---|
| **1 · Conductor** | Lista vertical origen/destino, sin imagen; «Costos» con un solo botón | Figura de ruta con la S del logo, miniatura del vehículo, hitos con **icono propio**, hilo que se rellena y estado de sincronización **por hito**; hoja de confirmación (**2 toques** desde Inicio); costo real con valor precargado «Est.»; peajes marcados «Automático» (solo llegan por GoPass); estados vacío/carga/error |
| **2 · Dashboard** | Tarjeta navy + KPI + 3 viajes | Selector de período; el conteo y el semáforo cambian entre meses; **medidor «9 de 14 viajes con costos confirmados»** que explica por qué es «Parcial»; flota con 4 pictogramas; tarjetas con miniatura, hito X de 4 y retraso; orden por atención |
| **3 · Detalle** | Tabla fija de 326 px que se rompía con texto grande | Tabla fluida que **se apila al 130 %**; peaje «Pendiente» que pasa a real al llegar GoPass (anima y recalcula el número); tiempos de hitos; cierre con **confirmación explícita**, éxito con ilustración y **ajuste con motivo obligatorio** (botón deshabilitado hasta completarlo) |

**Las 3 animaciones clave (brief §3.4-C):**
1. **Registrar hito** (pantalla 1): confirmar → check que se dibuja → el tramo del hilo se rellena → el siguiente hito se activa y el botón cambia. El guardado es inmediato; la animación solo lo acompaña.
2. **Estimado → real** (pantalla 1, ACPM; pantalla 3, peajes): sale el «≈ valor», entra el real con el check dibujándose.
3. **Rentabilidad** (pantalla 2 por mes, pantalla 3 al llegar GoPass): el número se acomoda en ≤ 600 ms una sola vez; el semáforo cambia con fundido de 200 ms.

---

## 8. Accesibilidad (mínimos no negociables)

| Requisito | Estado |
|---|---|
| Contraste AA | Cumple en todas las parejas usadas (tabla de §2.1; recalculable en la galería) |
| Objetivo táctil ≥ 48 dp | Botones, chips, flechas de período, aviso «Deshacer» y navegación (64) cumplen. Badges y chips de estado no son interactivos |
| Estado nunca solo por color | Icono con forma + texto en semáforo, badges y sincronización; `≈ / ✓ / historial` en estimado-real-ajustado |
| Reducir movimiento | Interruptor en cada panel y `prefers-reduced-motion`; todo pasa a 0 ms |
| Texto hasta 130 % | Interruptor «Texto 130 %»; capturas revisadas: sin recortes; la tabla se apila |
| Foco visible | Anillo rojo de marca de 2 px |
| Lectores de pantalla | `aria-label` en tarjetas y hero, región viva para hitos, alertas y rentabilidad |

**Pendiente de medir en dispositivo real:** TalkBack, rendimiento de las animaciones en gama media (decisión #17), brillo/uso nocturno en cabina (tema único claro).

---

## 9. Desviaciones

Las dos primeras tablas son **cambios que el brief ya propuso** (§3.3, aplicados sin pedir permiso otra vez). La tercera reúne las **desviaciones propias** que no estaban en el brief: esas sí piden tu visto bueno.

### 9.1 Aplicadas del brief §3.3 / §3.4

| # | Regla anterior | Qué propongo | Por qué | Qué se actualizaría |
|---|---|---|---|---|
| 1 | «Centro de control… no una app de consumo» | «Herramienta profesional con trato cercano y moderno» | El dueño pidió cercanía | Identidad Visual (Concepto y Principio general); `CLAUDE.md` (Identidad visual) |
| 2 | Radios máx. 8; botones sin pill | 6 / 12 / 16 / 24 + pill en badges y chips; botones 12, nunca pill | Más amigable sin perder seriedad | `sistema-de-diseno.md` §3 y «No adoptar»; Identidad Visual (Botones); `app_radius.dart` |
| 3 | Una sombra de tarjeta + una de overlay | Dos niveles `card` y `float` con nuevos valores | Mejor jerarquía en móvil | `sistema-de-diseno.md` §3 Sombra; `app_elevation.dart` |
| 4 | Vacío = texto o ilustración lineal | Ilustración de marca con función (vacío, éxito, error) | Cercanía sin decoración | `sistema-de-diseno.md` §6; Identidad Visual (Imágenes) |
| 5 | Tono neutro | Tuteo, frases cortas *(a confirmar #7)* | Alineado con «cercana» y RNF-04 | Identidad Visual (nueva sección «Tono») |
| 7 | Navegación genérica | Conductor 3 destinos, administrador 5 | Menos opciones | `sistema-de-diseno.md` §5 Navegación |
| 8 | Imágenes solo con función; evitar ilustración colorida | Foto de reemplazo de vehículo + figura de ruta + ilustración de marca | Esencia con función | Identidad Visual (Imágenes) |
| 9 | Iconos outline sin detalles | Lucide para genéricos + SVG propios con el nodo | Identidad reconocible | `CLAUDE.md` (Identidad visual / iconos); `sistema-de-diseno.md` §5 átomo Icono |
| 10 | Sin animaciones | Catálogo de movimiento (§2.4) | Feedback claro | Identidad Visual y `sistema-de-diseno.md` (nueva sección Movimiento); nuevo `AppMotion` |

### 9.2 Decisión del brief que recomiendo cerrar así (#6)

| Regla anterior | Qué propongo | Por qué | Qué se actualizaría |
|---|---|---|---|
| Botón primario con **degradado** en auth (`authGradient*`, incluye `#2C5A8F`, fuera de la paleta) | **Plano en toda la app** | Consistencia; elimina un color fuera de la paleta y la única excepción | `sistema-de-diseno.md` §1 (bloque Autenticación); `app_colors.dart` (quitar `authGradient*`) |

### 9.3 Desviaciones propias (requieren tu visto bueno)

| # | Regla anterior | Qué propongo | Por qué | Qué se actualizaría |
|---|---|---|---|---|
| 11 | Escala tipográfica de 6 escalones | Séptimo escalón `hero 36/42` solo para rentabilidad; `subtitle` pasa de 500 a 600 | El número de rentabilidad es el dato clave y debe dominar; el subtítulo a 500 no marcaba jerarquía | `sistema-de-diseno.md` §2; `app_typography.dart` |
| 12 | Colores de estado como «relleno de badge al 12–16 % con icono del color de estado» | Semáforo con **glifos de color pleno y forma propia**; badge de retraso en ámbar sólido con texto navy | El icono ámbar sobre su tinte da 2,7:1 (< 3:1). Además la forma da la redundancia que pide «nunca solo color» | `sistema-de-diseno.md` §1 (regla operativa) y §5 (Badge) |
| 13 | Franja lateral = «estado» genérico | Franja = **retraso** (RF-20); la rentabilidad solo en el semáforo | Evita dos señales con el mismo color | Identidad Visual (Tarjetas); `sistema-de-diseno.md` §5 Card |
| 14 | Badges de ciclo con color de estado | Ciclo del viaje en neutros y azul de acción | No confundir «En curso» con «Rentable» | `sistema-de-diseno.md` §5 Badge |
| 15 | Rojo de marca: logo, franja, nav activa, foco, destructivo | Añadir: pin de figura/ilustración y línea de 2 px bajo la barra del detalle (ya estaba en la muestra) | Es el pin del logo; la línea viene de la muestra que gustó | `CLAUDE.md` y Identidad Visual (lista de usos del rojo) |
| 16 | Sombra de color en el botón primario (de la muestra) | Sin sombra propia | «Sin glow»; ya hay dos niveles | — (la muestra no era doc vigente) |
| 17 | Tabla con encabezado fijo y numéricos a la derecha | Se mantiene, y **al texto grande pasa a filas apiladas** (concepto arriba, tres valores con rótulo) | Las columnas fijas se rompían al 130 % | `sistema-de-diseno.md` §5 Tabla |
| 18 | Hoja de éxito solo «check + resumen» | Hoja con ilustración de marca + resumen | Es el momento clave del cierre (brief §3.4-A) | `sistema-de-diseno.md` §6 Éxito |

---

## 10. Lo que falta definir (no lo inventé)

Para cada punto dice cómo quedó el prototipo y qué recomiendo.

| # | Pendiente | Cómo está en el prototipo | Recomendación |
|---|---|---|---|
| 9 | **Umbrales del semáforo** y etiquetas («Pérdida» presupone margen negativo) | Estado fijo de ejemplo; la app solo dibuja `ok/warn/bad/none` | Umbrales en una tabla de configuración leída por la RPC; etiquetas también configurables |
| 10 | **Qué cuenta como «real»** (peaje GoPass es real pero no lo confirma el conductor; la comisión es calculada) | Una sola marca «Real» + la fuente como texto | Definir si GoPass y «calculada» cuentan para pasar a «Confirmada» |
| 11 | **Corregir un hito** | Aviso «Deshacer» 6 s en el prototipo | Decidir si existe y hasta cuándo; el diseño admite un valor configurable |
| 13 | **Formato del número** | Pesos grande + margen % al lado | Mantener ambos; ver opciones abajo |
| — | **¿Registrar «llegada a destino» finaliza el viaje solo?** | Tras el 4.º hito: «Todos los pasos registrados», sin cambiar de estado | Definir quién pasa EN_CURSO → FINALIZADO |
| — | **¿Se puede cerrar con un costo aún estimado?** | Sí, con aviso explícito «se cerrará con ese valor» | Definir si se bloquea o se permite con aviso |
| — | **Umbral de «Margen bajo»** del hero por período vs. por viaje: ¿misma regla? | Mismo componente, datos de ejemplo | Responder junto a #9 |
| — | **Qué ve el conductor de dinero** | Su ACPM estimado/real y «Peajes: automático» | Confirmar que el conductor ve **sus** costos y no la rentabilidad |
| 12 | Pantalla de consentimiento de ubicación | No se diseña (GPS fuera del MVP, RF-23 en Fase 2) | Posponer |
| 14–18 | Fotos de flota, quién produce iconos, foto de conductor, dispositivos, geometría de ruta | Imagen de reemplazo; iconos propios; sin foto de conductor | Ver §3 y §4 |
| 1–8 | Concepto, radios, botón primario, degradado, pantallas estrella, uso, tuteo, audiencia | Todo aplicado como recomienda el brief | Confirmar |

**Opciones con pros y contras (donde hay dos caminos válidos):**

| Formato del número de rentabilidad (#13) | Pro | Contra |
|---|---|---|
| **Pesos grande + margen % al lado** *(usado)* | Responde «¿cuánto gané?» y «¿qué tan bien?» a la vez | Dos cifras que mantener coherentes |
| Solo pesos | Limpio | No sirve para comparar viajes de distinto flete |
| Solo % | Comparable | Abstracto para quien piensa en pesos |

| Unidad en tablas | Pro | Contra |
|---|---|---|
| **Miles de COP** *(usado, como la muestra)* | Cabe en 3 columnas | Dos escalas (hero en millones, tabla en miles) |
| Pesos completos | Una sola escala | No cabe al 130 % sin apilar siempre |

**Alcance conocido:** RNF-07 acota el modo sin conexión a hitos y costos del viaje en curso. Por eso «Mis viajes» (historial) **no** funciona sin red y, en la fase 2, debe decirlo con un aviso claro. La muestra del conductor solo cubre lo que sí funciona offline.

---

## 11. Inconsistencias que encontré en la documentación

1. **Botón primario:** Identidad Visual dice «ámbar» en *Botones* y «azul de acción» en *Colores*. Coincido con el brief: azul de acción.
2. **ACPM automático:** el brief (§8) lo lista como fuera del MVP, pero `CLAUDE.md` lo declara **dentro** del MVP (Edge Function `precio-acpm-scraper`). Mando `CLAUDE.md`; el diseño no depende de esto.
3. **`Optiruta.docx` no está en el repositorio.** Usé `requisitos-funcionales-y-no-funcionales.md` y `CLAUDE.md` como fuente de requisitos. Si el docx contiene algo que no esté ahí, dímelo.
4. **`sistema-de-diseno.md` §5** cita un token `color.brand.steel` que no existe en ningún otro lugar (el encabezado es `navy`).
5. **El brief dice «umbrales del semáforo sin definir»**, pero **sí** está definido el de **retraso** (RF-20). Lo usé para la franja.
6. **Muestra 1:** «Real · +10 min» en verde sugería que llegar tarde es bueno. Ahora la diferencia es neutra (`+10 min`, `−3 min`) y no se colorea (no hay regla de «a tiempo»).

---

## 12. Lista de cambios para actualizar la documentación (cuando apruebes)

**`Instrucciones de Identidad Visual.md`**
- Concepto y Principio general → «profesional con trato cercano».
- Colores → añadir tintes derivados; aclarar usos del rojo de marca (§9.3 #15).
- Botones → azul de acción (no ámbar); radio 12; no pill.
- Tarjetas → franja = retraso.
- Imágenes → foto de reemplazo, figura de ruta, ilustración de marca.
- Iconografía → familia propia + Lucide; rasgo del nodo.
- Nuevas secciones: **Movimiento** y **Tono**.

**`sistema-de-diseno.md`**
- §1: tintes; eliminar el bloque de degradado de auth y `#2C5A8F`; regla operativa del semáforo (glifos de color pleno).
- §2: escalón `hero`; `subtitle` 600.
- §3: radios 6/12/16/24/pill; dos sombras nuevas.
- §5: nuevos componentes (§5 de este documento); badge del ciclo; tabla apilable; corregir `color.brand.steel`.
- §6: éxito con ilustración.
- §7: añadir `AppMotion`; actualizar `app_radius`, `app_elevation`, `app_typography`, `app_colors`.
- «No adoptar»: quitar los radios y el rechazo de ilustración que ya no aplican.

**`CLAUDE.md`** — sección *Identidad visual*: concepto, radios, iconos (Lucide + SVG propios), usos del rojo, movimiento.

**`requisitos-funcionales-y-no-funcionales.md`** — nota en RNF-07: «Mis viajes» requiere conexión.

**`brief-rediseno-visual.md`** — marcar como resueltas las decisiones aprobadas y corregir la contradicción del ACPM automático.

**Sin cambios:** `pubspec.yaml` (no hay dependencias nuevas), esquema de BD, RPC, RLS, ciclo del viaje, permisos.

---

## 13. Qué sigue

Me detengo aquí. Con tu aprobación (o ajustes) preparo el **Entregable 2: plan de implementación por fases 0–5**, partiendo de que la fase 0 ya está entregada.
