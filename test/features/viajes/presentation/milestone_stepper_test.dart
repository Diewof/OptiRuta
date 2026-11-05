import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/features/viajes/domain/entities/hito.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_hito.dart';
import 'package:optiruta/features/viajes/presentation/widgets/milestone_stepper.dart';

Hito _hito(TipoHito tipo, DateTime fecha) =>
    Hito(id: tipo.codigo, viajeId: 'v-1', tipo: tipo, fechaHora: fecha);

void main() {
  testWidgets('sin hitos, el resumen accesible marca Salida como siguiente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MilestoneStepper(hitos: [])),
      ),
    );

    final Semantics semantics = tester.widget(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label != null,
      ),
    );
    expect(semantics.properties.label, contains('Salida'));
  });

  testWidgets('con todos los hitos, el resumen indica viaje completo', (
    WidgetTester tester,
  ) async {
    final DateTime ahora = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MilestoneStepper(
            hitos: <Hito>[
              _hito(TipoHito.salida, ahora),
              _hito(TipoHito.llegadaCargue, ahora),
              _hito(TipoHito.salidaConCarga, ahora),
              _hito(TipoHito.llegadaDestino, ahora),
            ],
          ),
        ),
      ),
    );

    final Semantics semantics = tester.widget(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label != null,
      ),
    );
    expect(semantics.properties.label, contains('completó los 4 hitos'));
  });

  testWidgets('muestra las 4 etiquetas de paso', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MilestoneStepper(hitos: [])),
      ),
    );

    expect(find.text('Salida'), findsOneWidget);
    expect(find.text('Cargue'), findsOneWidget);
    expect(find.text('Con carga'), findsOneWidget);
    expect(find.text('Destino'), findsOneWidget);
  });
}
