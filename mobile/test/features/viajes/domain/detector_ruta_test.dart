import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/features/viajes/domain/detector_ruta.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_alerta_viaje.dart';

// Ruta recta sobre el ecuador de ~111 km.
const List<Coordenada> _ruta = <Coordenada>[Coordenada(0, 0), Coordenada(0, 1)];
const Coordenada _enRuta = Coordenada(0, 0.5);
// ~2,2 km al norte de la ruta (umbral de desvío: 1 km).
const Coordenada _fueraDeRuta = Coordenada(0.02, 0.5);

void main() {
  final DateTime t0 = DateTime(2026, 10, 8, 8);
  late DetectorRuta detector;

  Duration min(int m) => Duration(minutes: m);

  setUp(() => detector = DetectorRuta(ruta: _ruta));

  group('parada prolongada', () {
    test('no alerta antes de 30 minutos quieto', () {
      detector.evaluar(_enRuta, t0);

      expect(detector.evaluar(_enRuta, t0.add(min(29))), isNull);
    });

    test('alerta a los 30 minutos quieto', () {
      detector.evaluar(_enRuta, t0);

      expect(
        detector.evaluar(_enRuta, t0.add(min(30))),
        TipoAlertaViaje.paradaProlongada,
      );
    });

    test('el ruido del GPS dentro de 100 m no reinicia la espera', () {
      detector.evaluar(_enRuta, t0);
      detector.evaluar(const Coordenada(0, 0.5003), t0.add(min(15)));

      expect(
        detector.evaluar(const Coordenada(0, 0.5002), t0.add(min(30))),
        TipoAlertaViaje.paradaProlongada,
      );
    });

    test('moverse más de 100 m reinicia la espera', () {
      detector.evaluar(_enRuta, t0);
      detector.evaluar(const Coordenada(0, 0.502), t0.add(min(20)));

      expect(
        detector.evaluar(const Coordenada(0, 0.502), t0.add(min(40))),
        isNull,
      );
    });

    test('tras alertar no repite hasta otro período completo', () {
      detector.evaluar(_enRuta, t0);
      detector.evaluar(_enRuta, t0.add(min(30)));

      expect(detector.evaluar(_enRuta, t0.add(min(40))), isNull);
      expect(
        detector.evaluar(_enRuta, t0.add(min(60))),
        TipoAlertaViaje.paradaProlongada,
      );
    });
  });

  group('desvío de ruta', () {
    test('no alerta de inmediato: debe sostenerse 2 minutos', () {
      expect(detector.evaluar(_fueraDeRuta, t0), isNull);
      expect(detector.evaluar(_fueraDeRuta, t0.add(min(1))), isNull);
    });

    test('alerta tras 2 minutos fuera de la ruta', () {
      detector.evaluar(_fueraDeRuta, t0);

      expect(
        detector.evaluar(_fueraDeRuta, t0.add(min(2))),
        TipoAlertaViaje.desvioRuta,
      );
    });

    test('volver a la ruta antes de 2 minutos cancela el desvío', () {
      detector.evaluar(_fueraDeRuta, t0);
      detector.evaluar(_enRuta, t0.add(min(1)));

      expect(detector.evaluar(_fueraDeRuta, t0.add(min(2))), isNull);
    });

    test('a 500 m de la ruta no es desvío', () {
      const Coordenada cerca = Coordenada(0.0045, 0.5);
      detector.evaluar(cerca, t0);

      expect(detector.evaluar(cerca, t0.add(min(5))), isNull);
    });

    test('sin trazado no hay desvío (viaje antiguo)', () {
      final DetectorRuta sinRuta = DetectorRuta(ruta: const <Coordenada>[]);
      sinRuta.evaluar(_fueraDeRuta, t0);

      expect(sinRuta.evaluar(_fueraDeRuta, t0.add(min(10))), isNull);
    });

    test('si coinciden, el desvío tiene prioridad sobre la parada', () {
      final DetectorRuta d = DetectorRuta(ruta: _ruta, tiempoDesvio: min(30));
      d.evaluar(_fueraDeRuta, t0);

      expect(
        d.evaluar(_fueraDeRuta, t0.add(min(30))),
        TipoAlertaViaje.desvioRuta,
      );
    });
  });
}
