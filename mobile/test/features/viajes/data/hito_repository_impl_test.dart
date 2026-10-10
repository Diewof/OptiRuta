import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/data/datasources/hito_remote_data_source.dart';
import 'package:optiruta/features/viajes/data/repositories/hito_repository_impl.dart';
import 'package:optiruta/features/viajes/domain/entities/hito.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_hito.dart';

class _MockRemote extends Mock implements HitoRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late HitoRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = HitoRepositoryImpl(remote);
  });

  test('listarPorViaje: mapea las filas a la entidad Hito', () async {
    when(() => remote.listarPorViaje('v-1')).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'h-1',
          'viaje_id': 'v-1',
          'tipo': 'SALIDA',
          'fecha_hora': '2026-09-25T06:00:00Z',
        },
      ],
    );

    final List<Hito> hitos = await repo.listarPorViaje('v-1');

    expect(hitos, hasLength(1));
    expect(hitos.first.tipo, TipoHito.salida);
  });

  test(
    'registrar: envía el código del tipo y mapea la fila devuelta',
    () async {
      final DateTime fechaHora = DateTime.utc(2026, 9, 25, 6);
      when(
        () => remote.registrar(
          viajeId: 'v-1',
          tipo: 'SALIDA',
          fechaHora: fechaHora,
        ),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'h-2',
          'viaje_id': 'v-1',
          'tipo': 'SALIDA',
          'fecha_hora': fechaHora.toIso8601String(),
        },
      );

      final Hito hito = await repo.registrar(
        viajeId: 'v-1',
        tipo: TipoHito.salida,
        fechaHora: fechaHora,
      );

      expect(hito.id, 'h-2');
      expect(hito.tipo, TipoHito.salida);
    },
  );
}
