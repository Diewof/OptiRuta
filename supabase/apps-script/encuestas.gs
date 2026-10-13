/**
 * Apps Script de la encuesta de satisfaccion de OptiRuta.
 *
 * Va asociado al Google Form de la encuesta (Extensiones > Apps Script desde el
 * Form) o, si esa opcion no aparece, como proyecto suelto en script.google.com
 * con la propiedad FORM_ID. Hace dos cosas, ambas hablando con la Edge Function `encuestas`:
 *   1. enviarPendientes(): cada 5 min pide las encuestas por enviar, arma el
 *      enlace prellenado con el token, manda el correo y avisa a Supabase.
 *   2. onFormSubmit(e): al responder el Form, reenvia las respuestas.
 *
 * Propiedades del script (Configuracion del proyecto > Propiedades):
 *   ENCUESTAS_URL     https://<proyecto>.supabase.co/functions/v1/encuestas
 *   ENCUESTAS_SECRET  el mismo valor del secreto ENCUESTAS_SECRET de la funcion
 *   FORM_ID           solo si el script NO se abrio desde el Form: el ID que
 *                     aparece en la URL del Form (docs.google.com/forms/d/<ID>/edit)
 *
 * Nunca se guarda aqui la service_role key: solo el secreto de esta funcion.
 * Pasos completos: Documentacion/Esquemas/encuesta-satisfaccion-configuracion.md
 */

// Titulos de las preguntas del Form. La comparacion ignora mayusculas, tildes,
// espacios sobrantes, signos de interrogacion y cualquier texto que venga
// DESPUES del titulo (p. ej. una descripcion escrita en la misma casilla), pero
// el titulo debe empezar igual (si se renombra de verdad, cambiarlo aqui).
var CAMPO_CODIGO = 'Código de referencia';
var CAMPOS = {
  csat_entrega: '¿Cómo califica la entrega de su carga?',
  csat_servicio: '¿Cómo califica el servicio en general?',
  csat_atencion: '¿Cómo califica la atención del conductor y del equipo?',
  csat_puntualidad: '¿Cómo califica la puntualidad de la entrega?',
  nps: '¿Qué tan probable es que recomiende nuestro servicio a otra empresa?',
  comentario: '¿Desea contarnos algo más? (opcional)',
};

function normalizar_(texto) {
  return String(texto || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[¿?¡!:.*]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function coincide_(titulo, objetivo) {
  var t = normalizar_(titulo);
  var o = normalizar_(objetivo);
  return t === o || t.indexOf(o) === 0;
}

function formulario_() {
  var id = PropertiesService.getScriptProperties().getProperty('FORM_ID');
  return id ? FormApp.openById(id) : FormApp.getActiveForm();
}

function llamar_(cuerpo) {
  var props = PropertiesService.getScriptProperties();
  var respuesta = UrlFetchApp.fetch(props.getProperty('ENCUESTAS_URL'), {
    method: 'post',
    contentType: 'application/json',
    headers: { 'x-service-secret': props.getProperty('ENCUESTAS_SECRET') },
    payload: JSON.stringify(cuerpo),
    muteHttpExceptions: true,
  });
  return {
    status: respuesta.getResponseCode(),
    cuerpo: JSON.parse(respuesta.getContentText() || '{}'),
  };
}

function enlacePrellenado_(token) {
  var form = formulario_();
  var items = form.getItems();
  var item = items.filter(function (i) {
    return coincide_(i.getTitle(), CAMPO_CODIGO);
  })[0];
  if (!item) {
    throw new Error(
      'No existe la pregunta "' + CAMPO_CODIGO + '". Preguntas encontradas: ' +
        items.map(function (i) { return '"' + i.getTitle() + '"'; }).join(', ')
    );
  }
  return form
    .createResponse()
    .withItemResponse(item.asTextItem().createResponse(token))
    .toPrefilledUrl();
}

function enviarPendientes() {
  var lista = llamar_({ accion: 'PENDIENTES' });
  if (lista.status !== 200) {
    console.error('PENDIENTES fallo: ' + lista.status + ' ' + JSON.stringify(lista.cuerpo));
    return;
  }
  lista.cuerpo.encuestas.forEach(function (enc) {
    var enlace = enlacePrellenado_(enc.token);
    var enviada = false;
    if (enc.destinatario) {
      try {
        MailApp.sendEmail({
          to: enc.destinatario,
          subject: 'Cuéntenos cómo le fue con su entrega (' + enc.remision + ')',
          name: 'OptiRuta',
          htmlBody:
            '<p>Hola, ' + enc.cliente + '.</p>' +
            '<p>Acabamos de finalizar su servicio <b>' + enc.origen + ' → ' + enc.destino +
            '</b> (remisión ' + enc.remision + ').</p>' +
            '<p>¿Nos regala un minuto para calificarlo?</p>' +
            '<p><a href="' + enlace + '">Responder la encuesta</a></p>' +
            '<p style="color:#666;font-size:12px">Sus respuestas se usan solo para mejorar nuestro servicio. ' +
            'Por favor no modifique el código de referencia del formulario.</p>',
        });
        enviada = true;
      } catch (err) {
        console.error('Correo fallido para ' + enc.id + ': ' + err);
      }
    }
    var registro = llamar_({ accion: 'ENVIO', id: enc.id, enlace: enlace, enviada: enviada });
    if (registro.status !== 200) {
      console.error('ENVIO fallo: ' + registro.status + ' ' + JSON.stringify(registro.cuerpo));
    }
  });
}

function respuestaACuerpo_(respuesta) {
  var respuestas = respuesta.getItemResponses();
  function dato(titulo) {
    var ir = respuestas.filter(function (r) {
      return coincide_(r.getItem().getTitle(), titulo);
    })[0];
    return ir ? ir.getResponse() : undefined;
  }
  return {
    accion: 'RESPUESTA',
    token: dato(CAMPO_CODIGO),
    csat_entrega: dato(CAMPOS.csat_entrega),
    csat_servicio: dato(CAMPOS.csat_servicio),
    csat_atencion: dato(CAMPOS.csat_atencion),
    csat_puntualidad: dato(CAMPOS.csat_puntualidad),
    nps: dato(CAMPOS.nps),
    comentario: dato(CAMPOS.comentario) || null,
  };
}

function onFormSubmit(e) {
  var resultado = llamar_(respuestaACuerpo_(e.response));
  if (resultado.status !== 200) {
    // La respuesta queda guardada en el Form: se puede repetir con reprocesarRespuestas().
    console.error('RESPUESTA fallo: ' + resultado.status + ' ' + JSON.stringify(resultado.cuerpo));
  }
}

/** Reenvia todas las respuestas del Form; las ya registradas (409) se ignoran. */
function reprocesarRespuestas() {
  formulario_().getResponses().forEach(function (r) {
    var resultado = llamar_(respuestaACuerpo_(r));
    if (resultado.status !== 200 && resultado.status !== 409) {
      console.error('Reproceso fallo: ' + resultado.status + ' ' + JSON.stringify(resultado.cuerpo));
    }
  });
}

/** Ejecutar una sola vez a mano para crear los dos disparadores. */
function instalarDisparadores() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('enviarPendientes').timeBased().everyMinutes(5).create();
  ScriptApp.newTrigger('onFormSubmit')
    .forForm(formulario_())
    .onFormSubmit()
    .create();
}
