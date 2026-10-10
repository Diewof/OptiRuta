// Adapter (patron permitido solo en supabase/functions segun CLAUDE.md):
// interfaz del proveedor de mapas/rutas. La implementacion actual esta en
// proveedor_osm.ts (Photon + OSRM, ambos publicos y sin API key); cambiar de
// proveedor en el futuro solo implica agregar otra implementacion de esta
// interfaz, sin tocar index.ts.

export interface Coordenada {
  lat: number;
  lng: number;
}

export interface RutaCalculada {
  distanciaKm: number;
  duracionMin: number;
  // Trazado codificado (polilinea de Google, precision 5); la app lo
  // decodifica para dibujar la ruta y detectar desvios.
  polilinea: string;
  origen: Coordenada;
  destino: Coordenada;
}

export interface Lugar extends Coordenada {
  nombre: string;
}

export interface ProveedorRutas {
  calcularRutaPorCoordenadas(
    origen: Coordenada,
    destino: Coordenada,
  ): Promise<RutaCalculada>;
  /** Autocompletado: lugares de Colombia que coinciden con lo escrito. */
  buscarLugares(consulta: string): Promise<Lugar[]>;
  lugarEnCoordenada(coordenada: Coordenada): Promise<Lugar>;
}

// Error propio para que index.ts distinga "no se pudo resolver" (lugar
// inexistente, sin ruta terrestre, proveedor caido) de un fallo inesperado, y
// lo traduzca al codigo de dominio correcto en vez de un 500 crudo.
export class RutaNoEncontradaError extends Error {
  constructor(motivo: string) {
    super(motivo);
    this.name = "RutaNoEncontradaError";
  }
}
