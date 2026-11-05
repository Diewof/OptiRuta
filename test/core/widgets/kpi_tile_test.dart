import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:optiruta/core/widgets/kpi_tile.dart';

void main() {
  testWidgets('muestra etiqueta, valor y varianza', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KpiTile(
            etiqueta: 'Ingresos',
            valor: r'$61,2 M',
            varianza: '8,4 % vs. ago.',
            tendencia: KpiTrend.up,
          ),
        ),
      ),
    );

    expect(find.text('Ingresos'), findsOneWidget);
    expect(find.text(r'$61,2 M'), findsOneWidget);
    expect(find.text('8,4 % vs. ago.'), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowUp), findsOneWidget);
  });
}
