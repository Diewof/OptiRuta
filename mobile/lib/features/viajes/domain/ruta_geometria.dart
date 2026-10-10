import 'dart:math' as math;

import 'entities/coordenada.dart';

const double _radioTierraM = 6371000;

double _rad(double grados) => grados * math.pi / 180;

/// Distancia en metros entre dos puntos (haversine).
double distanciaMetros(Coordenada a, Coordenada b) {
  final double dLat = _rad(b.lat - a.lat);
  final double dLng = _rad(b.lng - a.lng);
  final double h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _radioTierraM * math.asin(math.sqrt(h));
}

/// Distancia en metros del punto [p] al segmento [a]-[b], con una proyección
/// plana local (suficiente para tramos de carretera; el error es mucho menor
/// que el ruido del GPS).
({double distancia, double t, Coordenada punto}) _proyectarEnSegmento(
  Coordenada p,
  Coordenada a,
  Coordenada b,
) {
  final double cosLat = math.cos(_rad(p.lat));
  double x(Coordenada c) => _rad(c.lng - p.lng) * cosLat * _radioTierraM;
  double y(Coordenada c) => _rad(c.lat - p.lat) * _radioTierraM;

  final double ax = x(a), ay = y(a), bx = x(b), by = y(b);
  final double dx = bx - ax, dy = by - ay;
  final double largo2 = dx * dx + dy * dy;
  // Con p en el origen: t es la proyección de p sobre el segmento, acotada.
  final double t = largo2 == 0
      ? 0
      : ((-ax * dx - ay * dy) / largo2).clamp(0.0, 1.0);
  final double px = ax + t * dx, py = ay + t * dy;
  return (
    distancia: math.sqrt(px * px + py * py),
    t: t,
    punto: Coordenada(a.lat + t * (b.lat - a.lat), a.lng + t * (b.lng - a.lng)),
  );
}

double _distanciaASegmento(Coordenada p, Coordenada a, Coordenada b) =>
    _proyectarEnSegmento(p, a, b).distancia;

/// Parte del trazado que aún falta por recorrer: empieza en el punto de [ruta]
/// más cercano a [p] (proyectado sobre el tramo) y sigue hasta el final. Con
/// menos de dos puntos no hay nada que recortar y devuelve [ruta] tal cual.
List<Coordenada> rutaRestante(Coordenada p, List<Coordenada> ruta) {
  if (ruta.length < 2) return ruta;
  double minima = double.infinity;
  int tramo = 0;
  Coordenada punto = ruta.first;
  for (int i = 0; i < ruta.length - 1; i++) {
    final proyeccion = _proyectarEnSegmento(p, ruta[i], ruta[i + 1]);
    if (proyeccion.distancia < minima) {
      minima = proyeccion.distancia;
      tramo = i;
      punto = proyeccion.punto;
    }
  }
  return <Coordenada>[punto, ...ruta.sublist(tramo + 1)];
}

/// Parte del trazado ya recorrida: lo que [rutaRestante] deja atrás.
List<Coordenada> rutaRecorrida(Coordenada p, List<Coordenada> ruta) {
  if (ruta.length < 2) return const <Coordenada>[];
  final List<Coordenada> restante = rutaRestante(p, ruta);
  final int recorridos = ruta.length - (restante.length - 1);
  return <Coordenada>[...ruta.sublist(0, recorridos), restante.first];
}

/// Distancia mínima en metros de [p] al trazado [ruta]. Con un solo punto es
/// la distancia a ese punto; con la ruta vacía devuelve infinito.
double distanciaARuta(Coordenada p, List<Coordenada> ruta) {
  if (ruta.isEmpty) return double.infinity;
  if (ruta.length == 1) return distanciaMetros(p, ruta.first);
  double minima = double.infinity;
  for (int i = 0; i < ruta.length - 1; i++) {
    final double d = _distanciaASegmento(p, ruta[i], ruta[i + 1]);
    if (d < minima) minima = d;
  }
  return minima;
}

/// Decodifica una polilínea de Google (precisión 5), el formato en que la
/// Routes API entrega el trazado. Una cadena vacía o truncada da la lista hasta donde
/// se pudo leer.
List<Coordenada> decodificarPolilinea(String codificada) {
  final List<Coordenada> puntos = <Coordenada>[];
  int indice = 0, lat = 0, lng = 0;

  int? leerValor() {
    int resultado = 0, desplazamiento = 0, byte;
    do {
      if (indice >= codificada.length) return null;
      byte = codificada.codeUnitAt(indice++) - 63;
      resultado |= (byte & 0x1f) << desplazamiento;
      desplazamiento += 5;
    } while (byte >= 0x20);
    return (resultado & 1) != 0 ? ~(resultado >> 1) : resultado >> 1;
  }

  while (indice < codificada.length) {
    final int? dLat = leerValor();
    final int? dLng = leerValor();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;
    puntos.add(Coordenada(lat / 1e5, lng / 1e5));
  }
  return puntos;
}
