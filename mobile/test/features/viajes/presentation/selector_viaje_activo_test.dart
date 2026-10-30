import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/presentation/widgets/selector_viaje_activo.dart';

ViajeResumen _viaje(String id, String remision) => ViajeResumen(
  id: id,
  remision: remision,
  origen: 'Bogotá',
  destino: 'Cali',
  estado: EstadoViaje.asignado,
  placaVehiculo: 'TKM218',
  nombreConductor: 'Luis Herrera',
  nombreCliente: 'Andina',
  fechaCreacion: DateTime(2026, 10, 13),
);

void main() {
  final List<ViajeResumen> viajes = <ViajeResumen>[
    _viaje('a', 'REM-A'),
    _viaje('b', 'REM-B'),
    _viaje('c', 'REM-C'),
  ];

  Future<List<String>> montar(WidgetTester tester, String actual) async {
    final List<String> elegidos = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SelectorViajeActivo(
            viajes: viajes,
            seleccionadoId: actual,
            alSeleccionar: elegidos.add,
          ),
        ),
      ),
    );
    return elegidos;
  }

  testWidgets('las flechas eligen el anterior y el siguiente', (tester) async {
    final elegidos = await montar(tester, 'b');

    expect(find.text('Viaje 2 de 3 · REM-B'), findsOneWidget);
    await tester.tap(find.byTooltip('Viaje anterior'));
    await tester.tap(find.byTooltip('Viaje siguiente'));

    expect(elegidos, <String>['a', 'c']);
  });

  testWidgets('en los extremos la flecha correspondiente se desactiva', (
    tester,
  ) async {
    final elegidos = await montar(tester, 'a');

    await tester.tap(find.byTooltip('Viaje anterior'));

    expect(elegidos, isEmpty);
  });

  testWidgets('el menú permite elegir cualquier viaje', (tester) async {
    final elegidos = await montar(tester, 'a');

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('REM-C').last);
    await tester.pumpAndSettle();

    expect(elegidos, <String>['c']);
  });
}
