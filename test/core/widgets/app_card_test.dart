import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/theme/app_colors.dart';
import 'package:optiruta/core/widgets/app_card.dart';

void main() {
  testWidgets('renderiza el contenido hijo', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppCard(child: Text('Contenido'))),
      ),
    );

    expect(find.text('Contenido'), findsOneWidget);
  });

  testWidgets('aplica franja lateral del color indicado', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppCard(
            stripe: AppCardStripe.left,
            stripeColor: AppColors.success,
            child: Text('Viaje'),
          ),
        ),
      ),
    );

    final Positioned posicionado = tester.widget(find.byType(Positioned));
    final ColoredBox franja = posicionado.child as ColoredBox;
    expect(franja.color, AppColors.success);
  });
}
