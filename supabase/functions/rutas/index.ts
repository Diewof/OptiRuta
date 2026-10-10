// Edge Function rutas (POST /functions/v1/rutas).
//
// Mapas para Agendar viaje (RF-09/12, CLAUDE.md "Edge Functions... proveedor
// de rutas"): autocompletado de lugares (Colombia), nombre de un punto del mapa y
// distancia/tiempo/trazado entre origen y destino. Protegida por
// `verify_jwt = true` (default): Supabase exige un JWT valido de sesion antes
// de invocarla, no hace falta validarlo aqui. No toca la base de datos: solo
// valida el cuerpo, delega en el adapter de proveedor y traduce errores.
//
// Responsabilidad de esta funcion: validar la peticion, delegar el calculo de
// ruta al adapter de proveedor, y traducir cualquier error a un cuerpo de
// dominio -- nunca un error crudo del proveedor externo.

import { RutaNoEncontradaError } from "./proveedor.ts";
import { OsmProveedorRutas } from "./proveedor_osm.ts";
import { type CuerpoPeticion, resolverPeticion } from "./peticion.ts";

interface CuerpoError {
  timestamp: string;
  status: number;
  error: string;
  message: string;
  path: string;
}

function respuestaError(
  requestId: string,
  path: string,
  status: number,
  codigo: string,
  mensaje: string,
): Response {
  const cuerpo: CuerpoError = {
    timestamp: new Date().toISOString(),
    status,
    error: codigo,
    message: mensaje,
    path,
  };
  return new Response(JSON.stringify(cuerpo), {
    status,
    headers: {
      "content-type": "application/json",
      "x-request-id": requestId,
    },
  });
}

function log(
  nivel: "info" | "warn" | "error",
  requestId: string,
  mensaje: string,
  detalle?: Record<string, unknown>,
) {
  const linea = JSON.stringify({
    nivel,
    funcion: "rutas",
    requestId,
    mensaje,
    ...detalle,
  });
  if (nivel === "error") console.error(linea);
  else if (nivel === "warn") console.warn(linea);
  else console.info(linea);
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

  let cuerpo: CuerpoPeticion;
  try {
    cuerpo = await req.json();
  } catch {
    return respuestaError(
      requestId,
      path,
      400,
      "CUERPO_INVALIDO",
      "El cuerpo de la petición debe ser JSON válido.",
    );
  }

  const proveedor = new OsmProveedorRutas();

  try {
    const resultado = await resolverPeticion(proveedor, cuerpo);
    if (resultado === null) {
      return respuestaError(
        requestId,
        path,
        400,
        "DATOS_INCOMPLETOS",
        "Indica origen y destino (coordenadas), una consulta de al menos 3 " +
          "letras o una coordenada.",
      );
    }
    return new Response(JSON.stringify(resultado), {
      status: 200,
      headers: {
        "content-type": "application/json",
        "x-request-id": requestId,
      },
    });
  } catch (error) {
    if (error instanceof RutaNoEncontradaError) {
      log("warn", requestId, "No se pudo calcular la ruta.", {
        motivo: error.message,
      });
      return respuestaError(
        requestId,
        path,
        422,
        "RUTA_NO_ENCONTRADA",
        error.message,
      );
    }
    log("error", requestId, "Error no controlado calculando la ruta.", {
      error: error instanceof Error ? error.message : String(error),
    });
    return respuestaError(
      requestId,
      path,
      500,
      "ERROR_INTERNO",
      "No fue posible calcular la ruta.",
    );
  }
});
