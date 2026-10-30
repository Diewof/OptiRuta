import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/core/widgets/chip_opcion.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/presentation/pages/viajes_page.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

const Usuario _admin = Usuario(
  id: 'u-1',
  nombre: 'Ana Admin',
  rol: RolUsuario.administrador,
  activo: true,
);

ViajeResumen _v(
  String id,
  String destino,
  EstadoViaje estado,
  DateTime salida,
) => ViajeResumen(
  id: id,
  remision: 'REM-$id',
  origen: 'Bogotá',
  destino: destino,
  estado: estado,
  placaVehiculo: 'UFH664',
  nombreConductor: 'Camilo Rojas',
  nombreCliente: 'Distribuidora Andina',
  fechaSalidaProgramada: salida,
  fechaCreacion: DateTime.now(),
);

void main() {
  late _MockViajeRepository repo;

  setUp(() {
    repo = _MockViajeRepository();
    registerFallbackValue(DateTime(2026));
    final DateTime hoy = DateTime.now();
    final DateTime manana = hoy.add(const Duration(days: 1));
    when(
      () => repo.listarPorRango(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer(
      (_) async => <ViajeResumen>[
        _v(
          '1',
          'Cali',
          EstadoViaje.asignado,
          DateTime(hoy.year, hoy.month, hoy.day, 15),
        ),
        _v(
          '2',
          'Medellín',
          EstadoViaje.asignado,
          DateTime(manana.year, manana.month, manana.day, 6),
        ),
      ],
    );
    when(() => repo.listarActivos()).thenAnswer((_) async => <ViajeResumen>[]);
  });

  Future<void> montar(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepositoryProvider<ViajeRepository>.value(
        value: repo,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ViajesPage(usuario: _admin),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'abre en Hoy y los chips muestran cuántos viajes hay en cada vista',
    (WidgetTester tester) async {
      await montar(tester);

      expect(find.textContaining('Bogotá → Cali'), findsOneWidget);
      expect(find.textContaining('Bogotá → Medellín'), findsNothing);
      expect(find.text('Hoy · 1'), findsOneWidget);
      expect(find.text('Programados · 2'), findsOneWidget);
      expect(find.text('Agendar viaje'), findsOneWidget);
    },
  );

  testWidgets('el chip Programados y la búsqueda acotan la lista', (
    WidgetTester tester,
  ) async {
    await montar(tester);

    await tester.tap(find.widgetWithText(ChipOpcion, 'Programados · 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bogotá → Cali'), findsOneWidget);
    expect(find.textContaining('Bogotá → Medellín'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'medellin');
    await tester.pumpAndSettle();
    expect(find.textContaining('Bogotá → Cali'), findsNothing);
    expect(find.textContaining('Bogotá → Medellín'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Ningún viaje coincide con la búsqueda.'), findsOneWidget);
  });

  testWidgets('el modo agenda agrupa por día', (WidgetTester tester) async {
    await montar(tester);

    await tester.tap(find.widgetWithText(ChipOpcion, 'Programados · 2'));
    await tester.tap(find.byTooltip('Ver como agenda'));
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Mañana'), findsOneWidget);
    expect(find.byTooltip('Ver como lista'), findsOneWidget);
  });

  test('etiquetaDia nombra hoy, mañana, ayer y el resto con fecha', () {
    final DateTime hoy = DateTime(2026, 10, 29);
    expect(etiquetaDia(DateTime(2026, 10, 29, 8), hoy), 'Hoy');
    expect(etiquetaDia(DateTime(2026, 10, 30), hoy), 'Mañana');
    expect(etiquetaDia(DateTime(2026, 10, 28), hoy), 'Ayer');
    expect(etiquetaDia(DateTime(2026, 11, 3), hoy), 'Mar 3 nov');
    expect(etiquetaDia(null, hoy), 'Sin fecha');
  });
}
