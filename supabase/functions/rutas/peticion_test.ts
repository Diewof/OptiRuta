// deno test supabase/functions/rutas
import { assertEquals } from "jsr:@std/assert";
import type { ProveedorRutas, RutaCalculada } from "./proveedor.ts";
import { resolverPeticion } from "./peticion.ts";

const ruta: RutaCalculada = {
  distanciaKm: 10,
  duracionMin: 20,
  polilinea: "abc",
  origen: { lat: 1, lng: 2 },
  destino: { lat: 3, lng: 4 },
};

function proveedorFalso(): ProveedorRutas & { llamadas: string[] } {
  const llamadas: string[] = [];
  return {
    llamadas,
    calcularRutaPorCoordenadas: (o, d) => {
      llamadas.push(`ruta:${o.lat},${o.lng}|${d.lat},${d.lng}`);
      return Promise.resolve(ruta);
    },
    buscarLugares: (c) => {
      llamadas.push(`buscar:${c}`);
      return Promise.resolve([{ nombre: "Medellín", lat: 6.2, lng: -75.5 }]);
    },
    lugarEnCoordenada: (c) => {
      llamadas.push(`inversa:${c.lat},${c.lng}`);
      return Promise.resolve({ nombre: "Sitio", ...c });
    },
  };
}

Deno.test("origen y destino como coordenadas calculan la ruta", async () => {
  const p = proveedorFalso();
  const r = await resolverPeticion(p, {
    origen: { lat: 4.7, lng: -74 },
    destino: { lat: 3.4, lng: -76.5 },
  });
  assertEquals(r, ruta);
  assertEquals(p.llamadas, ["ruta:4.7,-74|3.4,-76.5"]);
});

Deno.test("origen y destino como texto ya no se aceptan", async () => {
  const cuerpo = { origen: "Bogotá", destino: "Cali" } as never;
  assertEquals(await resolverPeticion(proveedorFalso(), cuerpo), null);
});

Deno.test("una consulta devuelve lugares", async () => {
  const p = proveedorFalso();
  const r = await resolverPeticion(p, { consulta: " Medel " });
  assertEquals(r, { lugares: [{ nombre: "Medellín", lat: 6.2, lng: -75.5 }] });
  assertEquals(p.llamadas, ["buscar:Medel"]);
});

Deno.test("una consulta de menos de 3 letras es inválida", async () => {
  assertEquals(await resolverPeticion(proveedorFalso(), { consulta: "Me" }), null);
});

Deno.test("lat y lng piden el lugar en esa coordenada", async () => {
  const p = proveedorFalso();
  await resolverPeticion(p, { lat: 6.2, lng: -75.5 });
  assertEquals(p.llamadas, ["inversa:6.2,-75.5"]);
});

Deno.test("coordenadas fuera de rango son inválidas", async () => {
  assertEquals(await resolverPeticion(proveedorFalso(), { lat: 95, lng: 0 }), null);
  assertEquals(
    await resolverPeticion(proveedorFalso(), {
      origen: { lat: 4, lng: -74 },
      destino: { lat: 3, lng: 200 },
    }),
    null,
  );
});

Deno.test("un cuerpo vacío es inválido", async () => {
  assertEquals(await resolverPeticion(proveedorFalso(), {}), null);
});
