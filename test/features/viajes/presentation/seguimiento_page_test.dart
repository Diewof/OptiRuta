import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/hito.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/hito_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/rentabilidad_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/presentation/pages/seguimiento_page.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockHitoRepository extends Mock implements HitoRepository {}

class _MockRentabilidadRepository extends Mock
    implements RentabilidadRepository {}

const Usuario _admin = Usuario(
  id: 'u-1',
  nombre: 'Ana Admin',
  rol: RolUsuario.administrador,
  activo: true,
);

ViajeResumen _viaje() => ViajeResumen(
  id: 'v-1',
  remision: 'REM-1',
  origen: 'Bogotá',
  destino: 'Barranquilla',
  estado: EstadoViaje.enCurso,
  placaVehiculo: 'TKM218',
  nombreConductor: 'Luis Herrera',
  nombreCliente: 'Distribuidora Andina',
  fechaCreacion: DateTime.now(),
);

void main() {
  testWidgets('muestra el viaje activo con su stepper de hitos', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viajeRepo = _MockViajeRepository();
    final hitoRepo = _MockHitoRepository();
    final rentaRepo = _MockRentabilidadRepository();

    when(() => viajeRepo.listarActivos())
        .thenAnswer((_) async => <ViajeResumen>[_viaje()]);
    when(() => hitoRepo.listarPorViaje('v-1'))
        .thenAnswer((_) async => const <Hito>[]);
    when(
      () => viajeRepo.listarHistorial(
        pagina: any(named: 'pagina'),
        tamano: any(named: 'tamano'),
        filtroEstado: any(named: 'filtroEstado'),
      ),
    ).thenAnswer(
      (_) async => const PaginaViajes(viajes: <ViajeResumen>[], hayMas: false),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ViajeRepository>.value(value: viajeRepo),
          RepositoryProvider<HitoRepository>.value(value: hitoRepo),
          RepositoryProvider<RentabilidadRepository>.value(value: rentaRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SeguimientoPage(usuario: _admin),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seguimiento'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget); // solo el badge
    expect(find.text('Historial'), findsOneWidget);
    expect(find.textContaining('Bogotá → Barranquilla'), findsOneWidget);
    expect(find.text('Con retraso'), findsNothing);
    expect(find.text('A tiempo'), findsNothing); // solo se señala el retraso
    expect(find.text('Salida'), findsOneWidget);
    expect(find.text('Destino'), findsOneWidget);
  });

  testWidgets('la sección Historial muestra el estado vacío', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viajeRepo = _MockViajeRepository();
    final hitoRepo = _MockHitoRepository();
    final rentaRepo = _MockRentabilidadRepository();

    when(() => viajeRepo.listarActivos())
        .thenAnswer((_) async => const <ViajeResumen>[]);
    when(
      () => viajeRepo.listarHistorial(
        pagina: any(named: 'pagina'),
        tamano: any(named: 'tamano'),
        filtroEstado: any(named: 'filtroEstado'),
      ),
    ).thenAnswer(
      (_) async => const PaginaViajes(viajes: <ViajeResumen>[], hayMas: false),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ViajeRepository>.value(value: viajeRepo),
          RepositoryProvider<HitoRepository>.value(value: hitoRepo),
          RepositoryProvider<RentabilidadRepository>.value(value: rentaRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HistorialPage(usuario: _admin),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin historial'), findsOneWidget);
  });
}
