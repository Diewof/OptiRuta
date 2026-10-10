# Brief de rediseño visual y de pantallas — OptiRuta

> **Estado:** BORRADOR **v2** para aprobación del dueño del producto. *Novedad v2: se añade la "esencia" visual (imágenes con función, iconografía propia y animaciones, §3.4) y se adjuntan 3 pantallas de muestra como referencia base.*
> **Destino sugerido:** `/Documentacion/Esquemas/brief-rediseno-visual.md`
> **Alcance de este documento:** decisiones de producto y diseño. No define arquitectura ni código; eso lo resuelve Claude Code dentro de las reglas ya existentes en `CLAUDE.md` y `arquitectura-y-estandares.md`.

---

## 0. Cómo debe trabajar Claude Code con este brief

1. **Leer primero** `Instrucciones de Identidad Visual.md`, `sistema-de-diseno.md`, `CLAUDE.md` y `Optiruta.docx` (requisitos RF/RNF).
2. **Entregable 1 (único por ahora):** un **sistema de diseño renovado** + **3 pantallas de muestra** (ver §9). Después **detenerse y esperar aprobación**.
   - Las **3 pantallas adjuntas** (`pantallas/*.html`, ver Anexo) son la **referencia base**: su estructura, jerarquía, color y componentes gustaron al dueño. **Todavía no tienen la esencia de §3.4** (imágenes, iconos propios, animaciones): Claude Code debe incorporarla y no limitarse a copiarlas.
3. **Entregable 2 (solo si se aprueba el 1):** **plan de implementación total por fases** (ver §9). No implementar pantallas antes de aprobar el plan.
4. Donde este brief **cambia** algo de la documentación vigente (§3), no asumir que ya está aprobado: está marcado como *propuesto*. Si hay duda, preguntar.
5. Donde falte una regla de negocio (§11), **no inventarla**: señalarla y proponer una opción concreta.
6. No cambiar reglas de negocio, estados del viaje ni permisos (§8).

---

## 1. Motivación

| Hoy | Se busca |
|---|---|
| La app se ve **genérica** | Identidad propia, reconocible, con la marca OptiRuta |
| **Poco intuitiva** y difícil de usar | Cada pantalla con una acción clara; pocos pasos |
| Ninguna pantalla actual gusta | Rediseño **visual y de pantallas** (no solo colores) |

**Hallazgo del repositorio:** hoy solo están construidas las pantallas de **autenticación** (login, registro, recuperar contraseña). La vista posterior al login es un **marcador de posición** (`SesionIniciadaPage`). Es decir: las pantallas operativas de conductor y administrador **se diseñan por primera vez** con este brief; no hay que "migrarlas".

**Audiencia de la app:** administradores de flota y conductores de la empresa (flota de 4 vehículos). Presentación adicional (académica / terceros): **por confirmar** (§11).

---

## 2. Contexto y usuarios

| | **Conductor** | **Administrador** |
|---|---|---|
| Dónde usa la app | En ruta: paradas, cargue/descargue, cabina | Oficina y en movimiento *(por confirmar)* |
| Condiciones | Momentos breves (RNF-03); **señal intermitente** (RNF-07); manos/atención limitadas | Revisa y decide con más calma; consulta datos |
| Necesita | Saber **qué sigue** y registrarlo en pocos toques | Ver **cómo va la flota y cuánto rinde** de un vistazo |
| Dispositivo | Celular (única interfaz, sin web) | Celular (única interfaz, sin web) |

*Supuestos pendientes de confirmar:* nivel de comodidad tecnológica del conductor, uso nocturno en cabina, tamaño de pantalla de los equipos reales (§11).

---

## 3. Identidad visual

### 3.1 Dirección

- **Sensación (elegida por el dueño):** **cercana, moderna y profesional.**
- **Referencias de interacción:** InDrive, Uber, Rappi (ver §10 — se toman *patrones*, no se copian pantallas ni marcas).
- **Marca existente:** nombre **OptiRuta**, logo y eslogan *"Rentabilidad de punto a punto"* ya definidos. **No se rediseña el logo.**
- **Colores:** se mantienen los de la marca (**azul y rojo**) ya presentes en la paleta vigente.
- **Esencia (pedido del dueño tras ver las pantallas de muestra):** el esquema de diseño gusta, pero se siente **sin esencia**. Se añaden **imágenes con función, iconos con identidad propia y animaciones** (ver §3.4).
- **Tema:** **un solo tema claro** ("sin temas" = sin modo oscuro ni variantes). *Riesgo conocido:* uso nocturno en cabina; se mitiga con alto contraste y brillo cómodo (ver §11).

