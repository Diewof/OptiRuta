import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/presentation/pages/calendario_page.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

const Usuario _admin = Usuario(
  id: 'u-1',
  nombre: 'Ana Admin',
  rol: RolUsuario.administrador,
  activo: true,
);

void main() {
  // El grid + la lista del día exceden los 600px por defecto del banco de
  // pruebas; sin más alto, el contenido bajo la línea de scroll no se
  // construye (SliverList solo materializa lo que cae en el viewport +
  // cacheExtent) y los finders no lo encuentran aunque sí exista en el
  // estado.
  Future<void> agrandarSuperficie(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('muestra el mes actual y los viajes del día seleccionado', (
    WidgetTester tester,
  ) async {
    await agrandarSuperficie(tester);
    final repo = _MockViajeRepository();
    final DateTime hoy = DateTime.now();
    when(
      () => repo.listarPorRango(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer(
      (_) async => <ViajeResumen>[
        ViajeResumen(
          id: 'v-1',
          remision: 'REM-1',
          origen: 'Bogotá',
          destino: 'Barranquilla',
          estado: EstadoViaje.asignado,
          placaVehiculo: 'UFH664',
          nombreConductor: 'Camilo Rojas',
          nombreCliente: 'Distribuidora Andina',
          fechaSalidaProgramada: DateTime(hoy.year, hoy.month, hoy.day, 6),
          fechaCreacion: hoy,
        ),
      ],
    );

    await tester.pumpWidget(
      RepositoryProvider<ViajeRepository>.value(
        value: repo,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CalendarioPage(usuario: _admin),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calendario'), findsOneWidget);
    expect(find.textContaining('Bogotá → Barranquilla'), findsOneWidget);
    expect(find.text('Agendar viaje'), findsOneWidget);
    expect(find.text('1 viaje'), findsOneWidget);
  });

  testWidgets('muestra estado vacío cuando el día no tiene viajes', (
    WidgetTester tester,
  ) async {
    await agrandarSuperficie(tester);
    final repo = _MockViajeRepository();
    when(
      () => repo.listarPorRango(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer((_) async => const <ViajeResumen>[]);

    await tester.pumpWidget(
      RepositoryProvider<ViajeRepository>.value(
        value: repo,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CalendarioPage(usuario: _admin),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No hay viajes programados para este día.'),
      findsOneWidget,
    );
  });
}
