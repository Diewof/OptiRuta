import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_viajes_por_rango_use_case.dart';
import 'package:optiruta/features/viajes/presentation/bloc/calendario_cubit.dart';
import 'package:optiruta/features/viajes/presentation/bloc/calendario_state.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

ViajeResumen _viaje({
  required String id,
  required DateTime fechaSalida,
  EstadoViaje estado = EstadoViaje.asignado,
}) {
  return ViajeResumen(
    id: id,
    remision: 'REM-$id',
    origen: 'Bogotá',
    destino: 'Cali',
    estado: estado,
    placaVehiculo: 'UFH664',
    nombreConductor: 'Camilo Rojas',
    nombreCliente: 'Distribuidora Andina',
    fechaSalidaProgramada: fechaSalida,
    fechaCreacion: fechaSalida,
  );
}

void main() {
  late _MockViajeRepository repo;

  setUp(() {
    repo = _MockViajeRepository();
  });

  test('carga el mes actual al iniciar y agrupa el día seleccionado', () async {
    final DateTime hoy = DateTime.now();
    final DateTime hoyMediodia = DateTime(hoy.year, hoy.month, hoy.day, 12);
    when(
      () => repo.listarPorRango(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer(
      (_) async => <ViajeResumen>[_viaje(id: 'v-1', fechaSalida: hoyMediodia)],
    );

    final cubit = CalendarioCubit(
      listarPorRango: ListarViajesPorRangoUseCase(repo),
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final CalendarioListo estado = cubit.state as CalendarioListo;
    expect(estado.viajesDelDia, hasLength(1));
  });

  test('irAMesSiguiente recarga con el rango del mes siguiente', () async {
    when(
      () => repo.listarPorRango(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer((_) async => const <ViajeResumen>[]);

    final cubit = CalendarioCubit(
      listarPorRango: ListarViajesPorRangoUseCase(repo),
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final DateTime mesInicial = (cubit.state as CalendarioListo).mesMostrado;
    await cubit.irAMesSiguiente();

    final DateTime mesNuevo = (cubit.state as CalendarioListo).mesMostrado;
    expect(mesNuevo, DateTime(mesInicial.year, mesInicial.month + 1));
  });

  test('seleccionarDia no dispara una nueva consulta', () async {
    when(
      () => repo.listarPorRango(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer((_) async => const <ViajeResumen>[]);

    final cubit = CalendarioCubit(
      listarPorRango: ListarViajesPorRangoUseCase(repo),
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final DateTime otroDia = DateTime.now().add(const Duration(days: 3));
    cubit.seleccionarDia(otroDia);

    final CalendarioListo estado = cubit.state as CalendarioListo;
    expect(estado.diaSeleccionado, otroDia);
    verify(
      () => repo.listarPorRango(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).called(1);
  });

  test('CalendarioError cuando falla la carga', () async {
    when(
      () => repo.listarPorRango(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenThrow(CatalogoFailure.desconocido());

    final cubit = CalendarioCubit(
      listarPorRango: ListarViajesPorRangoUseCase(repo),
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<CalendarioError>());
  });
}
