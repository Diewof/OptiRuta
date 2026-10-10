# Instrucciones de Identidad Visual

## Concepto

Diseñar la aplicación como una **herramienta profesional con trato cercano y moderno** (v2). Detalle: `Diseno-v2/sistema-de-diseno-v2.md`.

La interfaz debe transmitir:

- Control.
- Precisión.
- Seguridad.
- Eficiencia.
- Solidez.
- Profesionalismo.

Priorizar siempre la función sobre la decoración.

No utilizar camiones, carreteras u otros elementos del transporte como decoración repetitiva.

## Colores

Paleta única, derivada del logo de la empresa (azul oscuro, rojo oscuro, gris, blanco). Usar únicamente esta paleta:

### Principales (dominan la interfaz)

- Azul marino: `#14273F` — encabezados, navegación, títulos, superficies oscuras.
- Gris pizarra: `#333A45` — texto de cuerpo, iconos, base de neutros.
- Gris claro: `#F3F4F6` — fondo de pantalla.
- Blanco: `#FFFFFF` — tarjetas, formularios, tablas.

### Acción y acento

- Azul de acción: `#1E3A5F` — **única acción principal por pantalla** (botón primario, texto blanco).
- Rojo de marca: `#A62C2C` — acento de identidad: logo, franja lateral de tarjeta, indicador activo de navegación, anillo de foco, botón destructivo.

### Estados

- Verde éxito: `#2E7D52`
- Ámbar advertencia: `#C6871B` (siempre con texto oscuro encima)
- Rojo error: `#C43D2E`

Reglas:

- El azul marino y el gris deben dominar la interfaz.
- La acción principal es **azul de acción**, nunca roja: acción y peligro no se confunden.
- El rojo de marca se usa como acento puntual (identidad y acción destructiva), nunca como fondo completo ni relleno decorativo.
- Usar verde, ámbar y rojo de error únicamente para estados, alertas e indicadores, siempre acompañados de icono y etiqueta.
- No utilizar colores de estado ni el rojo de marca como fondos completos.
- No introducir colores arbitrarios.

## Tipografía

Usar una sola familia sans-serif.

Preferencia:
- Inter
- IBM Plex Sans

Usar:

- Bold/Semibold → títulos.
- Medium → etiquetas y subtítulos.
- Regular → contenido y formularios.
- Números tabulares → cantidades, costos, distancias y porcentajes.

No mezclar familias tipográficas.

## Botones

- Botones rectangulares con esquinas de 12 (no pill; los badges y chips sí son pill).
- Tener un único botón primario por pantalla.
- El botón primario usa el **azul de acción** (nunca ámbar ni rojo). Radio 12, nunca pill.
- Usar botones secundarios con estilo outline.
- Atenuar claramente los botones deshabilitados.

## Formularios

- Usar campos con borde definido.
- Usar fondo blanco.
- Mantener las etiquetas siempre visibles.
- No depender únicamente de placeholders.
- Diferenciar visualmente los valores automáticos de los valores ingresados manualmente.
- Reducir al mínimo la escritura manual.
- Priorizar selectores, valores precargados y controles simples.

## Tablas

- Utilizar separadores finos.
- Evitar bordes pesados.
- Mantener encabezados visibles durante el scroll.
- Alinear valores numéricos a la derecha.
- Utilizar badges para los estados.
- No colorear filas completas para representar estados.

## Tarjetas

Utilizar tarjetas principalmente para:

- Dashboard.
- Viajes activos.
- Vehículos.
- Conductores.
- Resúmenes.

Características:

- Fondo blanco.
- Sombra sutil.
- Bordes definidos.
- Franja lateral = viaje con retraso (RF-20); la rentabilidad va en su propio semáforo.

## Navegación

Usar navegación inferior fija.

- Máximo 4–5 opciones por rol.
- Mostrar ícono + texto.
- No utilizar únicamente iconos.
- Mantener la navegación consistente entre pantallas.

## Iconografía

Usar iconos:

- Outline.
- De trazo uniforme.
- Simples.
- Sin detalles decorativos innecesarios.

Usar iconos específicos para:
- Vehículos.
- Rutas.
- Conductores.
- Carga.
- Mantenimiento.
- Documentos.
- Ubicación.
- Reportes.
- Alertas.
- ACPM.
- Peajes.

## Imágenes

No utilizar fotografías de stock como decoración.

Utilizar imágenes únicamente cuando tengan una función real, por ejemplo:

- Fotos de vehículos.
- Recibos.
- Evidencias de mantenimiento.
- Documentos.

Se permiten, siempre con función: foto o imagen de reemplazo del vehículo, figura de ruta (estática y estimada) e ilustración de marca (carretera en S del logo) en vacío, éxito de cierre y error; máximo una por pantalla. Prohibidas las fotos de stock y las ilustraciones con paletas ajenas.

## Gráficos

Usar la paleta definida.

- Azul marino → serie principal.
- Rojo de marca → punto de atención.
- Verde → cumplimiento/resultado positivo.
- Rojo de error → incumplimiento/resultado negativo.

Priorizar cifras clave antes que gráficos decorativos.

## Estados

Mantener siempre el mismo significado:

- Verde → éxito/normalidad.
- Ámbar → advertencia.
- Rojo → error/urgencia.

Nunca utilizar estos colores como decoración.

## Consistencia

Crear componentes reutilizables para:

- Botones.
- Inputs.
- Selectores.
- Cards.
- Badges.
- Tablas.
- Alertas.
- Encabezados.
- Navegación.

Definir una única fuente de verdad para:

- Colores.
- Tipografía.
- Espaciado.
- Bordes.
- Radios.
- Componentes.

No crear estilos diferentes para cada módulo.

## Principio general

La interfaz debe parecer una herramienta profesional de control operativo con trato cercano.

Priorizar:

**Legibilidad → jerarquía → eficiencia → consistencia → estética.**

Evitar:

**Decoración → saturación visual → colores innecesarios → elementos sin función.**

## Movimiento (v2)

Solo con función (confirmar, mostrar avance, dar estado), 120–300 ms y el conteo de rentabilidad 600 ms. Nunca retrasa ni bloquea el registro del conductor, respeta «reducir movimiento» y nunca es el único aviso. Catálogo y tokens en `Diseno-v2/sistema-de-diseno-v2.md` §2.4.

## Tono (v2)

Español colombiano, tuteo, frases cortas, sin jerga técnica («Hoy no tienes viaje asignado»).
