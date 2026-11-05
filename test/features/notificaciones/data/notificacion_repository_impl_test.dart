import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/notificaciones/data/datasources/notificacion_remote_data_source.dart';
import 'package:optiruta/features/notificaciones/data/repositories/notificacion_repository_impl.dart';
import 'package:optiruta/features/notificaciones/domain/entities/tipo_notificacion.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/notificaciones/domain/repositories/notificacion_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemote extends Mock implements NotificacionRemoteDataSource {}

Map<String, dynamic> _fila({String id = 'n-1', bool leida = false}) =>
    <String, dynamic>{
      'id': id,
      'tipo': 'RETRASO',
      'titulo': 'Retraso en viaje',
      'mensaje': 'Bogotá → Barranquilla lleva retraso.',
      'leida': leida,
      'fecha_creacion': '2026-09-24T10:00:00Z',
      'viaje_id': 'v-1',
      'vehiculo_id': null,
    };

void main() {
  late _MockRemote remote;
  late NotificacionRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = NotificacionRepositoryImpl(remote);
  });

  test('listar: mapea filas y detecta hayMas cuando llega tamano+1', () async {
    when(
      () => remote.listar(
        pagina: 0,
        tamano: 1,
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        soloNoLeidas: any(named: 'soloNoLeidas'),
      ),
    ).thenAnswer(
      (_) async => <Map<String, dynamic>>[_fila(), _fila(id: 'n-2')],
    );

    final PaginaNotificaciones pagina = await repo.listar(pagina: 0, tamano: 1);

    expect(pagina.notificaciones, hasLength(1));
    expect(pagina.notificaciones.first.tipo, TipoNotificacion.retraso);
    expect(pagina.hayMas, isTrue);
  });

  test('listar: una alerta de ruta trae su tipo y su ubicación', () async {
    when(
      () => remote.listar(
        pagina: 0,
        tamano: 5,
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        soloNoLeidas: any(named: 'soloNoLeidas'),
      ),
    ).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        <String, dynamic>{
          ..._fila(),
          'tipo': 'DESVIO_RUTA',
          'lat': 6.2442,
          'lng': -75.5812,
        },
        <String, dynamic>{..._fila(id: 'n-2'), 'tipo': 'PARADA_PROLONGADA'},
      ],
    );

    final PaginaNotificaciones pagina = await repo.listar(pagina: 0, tamano: 5);

    expect(pagina.notificaciones[0].tipo, TipoNotificacion.desvioRuta);
    expect(pagina.notificaciones[0].tipo.esAlertaDeRuta, isTrue);
    expect(
      pagina.notificaciones[0].ubicacion,
      const Coordenada(6.2442, -75.5812),
    );
    expect(pagina.notificaciones[1].tipo, TipoNotificacion.paradaProlongada);
    expect(pagina.notificaciones[1].ubicacion, isNull);
  });

  test('las notificaciones de otros tipos no son alertas de ruta', () {
    final Iterable<TipoNotificacion> otras = TipoNotificacion.values.where(
      (TipoNotificacion t) =>
          t != TipoNotificacion.desvioRuta &&
          t != TipoNotificacion.paradaProlongada,
    );

    expect(otras.any((TipoNotificacion t) => t.esAlertaDeRuta), isFalse);
  });

  test('marcarLeida: propaga al datasource', () async {
    when(() => remote.marcarLeida('n-1')).thenAnswer((_) async {});

    await repo.marcarLeida('n-1');

    verify(() => remote.marcarLeida('n-1')).called(1);
  });

  test(
    'marcarTodasLeidas: sin permiso (42501) se traduce a SIN_PERMISO',
    () async {
      when(() => remote.marcarTodasLeidas())
          .thenThrow(const PostgrestException(message: 'rls', code: '42501'));

      await expectLater(
        repo.marcarTodasLeidas(),
        throwsA(
          isA<CatalogoFailure>().having(
            (CatalogoFailure f) => f.codigo,
            'codigo',
            CatalogoErrorCodigo.sinPermiso,
          ),
        ),
      );
    },
  );
}
