// Logica pura de la funcion rutas: decide que operacion pide el cuerpo y la
// delega en el adapter. Vive aparte de index.ts para probarla sin Deno.serve.
//
// Operaciones (mismo endpoint /v1/rutas, para no multiplicar funciones):
//   { origen: {lat,lng}, destino: {lat,lng} }  -> ruta (distancia, tiempo, trazado)
//   { consulta }                               -> { lugares: [{nombre, lat, lng}] }
//   { lat, lng }                               -> lugar en esa coordenada

import type { Coordenada, ProveedorRutas } from "./proveedor.ts";

export interface CuerpoPeticion {
  origen?: Coordenada;
  destino?: Coordenada;
  consulta?: string;
  lat?: number;
  lng?: number;
}

// Con menos letras el autocompletado solo devuelve ruido y gasta cuota del
// servicio publico.
const MIN_CARACTERES_CONSULTA = 3;

function esCoordenada(valor: unknown): valor is Coordenada {
  if (typeof valor !== "object" || valor === null) return false;
  const { lat, lng } = valor as Record<string, unknown>;
  return typeof lat === "number" && typeof lng === "number" &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

/** Devuelve el resultado a serializar, o `null` si el cuerpo no es valido. */
export async function resolverPeticion(
  proveedor: ProveedorRutas,
  cuerpo: CuerpoPeticion,
): Promise<unknown | null> {
  if (typeof cuerpo.consulta === "string") {
    const consulta = cuerpo.consulta.trim();
    if (consulta.length < MIN_CARACTERES_CONSULTA) return null;
    return { lugares: await proveedor.buscarLugares(consulta) };
  }

  if (cuerpo.lat !== undefined || cuerpo.lng !== undefined) {
    const coordenada = { lat: cuerpo.lat, lng: cuerpo.lng };
    if (!esCoordenada(coordenada)) return null;
    return await proveedor.lugarEnCoordenada(coordenada);
  }

  if (esCoordenada(cuerpo.origen) && esCoordenada(cuerpo.destino)) {
    return await proveedor.calcularRutaPorCoordenadas(
      cuerpo.origen,
      cuerpo.destino,
    );
  }

  return null;
}
