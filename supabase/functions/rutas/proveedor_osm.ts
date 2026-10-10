// Implementacion de ProveedorRutas sobre servicios publicos de OpenStreetMap,
// sin API key ni facturacion:
//   - Photon (komoot): busqueda con autocompletado y nombre de un punto.
//     Se usa en lugar de Nominatim porque la politica de Nominatim prohibe el
//     autocompletado mientras se escribe; Photon esta hecho para eso.
//   - OSRM: distancia, duracion y trazado.
// Ambos son servicios compartidos de uso razonable (sin SLA): sirven para la
// demo; en produccion conviene un Photon/OSRM propio o un proveedor de pago.

import {
  type Coordenada,
  type Lugar,
  type ProveedorRutas,
  RutaNoEncontradaError,
  type RutaCalculada,
} from "./proveedor.ts";

const PHOTON_URL = "https://photon.komoot.io";
const OSRM_URL = "https://router.project-osrm.org/route/v1/driving";
// Caja de Colombia (minLon,minLat,maxLon,maxLat): Photon prioriza y limita los
// resultados a ese rectangulo.
const CAJA_COLOMBIA = "-79.1,-4.3,-66.8,13.5";
const MAX_RESULTADOS = 6;
// Identifica a la aplicacion ante los servicios publicos.
const USER_AGENT = "OptiRuta-rutas-edge-function/1.0";

export class OsmProveedorRutas implements ProveedorRutas {
  constructor(
    private readonly fetchFn: typeof fetch = fetch,
    private readonly photonUrl: string = PHOTON_URL,
    private readonly osrmUrl: string = OSRM_URL,
  ) {}

  async calcularRutaPorCoordenadas(
    origen: Coordenada,
    destino: Coordenada,
  ): Promise<RutaCalculada> {
    const url = `${this.osrmUrl}/${origen.lng},${origen.lat};` +
      `${destino.lng},${destino.lat}?overview=full&geometries=polyline`;
    const cuerpo = await this.pedirJson(url, "calcular la ruta");

    const ruta = cuerpo?.routes?.[0];
    if (!ruta) {
      throw new RutaNoEncontradaError(
        "No se encontró una ruta terrestre entre el origen y el destino.",
      );
    }
    return {
      distanciaKm: Math.round((ruta.distance / 1000) * 10) / 10,
      duracionMin: Math.round(ruta.duration / 60),
      polilinea: typeof ruta.geometry === "string" ? ruta.geometry : "",
      origen,
      destino,
    };
  }

  async buscarLugares(consulta: string): Promise<Lugar[]> {
    const url = `${this.photonUrl}/api/?q=${encodeURIComponent(consulta)}` +
      `&limit=${MAX_RESULTADOS}&bbox=${CAJA_COLOMBIA}`;
    const cuerpo = await this.pedirJson(url, "buscar el lugar");
    return lugaresDe(cuerpo);
  }

  async lugarEnCoordenada(coordenada: Coordenada): Promise<Lugar> {
    const url = `${this.photonUrl}/reverse?lat=${coordenada.lat}` +
      `&lon=${coordenada.lng}&limit=1`;
    const cuerpo = await this.pedirJson(url, "identificar el lugar");
    const lugar = lugaresDe(cuerpo, false)[0];
    return {
      // Punto sin nombre (carretera rural): se conserva la coordenada elegida.
      nombre: lugar?.nombre ??
        `${coordenada.lat.toFixed(4)}, ${coordenada.lng.toFixed(4)}`,
      ...coordenada,
    };
  }

  // deno-lint-ignore no-explicit-any
  private async pedirJson(url: string, accion: string): Promise<any> {
    let respuesta: Response;
    try {
      respuesta = await this.fetchFn(url, {
        headers: { "User-Agent": USER_AGENT },
      });
    } catch (error) {
      throw new RutaNoEncontradaError(
        `No se pudo ${accion}: el proveedor de mapas no respondió (${
          error instanceof Error ? error.message : String(error)
        }).`,
      );
    }
    if (!respuesta.ok) {
      throw new RutaNoEncontradaError(
        `No se pudo ${accion}: el proveedor de mapas respondió con estado ${respuesta.status}.`,
      );
    }
    return respuesta.json();
  }
}

// Photon responde GeoJSON: coordinates = [lon, lat] y properties con las
// partes del nombre (name, street, city, state...).
// deno-lint-ignore no-explicit-any
function lugaresDe(cuerpo: any, incluirNombre = true): Lugar[] {
  const features: unknown[] = cuerpo?.features ?? [];
  const lugares: Lugar[] = [];
  const vistos = new Set<string>();
  for (const feature of features) {
    // deno-lint-ignore no-explicit-any
    const f = feature as any;
    const coords = f?.geometry?.coordinates;
    if (!Array.isArray(coords) || coords.length < 2) continue;
    const nombre = nombreDe(f.properties ?? {}, incluirNombre);
    if (!nombre || vistos.has(nombre)) continue;
    vistos.add(nombre);
    lugares.push({ nombre, lat: Number(coords[1]), lng: Number(coords[0]) });
  }
  return lugares;
}

// "Terminal del Norte, Cra. 64C 78-580, Medellín, Antioquia": nombre, calle y
// numero, ciudad y departamento, sin repetir partes. El departamento y la
// ciudad quedan en el nombre porque el ACPM se busca por ciudad.
// Con `incluirNombre: false` se omite el nombre del sitio: en el nombre de un
// punto cualquiera del mapa solo sirve la direccion (el sitio mas cercano es
// casi siempre un comercio que nada tiene que ver con lo elegido).
function nombreDe(
  p: Record<string, unknown>,
  incluirNombre = true,
): string {
  const calle = [p.street, p.housenumber].filter(Boolean).join(" ");
  const partes = [
    incluirNombre ? p.name : undefined,
    calle,
    p.district,
    p.city ?? p.county,
    p.state,
  ]
    .map(limpiarParte)
    .filter((x) => x !== "");
  const unicas: string[] = [];
  for (const parte of partes) {
    if (!unicas.includes(parte)) unicas.push(parte);
  }
  return unicas.join(", ");
}

// OpenStreetMap guarda varios valores en un mismo campo separados por ";"
// (p. ej. varios comercios en una misma direccion): se conserva el primero.
const MAX_PARTE = 80;
function limpiarParte(valor: unknown): string {
  if (typeof valor !== "string") return "";
  const primero = valor.split(";")[0].trim();
  return primero.length > MAX_PARTE
    ? `${primero.slice(0, MAX_PARTE - 1).trimEnd()}…`
    : primero;
}
