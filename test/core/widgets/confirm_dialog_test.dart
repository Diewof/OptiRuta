import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/core/widgets/confirm_dialog.dart';

void main() {
  testWidgets('resuelve true al confirmar', (WidgetTester tester) async {
    bool? resultado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  resultado = await ConfirmDialog.mostrar(
                    context,
                    titulo: '¿Cerrar sesión?',
                    mensaje: 'Tendrás que ingresar de nuevo.',
                    icono: Icons.logout,
                    textoConfirmar: 'Cerrar sesión',
                    esDestructivo: true,
                  );
                },
                child: const Text('Abrir'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(resultado, isTrue);
  });

  testWidgets('resuelve false al cancelar', (WidgetTester tester) async {
    bool? resultado;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  resultado = await ConfirmDialog.mostrar(
                    context,
                    titulo: '¿Cerrar sesión?',
                    mensaje: 'Tendrás que ingresar de nuevo.',
                    icono: Icons.logout,
                  );
                },
                child: const Text('Abrir'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(resultado, isFalse);
  });
}
