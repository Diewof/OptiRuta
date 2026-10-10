// deno test supabase/functions/rutas
import { assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert";
import { RutaNoEncontradaError } from "./proveedor.ts";
import { OsmProveedorRutas } from "./proveedor_osm.ts";

function fetchFalso(
  respuesta: unknown,
  estado = 200,
): { fetchFn: typeof fetch; urls: string[] } {
  const urls: string[] = [];
  const fetchFn = ((input: string | URL | Request) => {
    urls.push(input.toString());
    return Promise.resolve(
      new Response(JSON.stringify(respuesta), {
        status: estado,
        headers: { "content-type": "application/json" },
      }),
    );
  }) as typeof fetch;
  return { fetchFn, urls };
}

const bogota = { lat: 4.711, lng: -74.0721 };
const barranquilla = { lat: 10.9685, lng: -74.7813 };

Deno.test("calcularRutaPorCoordenadas devuelve km, minutos y trazado", async () => {
  const { fetchFn, urls } = fetchFalso({
    routes: [{ distance: 1012300, duration: 64800, geometry: "_p~iF~ps|U" }],
  });

  const r = await new OsmProveedorRutas(fetchFn)
    .calcularRutaPorCoordenadas(bogota, barranquilla);

  assertEquals(r.distanciaKm, 1012.3);
  assertEquals(r.duracionMin, 1080);
  assertEquals(r.polilinea, "_p~iF~ps|U");
  // OSRM recibe lon,lat (al revés que la app) y pide la geometría completa.
  assertStringIncludes(urls[0], "-74.0721,4.711;-74.7813,10.9685");
  assertStringIncludes(urls[0], "overview=full");
});

Deno.test("calcularRutaPorCoordenadas lanza RutaNoEncontradaError sin rutas", async () => {
  const { fetchFn } = fetchFalso({ routes: [] });

  await assertRejects(
    () => new OsmProveedorRutas(fetchFn).calcularRutaPorCoordenadas(bogota, barranquilla),
    RutaNoEncontradaError,
  );
});

Deno.test("un error HTTP del proveedor se traduce a error de dominio", async () => {
  const { fetchFn } = fetchFalso({ detalle: "interno" }, 503);

  const error = await assertRejects(
    () => new OsmProveedorRutas(fetchFn).calcularRutaPorCoordenadas(bogota, barranquilla),
    RutaNoEncontradaError,
  );
  assertStringIncludes(error.message, "503");
  assertEquals(error.message.includes("interno"), false);
});

Deno.test("buscarLugares arma el nombre, convierte [lon,lat] y limita a Colombia", async () => {
  const { fetchFn, urls } = fetchFalso({
    features: [
      {
        geometry: { coordinates: [-75.5812, 6.2442] },
        properties: { name: "Medellín", state: "Antioquia", country: "Colombia" },
      },
      {
        geometry: { coordinates: [-75.5703, 6.2784] },
        properties: {
          name: "Terminal del Norte",
          street: "Carrera 64C",
          housenumber: "78-580",
          city: "Medellín",
          state: "Antioquia",
        },
      },
    ],
  });

  const lugares = await new OsmProveedorRutas(fetchFn).buscarLugares("Medel");

  assertEquals(lugares, [
    { nombre: "Medellín, Antioquia", lat: 6.2442, lng: -75.5812 },
    {
      nombre: "Terminal del Norte, Carrera 64C 78-580, Medellín, Antioquia",
      lat: 6.2784,
      lng: -75.5703,
    },
  ]);
  assertStringIncludes(urls[0], "q=Medel");
  assertStringIncludes(urls[0], "bbox=-79.1,-4.3,-66.8,13.5");
});

Deno.test("buscarLugares descarta resultados repetidos o sin coordenadas", async () => {
  const { fetchFn } = fetchFalso({
    features: [
      { geometry: { coordinates: [-75.5, 6.2] }, properties: { name: "Sabaneta" } },
      { geometry: { coordinates: [-75.6, 6.3] }, properties: { name: "Sabaneta" } },
      { geometry: {}, properties: { name: "Sin punto" } },
      { geometry: { coordinates: [-75.7, 6.4] }, properties: {} },
    ],
  });

  const lugares = await new OsmProveedorRutas(fetchFn).buscarLugares("Saba");

  assertEquals(lugares.map((l) => l.nombre), ["Sabaneta"]);
});

Deno.test("lugarEnCoordenada usa el nombre y conserva la coordenada elegida", async () => {
  const { fetchFn, urls } = fetchFalso({
    features: [{
      geometry: { coordinates: [-75.6, 6.15] },
      properties: { name: "Sabaneta", state: "Antioquia" },
    }],
  });

  const lugar = await new OsmProveedorRutas(fetchFn)
    .lugarEnCoordenada({ lat: 6.15, lng: -75.61 });

  // El punto cercano que devuelve Photon no reemplaza lo que eligió el usuario.
  assertEquals(lugar, { nombre: "Sabaneta, Antioquia", lat: 6.15, lng: -75.61 });
  assertStringIncludes(urls[0], "/reverse?lat=6.15&lon=-75.61");
});

Deno.test("lugarEnCoordenada sin resultados usa la coordenada como nombre", async () => {
  const { fetchFn } = fetchFalso({ features: [] });

  const lugar = await new OsmProveedorRutas(fetchFn)
    .lugarEnCoordenada({ lat: 6.15, lng: -75.6 });

  assertEquals(lugar.nombre, "6.1500, -75.6000");
});

Deno.test("lugarEnCoordenada no usa nombres de comercios ni valores separados por ;", async () => {
  const { fetchFn } = fetchFalso({
    features: [{
      geometry: { coordinates: [-75.58, 6.24] },
      properties: {
        name: "LITO S.A.S;DEPOSITO OMAR GONZALEZ",
        street: "CARRERA 58 #43 sur 83;CALLE 57 # 53-39",
        district: "Laureles-Estadio",
        city: "Medellin",
        state: "Antioquia",
      },
    }],
  });

  const lugar = await new OsmProveedorRutas(fetchFn)
    .lugarEnCoordenada({ lat: 6.2442, lng: -75.5812 });

  assertEquals(
    lugar.nombre,
    "CARRERA 58 #43 sur 83, Laureles-Estadio, Medellin, Antioquia",
  );
});

Deno.test("buscarLugares conserva solo el primer valor de campos con ;", async () => {
  const { fetchFn } = fetchFalso({
    features: [{
      geometry: { coordinates: [-75.58, 6.24] },
      properties: { name: "Bodega Uno;Bodega Dos", city: "Itagüí", state: "Antioquia" },
    }],
  });

  const lugares = await new OsmProveedorRutas(fetchFn).buscarLugares("Bodega");

  assertEquals(lugares[0].nombre, "Bodega Uno, Itagüí, Antioquia");
});
