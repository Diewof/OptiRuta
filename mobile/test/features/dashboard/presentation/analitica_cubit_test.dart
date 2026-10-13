import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/dashboard/domain/entities/metricas.dart';
import 'package:optiruta/features/reportes/domain/entities/reporte.dart';
import 'package:optiruta/features/dashboard/domain/repositories/metricas_repository.dart';
import 'package:optiruta/features/dashboard/domain/usecases/metricas_use_cases.dart';
import 'package:optiruta/features/notificaciones/domain/entities/notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/entities/tipo_notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/repositories/notificacion_repository.dart';
import 'package:optiruta/features/notificaciones/domain/usecases/listar_notificaciones_use_case.dart';
import 'package:optiruta/features/dashboard/presentation/bloc/analitica_cubit.dart';
import 'package:optiruta/features/dashboard/presentation/bloc/analitica_state.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/vehiculo_repository.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_consolidada.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/rentabilidad_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_viajes_activos_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/rentabilidad_consolidada_use_case.dart';

class _MockVehiculoRepository extends Mock implements VehiculoRepository {}

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockRentabilidadRepository extends Mock
    implements RentabilidadRepository {}

Vehiculo _vehiculo(String placa, {bool activo = true}) => Vehiculo(
  id: placa,
  placa: placa,
  tipo: TipoVehiculo.dobleTroque,
  capacidadCarga: 17,
  rendimientoKmGalon: 9,
  activo: activo,
);

ViajeResumen _viajeActivo(String placa) => ViajeResumen(
  id: 'v-$placa',
  remision: 'REM-$placa',
  origen: 'Bogotá',
  destino: 'Cali',
  estado: EstadoViaje.enCurso,
  placaVehiculo: placa,
  nombreConductor: 'Conductor',
  nombreCliente: 'Cliente',
  fechaCreacion: DateTime.now(),
);

const RentabilidadConsolidada _rentabilidad = RentabilidadConsolidada(
  totalFlete: 61200000,
  totalCostosDirectos: 33400000,
  mantenimientoAmortizado: 3000000,
  sueldoFijoProrrateado: 2000000,
  rentabilidadConsolidada: 22800000,
  viajesIncluidos: 46,
);

class _MockMetricasRepository extends Mock implements MetricasRepository {}

class _MockNotificacionRepository extends Mock
    implements NotificacionRepository {}

const MetricasPeriodo _metricas = MetricasPeriodo(
  viajesCerrados: 46,
  kmTotal: 18400,
  costosDirectos: 33400000,
  costoPorKm: 1815,
  viajesATiempo: 30,
  viajesMedidos: 40,
  utilizacionFlotaPct: 62.5,
);

final Notificacion _alerta = Notificacion(
  id: 'n-1',
  tipo: TipoNotificacion.retraso,
  titulo: 'Retraso en viaje',
  mensaje: 'Bogotá → Cali lleva retraso.',
  leida: false,
  fechaCreacion: DateTime(2026, 10, 9),
);

