import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/features/viajes/domain/detector_fatiga.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';

/// Cada índice está ~1,1 km del anterior: siempre «en movimiento».
Coordenada _punto(int i) => Coordenada(i * 0.01, 0);

void main() {
  final DateTime t0 = DateTime(2026, 10, 13, 6);
  late DetectorFatiga detector;

  setUp(() => detector = DetectorFatiga());

  /// Conduce [minutos] con una posición nueva cada 5 min y devuelve los
  /// eventos emitidos con el instante en que ocurrieron.
  List<(Duration, EventoFatiga)> conducir(
    int desde,
    int minutos, {
    int primerPunto = 0,
  }) {
    final List<(Duration, EventoFatiga)> eventos = <(Duration, EventoFatiga)>[];
    for (int m = desde; m <= desde + minutos; m += 5) {
      final EventoFatiga? e = detector.evaluar(
        _punto(primerPunto + m ~/ 5),
        t0.add(Duration(minutes: m)),
      );
      if (e != null) eventos.add((Duration(minutes: m), e));
    }
    return eventos;
  }

  test('avisa una sola vez al cumplir 4 horas de conducción continua', () {
    final eventos = conducir(0, 300);

    expect(eventos.first, (const Duration(hours: 4), EventoFatiga.pausaActiva));
    expect(
      eventos.where((e) => e.$2 == EventoFatiga.pausaActiva),
      hasLength(1),
    );
  });

  test('no avisa antes de las 4 horas', () {
    expect(conducir(0, 235), isEmpty);
  });

  test('una parada de 15 min reinicia la cuenta', () {
    expect(conducir(0, 180), isEmpty);
    // Parado en el mismo punto 15 min (cada 5 min llega la re-evaluación).
    for (int m = 185; m <= 200; m += 5) {
      detector.evaluar(_punto(36), t0.add(Duration(minutes: m)));
    }
    // 3 h más conduciendo: desde la pausa no se llega a 4 h.
    expect(conducir(205, 180, primerPunto: 37), isEmpty);
  });

  test('una parada corta (menos de 15 min) no reinicia la cuenta', () {
    conducir(0, 200);
    detector.evaluar(_punto(40), t0.add(const Duration(minutes: 205)));
    detector.evaluar(_punto(40), t0.add(const Duration(minutes: 210)));

    final eventos = conducir(215, 60, primerPunto: 41);

    expect(eventos.map((e) => e.$2), contains(EventoFatiga.pausaActiva));
  });

  test('ignorada: sigue en movimiento 15 min después del aviso', () {
    final eventos = conducir(0, 270);

    expect(eventos, <(Duration, EventoFatiga)>[
      (const Duration(hours: 4), EventoFatiga.pausaActiva),
      (const Duration(hours: 4, minutes: 15), EventoFatiga.pausaIgnorada),
    ]);
    expect(
      detector.tiempoIgnorado(t0.add(const Duration(minutes: 255))),
      const Duration(minutes: 15),
    );
  });

  test('si se detiene tras el aviso no se acusa de ignorarla', () {
    conducir(0, 240);
    // Se detiene en el último punto y espera 10 min (menos que la pausa).
    for (int m = 245; m <= 250; m += 5) {
      detector.evaluar(_punto(48), t0.add(Duration(minutes: m)));
    }
    final EventoFatiga? e = detector.evaluar(
      _punto(48),
      t0.add(const Duration(minutes: 256)),
    );

    expect(e, isNull);
  });

  test('forzarAviso (prueba): aviso vigente que se retira con una pausa', () {
    detector.evaluar(_punto(0), t0);
    detector.forzarAviso(t0);

    expect(detector.avisoVigente, isTrue);
    expect(detector.prueba, isTrue);
    expect(detector.conduccion(t0), const Duration(hours: 4));

    // Teléfono quieto 15 min: la pausa cuenta desde el aviso.
    detector.evaluar(_punto(0), t0.add(const Duration(minutes: 15)));

    expect(detector.avisoVigente, isFalse);
    expect(detector.prueba, isFalse);
  });

  test('forzarAviso (prueba): ignorarlo en movimiento genera el evento', () {
    detector.evaluar(_punto(0), t0);
    detector.forzarAviso(t0);

    final eventos = conducir(5, 20, primerPunto: 1);

    expect(eventos, <(Duration, EventoFatiga)>[
      (const Duration(minutes: 15), EventoFatiga.pausaIgnorada),
    ]);
  });
}
