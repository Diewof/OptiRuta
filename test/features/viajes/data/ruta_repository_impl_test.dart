import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/viajes/data/datasources/ruta_remote_data_source.dart';
import 'package:optiruta/features/viajes/data/repositories/ruta_repository_impl.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/lugar.dart';
import 'package:optiruta/features/viajes/domain/entities/ruta_estimada.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemote extends Mock implements RutaRemoteDataSource {}

const Coordenada _bogota = Coordenada(4.711, -74.0721);
const Coordenada _barranquilla = Coordenada(10.9685, -74.7813);
const Map<String, double> _bogotaMapa = <String, double>{
  'lat': 4.711,
  'lng': -74.0721,
};
const Map<String, double> _barranquillaMapa = <String, double>{
  'lat': 10.9685,
  'lng': -74.7813,
};

void main() {
  late _MockRemote remote;
  late RutaRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = RutaRepositoryImpl(remote);
  });

  test(
    'estimar: envía coordenadas y mapea distancia, tiempo y trazado',
    () async {
      when(
        () => remote.estimar(origen: _bogotaMapa, destino: _barranquillaMapa),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'distanciaKm': 1012.3,
          'duracionMin': 1080,
          'polilinea': '_p~iF~ps|U',
        },
      );

      final RutaEstimada ruta = await repo.estimar(
        origen: _bogota,
        destino: _barranquilla,
      );

      expect(ruta.distanciaKm, 1012.3);
      expect(ruta.duracionMin, 1080);
      expect(ruta.polilinea, '_p~iF~ps|U');
    },
  );

  test('estimar: respuesta sin trazado deja la polilínea vacía', () async {
    when(() => remote.estimar(origen: _bogotaMapa, destino: _barranquillaMapa))
        .thenAnswer(
          (_) async => <String, dynamic>{'distanciaKm': 10, 'duracionMin': 20},
        );

    final RutaEstimada ruta = await repo.estimar(
      origen: _bogota,
      destino: _barranquilla,
    );

    expect(ruta.polilinea, isEmpty);
  });

  test('estimar: FunctionsHttpException con mensaje de dominio conserva el mensaje', () async {
    when(() => remote.estimar(origen: _bogotaMapa, destino: _barranquillaMapa))
        .thenThrow(
          const FunctionsHttpException(
            status: 422,
            details: <String, dynamic>{
              'error': 'RUTA_NO_ENCONTRADA',
              'message': 'No se encontró una ruta terrestre.',
            },
          ),
        );

    await expectLater(
      repo.estimar(origen: _bogota, destino: _barranquilla),
      throwsA(
        isA<CatalogoFailure>().having(
          (CatalogoFailure f) => f.mensaje,
          'mensaje',
          'No se encontró una ruta terrestre.',
        ),
      ),
    );
  });

  test('estimar: FunctionsHttpException sin detalles usables cae al mensaje genérico', () async {
    when(() => remote.estimar(origen: _bogotaMapa, destino: _barranquillaMapa))
        .thenThrow(const FunctionsHttpException(status: 500));

    await expectLater(
      repo.estimar(origen: _bogota, destino: _barranquilla),
      throwsA(
        isA<CatalogoFailure>().having(
          (CatalogoFailure f) => f.codigo,
          'codigo',
          CatalogoErrorCodigo.desconocido,
        ),
      ),
    );
  });

  test('buscarLugares: mapea nombre y coordenada de cada resultado', () async {
    when(() => remote.buscar('Medel')).thenAnswer(
      (_) async => <String, dynamic>{
        'lugares': <Map<String, dynamic>>[
          <String, dynamic>{
            'nombre': 'Medellín, Antioquia',
            'lat': 6.2442,
            'lng': -75.5812,
          },
        ],
      },
    );

    final List<Lugar> lugares = await repo.buscarLugares('Medel');

    expect(lugares, hasLength(1));
    expect(lugares.single.nombre, 'Medellín, Antioquia');
    expect(lugares.single.coordenada, const Coordenada(6.2442, -75.5812));
  });

  test('lugarEn: devuelve el lugar del punto elegido', () async {
    when(() => remote.lugarEn(lat: 6.2, lng: -75.5)).thenAnswer(
      (_) async => <String, dynamic>{
        'nombre': 'Sabaneta',
        'lat': 6.2,
        'lng': -75.5,
      },
    );

    final Lugar lugar = await repo.lugarEn(const Coordenada(6.2, -75.5));

    expect(lugar.nombre, 'Sabaneta');
  });
}
