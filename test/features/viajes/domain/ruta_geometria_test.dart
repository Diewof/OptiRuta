import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/ruta_geometria.dart';

void main() {
  group('decodificarPolilinea', () {
    test('decodifica el ejemplo de referencia de Google', () {
      final List<Coordenada> puntos = decodificarPolilinea(
        r'_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      );

      expect(puntos, hasLength(3));
      expect(puntos[0].lat, closeTo(38.5, 1e-5));
      expect(puntos[0].lng, closeTo(-120.2, 1e-5));
      expect(puntos[1].lat, closeTo(40.7, 1e-5));
      expect(puntos[1].lng, closeTo(-120.95, 1e-5));
      expect(puntos[2].lat, closeTo(43.252, 1e-5));
      expect(puntos[2].lng, closeTo(-126.453, 1e-5));
    });

    test('una cadena vacía da una lista vacía', () {
      expect(decodificarPolilinea(''), isEmpty);
    });

    test('una cadena truncada devuelve solo los puntos completos', () {
      expect(decodificarPolilinea('_p~iF~ps|U_ulLnnq'), hasLength(1));
    });
  });

  group('distanciaMetros', () {
    test('0,1 grados sobre el ecuador son unos 11,1 km', () {
      expect(
        distanciaMetros(const Coordenada(0, 0), const Coordenada(0, 0.1)),
        closeTo(11119, 20),
      );
    });
  });

  group('distanciaARuta', () {
    const List<Coordenada> ruta = <Coordenada>[
      Coordenada(0, 0),
      Coordenada(0, 0.1),
    ];

    test('un punto sobre la ruta está a ~0 m', () {
      expect(distanciaARuta(const Coordenada(0, 0.05), ruta), lessThan(1));
    });

    test('un punto al costado mide la distancia perpendicular', () {
      expect(
        distanciaARuta(const Coordenada(0.01, 0.05), ruta),
        closeTo(1112, 10),
      );
    });

    test(
      'más allá del extremo mide la distancia al extremo, no a la recta',
      () {
        expect(
          distanciaARuta(const Coordenada(0, 0.11), ruta),
          closeTo(1112, 10),
        );
      },
    );

    test('ruta vacía da infinito', () {
      expect(
        distanciaARuta(const Coordenada(0, 0), const <Coordenada>[]),
        double.infinity,
      );
    });
  });

  group('rutaRestante / rutaRecorrida', () {
    const List<Coordenada> ruta = <Coordenada>[
      Coordenada(0, 0),
      Coordenada(0, 0.1),
      Coordenada(0, 0.2),
    ];

    test('al inicio queda toda la ruta', () {
      final List<Coordenada> restante = rutaRestante(
        const Coordenada(0, 0),
        ruta,
      );
      expect(restante.first.lng, closeTo(0, 1e-9));
      expect(restante, hasLength(3));
    });

    test(
      'a mitad del segundo tramo la línea empieza donde está el conductor',
      () {
        final List<Coordenada> restante = rutaRestante(
          const Coordenada(0.0005, 0.15),
          ruta,
        );
        expect(restante, hasLength(2));
        expect(restante.first.lng, closeTo(0.15, 1e-6));
        expect(restante.first.lat, closeTo(0, 1e-9));
        expect(restante.last, ruta.last);
      },
    );

    test('lo recorrido y lo restante se unen en el mismo punto', () {
      const Coordenada p = Coordenada(0, 0.15);
      final List<Coordenada> recorrida = rutaRecorrida(p, ruta);
      final List<Coordenada> restante = rutaRestante(p, ruta);
      expect(recorrida.first, ruta.first);
      expect(recorrida.last, restante.first);
      expect(recorrida, hasLength(3));
    });

    test('con menos de dos puntos no recorta nada', () {
      expect(
        rutaRestante(const Coordenada(0, 0), const <Coordenada>[]),
        isEmpty,
      );
      expect(
        rutaRecorrida(const Coordenada(0, 0), const <Coordenada>[]),
        isEmpty,
      );
    });
  });
}
