import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/core/widgets/app_select_field.dart';

void main() {
  testWidgets('muestra el marcador de posicion sin valor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppSelectField(
            label: 'Cliente',
            marcador: 'Seleccionar cliente',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Seleccionar cliente'), findsOneWidget);
  });

  testWidgets('muestra el valor elegido y llama a onTap', (
    WidgetTester tester,
  ) async {
    var tocado = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppSelectField(
            label: 'Cliente',
            valor: 'Distribuidora Andina',
            onTap: () => tocado = true,
          ),
        ),
      ),
    );

    expect(find.text('Distribuidora Andina'), findsOneWidget);

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(tocado, isTrue);
  });

  testWidgets('muestra el texto de error cuando se provee', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppSelectField(
            label: 'Cliente',
            onTap: () {},
            errorText: 'Selecciona un cliente',
          ),
        ),
      ),
    );

    expect(find.text('Selecciona un cliente'), findsOneWidget);
  });
}
