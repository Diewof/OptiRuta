import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/core/widgets/primary_action_button.dart';

Widget _envolver(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('llama a onPressed al tocarlo', (WidgetTester tester) async {
    var tocado = false;
    await tester.pumpWidget(
      _envolver(
        PrimaryActionButton(
          label: 'Agendar viaje',
          onPressed: () => tocado = true,
        ),
      ),
    );

    await tester.tap(find.text('Agendar viaje'));
    await tester.pump();

    expect(tocado, isTrue);
  });

  testWidgets('se deshabilita cuando onPressed es null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        const PrimaryActionButton(label: 'Agendar viaje', onPressed: null),
      ),
    );

    final ElevatedButton boton = tester.widget(find.byType(ElevatedButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets('muestra un spinner y oculta el texto en loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        PrimaryActionButton(
          label: 'Agendar viaje',
          onPressed: () {},
          loading: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Agendar viaje'), findsNothing);
  });
}