### 3.2 Qué se MANTIENE de la documentación vigente

- Paleta cerrada: azul marino `#14273F`, gris pizarra `#333A45`, lienzo `#F3F4F6`, blanco, **azul de acción `#1E3A5F`**, **rojo de marca `#A62C2C`**, estados verde `#2E7D52` / ámbar `#C6871B` / rojo error `#C43D2E`. Sin colores nuevos.
- Tipografía: **Inter**, una sola familia; cifras **tabulares** en dinero, km, % y fechas.
- Grilla 4/8, *touch targets* ≥ 48 dp, contraste WCAG AA, escala de texto del sistema (hasta 130 %).
- Los **cuatro estados** de pantalla (carga con *skeleton*, vacío, error, éxito sobrio).
- Acción principal **nunca roja**; el estado **nunca depende solo del color** (icono + texto).
- Navegación inferior fija, icono outline + texto, 4–5 destinos por rol, activo con rojo de marca.
- Tokens como **fuente única** (`lib/core/theme/`), sin estilos inline en features.

### 3.3 Qué CAMBIA (propuesto — requiere aprobación explícita)

| # | Hoy (documentación vigente) | Propuesta | Por qué |
|---|---|---|---|
| 1 | Concepto "centro de control logístico… **no una app de consumo**" | **"Herramienta profesional con trato cercano y moderno"** | El dueño pidió cercanía y referencias tipo Uber/InDrive/Rappi, que son apps de consumo |
| 2 | Radios máx. **8**; botones rectangulares; **sin pill** | Cards y hojas ~**16**, botones ~**12**, chips/badges tipo **pill** | Se siente más amigable sin perder seriedad |
| 3 | Sombra única y sutil | **Dos niveles** de elevación suaves (tarjeta, hoja flotante) | Mejor jerarquía visual en móvil |
| 4 | Estados vacíos: texto o ilustración lineal | Ilustración **lineal ligera en paleta de marca**, solo con función (explicar + ofrecer acción) | Más cercanía sin decoración |
| 5 | Tono neutro | **Microcopy cercano** en español colombiano (tuteo, frases cortas, sin jerga técnica) | Alineado con "cercana" y RNF-04 |
| 6 | Primaria con degradado solo en auth | **A decidir:** mantener excepción en auth o unificar a plano en toda la app | Consistencia (§11) |
| 7 | Navegación genérica por rol | Conductor: **3–4 destinos**; Administrador: **5** | Menos opciones = más intuitivo |
| 8 | Imágenes: solo con función; evitar ilustración colorida tipo *flat* | Fotos propias de la flota, **ilustración de marca** en momentos clave y figura de ruta estática; **sigue prohibida la foto de stock** | Más esencia sin decoración vacía (§3.4-A) |
| 9 | Iconos: outline uniforme, "sin detalles decorativos" | **Set propio** con un rasgo de marca consistente (el nodo de ruta del logo) | Identidad reconocible (§3.4-B) |
| 10 | Sin animaciones (solo se prohíbe lo "celebratorio") | **Movimiento con función** definido en un catálogo; sigue prohibido lo celebratorio | Feedback claro y sensación de calidad (§3.4-C) |

**Se sigue prohibiendo:** glassmorphism, *glow*, gradientes decorativos, gamificación, confeti/celebraciones, fotografía de stock, emojis decorativos, colores fuera de la paleta, camiones/carreteras como decoración repetitiva (la ilustración de marca es puntual y con función, §3.4).

> **Contradicción detectada en la documentación vigente:** `Instrucciones de Identidad Visual.md` dice en *Colores* que la acción principal es el **azul de acción**, pero en *Botones* dice que el botón primario "debe utilizar el color **ámbar**". Además el ámbar es el color de **advertencia**. **Recomendación:** mantener azul de acción como primario (así lo implementa `sistema-de-diseno.md`) y corregir el texto de *Botones*. Confirmar en §11.


