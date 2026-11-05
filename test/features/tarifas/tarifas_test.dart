import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/tarifas/data/datasources/tarifa_combustible_remote_data_source.dart';
import 'package:optiruta/features/tarifas/data/repositories/tarifa_combustible_repository_impl.dart';
import 'package:optiruta/features/tarifas/domain/entities/tarifa_combustible.dart';
import 'package:optiruta/features/tarifas/domain/repositories/tarifa_combustible_repository.dart';
import 'package:optiruta/features/tarifas/domain/usecases/tarifa_use_cases.dart';
import 'package:optiruta/features/tarifas/presentation/bloc/tarifa_list_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemote extends Mock implements TarifaCombustibleRemoteDataSource {}

class _MockRepo extends Mock implements TarifaCombustibleRepository {}

Map<String, dynamic> _fila(
  String id,
  String ciudad,
  num precio,
  String desde,
) => <String, dynamic>{
  'id': id,
  'ciudad': ciudad,
  'precio_galon': precio,
  'fecha_vigencia_desde': desde,
  'fuente': 'MANUAL',
};

void main() {
  group('TarifaCombustibleRepositoryImpl', () {
    late _MockRemote remote;
    late TarifaCombustibleRepositoryImpl repo;

    setUp(() {
      remote = _MockRemote();
      repo = TarifaCombustibleRepositoryImpl(remote);
    });

    test('registrar: envía fecha sin hora y fuente MANUAL', () async {
      when(() => remote.crear(any()))
          .thenAnswer((_) async => _fila('t-1', 'Bogotá', 9800, '2026-10-01'));

      final TarifaCombustible t = await repo.registrar(
        ciudad: 'Bogotá',
        precioGalon: 9800,
        fechaVigenciaDesde: DateTime(2026, 10),
      );

      final Map<String, dynamic> enviada =
          verify(() => remote.crear(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(enviada['fecha_vigencia_desde'], '2026-10-01');
      expect(enviada['fuente'], 'MANUAL');
      expect(t.precioGalon, 9800);
      expect(t.automatica, isFalse);
    });

    test('registrar: unicidad ciudad+fecha da un mensaje accionable', () async {
      when(() => remote.crear(any()))
          .thenThrow(const PostgrestException(message: 'dup', code: '23505'));

      expect(
        () => repo.registrar(
          ciudad: 'Bogotá',
          precioGalon: 9800,
          fechaVigenciaDesde: DateTime(2026, 10),
        ),
        throwsA(
          isA<CatalogoFailure>()
              .having((f) => f.codigo, 'codigo', CatalogoErrorCodigo.yaExiste)
              .having((f) => f.mensaje, 'mensaje', contains('Edita su precio')),
        ),
      );
    });
  });

  group('casos de uso', () {
    late _MockRepo repo;

    setUp(() => repo = _MockRepo());

    test('RegistrarTarifaUseCase rechaza ciudad vacía y precio <= 0', () {
      final RegistrarTarifaUseCase uc = RegistrarTarifaUseCase(repo);
      expect(
        () => uc(
          ciudad: '  ',
          precioGalon: 9000,
          fechaVigenciaDesde: DateTime(2026),
        ),
        throwsArgumentError,
      );
      expect(
        () => uc(
          ciudad: 'Cali',
          precioGalon: 0,
          fechaVigenciaDesde: DateTime(2026),
        ),
        throwsArgumentError,
      );
      verifyNever(
        () => repo.registrar(
          ciudad: any(named: 'ciudad'),
          precioGalon: any(named: 'precioGalon'),
          fechaVigenciaDesde: any(named: 'fechaVigenciaDesde'),
        ),
      );
    });
  });

  group('TarifaListCubit', () {
    test('vigentes: toma por ciudad la más reciente que ya empezó', () {
      final TarifaListListo estado = TarifaListListo(<TarifaCombustible>[
        TarifaCombustible(
          id: 'futura',
          ciudad: 'Bogotá',
          precioGalon: 12000,
          fechaVigenciaDesde: DateTime(2026, 12),
          automatica: false,
        ),
        TarifaCombustible(
          id: 'actual',
          ciudad: 'Bogotá',
          precioGalon: 10000,
          fechaVigenciaDesde: DateTime(2026, 10),
          automatica: false,
        ),
        TarifaCombustible(
          id: 'vieja',
          ciudad: 'bogotá',
          precioGalon: 9000,
          fechaVigenciaDesde: DateTime(2026, 8),
          automatica: true,
        ),
      ]);

      final List<TarifaCombustible> v = estado.vigentes(DateTime(2026, 10, 10));

      expect(v.map((t) => t.id), <String>['actual']);
    });

    test('registrar y recargar la lista', () async {
      final _MockRepo repo = _MockRepo();
      final List<TarifaCombustible> lista = <TarifaCombustible>[];
      when(() => repo.listar()).thenAnswer((_) async => List.of(lista));
      when(
        () => repo.registrar(
          ciudad: 'Cali',
          precioGalon: 9500,
          fechaVigenciaDesde: DateTime(2026, 10),
        ),
      ).thenAnswer((_) async {
        final TarifaCombustible t = TarifaCombustible(
          id: 't-1',
          ciudad: 'Cali',
          precioGalon: 9500,
          fechaVigenciaDesde: DateTime(2026, 10),
          automatica: false,
        );
        lista.add(t);
        return t;
      });

      final TarifaListCubit cubit = TarifaListCubit(
        listar: ListarTarifasUseCase(repo),
        registrar: RegistrarTarifaUseCase(repo),
        actualizarPrecio: ActualizarPrecioTarifaUseCase(repo),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as TarifaListListo).tarifas, isEmpty);

      await cubit.registrar(
        ciudad: 'Cali',
        precioGalon: 9500,
        fechaVigenciaDesde: DateTime(2026, 10),
      );

      expect((cubit.state as TarifaListListo).tarifas, hasLength(1));
    });
  });
}
