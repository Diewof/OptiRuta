import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/data/datasources/ajuste_viaje_remote_data_source.dart';
import 'package:optiruta/features/viajes/data/repositories/ajuste_viaje_repository_impl.dart';
import 'package:optiruta/features/viajes/domain/entities/ajuste_viaje.dart';

class _MockRemote extends Mock implements AjusteViajeRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late AjusteViajeRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = AjusteViajeRepositoryImpl(remote);
  });

  test('listarPorViaje mapea las filas a AjusteViaje', () async {
    when(() => remote.listarPorViaje('v-1')).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'a-1',
          'viaje_id': 'v-1',
          'motivo': 'El recibo llegó con otro valor',
          'campo_modificado': 'ACPM',
          'valor_anterior': '3210000',
          'valor_nuevo': '3300000',
          'fecha': '2026-10-08T15:00:00Z',
        },
      ],
    );

    final List<AjusteViaje> ajustes = await repo.listarPorViaje('v-1');

    expect(ajustes.single.motivo, 'El recibo llegó con otro valor');
    expect(ajustes.single.campoModificado, 'ACPM');
    expect(ajustes.single.valorNuevo, '3300000');
  });

  test('registrar envía motivo y valores a la RPC y mapea la fila', () async {
    when(
      () => remote.registrar(
        viajeId: 'v-1',
        motivo: 'Corrección',
        concepto: 'ACPM',
        valorNuevo: 3300000,
      ),
    ).thenAnswer(
      (_) async => <String, dynamic>{
        'id': 'a-2',
        'viaje_id': 'v-1',
        'motivo': 'Corrección',
        'campo_modificado': 'ACPM',
        'valor_anterior': '3210000',
        'valor_nuevo': '3300000',
        'concepto': 'ACPM',
        'monto': 90000,
        'fecha': '2026-10-08T15:00:00Z',
      },
    );

    final AjusteViaje a = await repo.registrar(
      viajeId: 'v-1',
      motivo: 'Corrección',
      concepto: 'ACPM',
      valorNuevo: 3300000,
    );

    expect(a.id, 'a-2');
    expect(a.concepto, 'ACPM');
    expect(a.monto, 90000);
    verify(
      () => remote.registrar(
        viajeId: 'v-1',
        motivo: 'Corrección',
        concepto: 'ACPM',
        valorNuevo: 3300000,
      ),
    ).called(1);
  });
}