### 3.4 Esencia de marca: imágenes, iconografía y movimiento *(propuesto — pedido del dueño)*

**Diagnóstico:** las pantallas de muestra funcionan en estructura y jerarquía, pero se sienten **sin esencia**. **Principio rector:** la esencia se gana con **identidad consistente y función**, no con decoración. Toda imagen, icono o animación debe cumplir al menos uno de estos fines: **orientar, confirmar, dar estado o reforzar la marca en un momento clave**.

#### A. Imágenes

| Tipo | Dónde | Reglas |
|---|---|---|
| **Foto real de cada vehículo** (3 doble troque, 1 mula) | Miniatura en tarjeta de viaje, lista de flota, detalle de vehículo | Fotos propias de la empresa, mismo encuadre y luz, recorte consistente (esquinas ~12); si falta, **imagen de reemplazo de marca**, nunca un hueco |
| **Foto del conductor** (opcional) | Perfil, asignación de viaje | Solo con **consentimiento** (dato personal); alternativa: iniciales |
| **Ilustración de marca** | Login y registro (ya existe `AuthHero`), estados vacíos, éxito al cerrar un viaje, sin conexión, primera vez en la app | Un lenguaje propio: **trazos de ruta, nodos y camiones** en la paleta cerrada (azul y gris, con un único acento de rojo de marca). Máximo **una por pantalla**, nunca en pantallas de trabajo denso |
| **Figura del trazado de ruta** (estática) | Tarjeta y detalle de viaje | Línea estilizada origen → destino. Es una **figura estimada, no seguimiento en vivo** (el GPS continuo sigue fuera del MVP) |
| **Evidencias** (recibos, documentos, mantenimiento) | Costos, documentos del vehículo | Ya permitido en la identidad vigente: miniatura + vista ampliada |

**Se mantiene prohibido:** fotos de stock, imágenes decorativas sin función, ilustraciones con paletas ajenas a la marca.

#### B. Iconos con identidad

- **Set propio, una sola familia:** trazo uniforme (~1,75–2 px), esquinas y terminales redondeados, cuadrícula de 24, en versión **contorno** y versión **rellena** (destino activo de navegación y estados).
- **Rasgo de marca:** el **nodo de ruta** (el punto del logo) como detalle funcional repetido en los iconos clave. El punto en **rojo de marca** solo en navegación activa y acentos de identidad, **nunca** en iconos de estado (verde/ámbar/rojo).
- **Iconos de dominio mínimos:** doble troque, mula, ruta, origen, destino, carga, cliente, conductor, ACPM, peaje, mantenimiento, documentos (SOAT / tecnomecánica), vencimiento, retraso, rentabilidad, **los 4 hitos** (salida, llegada a cargue, salida con carga, llegada a destino), **sincronización** (en línea, pendiente, sin señal) y **dato** (estimado, real, parcial, ajustado).
- **Reglas:** en navegación siempre icono + texto; sin emojis; icono ≥ 20 px y objetivo táctil ≥ 48 dp.

| Opción para obtenerlos | Ventaja | Desventaja |
|---|---|---|
| **A. Base abierta de trazo adaptada + iconos de dominio propios** *(recomendada)* | Rápido, coherente y con identidad donde importa | Hay que verificar la licencia de la base |
| **B. Set 100 % a medida** | Máxima identidad | Más tiempo y costo; probablemente requiere diseñador |
| **C. Solo iconos estándar de Material** | Barato | Es justo lo que hoy hace ver la app genérica |

#### C. Animaciones (movimiento con función)

**Principios:** rápidas (**150–300 ms**, curvas suaves de desaceleración); **nunca retrasan ni bloquean** el registro del conductor; respetan la opción **"reducir movimiento"** del celular (alternativa: cambio instantáneo); **nunca son el único canal** de información; sin bucles decorativos; fluidas en celulares de gama media.

