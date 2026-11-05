import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_marginal.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/rentabilidad_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart'
    show PaginaViajes, ViajeRepository;
import 'package:optiruta/features/viajes/domain/usecases/listar_historial_viajes_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/rentabilidad_marginal_use_case.dart';
import 'package:optiruta/features/viajes/presentation/bloc/historial_cubit.dart';
import 'package:optiruta/features/viajes/presentation/bloc/historial_state.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockRentabilidadRepository extends Mock
    implements RentabilidadRepository {}

ViajeResumen _viaje(String id) => ViajeResumen(
  id: id,
  remision: 'REM-$id',
  origen: 'Bogotá',
  destino: 'Cali',
  estado: EstadoViaje.cerrado,
  placaVehiculo: 'UFH664',
  nombreConductor: 'Camilo Rojas',
  nombreCliente: 'Distribuidora Andina',
  fechaCreacion: DateTime.now(),
);

void main() {
  late _MockViajeRepository viajeRepo;
  late _MockRentabilidadRepository rentaRepo;

  setUp(() {
    viajeRepo = _MockViajeRepository();
    rentaRepo = _MockRentabilidadRepository();
  });

  HistorialCubit crear() => HistorialCubit(
    listar: ListarHistorialViajesUseCase(viajeRepo),
    rentabilidadMarginal: RentabilidadMarginalUseCase(rentaRepo),
  );

  test('carga la primera página y luego resuelve la rentabilidad', () async {
    when(
      () =>
          viajeRepo.listarHistorial(pagina: 0, tamano: 20, filtroEstado: null),
    ).thenAnswer(
      (_) async =>
          PaginaViajes(viajes: <ViajeResumen>[_viaje('v-1')], hayMas: false),
    );
    when(() => rentaRepo.marginal('v-1')).thenAnswer(
      (_) async => const RentabilidadMarginal(
        valorFlete: 2000000,
        costosTotales: 800000,
        rentabilidad: 1200000,
      ),
    );

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final HistorialListo estado = cubit.state as HistorialListo;
    expect(estado.viajes.first.rentabilidad, 1200000);
  });

  test('cargarPrimeraPagina con filtro pasa el estado a la RPC', () async {
    when(
      () =>
          viajeRepo.listarHistorial(pagina: 0, tamano: 20, filtroEstado: null),
    ).thenAnswer(
      (_) async => const PaginaViajes(viajes: <ViajeResumen>[], hayMas: false),
    );
    when(
      () => viajeRepo.listarHistorial(
        pagina: 0,
        tamano: 20,
        filtroEstado: EstadoViaje.cerrado,
      ),
    ).thenAnswer(
      (_) async => const PaginaViajes(viajes: <ViajeResumen>[], hayMas: false),
    );

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.cargarPrimeraPagina(filtroEstado: EstadoViaje.cerrado);

    final HistorialListo estado = cubit.state as HistorialListo;
    expect(estado.filtroEstado, EstadoViaje.cerrado);
    verify(
      () => viajeRepo.listarHistorial(
        pagina: 0,
        tamano: 20,
        filtroEstado: EstadoViaje.cerrado,
      ),
    ).called(1);
  });

  test('HistorialError cuando falla la carga', () async {
    when(
      () =>
          viajeRepo.listarHistorial(pagina: 0, tamano: 20, filtroEstado: null),
    ).thenThrow(CatalogoFailure.desconocido());

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<HistorialError>());
  });
}
