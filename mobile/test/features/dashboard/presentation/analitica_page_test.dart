import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:optiruta/features/conductores/domain/repositories/conductor_repository.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/dashboard/domain/entities/metricas.dart';
import 'package:optiruta/features/dashboard/domain/repositories/metricas_repository.dart';
import 'package:optiruta/features/dashboard/presentation/pages/analitica_page.dart';
import 'package:optiruta/features/notificaciones/domain/entities/notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/entities/tipo_notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/repositories/notificacion_repository.dart';
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

class _MockMetricasRepository extends Mock implements MetricasRepository {}

class _MockNotificacionRepository extends Mock
    implements NotificacionRepository {}

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

class _MockClienteRepository extends Mock implements ClienteRepository {}

class _MockConductorRepository extends Mock implements ConductorRepository {}

void main() {
  setUpAll(() => registerFallbackValue(DimensionMetrica.ruta));

  testWidgets('muestra los KPIs y el estado de flota con datos reales', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2600));
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

    final metricasRepo = _MockMetricasRepository();
    final notifRepo = _MockNotificacionRepository();
    when(
      () => metricasRepo.periodo(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer(
      (_) async => const MetricasPeriodo(
        viajesCerrados: 46,
        kmTotal: 18400,
        costosDirectos: 33400000,
        costoPorKm: 1815,
        viajesATiempo: 30,
        viajesMedidos: 40,
        utilizacionFlotaPct: 62.5,
      ),
    );
    when(
      () => metricasRepo.porDimension(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        dimension: any(named: 'dimension'),
      ),
    ).thenAnswer(
      (_) async => const <MetricaDimension>[
        MetricaDimension(
          clave: 'Medellín → Cali',
          viajes: 4,
          totalFlete: 40000000,
          totalCostos: 25000000,
          rentabilidad: 15000000,
          kmTotal: 1800,
          viajesATiempo: 3,
          viajesMedidos: 4,
        ),
      ],
    );
    when(
      () => notifRepo.listar(
        pagina: 0,
        tamano: any(named: 'tamano'),
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        soloNoLeidas: any(named: 'soloNoLeidas'),
      ),
    ).thenAnswer(
      (_) async => PaginaNotificaciones(
        notificaciones: <Notificacion>[
          Notificacion(
            id: 'n-1',
            tipo: TipoNotificacion.desvioRuta,
            titulo: 'Desvío de ruta',
            mensaje: 'Bogotá → Cali: el conductor se desvió.',
            leida: false,
            fechaCreacion: DateTime(2026, 10, 9),
          ),
        ],
        hayMas: false,
      ),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ClienteRepository>.value(
            value: _MockClienteRepository(),
          ),
          RepositoryProvider<ConductorRepository>.value(
            value: _MockConductorRepository(),
          ),
          RepositoryProvider<VehiculoRepository>.value(value: vehiculoRepo),
          RepositoryProvider<ViajeRepository>.value(value: viajeRepo),
          RepositoryProvider<RentabilidadRepository>.value(value: rentaRepo),
          RepositoryProvider<MetricasRepository>.value(value: metricasRepo),
          RepositoryProvider<NotificacionRepository>.value(value: notifRepo),
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
    // RF-24: costo por km; RF-26: alertas activas; RF-25: rendimiento.
    expect(find.text('Costo por km'), findsOneWidget);
    expect(find.text(r'$1.815'), findsOneWidget);
    expect(find.text('Cumplimiento'), findsOneWidget);
    expect(find.text('75,0 %'), findsOneWidget);
    expect(find.text('1 alerta activa'), findsOneWidget);
    expect(find.text('Desvío de ruta'), findsOneWidget);
    expect(find.text('Medellín → Cali'), findsOneWidget);
  });
}