void stubMetricas(
  MetricasRepository metricasRepo,
  NotificacionRepository notifRepo,
) {
  when(
    () => metricasRepo.periodo(
      desde: any(named: 'desde'),
      hasta: any(named: 'hasta'),
      clienteId: any(named: 'clienteId'),
      conductorId: any(named: 'conductorId'),
      vehiculoId: any(named: 'vehiculoId'),
      ruta: any(named: 'ruta'),
    ),
  ).thenAnswer((_) async => _metricas);
  when(
    () => metricasRepo.porDimension(
      desde: any(named: 'desde'),
      hasta: any(named: 'hasta'),
      dimension: any(named: 'dimension'),
      clienteId: any(named: 'clienteId'),
      conductorId: any(named: 'conductorId'),
      vehiculoId: any(named: 'vehiculoId'),
      ruta: any(named: 'ruta'),
    ),
  ).thenAnswer(
    (_) async => const <MetricaDimension>[
      MetricaDimension(
        clave: 'Bogotá → Cali',
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
      notificaciones: <Notificacion>[_alerta],
      hayMas: false,
    ),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(DimensionMetrica.ruta));

  late _MockVehiculoRepository vehiculoRepo;
  late _MockViajeRepository viajeRepo;
  late _MockRentabilidadRepository rentaRepo;
  late _MockMetricasRepository metricasRepo;
  late _MockNotificacionRepository notifRepo;

  setUp(() {
    vehiculoRepo = _MockVehiculoRepository();
    viajeRepo = _MockViajeRepository();
    rentaRepo = _MockRentabilidadRepository();
    metricasRepo = _MockMetricasRepository();
    notifRepo = _MockNotificacionRepository();
    stubMetricas(metricasRepo, notifRepo);
  });

  AnaliticaCubit crear() => AnaliticaCubit(
    rentabilidadConsolidada: RentabilidadConsolidadaUseCase(rentaRepo),
    vehiculoRepository: vehiculoRepo,
    listarViajesActivos: ListarViajesActivosUseCase(viajeRepo),
    metricasPeriodo: ObtenerMetricasPeriodoUseCase(metricasRepo),
    metricasPorDimension: ObtenerMetricasPorDimensionUseCase(metricasRepo),
    listarNotificaciones: ListarNotificacionesUseCase(notifRepo),
    cargarOpciones: () async => const OpcionesReporte(),
  );

  test('cruza vehículos activos con viajes en curso por placa', () async {
    when(
      () => rentaRepo.consolidada(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer((_) async => _rentabilidad);
    when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => PaginaVehiculos(
        vehiculos: <Vehiculo>[
          _vehiculo('UFH664'),
          _vehiculo('TKM218'),
          _vehiculo('SXP507', activo: false),
        ],
        hayMas: false,
      ),
    );
    when(() => viajeRepo.listarActivos())
        .thenAnswer((_) async => <ViajeResumen>[_viajeActivo('UFH664')]);

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final AnaliticaListo estado = cubit.state as AnaliticaListo;
    expect(estado.totalVehiculosActivos, 2);
    expect(estado.vehiculosEnRuta, 1);
    expect(estado.vehiculosDisponibles, 1);
    expect(estado.rentabilidad, _rentabilidad);
  });

  test(
    'carga costo por km, rendimiento por dimensión y alertas sin leer',
    () async {
      when(
        () => rentaRepo.consolidada(
          desde: any(named: 'desde'),
          hasta: any(named: 'hasta'),
        ),
      ).thenAnswer((_) async => _rentabilidad);
      when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
        (_) async => const PaginaVehiculos(vehiculos: [], hayMas: false),
      );
      when(() => viajeRepo.listarActivos())
          .thenAnswer((_) async => const <ViajeResumen>[]);
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
          notificaciones: <Notificacion>[_alerta],
          hayMas: false,
        ),
      );

      final cubit = crear();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      final AnaliticaListo estado = cubit.state as AnaliticaListo;
      expect(estado.metricas.costoPorKm, 1815);
      expect(estado.metricas.cumplimientoPct, 75);
      expect(estado.rendimiento.keys, DimensionMetrica.values);
      expect(
        estado.rendimiento[DimensionMetrica.ruta]!.single.clave,
        'Bogotá → Cali',
      );
      expect(estado.alertas.map((n) => n.id), <String>['n-1']);
      // Solo pendientes y solo del mes que se ve (el actual, completo).
      final DateTime hoy = DateTime.now();
      final List<dynamic> args = verify(
        () => notifRepo.listar(
          pagina: 0,
          tamano: any(named: 'tamano'),
          desde: captureAny(named: 'desde'),
          hasta: captureAny(named: 'hasta'),
          soloNoLeidas: captureAny(named: 'soloNoLeidas'),
        ),
      ).captured;
      expect(
        args,
        containsAll(<Object>[
          DateTime(hoy.year, hoy.month),
          DateTime(hoy.year, hoy.month + 1),
          true,
        ]),
      );
    },
  );

  test('irAMesSiguiente vuelve a consultar el mes siguiente', () async {
    when(
      () => rentaRepo.consolidada(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer((_) async => _rentabilidad);
    when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaVehiculos(vehiculos: [], hayMas: false),
    );
    when(() => viajeRepo.listarActivos())
        .thenAnswer((_) async => const <ViajeResumen>[]);

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final DateTime mesInicial = (cubit.state as AnaliticaListo).mes;
    await cubit.irAMesSiguiente();

    final DateTime mesNuevo = (cubit.state as AnaliticaListo).mes;
    expect(mesNuevo, DateTime(mesInicial.year, mesInicial.month + 1));
  });

  test('AnaliticaError cuando falla la carga', () async {
    when(
      () => rentaRepo.consolidada(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenThrow(CatalogoFailure.desconocido());
    when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaVehiculos(vehiculos: [], hayMas: false),
    );
    when(() => viajeRepo.listarActivos())
        .thenAnswer((_) async => const <ViajeResumen>[]);

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<AnaliticaError>());
  });

  test(
    'aplicarFiltro envía cliente, vehículo y ruta a Resumen y métricas',
    () async {
      when(
        () => rentaRepo.consolidada(
          desde: any(named: 'desde'),
          hasta: any(named: 'hasta'),
          clienteId: any(named: 'clienteId'),
          conductorId: any(named: 'conductorId'),
          vehiculoId: any(named: 'vehiculoId'),
          ruta: any(named: 'ruta'),
        ),
      ).thenAnswer((_) async => _rentabilidad);
      when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
        (_) async => const PaginaVehiculos(vehiculos: [], hayMas: false),
      );
      when(() => viajeRepo.listarActivos())
          .thenAnswer((_) async => const <ViajeResumen>[]);

      final cubit = crear();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      await cubit.aplicarFiltro(
        FiltroReporte(
          desde: DateTime(2026, 9),
          hasta: DateTime(2026, 9, 15),
          clienteId: 'c-1',
          vehiculoId: 'veh-1',
          ruta: 'Cali',
        ),
      );

      verify(
        () => rentaRepo.consolidada(
          desde: DateTime(2026, 9),
          hasta: DateTime(2026, 9, 15),
          clienteId: 'c-1',
          conductorId: null,
          vehiculoId: 'veh-1',
          ruta: 'Cali',
        ),
      ).called(1);
      verify(
        () => metricasRepo.periodo(
          desde: DateTime(2026, 9),
          hasta: DateTime(2026, 9, 15),
          clienteId: 'c-1',
          conductorId: null,
          vehiculoId: 'veh-1',
          ruta: 'Cali',
        ),
      ).called(1);
      final AnaliticaListo estado = cubit.state as AnaliticaListo;
      expect(estado.filtro.clienteId, 'c-1');

      // Cambiar de mes conserva los filtros de cliente, vehículo y ruta.
      await cubit.irAMesAnterior();
      expect((cubit.state as AnaliticaListo).filtro.ruta, 'Cali');
      expect((cubit.state as AnaliticaListo).mes, DateTime(2026, 8));
    },
  );
}
