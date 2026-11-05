import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/vehiculos/domain/entities/documento_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/hoja_vida.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/hoja_vida_repository.dart';
import 'package:optiruta/features/vehiculos/presentation/widgets/estado_vehiculo_chip.dart';

class _MockHojaVida extends Mock implements HojaVidaRepository {}

DocumentoVehiculo _doc(TipoDocumentoVehiculo t, EstadoDocumento e) =>
    DocumentoVehiculo(
      id: t.codigo,
      vehiculoId: 'v-1',
      tipo: t,
      fechaVencimiento: DateTime(2027),
      diasRestantes: e == EstadoDocumento.vencido ? -2 : 100,
      estado: e,
    );

void main() {
  late _MockHojaVida repo;

  setUp(() => repo = _MockHojaVida());

  Future<void> montar(WidgetTester tester) => tester.pumpWidget(
    RepositoryProvider<HojaVidaRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: EstadoVehiculoChip(vehiculoId: 'v-1')),
      ),
    ),
  );

  testWidgets('muestra Al día cuando no hay pendientes', (tester) async {
    when(() => repo.obtener('v-1')).thenAnswer(
      (_) async => HojaVida(
        odometroKm: 0,
        documentos: <DocumentoVehiculo>[
          _doc(TipoDocumentoVehiculo.soat, EstadoDocumento.vigente),
          _doc(TipoDocumentoVehiculo.tecnomecanica, EstadoDocumento.vigente),
        ],
        plan: const <ItemPlanMantenimiento>[],
        eventos: const <EventoHojaVida>[],
      ),
    );
    await montar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Al día'), findsOneWidget);
  });

  testWidgets('muestra Requiere acción y el motivo', (tester) async {
    when(() => repo.obtener('v-1')).thenAnswer(
      (_) async => HojaVida(
        odometroKm: 0,
        documentos: <DocumentoVehiculo>[
          _doc(TipoDocumentoVehiculo.soat, EstadoDocumento.vencido),
          _doc(TipoDocumentoVehiculo.tecnomecanica, EstadoDocumento.vigente),
        ],
        plan: const <ItemPlanMantenimiento>[],
        eventos: const <EventoHojaVida>[],
      ),
    );
    await montar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Requiere acción'), findsOneWidget);
    expect(find.text('SOAT vencido'), findsOneWidget);
  });

  testWidgets('si la consulta falla no muestra nada ni rompe', (tester) async {
    when(() => repo.obtener('v-1')).thenThrow(Exception('sin red'));
    await montar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Al día'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
