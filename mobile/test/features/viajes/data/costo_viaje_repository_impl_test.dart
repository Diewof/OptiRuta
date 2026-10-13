import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/data/datasources/costo_viaje_remote_data_source.dart';
import 'package:optiruta/features/viajes/data/repositories/costo_viaje_repository_impl.dart';
import 'package:optiruta/features/viajes/domain/entities/categoria_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/costo_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/fuente_costo.dart';

class _MockRemote extends Mock implements CostoViajeRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late CostoViajeRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = CostoViajeRepositoryImpl(remote);
  });

  test('listarPorViaje: mapea categoría, estimado, real y fuente', () async {
    when(() => remote.listarPorViaje('v-1')).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'c-1',
          'viaje_id': 'v-1',
          'categoria': 'ACPM',
          'valor_estimado': 1840000,
          'valor_real': null,
          'fuente': 'AUTOMATICO',
        },
      ],
    );

    final List<CostoViaje> costos = await repo.listarPorViaje('v-1');

    expect(costos, hasLength(1));
    expect(costos.first.categoria, CategoriaCosto.acpm);
    expect(costos.first.fuente, FuenteCosto.automatico);
    expect(costos.first.valorReal, isNull);
  });

  test(
    'actualizarValorReal: envía el valor y mapea la fila devuelta',
    () async {
      when(() => remote.actualizarValorReal(costoId: 'c-1', valorReal: 1910000))
          .thenAnswer(
            (_) async => <String, dynamic>{
              'id': 'c-1',
              'viaje_id': 'v-1',
              'categoria': 'ACPM',
              'valor_estimado': 1840000,
              'valor_real': 1910000,
              'fuente': 'AUTOMATICO',
            },
          );

      final CostoViaje costo = await repo.actualizarValorReal(
        costoId: 'c-1',
        valorReal: 1910000,
      );

      expect(costo.valorReal, 1910000);
    },
  );

  test(
    'agregarOtro: envía estimado 0 y real, y mapea la descripción',
    () async {
      when(
        () => remote.agregarOtro(
          viajeId: 'v-1',
          descripcion: 'Grúa',
          valorEstimado: 0,
          valorReal: 350000,
        ),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'c-9',
          'viaje_id': 'v-1',
          'categoria': 'OTRO',
          'valor_estimado': 0,
          'valor_real': 350000,
          'fuente': 'MANUAL',
          'descripcion': 'Grúa',
        },
      );

      final CostoViaje c = await repo.agregarOtro(
        viajeId: 'v-1',
        descripcion: 'Grúa',
        valorReal: 350000,
      );

      expect(c.categoria, CategoriaCosto.otro);
      expect(c.descripcion, 'Grúa');
      expect(c.etiqueta, 'Grúa');
      expect(c.valorReal, 350000);
    },
  );
}
