import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/data/datasources/rentabilidad_remote_data_source.dart';
import 'package:optiruta/features/viajes/data/repositories/rentabilidad_repository_impl.dart';
import 'package:optiruta/features/viajes/data/models/rentabilidad_model.dart';
import 'package:optiruta/features/viajes/domain/entities/categoria_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_consolidada.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_marginal.dart';

class _MockRemote extends Mock implements RentabilidadRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late RentabilidadRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = RentabilidadRepositoryImpl(remote);
  });

  test('marginal: mapea la fila a RentabilidadMarginal', () async {
    when(() => remote.marginal('v-1')).thenAnswer(
      (_) async => <String, dynamic>{
        'valor_flete': 9200000,
        'costos_totales': 3400000,
        'rentabilidad': 5800000,
      },
    );

    final RentabilidadMarginal r = await repo.marginal('v-1');

    expect(r.valorFlete, 9200000);
    expect(r.rentabilidad, 5800000);
  });

  test('consolidada: envía solo la fecha (sin hora) y mapea la fila', () async {
    when(
      () => remote.consolidada(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer(
      (_) async => <String, dynamic>{
        'total_flete': 61200000,
        'total_costos_directos': 38400000,
        'mantenimiento_amortizado': 3000000,
        'sueldo_fijo_prorrateado': 2000000,
        'rentabilidad_consolidada': 17800000,
        'viajes_incluidos': 46,
      },
    );

    final DateTime desde = DateTime(2026, 9);
    final DateTime hasta = DateTime(2026, 9, 30);
    final RentabilidadConsolidada r = await repo.consolidada(
      desde: desde,
      hasta: hasta,
    );

    expect(r.viajesIncluidos, 46);
    expect(r.totalCostos, 38400000 + 3000000 + 2000000);
  });

  test(
    'consolidada: mapea el desglose por categoría y ignora las desconocidas',
    () {
      final RentabilidadConsolidada r = RentabilidadModel.consolidadaDesdeFila(
        <String, dynamic>{
          'total_flete': 1000000,
          'total_costos_directos': 400000,
          'mantenimiento_amortizado': 80000,
          'sueldo_fijo_prorrateado': 0,
          'rentabilidad_consolidada': 520000,
          'viajes_incluidos': 1,
          'costos_por_categoria': <String, dynamic>{
            'ACPM': 250000,
            'PEAJE': 50.5,
            'CATEGORIA_NUEVA': 1,
          },
        },
      );

      expect(r.costosPorCategoria, <CategoriaCosto, double>{
        CategoriaCosto.acpm: 250000,
        CategoriaCosto.peaje: 50.5,
      });
    },
  );

  test('consolidada: sin desglose (RPC antigua) queda vacío', () {
    final RentabilidadConsolidada r = RentabilidadModel.consolidadaDesdeFila(
      <String, dynamic>{
        'total_flete': 0,
        'total_costos_directos': 0,
        'mantenimiento_amortizado': 0,
        'sueldo_fijo_prorrateado': 0,
        'rentabilidad_consolidada': 0,
        'viajes_incluidos': 0,
      },
    );

    expect(r.costosPorCategoria, isEmpty);
  });
}
