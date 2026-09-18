// Edge Function precio-acpm-scraper (POST /functions/v1/precio-acpm-scraper).
//
// Disparada mensualmente por pg_cron (via pg_net) para actualizar el precio
// de ACPM de referencia (Medellin, MVP: una sola ciudad automatica -- ver
// diseno-base-de-datos-optiruta.md seccion 6). No es un endpoint de la app:
// se protege con una clave de servicio en cabecera, no con JWT de Supabase
// Auth (mismo patron que peajes-correo en CLAUDE.md).
//
// Responsabilidad de esta funcion: validar la peticion, delegar el scraping
// al adapter de proveedor y la validacion de negocio (+/-15%) a la RPC
// tarifa_combustible_registrar_automatico, y traducir cualquier error a un
// cuerpo de dominio -- nunca un error crudo de Postgres.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ProveedorLaRepublica, ScrapingFallidoError } from "./proveedor.ts";

const CIUDAD_REFERENCIA = "Medellin";

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
    funcion: "precio-acpm-scraper",
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

  const secretoEsperado = Deno.env.get("PRECIO_ACPM_SCRAPER_SECRET");
  const secretoRecibido = req.headers.get("x-service-secret");
  if (!secretoEsperado || secretoRecibido !== secretoEsperado) {
    log("warn", requestId, "Intento de invocacion sin clave de servicio valida.");
    return respuestaError(
      requestId,
      path,
      401,
      "NO_AUTORIZADO",
      "Clave de servicio invalida o ausente.",
    );
  }

  const proveedor = new ProveedorLaRepublica();

  let precio;
  try {
    precio = await proveedor.obtenerPrecioVigente();
  } catch (error) {
    if (error instanceof ScrapingFallidoError) {
      // No se sobrescribe nada: se deja constancia (alerta) y se responde
      // 422 -- es una regla de negocio incumplida (no hay precio nuevo
      // confiable), no un error no controlado.
      log("warn", requestId, "Scraping de precio de ACPM fallido; se mantiene el ultimo precio valido.", {
        motivo: error.message,
      });
      return respuestaError(
        requestId,
        path,
        422,
        "SCRAPING_ACPM_FALLIDO",
        "No fue posible obtener un precio de ACPM confiable de la fuente; se mantiene el ultimo precio registrado.",
      );
    }
    log("error", requestId, "Error no controlado al scrapear el precio de ACPM.", {
      error: error instanceof Error ? error.message : String(error),
    });
    return respuestaError(
      requestId,
      path,
      500,
      "ERROR_INTERNO",
      "No fue posible procesar la actualizacion de precio de ACPM.",
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    log("error", requestId, "Faltan variables de entorno de Supabase para el cliente service_role.");
    return respuestaError(
      requestId,
      path,
      500,
      "ERROR_INTERNO",
      "No fue posible procesar la actualizacion de precio de ACPM.",
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data, error } = await supabase
    .rpc("tarifa_combustible_registrar_automatico", {
      p_ciudad: CIUDAD_REFERENCIA,
      p_precio_galon: precio.precioGalon,
      p_fecha_vigencia: precio.fechaVigencia,
    })
    .single();

  if (error) {
    log("error", requestId, "La RPC tarifa_combustible_registrar_automatico fallo.", {
      error: error.message,
    });
    return respuestaError(
      requestId,
      path,
      500,
      "ERROR_INTERNO",
      "No fue posible registrar el precio de ACPM scrapeado.",
    );
  }

  const resultado = data as {
    aplicado: boolean;
    precio_anterior: number | null;
    motivo: string;
  };

  if (!resultado.aplicado) {
    log("warn", requestId, "Precio de ACPM scrapeado fuera de rango; no se sobrescribe.", {
      precioScrapeado: precio.precioGalon,
      precioAnterior: resultado.precio_anterior,
      motivo: resultado.motivo,
    });
  } else {
    log("info", requestId, "Precio de ACPM actualizado.", {
      ciudad: CIUDAD_REFERENCIA,
      precioGalon: precio.precioGalon,
    });
  }

  return new Response(
    JSON.stringify({
      ciudad: CIUDAD_REFERENCIA,
      precioScrapeado: precio.precioGalon,
      fechaVigencia: precio.fechaVigencia,
      ...resultado,
    }),
    {
      status: 200,
      headers: {
        "content-type": "application/json",
        "x-request-id": requestId,
      },
    },
  );
});
