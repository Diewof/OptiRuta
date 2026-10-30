// Adapter (patron permitido solo en supabase/functions segun CLAUDE.md):
// interfaz de proveedor de precio de ACPM + una implementacion (La Republica).
// Cambiar de fuente en el futuro solo implica agregar otra implementacion de
// esta interfaz, sin tocar index.ts.

export interface PrecioAcpm {
  precioGalon: number;
  fechaVigencia: string; // YYYY-MM-DD
}

export interface ProveedorPrecioAcpm {
  obtenerPrecioVigente(): Promise<PrecioAcpm>;
}

// Error propio para que index.ts distinga "el scraping fallo" (pagina caida,
// HTML cambio de estructura) de un fallo de red generico, y lo traduzca al
// codigo de dominio correcto en vez de un 500 crudo.
export class ScrapingFallidoError extends Error {
  constructor(motivo: string) {
    super(motivo);
    this.name = "ScrapingFallidoError";
  }
}

const URL_FUENTE =
  "https://www.larepublica.co/indicadores-economicos/macro/acpm";

// La pagina es HTML estatico (confirmado en diseno-base-de-datos-optiruta.md
// seccion 6): sin autenticacion, sin JavaScript a ejecutar. Se extrae con una
// expresion regular simple en vez de sumar una dependencia de parseo de DOM,
// que para un solo valor numerico seria sobre-ingenieria.
const PATRON_PRECIO = /ACPM[\s\S]{0,400}?\$\s?([\d.,]+)/i;

export class ProveedorLaRepublica implements ProveedorPrecioAcpm {
  constructor(private readonly urlFuente: string = URL_FUENTE) {}

  async obtenerPrecioVigente(): Promise<PrecioAcpm> {
    let html: string;
    try {
      const respuesta = await fetch(this.urlFuente, {
        headers: { "User-Agent": "OptiRuta-precio-acpm-scraper/1.0" },
      });
      if (!respuesta.ok) {
        throw new ScrapingFallidoError(
          `La fuente respondio con estado ${respuesta.status}.`,
        );
      }
      html = await respuesta.text();
    } catch (error) {
      if (error instanceof ScrapingFallidoError) throw error;
      throw new ScrapingFallidoError(
        `No se pudo contactar la fuente de precio de ACPM: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }

    const coincidencia = PATRON_PRECIO.exec(html);
    if (!coincidencia) {
      throw new ScrapingFallidoError(
        "No se encontro el precio de ACPM en el HTML; la estructura de la pagina pudo haber cambiado.",
      );
    }

    const crudo = coincidencia[1].replace(/\./g, "").replace(",", ".");
    const precioGalon = Number(crudo);
    if (!Number.isFinite(precioGalon) || precioGalon <= 0) {
      throw new ScrapingFallidoError(
        `El valor extraido ("${coincidencia[1]}") no es un precio valido.`,
      );
    }

    return {
      precioGalon,
      // Fecha civil de Colombia (UTC adelantaria el dia pasadas las 7 p. m.).
      fechaVigencia: new Intl.DateTimeFormat("en-CA", {
        timeZone: "America/Bogota",
      }).format(new Date()),
    };
  }
}
