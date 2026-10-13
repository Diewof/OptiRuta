// Logica pura de la funcion encuestas: valida el cuerpo, delega en el
// repositorio (RPC de Postgres) y traduce los errores de dominio. Vive aparte
// de index.ts para probarla sin Deno.serve ni Supabase.
//
// Un solo endpoint /v1/encuestas; la operacion va en `accion`:
//   PENDIENTES                                    -> encuestas por enviar
//   ENVIO      { id, enlace, enviada }            -> guarda enlace / marca enviada
//   RESPUESTA  { token, csat_*, nps, comentario } -> registra la respuesta

export interface EncuestaPendiente {
  id: string;
  token: string;
  destinatario: string | null;
  cliente: string;
  origen: string;
  destino: string;
  remision: string;
}

export interface RespuestaEncuesta {
  token: string;
  csatEntrega: number;
  csatServicio: number;
  csatAtencion: number;
  csatPuntualidad: number;
  nps: number;
  comentario: string | null;
}

export interface RepositorioEncuestas {
  pendientes(): Promise<EncuestaPendiente[]>;
  registrarEnvio(id: string, enlace: string, enviada: boolean): Promise<void>;
  registrarRespuesta(respuesta: RespuestaEncuesta): Promise<void>;
}

/** Error con el status HTTP y el codigo de dominio a devolver. */
export class ErrorDominio extends Error {
  constructor(
    readonly status: number,
    readonly codigo: string,
    mensaje: string,
  ) {
    super(mensaje);
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_ENLACE = 2000;

function datosInvalidos(mensaje: string): ErrorDominio {
  return new ErrorDominio(400, "DATOS_INVALIDOS", mensaje);
}

function entero(valor: unknown, min: number, max: number): number | null {
  // Google Forms entrega las escalas como numero o como texto ("4").
  const n = typeof valor === "string" && valor.trim() !== ""
    ? Number(valor)
    : valor;
  return typeof n === "number" && Number.isInteger(n) && n >= min && n <= max
    ? n
    : null;
}

function uuid(valor: unknown): string | null {
  return typeof valor === "string" && UUID.test(valor.trim())
    ? valor.trim().toLowerCase()
    : null;
}

/** Devuelve el resultado a serializar; lanza [ErrorDominio] si el cuerpo no vale. */
export async function resolverPeticion(
  repositorio: RepositorioEncuestas,
  cuerpo: Record<string, unknown>,
): Promise<unknown> {
  switch (cuerpo.accion) {
    case "PENDIENTES":
      return { encuestas: await repositorio.pendientes() };

    case "ENVIO": {
      const id = uuid(cuerpo.id);
      const enlace = typeof cuerpo.enlace === "string"
        ? cuerpo.enlace.trim()
        : "";
      if (!id) throw datosInvalidos("El id de la encuesta no es valido.");
      if (!enlace.startsWith("https://") || enlace.length > MAX_ENLACE) {
        throw datosInvalidos("El enlace de la encuesta no es valido.");
      }
      if (typeof cuerpo.enviada !== "boolean") {
        throw datosInvalidos("Falta indicar si la encuesta fue enviada.");
      }
      await repositorio.registrarEnvio(id, enlace, cuerpo.enviada);
      return { ok: true };
    }

    case "RESPUESTA": {
      const token = uuid(cuerpo.token);
      const csatEntrega = entero(cuerpo.csat_entrega, 1, 5);
      const csatServicio = entero(cuerpo.csat_servicio, 1, 5);
      const csatAtencion = entero(cuerpo.csat_atencion, 1, 5);
      const csatPuntualidad = entero(cuerpo.csat_puntualidad, 1, 5);
      const nps = entero(cuerpo.nps, 0, 10);
      if (!token) throw datosInvalidos("El codigo de la encuesta no es valido.");
      if (
        csatEntrega === null || csatServicio === null ||
        csatAtencion === null || csatPuntualidad === null || nps === null
      ) {
        throw datosInvalidos(
          "Las calificaciones deben ir de 1 a 5 y la recomendacion de 0 a 10.",
        );
      }
      const comentario = typeof cuerpo.comentario === "string"
        ? cuerpo.comentario.trim().slice(0, 1000) || null
        : null;
      await repositorio.registrarRespuesta({
        token,
        csatEntrega,
        csatServicio,
        csatAtencion,
        csatPuntualidad,
        nps,
        comentario,
      });
      return { ok: true };
    }

    default:
      throw datosInvalidos("Accion no soportada.");
  }
}

/** Traduce el SQLSTATE de las RPC a un error de dominio; nunca expone el crudo. */
export function traducirErrorRpc(codigo: string | undefined): ErrorDominio {
  switch (codigo) {
    case "OR141":
      return new ErrorDominio(
        404,
        "ENCUESTA_NO_ENCONTRADA",
        "La encuesta no existe o ya no admite cambios.",
      );
    case "OR142":
      return new ErrorDominio(
        409,
        "ENCUESTA_YA_RESPONDIDA",
        "Esta encuesta ya fue respondida.",
      );
    case "OR143":
      return new ErrorDominio(
        422,
        "ENCUESTA_VENCIDA",
        "Esta encuesta ya vencio.",
      );
    case "OR144":
      return datosInvalidos("Los datos de la encuesta no son validos.");
    default:
      return new ErrorDominio(
        500,
        "ERROR_INTERNO",
        "No fue posible procesar la solicitud de encuestas.",
      );
  }
}
