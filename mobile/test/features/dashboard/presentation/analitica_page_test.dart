import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/dashboard/presentation/pages/analitica_page.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/vehiculo_repository.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_consolidada.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/rentabilidad_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';

class _MockVehiculoRepository extends Mock implements VehiculoRepository {}

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockRentabilidadRepository extends Mock
    implements RentabilidadRepository {}

const Usuario _admin = Usuario(
  id: 'u-1',
  nombre: 'Ana Admin',
  rol: RolUsuario.administrador,
  activo: true,
);

String _mes() {
  const List<String> m = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return m[DateTime.now().month - 1];
}

void main() {
  testWidgets('muestra los KPIs y el estado de flota con datos reales', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vehiculoRepo = _MockVehiculoRepository();
    final viajeRepo = _MockViajeRepository();
    final rentaRepo = _MockRentabilidadRepository();

    when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaVehiculos(
        vehiculos: <Vehiculo>[
          Vehiculo(
            id: 'v-1',
            placa: 'UFH664',
            tipo: TipoVehiculo.dobleTroque,
            capacidadCarga: 17,
            rendimientoKmGalon: 9,
            activo: true,
          ),
        ],
        hayMas: false,
      ),
    );
    when(() => viajeRepo.listarActivos()).thenAnswer(
      (_) async => <ViajeResumen>[
        ViajeResumen(
          id: 'v-1',
          remision: 'REM-1',
          origen: 'Bogotá',
          destino: 'Cali',
          estado: EstadoViaje.enCurso,
          placaVehiculo: 'UFH664',
          nombreConductor: 'Camilo Rojas',
          nombreCliente: 'Distribuidora Andina',
          fechaCreacion: DateTime.now(),
        ),
      ],
    );
    when(
      () => rentaRepo.consolidada(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer(
      (_) async => const RentabilidadConsolidada(
        totalFlete: 61200000,
        totalCostosDirectos: 33400000,
        mantenimientoAmortizado: 3000000,
        sueldoFijoProrrateado: 2000000,
        rentabilidadConsolidada: 22800000,
        viajesIncluidos: 46,
      ),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<VehiculoRepository>.value(value: vehiculoRepo),
          RepositoryProvider<ViajeRepository>.value(value: viajeRepo),
          RepositoryProvider<RentabilidadRepository>.value(value: rentaRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AnaliticaPage(usuario: _admin),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rentabilidad consolidada · ${_mes()}'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget); // base del cálculo
    expect(find.text(r'$ 22,8 M'), findsOneWidget); // cifra clave
    expect(find.text('Margen 37,3 %'), findsOneWidget);
    expect(find.text('46'), findsOneWidget); // viajes cerrados
    expect(find.text('Flota en ruta'), findsOneWidget);
    expect(find.text('Viajes en curso'), findsNWidgets(2)); // KPI + sección
    expect(find.text('Bogotá → Cali'), findsOneWidget);
    expect(find.text('Desglose de costos'), findsOneWidget);
  });
}
