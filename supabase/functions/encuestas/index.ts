// Edge Function encuestas (POST /functions/v1/encuestas).
//
// Puente entre Postgres y el Google Form + Apps Script de la encuesta de
// satisfaccion. No es un endpoint de la app: se protege con una clave de
// servicio en cabecera (ENCUESTAS_SECRET), no con JWT de Supabase Auth (mismo
// patron que precio-acpm-scraper). Solo valida, delega en las RPC y traduce
// errores; las reglas viven en Postgres.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  ErrorDominio,
  type RepositorioEncuestas,
  resolverPeticion,
  traducirErrorRpc,
} from "./peticion.ts";

function log(
  nivel: "info" | "warn" | "error",
  requestId: string,
  mensaje: string,
  detalle?: Record<string, unknown>,
) {
  const linea = JSON.stringify({
    nivel,
    funcion: "encuestas",
    requestId,
    mensaje,
    ...detalle,
  });
  if (nivel === "error") console.error(linea);
  else if (nivel === "warn") console.warn(linea);
  else console.info(linea);
}

function respuestaError(
  requestId: string,
  path: string,
  status: number,
  codigo: string,
  mensaje: string,
): Response {
  return new Response(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      status,
      error: codigo,
      message: mensaje,
      path,
    }),
    {
      status,
      headers: {
        "content-type": "application/json",
        "x-request-id": requestId,
      },
    },
  );
}

function crearRepositorio(
  supabase: ReturnType<typeof createClient>,
): RepositorioEncuestas {
  return {
    async pendientes() {
      const { data, error } = await supabase.rpc("encuesta_pendientes_envio");
      if (error) throw traducirErrorRpc(error.code);
      return data ?? [];
    },
    async registrarEnvio(id, enlace, enviada) {
      const { error } = await supabase.rpc("encuesta_registrar_envio", {
        p_id: id,
        p_enlace: enlace,
        p_enviada: enviada,
      });
      if (error) throw traducirErrorRpc(error.code);
    },
    async registrarRespuesta(r) {
      const { error } = await supabase.rpc("encuesta_registrar_respuesta", {
        p_token: r.token,
        p_csat_entrega: r.csatEntrega,
        p_csat_servicio: r.csatServicio,
        p_csat_atencion: r.csatAtencion,
        p_csat_puntualidad: r.csatPuntualidad,
        p_nps: r.nps,
        p_comentario: r.comentario,
      });
      if (error) throw traducirErrorRpc(error.code);
    },
  };
}

Deno.serve(async (req) => {
  const path = new URL(req.url).pathname;
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();

  if (req.method !== "POST") {
    return respuestaError(
      requestId,
      path,
      405,
      "METODO_NO_PERMITIDO",
      "Este endpoint solo acepta POST.",
    );
  }

  const secretoEsperado = Deno.env.get("ENCUESTAS_SECRET");
  if (
    !secretoEsperado || req.headers.get("x-service-secret") !== secretoEsperado
  ) {
    log("warn", requestId, "Invocacion sin clave de servicio valida.");
    return respuestaError(
      requestId,
      path,
      401,
      "NO_AUTORIZADO",
      "Clave de servicio invalida o ausente.",
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    log("error", requestId, "Faltan variables de entorno de Supabase.");
    return respuestaError(
      requestId,
      path,
      500,
      "ERROR_INTERNO",
      "No fue posible procesar la solicitud de encuestas.",
    );
  }

  let cuerpo: Record<string, unknown>;
  try {
    cuerpo = await req.json();
    if (typeof cuerpo !== "object" || cuerpo === null) throw new Error();
  } catch {
    return respuestaError(
      requestId,
      path,
      400,
      "DATOS_INVALIDOS",
      "El cuerpo debe ser JSON.",
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  try {
    const resultado = await resolverPeticion(
      crearRepositorio(supabase),
      cuerpo,
    );
    log("info", requestId, "Peticion procesada.", { accion: cuerpo.accion });
    return new Response(JSON.stringify(resultado), {
      status: 200,
      headers: {
        "content-type": "application/json",
        "x-request-id": requestId,
      },
    });
  } catch (error) {
    if (error instanceof ErrorDominio) {
      log(error.status >= 500 ? "error" : "warn", requestId, error.message, {
        accion: cuerpo.accion,
        codigo: error.codigo,
      });
      return respuestaError(
        requestId,
        path,
        error.status,
        error.codigo,
        error.message,
      );
    }
    log("error", requestId, "Error no controlado.", {
      error: error instanceof Error ? error.message : String(error),
    });
    return respuestaError(
      requestId,
      path,
      500,
      "ERROR_INTERNO",
      "No fue posible procesar la solicitud de encuestas.",
    );
  }
});
