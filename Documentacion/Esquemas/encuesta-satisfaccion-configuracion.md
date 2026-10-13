# Encuesta de satisfacción: puesta en marcha

Pasos manuales para activar la encuesta post-viaje (RF-33). El código ya está en el repo; esto es lo que depende de cuentas y secretos tuyos.

## 1. Base de datos (migración `20261012100000_encuesta_satisfaccion.sql`)

```powershell
npx supabase migration list --linked   # ver qué falta aplicar
npx supabase db push --linked          # aplica TODAS las pendientes, en orden
```

Ojo: si las migraciones `20261011*` (flota) siguen sin aplicar, `db push` también las aplicará. Esas bloquean `viaje_iniciar` si el vehículo no tiene SOAT y tecnomecánica cargados: registra esos documentos antes.

Prueba (requiere Docker, `supabase start`): `npx supabase test db` → debe pasar `encuesta_satisfaccion_test.sql` (23 pruebas).

## 2. Edge Function `encuestas`

Inventa un secreto largo (por ejemplo 40 caracteres aleatorios) y úsalo en los dos lados:

```powershell
npx supabase secrets set ENCUESTAS_SECRET=<el-secreto>
npx supabase functions deploy encuestas --no-verify-jwt
```

URL resultante: `https://<ref-del-proyecto>.supabase.co/functions/v1/encuestas`.

Prueba rápida (debe responder `{"encuestas":[]}` o la lista de pendientes):

```powershell
curl -X POST "https://<ref>.supabase.co/functions/v1/encuestas" -H "x-service-secret: <el-secreto>" -H "content-type: application/json" -d '{"accion":"PENDIENTES"}'
```

Pruebas unitarias (requieren Deno): `deno test supabase/functions/encuestas`.

## 3. Google Form

Crea un formulario nuevo con la cuenta de Gmail que enviará los correos (se muestra como remitente; sugerido: una cuenta de la empresa). Los **títulos deben ser exactamente estos**; si los cambias, cámbialos también en las constantes de `encuestas.gs`.

| # | Título (exacto) | Tipo | Obligatoria |
|---|---|---|---|
| 1 | Código de referencia | Respuesta corta | Sí |
| 2 | ¿Cómo califica la entrega de su carga? | Escala lineal 1–5 (1 = Muy mala, 5 = Excelente) | Sí |
| 3 | ¿Cómo califica el servicio en general? | Escala lineal 1–5 (1 = Muy malo, 5 = Excelente) | Sí |
| 4 | ¿Cómo califica la atención del conductor y del equipo? | Escala lineal 1–5 (1 = Muy mala, 5 = Excelente) | Sí |
| 5 | ¿Cómo califica la puntualidad de la entrega? | Escala lineal 1–5 (1 = Muy mala, 5 = Excelente) | Sí |
| 6 | ¿Qué tan probable es que recomiende nuestro servicio a otra empresa? | Escala lineal 0–10 (0 = Nada probable, 10 = Muy probable) | Sí |
| 7 | ¿Desea contarnos algo más? (opcional) | Párrafo | No |

- En la descripción de la pregunta 1 escribe: «Este código viene prellenado; por favor no lo modifique.»
- Descripción del formulario: aviso breve de tratamiento de datos (Ley 1581): las respuestas se usan solo para mejorar el servicio.
- **Configuración**: desactiva «Limitar a 1 respuesta» (evita pedir inicio de sesión) y no actives «Recopilar correos».
- Envía el formulario (se acepta respuestas = activado).

Google Forms no permite campos ocultos ni de solo lectura: el cliente podría editar el código. Es seguro: el código es de un solo uso y el servidor rechaza uno inválido, ya respondido o vencido.

## 4. Apps Script

1. En el Form: **⋮ → Editor de secuencias de comandos** (Apps Script).
2. Pega el contenido de `supabase/apps-script/encuestas.gs` en `Código.gs`.
3. **Configuración del proyecto → Propiedades del script**, agrega:
   - `ENCUESTAS_URL` = la URL de la función (paso 2).
   - `ENCUESTAS_SECRET` = el mismo secreto del paso 2.
4. Selecciona la función `instalarDisparadores` y ejecútala una vez. Acepta los permisos (enviar correo, conectarse a servicios externos, ver el formulario). Crea el envío cada 5 minutos y el reenvío al responder.
5. Límite gratuito de Gmail: unos 100 correos al día; sobra para 4 vehículos.

Si una respuesta no llegó a la base (error de red), ejecuta `reprocesarRespuestas`: reenvía todas las del Form y las ya registradas se ignoran.

## 5. Prueba de punta a punta

1. En **Personas → Clientes** asegúrate de que el cliente de prueba tenga **correo** (el tuyo).
2. Lleva un viaje de prueba hasta Finalizado (el conductor registra la llegada al destino).
3. En ≤ 5 min llega el correo; el detalle del viaje (administrador) muestra «Encuesta de satisfacción: Enviada».
4. Responde el formulario con una calificación baja (alguna ≤ 2): en **Resumen → Satisfacción** aparece la respuesta (con ≥ 5 respuestas se muestran promedios) y llega la notificación «Satisfacción baja».
5. Un cliente sin correo deja la encuesta en «Cliente sin correo»: el detalle del viaje ofrece **Copiar mensaje con el enlace** para mandarlo por WhatsApp.

## Operación

- Vigencia de cada encuesta: 14 días; luego pasa a «Sin respuesta» (cron diario 7:00).
- Cambiar el texto del correo: `encuestas.gs`, función `enviarPendientes`.
- Rotar el secreto: `npx supabase secrets set ENCUESTAS_SECRET=<nuevo>` y actualizar la propiedad del script.
