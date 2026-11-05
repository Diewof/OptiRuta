import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:optiruta/features/dashboard/presentation/widgets/metricas_widgets.dart';
import 'package:optiruta/features/notificaciones/domain/entities/notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/entities/tipo_notificacion.dart';

Notificacion _n(String id, TipoNotificacion tipo, String titulo) =>
    Notificacion(
      id: id,
      tipo: tipo,
      titulo: titulo,
      mensaje: 'Detalle de $titulo',
      leida: false,
      fechaCreacion: DateTime(2026, 10, 9),
    );

void main() {
  Future<void> montar(WidgetTester tester, List<Notificacion> alertas) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AlertasActivasCard(alertas: alertas)),
        ),
      );

  testWidgets(
    'mezcla avisos, completados e informativas sin ser solo advertencia',
    (WidgetTester tester) async {
      await montar(tester, <Notificacion>[
        _n('1', TipoNotificacion.retraso, 'Retraso en viaje'),
        _n('2', TipoNotificacion.viajeCompletado, 'Viaje completado'),
        _n('3', TipoNotificacion.peajeRegistrado, 'Peajes registrados'),
        _n('4', TipoNotificacion.documentoVencido, 'Documento vencido'),
      ]);

      expect(find.text('4 alertas activas'), findsOneWidget);
      expect(find.text('1 crítica'), findsOneWidget);
      expect(find.text('1 aviso'), findsOneWidget);
      expect(find.text('1 completado'), findsOneWidget);
      expect(find.text('1 informativa'), findsOneWidget);
      // La cabecera es una campana, no un triángulo de advertencia.
      expect(find.byIcon(LucideIcons.bell), findsOneWidget);
    },
  );

  testWidgets('sin alertas no ocupa espacio', (WidgetTester tester) async {
    await montar(tester, const <Notificacion>[]);

    expect(find.byType(Text), findsNothing);
  });
}
