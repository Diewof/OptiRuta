// deno test supabase/functions/encuestas
import { assertEquals, assertRejects } from "jsr:@std/assert";
import {
  ErrorDominio,
  type RepositorioEncuestas,
  type RespuestaEncuesta,
  resolverPeticion,
  traducirErrorRpc,
} from "./peticion.ts";

const TOKEN = "11111111-2222-3333-4444-555555555555";

function repositorioFalso() {
  const respuestas: RespuestaEncuesta[] = [];
  const envios: Array<[string, string, boolean]> = [];
  const repo: RepositorioEncuestas = {
    pendientes: () => Promise.resolve([]),
    registrarEnvio: (id, enlace, enviada) => {
      envios.push([id, enlace, enviada]);
      return Promise.resolve();
    },
    registrarRespuesta: (r) => {
      respuestas.push(r);
      return Promise.resolve();
    },
  };
  return { repo, respuestas, envios };
}

const cuerpoRespuesta = {
  accion: "RESPUESTA",
  token: TOKEN,
  csat_entrega: "5",
  csat_servicio: 4,
  csat_atencion: "3",
  csat_puntualidad: 2,
  nps: "9",
  comentario: "  Todo bien  ",
};

Deno.test("RESPUESTA acepta escalas como texto y limpia el comentario", async () => {
  const { repo, respuestas } = repositorioFalso();
  await resolverPeticion(repo, cuerpoRespuesta);
  assertEquals(respuestas[0], {
    token: TOKEN,
    csatEntrega: 5,
    csatServicio: 4,
    csatAtencion: 3,
    csatPuntualidad: 2,
    nps: 9,
    comentario: "Todo bien",
  });
});

Deno.test("RESPUESTA rechaza calificaciones fuera de rango", async () => {
  const { repo, respuestas } = repositorioFalso();
  const error = await assertRejects(
    () => resolverPeticion(repo, { ...cuerpoRespuesta, csat_entrega: 6 }),
    ErrorDominio,
  );
  assertEquals(error.status, 400);
  assertEquals(respuestas.length, 0);
});

Deno.test("RESPUESTA rechaza un token que no es UUID", async () => {
  const { repo } = repositorioFalso();
  await assertRejects(
    () => resolverPeticion(repo, { ...cuerpoRespuesta, token: "abc" }),
    ErrorDominio,
  );
});

Deno.test("ENVIO exige enlace https y bandera enviada", async () => {
  const { repo, envios } = repositorioFalso();
  await assertRejects(
    () =>
      resolverPeticion(repo, {
        accion: "ENVIO",
        id: TOKEN,
        enlace: "http://x",
        enviada: true,
      }),
    ErrorDominio,
  );
  await resolverPeticion(repo, {
    accion: "ENVIO",
    id: TOKEN,
    enlace: "https://forms.gle/x",
    enviada: false,
  });
  assertEquals(envios, [[TOKEN, "https://forms.gle/x", false]]);
});

Deno.test("accion desconocida es 400", async () => {
  const { repo } = repositorioFalso();
  const error = await assertRejects(
    () => resolverPeticion(repo, { accion: "BORRAR" }),
    ErrorDominio,
  );
  assertEquals(error.codigo, "DATOS_INVALIDOS");
});

Deno.test("traducirErrorRpc mapea codigos y nunca expone el crudo", () => {
  assertEquals(traducirErrorRpc("OR142").status, 409);
  assertEquals(traducirErrorRpc("OR143").status, 422);
  assertEquals(traducirErrorRpc("OR141").status, 404);
  const generico = traducirErrorRpc("42P01");
  assertEquals(generico.status, 500);
  assertEquals(generico.codigo, "ERROR_INTERNO");
});
