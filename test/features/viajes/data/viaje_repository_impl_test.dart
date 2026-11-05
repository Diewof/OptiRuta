import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/lugar.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/viajes/data/datasources/viaje_remote_data_source.dart';
import 'package:optiruta/features/viajes/data/repositories/viaje_repository_impl.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemote extends Mock implements ViajeRemoteDataSource {}

Map<String, dynamic> _filaViaje({
  String id = 'v-1',
  String estado = 'PLANIFICADO',
}) => <String, dynamic>{
  'id': id,
  'remision': 'REM-001',
  'vehiculo_id': 'veh-1',
  'conductor_id': 'con-1',
  'cliente_id': 'cli-1',
  'origen': 'Bogotá',
  'destino': 'Barranquilla',
  'fecha_salida_programada': '2026-09-30T06:00:00Z',
  'distancia_estimada': 1012,
  'tiempo_estimado_min': 1080,
  'peso_carga': 28,
  'estado': estado,
  'valor_flete': 9200000,
  'valor_anticipo': 0,
  'saldo_pendiente': 9200000,
  'fecha_cierre': null,
  'fecha_creacion': '2026-09-24T10:00:00Z',
};

Map<String, dynamic> _filaResumen({String id = 'v-1'}) => <String, dynamic>{
  'id': id,
  'remision': 'REM-001',
  'origen': 'Bogotá',
  'destino': 'Barranquilla',
  'estado': 'ASIGNADO',
  'fecha_salida_programada': '2026-09-25T06:00:00Z',
  'fecha_creacion': '2026-09-24T10:00:00Z',
  'vehiculo': <String, dynamic>{'placa': 'UFH664'},
  'conductor': <String, dynamic>{
    'usuario': <String, dynamic>{'nombre': 'Camilo Rojas'},
  },
  'cliente': <String, dynamic>{'nombre': 'Distribuidora Andina'},
};

const Lugar _bogota = Lugar(
  nombre: 'Bogotá',
  coordenada: Coordenada(4.711, -74.0721),
);
const Lugar _barranquilla = Lugar(
  nombre: 'Barranquilla',
  coordenada: Coordenada(10.9685, -74.7813),
);