| Momento | Movimiento | Para qué |
|---|---|---|
| Abrir el detalle de un viaje | La tarjeta se expande hasta el detalle (transición compartida) | Continuidad y orientación |
| **Registrar un hito** | Botón → "guardando" → **check que se dibuja** → el tramo de la línea de progreso se rellena y el siguiente hito se activa | Confirmar y mostrar avance |
| Sin señal → con señal | El hito queda "guardado en el equipo"; al sincronizar, cambia a "sincronizado" con fundido | Que lo registrado nunca parezca perdido |
| **Estimado → real** | El valor "≈" se reemplaza por el real con fundido y aparece el ✓ | Hacer visible que el dato se confirmó |
| **Rentabilidad** | Al cargar, el número se acomoda al valor (conteo breve, ≤ 600 ms, **una sola vez**); el semáforo cambia de color con transición suave | Dar vida al dato clave sin celebrarlo |
| Hoja inferior | Sube desde abajo con el fondo atenuado | Contexto sin salir de la pantalla |
| Carga de contenido | *Skeleton* con brillo suave | Percepción de rapidez |
| Listas | Entrada escalonada corta (máx. 5 elementos) | Orden de lectura |
| Refrescar | Gesto de jalar con indicador de marca | Familiaridad |
| Alerta nueva | La insignia aparece con **un solo pulso** | Atención sin molestar |
| Éxito (crear/asignar, cerrar viaje) | Check + resumen sobrio | Confirmación clara |

**Prohibido:** confeti y celebraciones, rebotes exagerados, paralaje, animaciones infinitas decorativas, esperas forzadas, transiciones > 400 ms. *(Se conserva la prohibición vigente de lo "celebratorio"; solo se permite el movimiento funcional de la tabla.)* La forma de implementarlo (herramientas, formatos) la decide Claude Code.

---

## 4. Principios de UX (aplican a todas las pantallas)

1. **Una acción principal por pantalla**, visible y al alcance del pulgar (zona inferior).
2. **Qué sigue, siempre a la vista:** cada pantalla de viaje responde "¿en qué estado estoy y cuál es el siguiente paso?".
3. **Pocos pasos y poco teclado:** selectores, valores precargados y estimados editables (RNF-01, RNF-03).
4. **Hojas inferiores (*bottom sheets*)** para registrar hitos y costos sin salir de la pantalla de viaje.
5. **Estado de sincronización visible:** *en línea / guardado en el equipo / sincronizando / sincronizado*. Lo registrado sin señal nunca debe parecer perdido (RNF-07).
6. **Confirmación sobria y reversible** cuando la regla de negocio lo permita; confirmación explícita en acciones sin retorno (cerrar viaje, ajustes).
7. **Errores en lenguaje de negocio** con acción de recuperación (RNF-04).
8. **Jerarquía de decisión:** legibilidad → jerarquía → eficiencia → consistencia → estética.
9. **Consistencia entre roles:** mismos componentes, mismos significados de color y estado.

---

## 5. Inventario de pantallas

> Basado en los requisitos RF-01 a RF-28. **Fase** = propuesta de prioridad (ver §9). La fase 0 solo incluye las 3 pantallas de muestra.

### Todos los roles
| Pantalla | Objetivo | Fase |
|---|---|---|
| Login / Registro / Recuperar contraseña | Entrar con correo y contraseña (el servidor asigna rol conductor al registro) | 1 *(ya existe, se rediseña)* |
| Inicio según rol | Enrutamiento por rol tras el login | 1 |

### Conductor (navegación inferior de 3–4 destinos)
| Pantalla | Objetivo | Fase |
|---|---|---|
| **Inicio — viaje activo / próximo** ⭐ | Ver el viaje actual, su estado y **el siguiente hito**; acción principal en un toque | 0 y 2 |
| Detalle del viaje (planilla digital) | Ruta, cliente, hitos como línea de progreso, costos estimado vs. real | 2 |
| Registrar hito (hoja inferior) | Salida · Llegada a cargue · Salida con carga · Llegada a destino | 2 |
| Registrar costos reales (hoja inferior) | ACPM real y costos manuales (cargue, descargue, parqueadero, otros) | 2 |
| Mis viajes / Historial | Ver viajes propios, completados o no (RF-06) | 2 |
| Perfil y estado de sincronización | Datos propios, cerrar sesión, ver pendientes por sincronizar | 2 |

