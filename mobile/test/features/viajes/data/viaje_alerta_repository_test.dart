import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/viajes/data/datasources/viaje_remote_data_source.dart';
import 'package:optiruta/features/viajes/data/repositories/viaje_repository_impl.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_alerta_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemote extends Mock implements ViajeRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late ViajeRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = ViajeRepositoryImpl(remote);
  });

  test('registrarAlerta: envía solo el evento puntual a la RPC', () async {
    when(() => remote.registrarAlerta(any())).thenAnswer((_) async => true);

    final bool creada = await repo.registrarAlerta(
      viajeId: 'v-1',
      tipo: TipoAlertaViaje.desvioRuta,
      ubicacion: const Coordenada(6.2, -75.5),
    );

    expect(creada, isTrue);
    final Map<String, dynamic> parametros =
        verify(() => remote.registrarAlerta(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(parametros, <String, dynamic>{
      'p_viaje_id': 'v-1',
      'p_tipo': 'DESVIO_RUTA',
      'p_lat': 6.2,
      'p_lng': -75.5,
    });
  });

  test(
    'registrarAlerta: false cuando el servidor ya tenía una reciente',
    () async {
      when(() => remote.registrarAlerta(any())).thenAnswer((_) async => false);

      final bool creada = await repo.registrarAlerta(
        viajeId: 'v-1',
        tipo: TipoAlertaViaje.paradaProlongada,
        ubicacion: const Coordenada(6.2, -75.5),
      );

      expect(creada, isFalse);
    },
  );

  test('registrarAlerta: un error de dominio llega con su mensaje', () async {
    when(() => remote.registrarAlerta(any())).thenThrow(
      const PostgrestException(
        message: 'Solo se registran alertas en viajes en curso.',
        code: 'OR118',
      ),
    );

    await expectLater(
      repo.registrarAlerta(
        viajeId: 'v-1',
        tipo: TipoAlertaViaje.paradaProlongada,
        ubicacion: const Coordenada(6.2, -75.5),
      ),
      throwsA(
        isA<CatalogoFailure>().having(
          (CatalogoFailure f) => f.mensaje,
          'mensaje',
          'Solo se registran alertas en viajes en curso.',
        ),
      ),
    );
  });

  test(
    'obtenerResumen: mapea el viaje con sus ubicaciones y trazado',
    () async {
      when(() => remote.obtenerResumen('v-1')).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'v-1',
          'remision': 'V-001',
          'origen': 'Medellín',
          'destino': 'Cartagena',
          'estado': 'EN_CURSO',
          'fecha_creacion': '2026-10-08T10:00:00Z',
          'origen_lat': 6.2442,
          'origen_lng': -75.5812,
          'destino_lat': 10.391,
          'destino_lng': -75.4794,
          'ruta_polilinea': '_p~iF~ps|U',
          'vehiculo': <String, dynamic>{
            'placa': 'UFH664',
            'tipo': 'DOBLE_TROQUE',
          },
          'conductor': <String, dynamic>{
            'usuario': <String, dynamic>{'nombre': 'Camilo Rojas'},
          },
          'cliente': <String, dynamic>{'nombre': 'Distribuidora Andina'},
        },
      );

      final ViajeResumen viaje = await repo.obtenerResumen('v-1');

      expect(viaje.tieneMapa, isTrue);
      expect(viaje.origenCoordenada, const Coordenada(6.2442, -75.5812));
      expect(viaje.rutaPolilinea, '_p~iF~ps|U');
      expect(viaje.placaVehiculo, 'UFH664');
    },
  );

  test('obtenerResumen: un viaje anterior a los mapas no tiene mapa', () async {
    when(() => remote.obtenerResumen('v-2')).thenAnswer(
      (_) async => <String, dynamic>{
        'id': 'v-2',
        'remision': 'V-002',
        'origen': 'Cali',
        'destino': 'Bogotá',
        'estado': 'CERRADO',
        'fecha_creacion': '2026-01-08T10:00:00Z',
        'origen_lat': null,
        'origen_lng': null,
        'destino_lat': null,
        'destino_lng': null,
        'ruta_polilinea': null,
        'vehiculo': <String, dynamic>{'placa': 'UFH664', 'tipo': 'MULA'},
        'conductor': <String, dynamic>{
          'usuario': <String, dynamic>{'nombre': 'Camilo Rojas'},
        },
        'cliente': <String, dynamic>{'nombre': 'Distribuidora Andina'},
      },
    );

    final ViajeResumen viaje = await repo.obtenerResumen('v-2');

    expect(viaje.tieneMapa, isFalse);
    expect(viaje.rutaPolilinea, isNull);
  });
}
