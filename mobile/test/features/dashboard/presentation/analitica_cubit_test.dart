import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
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

void main() {
  late _MockVehiculoRepository vehiculoRepo;
  late _MockViajeRepository viajeRepo;
  late _MockRentabilidadRepository rentaRepo;

  setUp(() {
    vehiculoRepo = _MockVehiculoRepository();
    viajeRepo = _MockViajeRepository();
    rentaRepo = _MockRentabilidadRepository();
  });

  AnaliticaCubit crear() => AnaliticaCubit(
    rentabilidadConsolidada: RentabilidadConsolidadaUseCase(rentaRepo),
    vehiculoRepository: vehiculoRepo,
    listarViajesActivos: ListarViajesActivosUseCase(viajeRepo),
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
}