### Administrador (navegación inferior de 5 destinos)
| Pantalla | Objetivo | Fase |
|---|---|---|
| **Dashboard** ⭐ | KPIs (ingresos, costos, rentabilidad, costo/km), viajes activos, alertas (RF-24 a RF-26) | 0 y 4 |
| **Detalle de viaje + rentabilidad** ⭐ | Número + semáforo, estimado vs. real, peajes, hitos vs. tiempo estimado, cierre | 0 y 4 |
| Viajes (lista y calendario) | Planear y consultar viajes por fecha y estado (RF-09, RF-10) | 3 |
| Crear / asignar viaje | Origen, destino, vehículo, conductor, cliente, carga; estimados automáticos | 3 |
| Flota: vehículos, documentos, mantenimiento | Estado de la flota; vencimientos de SOAT/tecnomecánica | 3 |
| Personas: conductores y clientes | Alta, edición, baja lógica | 3 |
| Rentabilidad por ruta / cliente / conductor | Comparar y decidir (RF-25) | 4 |
| Alertas | Documentos por vencer, viajes con retraso (RF-20, RF-26) | 4 |
| Ajustes sobre viaje cerrado | Registrar corrección con motivo obligatorio | 4 |
| Tarifas de ACPM | Precio por ciudad y vigencia (RF-12) | 3 |
| Reportes y exportación | Filtros y PDF (RF-27, RF-28) | 5 *(posponible)* |

⭐ = pantallas estrella propuestas (a confirmar, §11).

---

## 6. Componentes clave

Se parte de los componentes ya listados en `sistema-de-diseno.md` y se añaden los marcados **(nuevo)**.

| Componente | Descripción |
|---|---|
| **Tarjeta de viaje** | Origen → destino, cliente, vehículo/conductor, **badge de estado**, franja lateral de estado, rentabilidad (admin) |
| **Línea de progreso de hitos (nuevo)** | Los 4 hitos como pasos; el siguiente destacado; hora real vs. estimada |
| **Badge de estado del viaje** | Planificado · Asignado · En curso · Finalizado · Cerrado (icono + texto + color) |
| **Indicador de rentabilidad (nuevo)** | Número + semáforo + etiqueta de base de cálculo (§6.1) |
| **Marca de dato estimado/real (nuevo)** | Distingue de un vistazo qué es estimado, real o ajustado (§6.2) |
| **Indicador de sincronización (nuevo)** | Estado de datos locales y envío pendiente |
| **Hoja inferior de acción (nuevo)** | Registrar hito/costo sin cambiar de pantalla |
| **Campo con valor estimado editable** | Valor precargado visiblemente "automático" hasta que el usuario lo cambia |
| **Tarjeta KPI** | Cifra grande tabular + variación + navegación al detalle |
| **Alerta / banner** | Borde lateral del color de estado, icono + texto |
| **Estados vacío / error / carga / éxito** | Los cuatro, siempre diseñados |
| **Miniatura de vehículo (nuevo)** | Foto del vehículo en tarjetas de viaje y flota, con imagen de reemplazo de marca |
| **Ilustración de estado (nuevo)** | Vacío, sin conexión, éxito de cierre; una por pantalla |
| **Figura de ruta (nuevo)** | Trazado estático origen → destino, marcado como estimado |
| **Set de iconos de marca (nuevo)** | Familia propia con el rasgo del nodo de ruta (§3.4-B) |
| **Catálogo de movimiento (nuevo)** | Duraciones, curvas y disparadores de §3.4-C como tokens reutilizables |

### 6.1 Rentabilidad: número + semáforo (decisión del dueño)

