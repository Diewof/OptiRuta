import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/esperas/domain/entities/espera_cliente.dart';
import 'package:optiruta/features/esperas/domain/repositories/espera_repository.dart';
import 'package:optiruta/features/esperas/domain/usecases/obtener_esperas_use_case.dart';
import 'package:optiruta/features/esperas/presentation/bloc/esperas_cubit.dart';
import 'package:optiruta/features/esperas/presentation/bloc/esperas_state.dart';

class _MockEsperaRepository extends Mock implements EsperaRepository {}

void main() {
  late _MockEsperaRepository repo;

  setUp(() {
    repo = _MockEsperaRepository();
    registerFallbackValue(DateTime(2026));
  });

  EsperasCubit crear() =>
      EsperasCubit(obtener: ObtenerEsperasPorClienteUseCase(repo));

  test('carga las esperas por cliente del mes actual', () async {
    const EsperaCliente cliente = EsperaCliente(
      cliente: 'Cliente X',
      viajes: 4,
      carguesMedidos: 3,
      esperaCargueH: 4,
      descarguesMedidos: 2,
      esperaDescargueH: 2,
      esperaTotalH: 16,
      esperaMaximaH: 6,
      viajesSobreUmbral: 2,
    );
    when(
      () => repo.porCliente(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer((_) async => const <EsperaCliente>[cliente]);

    final EsperasCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final EsperasListo estado = cubit.state as EsperasListo;
    expect(estado.clientes, <EsperaCliente>[cliente]);
    final DateTime hoy = DateTime.now();
    expect(estado.mes, DateTime(hoy.year, hoy.month));
  });

  test('si el servidor falla emite el mensaje de dominio', () async {
    when(
      () => repo.porCliente(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenThrow(CatalogoFailure.sinConexion());

    final EsperasCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<EsperasError>());
  });
}
