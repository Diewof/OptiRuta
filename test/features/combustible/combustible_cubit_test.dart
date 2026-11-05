import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/combustible/domain/entities/rendimiento_combustible.dart';
import 'package:optiruta/features/combustible/domain/repositories/combustible_repository.dart';
import 'package:optiruta/features/combustible/domain/usecases/combustible_use_cases.dart';
import 'package:optiruta/features/combustible/presentation/bloc/combustible_cubit.dart';
import 'package:optiruta/features/combustible/presentation/bloc/combustible_state.dart';

class _MockCombustibleRepository extends Mock
    implements CombustibleRepository {}

void main() {
  late _MockCombustibleRepository repo;

  setUp(() {
    repo = _MockCombustibleRepository();
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(DimensionCombustible.vehiculo);
  });

  CombustibleCubit crear() =>
      CombustibleCubit(obtener: ObtenerRendimientoCombustibleUseCase(repo));

  test('carga el rendimiento por vehículo y por ruta del mes', () async {
    const RendimientoCombustible fila = RendimientoCombustible(
      clave: 'TKM218',
      viajes: 3,
      km: 2400,
      galones: 300,
      kmPorGalon: 8,
      kmPorGalonPrevio: 10,
      variacionPct: -20,
      alerta: true,
    );
    when(
      () => repo.rendimiento(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        dimension: DimensionCombustible.vehiculo,
      ),
    ).thenAnswer((_) async => const <RendimientoCombustible>[fila]);
    when(
      () => repo.rendimiento(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        dimension: DimensionCombustible.ruta,
      ),
    ).thenAnswer((_) async => const <RendimientoCombustible>[]);

    final CombustibleCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final CombustibleListo estado = cubit.state as CombustibleListo;
    expect(estado.porDimension[DimensionCombustible.vehiculo], <Object>[fila]);
    expect(estado.porDimension[DimensionCombustible.ruta], isEmpty);
  });

  test('pide el mes completo, del primer al último día', () async {
    when(
      () => repo.rendimiento(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        dimension: any(named: 'dimension'),
      ),
    ).thenAnswer((_) async => const <RendimientoCombustible>[]);

    final CombustibleCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    await cubit.irAMesAnterior();

    final DateTime hoy = DateTime.now();
    final DateTime esperadoDesde = DateTime(hoy.year, hoy.month - 1);
    final DateTime esperadoHasta = DateTime(hoy.year, hoy.month, 0);
    verify(
      () => repo.rendimiento(
        desde: esperadoDesde,
        hasta: esperadoHasta,
        dimension: DimensionCombustible.vehiculo,
      ),
    ).called(1);
  });

  test('si el servidor falla emite el mensaje de dominio', () async {
    when(
      () => repo.rendimiento(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        dimension: any(named: 'dimension'),
      ),
    ).thenThrow(CatalogoFailure.sinPermiso());

    final CombustibleCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<CombustibleError>());
  });
}
