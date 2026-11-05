import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/widgets/error_state.dart';

void main() {
  testWidgets('muestra el mensaje de error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ErrorState(mensaje: 'No se pudo cargar')),
      ),
    );

    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('muestra y dispara el botón de reintentar si se provee', (
    WidgetTester tester,
  ) async {
    var reintentado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorState(
            mensaje: 'No se pudo cargar',
            onReintentar: () => reintentado = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(reintentado, isTrue);
  });
}