- **Número:** valor en pesos y/o % de margen *(formato exacto por confirmar)*, en cifras tabulares.
- **Semáforo:** verde / ámbar / rojo **siempre con icono y etiqueta de texto** (no solo color). Se propone un **cuarto estado gris "Sin datos suficientes"**.
- **Dos niveles de lectura, nunca mezclados** (regla vigente): **marginal por viaje** (RF-16) y **consolidada por período** (RF-17). Cada indicador debe decir cuál es.
- **Etiqueta de base de cálculo** bajo el número (propuesta): **Proyectada** (todo estimado) → **Parcial** (mezcla) → **Confirmada** (viaje finalizado/cerrado con costos reales). Ver pendientes §11 sobre qué cuenta como "real".
- **Los umbrales del semáforo NO están definidos** (§11). No inventarlos: el diseño debe aceptar umbrales configurables.
- **Cuidado visual:** el rojo de error del semáforo (`#C43D2E`) es cercano al rojo de marca (`#A62C2C`). El rojo de marca **no se usa** dentro del indicador de rentabilidad.

### 6.2 Estimado vs. real (el dueño pidió propuestas)

Regla de negocio vigente: todo dato automático existe como **valor estimado** y **valor real** separados, editables y auditables; un viaje cerrado solo cambia por **ajuste** con motivo.

| Opción | Cómo se ve | Ventaja | Desventaja |
|---|---|---|---|
| **A. Marca por valor** | Estimado: prefijo **≈**, texto en gris azulado, chip "Est."; Real: texto pleno, icono ✓, chip "Real" | Se entiende al instante, ocupa poco | Solo no basta para comparar |
| **B. Par lado a lado** | Columnas **Estimado · Real · Diferencia** | Ideal para analizar desviaciones | Ocupa mucho; poco útil en listas |
| **C. Combinada (recomendada)** | **A** en listas y tarjetas; **B** en el detalle; tercer estado **"Ajustado"** (icono de historial, abre el ajuste) tras el cierre | Cubre las 3 realidades del negocio sin saturar | Requiere definir bien los 3 estados |

**Recomendación: opción C.** Reglas comunes: nunca depender solo del color; en campos editables el valor estimado se muestra con **borde punteado** hasta que el usuario lo confirme/cambie.

---

## 7. Flujos clave (a diseñar, sin cambiar la lógica)

1. **Conductor, viaje en curso:** Inicio → ve siguiente hito → toca acción principal → hoja de confirmación → hito guardado (con o sin señal) → línea de progreso avanza.
2. **Conductor, costos:** desde el detalle del viaje → hoja de costo real → categoría (selector) + valor → guardado → marca "Real".
3. **Administrador, crear y asignar:** datos del viaje → estimados automáticos (ruta, ACPM) visibles como "Est." → asignar vehículo y conductor → viaje Asignado.
4. **Administrador, revisar rentabilidad:** Dashboard → tarjeta KPI → detalle de viaje → número + semáforo + desglose estimado/real.
5. **Administrador, cerrar y ajustar:** cierre con confirmación explícita → luego solo "Registrar ajuste" con motivo obligatorio.

---

## 8. Restricciones (no se tocan)

- **Ciclo del viaje:** `Planificado → Asignado → En curso → Finalizado → Cerrado`. Editable hasta Cerrado.
- **Viaje cerrado:** no se edita ni se borra; solo **ajustes** auditables (motivo, usuario, fecha, valor anterior/nuevo).
- **Estimado y real** siempre separados.
- **Rentabilidad marginal** (viaje) y **consolidada** (período) siempre separadas; sueldo fijo por período, comisión por viaje.
- **Permisos por rol:** el conductor no ve información financiera de otros ni configuración administrativa (la regla vive en el servidor; la interfaz no es la defensa).
- **Hitos:** los cuatro definidos; sin tracking GPS continuo en el MVP.
- **Peajes:** solo vía correo GoPass (no se editan como si fueran captura manual del conductor sin definir regla — ver §11).
- **Sin conexión:** registro local de hitos y costos, sincronización automática.
- **Imágenes y movimiento:** solo con función; sin fotos de stock; ninguna animación puede retrasar el registro del conductor ni ser el único aviso; se respeta "reducir movimiento". La figura de ruta es **estática y estimada**, no seguimiento.
- **Una sola app móvil Flutter**, sin web; Material único (sin dos lenguajes de plataforma).
- **Fuera del MVP:** GPS continuo, detección automática de paradas, precio de ACPM automático, analítica predictiva, RNDC, DIAN, multiempresa, otros operadores de peaje, "Continuar con Google" (se mantiene deshabilitado).
- **Flexible (el dueño lo permitió):** disposición de pantallas, estructura de navegación, componentes, microcopy y jerarquía visual. **No flexible:** reglas de negocio, estados, permisos.

