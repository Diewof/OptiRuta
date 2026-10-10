import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/widgets/empty_state.dart';

void main() {
  testWidgets('muestra titulo y mensaje cuando se proveen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            titulo: 'Sin viajes',
            mensaje: 'No hay viajes programados para este día.',
          ),
        ),
      ),
    );

    expect(find.text('Sin viajes'), findsOneWidget);
    expect(
      find.text('No hay viajes programados para este día.'),
      findsOneWidget,
    );
  });
}