void main() {
  late _MockRemote remote;
  late ViajeRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = ViajeRepositoryImpl(remote);
  });

  test(
    'crear: envía p_fecha_salida_programada en ISO8601 y mapea la fila',
    () async {
      final DateTime fecha = DateTime.utc(2026, 9, 30, 6);
      when(() => remote.crear(any())).thenAnswer((_) async => _filaViaje());

      final Viaje viaje = await repo.crear(
        remision: 'REM-001',
        vehiculoId: 'veh-1',
        conductorId: 'con-1',
        clienteId: 'cli-1',
        origen: _bogota,
        destino: _barranquilla,
        rutaPolilinea: 'abc',
        fechaSalidaProgramada: fecha,
        distanciaEstimada: 1012,
        tiempoEstimadoMin: 1080,
        pesoCarga: 28,
        valorFlete: 9200000,
      );

      expect(viaje.estado, EstadoViaje.planificado);
      final Map<String, dynamic> parametros =
          verify(() => remote.crear(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(parametros['p_fecha_salida_programada'], fecha.toIso8601String());
      expect(parametros['p_origen'], 'Bogotá');
      expect(parametros['p_origen_lat'], 4.711);
      expect(parametros['p_destino_lng'], -74.7813);
      expect(parametros['p_ruta_polilinea'], 'abc');
    },
  );

  test('crear: 42501 se traduce a SIN_PERMISO', () async {
    when(() => remote.crear(any()))
        .thenThrow(const PostgrestException(message: 'rls', code: '42501'));

    await expectLater(
      repo.crear(
        remision: 'REM-002',
        vehiculoId: 'veh-1',
        conductorId: 'con-1',
        clienteId: 'cli-1',
        origen: _bogota,
        destino: _barranquilla,
        rutaPolilinea: 'abc',
        fechaSalidaProgramada: DateTime.now(),
        distanciaEstimada: 100,
        tiempoEstimadoMin: 100,
        pesoCarga: 10,
        valorFlete: 100000,
      ),
      throwsA(
        isA<CatalogoFailure>().having(
          (CatalogoFailure f) => f.codigo,
          'codigo',
          CatalogoErrorCodigo.sinPermiso,
        ),
      ),
    );
  });

  test('cambiarEstado: envía el código del nuevo estado', () async {
    when(() => remote.cambiarEstado(viajeId: 'v-1', nuevoEstado: 'ASIGNADO'))
        .thenAnswer((_) async => _filaViaje(estado: 'ASIGNADO'));

    final Viaje viaje = await repo.cambiarEstado(
      viajeId: 'v-1',
      nuevoEstado: EstadoViaje.asignado,
    );

    expect(viaje.estado, EstadoViaje.asignado);
    verify(() => remote.cambiarEstado(viajeId: 'v-1', nuevoEstado: 'ASIGNADO'))
        .called(1);
  });

  test('cerrar: mapea la fila devuelta', () async {
    when(() => remote.cerrar('v-1'))
        .thenAnswer((_) async => _filaViaje(estado: 'CERRADO'));

    final Viaje viaje = await repo.cerrar('v-1');

    expect(viaje.estado, EstadoViaje.cerrado);
  });

  test('estimarAcpm: devuelve el valor calculado por la RPC', () async {
    when(
      () => remote.estimarAcpm(
        vehiculoId: 'veh-1',
        distanciaKm: 1012,
        ciudad: 'Bogotá',
      ),
    ).thenAnswer((_) async => 1840000);

    final double valor = await repo.estimarAcpm(
      vehiculoId: 'veh-1',
      distanciaKm: 1012,
      ciudad: 'Bogotá',
    );

    expect(valor, 1840000);
  });

  test(
    'listarPorRango: pasa desde/hasta y mapea las filas embebidas',
    () async {
      when(
        () => remote.listarPorRango(
          desde: any(named: 'desde'),
          hasta: any(named: 'hasta'),
        ),
      ).thenAnswer((_) async => <Map<String, dynamic>>[_filaResumen()]);

      final DateTime desde = DateTime(2026, 9);
      final DateTime hasta = DateTime(2026, 10);
      final resultado = await repo.listarPorRango(desde: desde, hasta: hasta);

      expect(resultado, hasLength(1));
      expect(resultado.first.placaVehiculo, 'UFH664');
      expect(resultado.first.nombreConductor, 'Camilo Rojas');

      final captura = verify(
        () => remote.listarPorRango(
          desde: captureAny(named: 'desde'),
          hasta: captureAny(named: 'hasta'),
        ),
      ).captured;
      expect(captura[0], desde);
      expect(captura[1], hasta);
    },
  );

  test('listarActivos: mapea las filas embebidas', () async {
    when(() => remote.listarActivos())
        .thenAnswer((_) async => <Map<String, dynamic>>[_filaResumen()]);

    final resultado = await repo.listarActivos();

    expect(resultado, hasLength(1));
    expect(resultado.first.nombreCliente, 'Distribuidora Andina');
  });

  test('listarHistorial: detecta hayMas y pasa el filtro de estado', () async {
    when(
      () =>
          remote.listarHistorial(pagina: 0, tamano: 1, filtroEstado: 'CERRADO'),
    ).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        _filaResumen(id: 'v-1'),
        _filaResumen(id: 'v-2'),
      ],
    );

    final pagina = await repo.listarHistorial(
      pagina: 0,
      tamano: 1,
      filtroEstado: EstadoViaje.cerrado,
    );

    expect(pagina.viajes, hasLength(1));
    expect(pagina.hayMas, isTrue);
  });
}