---

## 9. Entregables y fases

### Entregable 1 — Sistema de diseño renovado *(primero)*
- Tokens: color, tipografía, espaciado, radios, elevación y **movimiento** (duraciones y curvas), actualizados según §3.3 y §3.4 si se aprueban.
- **Set de iconos propio** (lista mínima de §3.4-B), **guía de ilustración** y **catálogo de movimiento** (§3.4-C).
- Componentes de §6 con todos sus estados (normal, presionado, deshabilitado, error, carga).
- Reglas de uso del estimado/real y del semáforo.
- **3 pantallas de muestra** para validar la dirección: **(a) Inicio del conductor**, **(b) Dashboard del administrador**, **(c) Detalle de viaje con rentabilidad**. Deben mostrar la esencia de §3.4: como mínimo **una foto o imagen de reemplazo de vehículo, una ilustración de marca, iconos propios y 3 animaciones clave** (registrar hito, estimado → real, rentabilidad). Las pantallas adjuntas son solo el punto de partida estático.
- Lista de cambios necesarios en `Identidad Visual.md` y `sistema-de-diseno.md` para que sigan siendo fuente única de verdad.
- **Parar y esperar aprobación.**

### Entregable 2 — Plan de implementación total por fases *(solo tras aprobar el 1)*
Estructura propuesta (Claude Code puede ajustarla justificando):

| Fase | Contenido |
|---|---|
| **0** | Sistema de diseño + 3 pantallas de muestra *(Entregable 1)* |
| **1** | Aplicar el sistema a autenticación + estructura de navegación por rol |
| **2** | Experiencia del **conductor** completa (inicio, detalle, hitos, costos, historial, sincronización) |
| **3** | Operación del **administrador** (viajes y calendario, crear/asignar, flota, personas, tarifas ACPM) |
| **4** | **Rentabilidad y control** (dashboard, detalle, por ruta/cliente/conductor, alertas, ajustes) |
| **5** | Reportes y exportación; pulido y accesibilidad final |

Cada fase del plan debe indicar: pantallas incluidas, componentes nuevos, dependencias con reglas de negocio ya implementadas en backend, y criterio de cierre.

---

## 10. Referencias

| Referencia | Qué se toma (patrón) | Qué NO se toma |
|---|---|---|
| **Uber** | Jerarquía clara, una acción principal, hojas inferiores, tarjetas limpias | Su estética de marca, mapa como protagonista (no hay GPS en MVP) |
| **InDrive** | Tarjetas de viaje con datos clave y precio visibles, interacción directa | Su paleta y negociación de precios (no aplica) |
| **Rappi** | Línea de progreso por pasos (→ hitos), tono cercano, estados vacíos amables | Su saturación de color y promociones |

Además de los patrones de interacción, de estas apps se toma el **trato cercano con movimiento sutil** (confirmaciones, transiciones) y las **ilustraciones amables** en estados vacíos; no se copian sus marcas ni pantallas.

El dueño indicó que **no le gusta ninguna pantalla actual**, por lo que no hay un "anti-referencia" interno; se evita el aspecto genérico de plantilla por defecto.

---

## 11. Decisiones y reglas pendientes (no inventar)

**Para el dueño del producto**
1. ¿Se aprueba el cambio de concepto (§3.3 #1) de "no app de consumo" a "profesional con trato cercano"? Implica reescribir partes de `Identidad Visual.md`.
2. Radios, pills y elevación (§3.3 #2–3): ¿se aprueba la propuesta o prefieres algo más sobrio?
3. Botón primario: ¿azul de acción (recomendado) o ámbar como dice el texto actual?
4. Degradado del botón en auth: ¿se mantiene o se unifica a plano?
5. Pantallas estrella propuestas (⭐): ¿son las correctas?
6. Contexto de uso: comodidad tecnológica del conductor, uso nocturno, dispositivos reales.
7. Tratamiento: ¿tuteo ("tú") o "usted" en el texto de la app?
8. ¿Quién más verá la app (presentación académica, clientes, inversionistas)?

**Reglas de negocio sin definir (afectan el diseño)**
9. **Umbrales del semáforo:** ¿qué margen es verde, ámbar y rojo? ¿Fijos o configurables por el administrador? ¿Misma regla para marginal y consolidada?
10. **¿Qué cuenta como "real"?** El mantenimiento amortizado siempre es estimado; el peaje de GoPass es real pero no lo confirma el conductor. ¿Cómo se etiqueta cada uno y cuándo una rentabilidad pasa a "Confirmada"?
11. **Corrección de hitos:** ¿el conductor puede deshacer o corregir un hito registrado por error? ¿Hasta cuándo?
12. **Consentimiento de ubicación (RF-23):** el requisito lo exige, pero el tracking GPS está fuera del MVP. ¿Se diseña la pantalla de consentimiento ahora o se pospone?
13. **Formato del número de rentabilidad:** ¿pesos, porcentaje o ambos?
14. **Fotos de la flota:** ¿la empresa tiene fotos de los 4 vehículos y permiso para usarlas? Si no, ¿se usa imagen de reemplazo de marca por ahora?
15. **Quién produce iconos e ilustraciones** y bajo qué licencia (opciones A/B/C de §3.4-B). La recomendada es A.
16. **Foto del conductor:** ¿se desea? Es dato personal y requiere consentimiento.
17. **Dispositivos reales (gama y versión):** definen cuánto movimiento es viable sin que se sienta lento.
18. **Trazado de ruta:** ¿el proveedor de rutas entrega la geometría del trayecto? Si no, la figura sería solo un esquema de origen y destino.

---

## 12. Criterios de aceptación

**Del sistema de diseño (Entregable 1)**
- [ ] Un solo origen de tokens; ningún color, espaciado o radio fuera de él.
- [ ] Los componentes de §6 existen con todos sus estados.
- [ ] Contraste AA verificado; *touch targets* ≥ 48 dp; sin recortes al 130 % de texto.
- [ ] Estimado, real y ajustado se distinguen **sin depender del color**.
- [ ] El semáforo siempre lleva icono + texto.
- [ ] Las 3 pantallas de muestra se ven coherentes entre sí y entre roles.
- [ ] El dueño aprueba la dirección visual antes de pasar al plan.
- [ ] El set de iconos es una sola familia coherente y cubre la lista mínima de §3.4-B.
- [ ] Toda imagen cumple una función; no hay fotos de stock.
- [ ] Cada animación del catálogo dura ≤ 300 ms (salvo el conteo de rentabilidad, ≤ 600 ms) y existe su alternativa con "reducir movimiento".
- [ ] Las pantallas de muestra se sienten propias de OptiRuta y no una plantilla genérica *(prueba: mostrarlas sin logo a alguien de la empresa)*.

**De las pantallas (fases siguientes)**
- [ ] El conductor registra un hito en **≤ 2 toques desde el Inicio** *(umbral propuesto)*.
- [ ] Cada pantalla tiene los cuatro estados diseñados.
- [ ] El estado de sincronización es visible y lo registrado sin señal nunca parece perdido.
- [ ] Prueba de 5 segundos: un administrador identifica qué viajes son rentables y cuáles no sin leer detalles.
- [ ] Ninguna regla de negocio, estado o permiso cambia.
- [ ] Todo texto visible en español colombiano, sin jerga técnica.

---

## Anexo — Archivos de referencia adjuntos

Archivo comprimido `optiruta-pantallas-muestra.zip` (ábranse con doble clic en el navegador; tamaño de celular 390 × 844):

| Archivo | Pantalla |
|---|---|
| `1-conductor-inicio.html` | Conductor · Inicio (viaje activo, línea de progreso de hitos, acción principal) |
| `2-administrador-dashboard.html` | Administrador · Dashboard (rentabilidad consolidada, semáforo, viajes en curso) |
| `3-administrador-detalle-viaje.html` | Administrador · Detalle de viaje (rentabilidad marginal, estimado vs. real) |

Son **referencia estática** de estructura, color, tipografía y jerarquía. Los datos son de ejemplo, el logo es provisional y **no incluyen aún** imágenes, iconos propios ni animaciones (§3.4).
