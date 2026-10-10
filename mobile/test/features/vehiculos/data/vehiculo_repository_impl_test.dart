import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/vehiculos/data/datasources/vehiculo_remote_data_source.dart';
import 'package:optiruta/features/vehiculos/data/repositories/vehiculo_repository_impl.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/vehiculo_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemote extends Mock implements VehiculoRemoteDataSource {}

Map<String, dynamic> _fila({String placa = 'ABC123', bool activo = true}) =>
    <String, dynamic>{
      'id': 'v-1',
      'placa': placa,
      'tipo': 'DOBLE_TROQUE',
      'capacidad_carga': 17,
      'rendimiento_km_galon': 9,
      'activo': activo,
    };

void main() {
  late _MockRemote remote;
  late VehiculoRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = VehiculoRepositoryImpl(remote);
  });

  test('listar: mapea filas y detecta hayMas cuando llega tamano+1', () async {
    when(() => remote.listar(pagina: 0, tamano: 2)).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        _fila(placa: 'AAA111'),
        _fila(placa: 'BBB222'),
        _fila(placa: 'CCC333'),
      ],
    );

    final PaginaVehiculos pagina = await repo.listar(pagina: 0, tamano: 2);

    expect(pagina.vehiculos, hasLength(2));
    expect(pagina.hayMas, isTrue);
    expect(pagina.vehiculos.first.placa, 'AAA111');
    expect(pagina.vehiculos.first.tipo, TipoVehiculo.dobleTroque);
  });

  test('listar: hayMas es false cuando no sobra fila', () async {
    when(() => remote.listar(pagina: 0, tamano: 2))
        .thenAnswer((_) async => <Map<String, dynamic>>[_fila()]);

    final PaginaVehiculos pagina = await repo.listar(pagina: 0, tamano: 2);

    expect(pagina.vehiculos, hasLength(1));
    expect(pagina.hayMas, isFalse);
  });

  test('crear: mapea la fila creada a la entidad', () async {
    when(() => remote.crear(any()))
        .thenAnswer((_) async => _fila(placa: 'XYZ999'));

    final Vehiculo vehiculo = await repo.crear(
      placa: 'XYZ999',
      tipo: TipoVehiculo.dobleTroque,
      capacidadCarga: 17,
      rendimientoKmGalon: 9,
    );

    expect(vehiculo.placa, 'XYZ999');
  });

  test('crear: placa duplicada (23505) se traduce a YA_EXISTE', () async {
    when(() => remote.crear(any())).thenThrow(
      const PostgrestException(message: 'duplicate key', code: '23505'),
    );

    await expectLater(
      repo.crear(
        placa: 'ABC123',
        tipo: TipoVehiculo.mula,
        capacidadCarga: 30,
        rendimientoKmGalon: 7,
      ),
      throwsA(
        isA<CatalogoFailure>().having(
          (CatalogoFailure f) => f.codigo,
          'codigo',
          CatalogoErrorCodigo.yaExiste,
        ),
      ),
    );
  });

  test('inhabilitar: RLS (42501) se traduce a SIN_PERMISO', () async {
    when(() => remote.inhabilitar(any())).thenThrow(
      const PostgrestException(message: 'permission denied', code: '42501'),
    );

    await expectLater(
      repo.inhabilitar('v-1'),
      throwsA(
        isA<CatalogoFailure>().having(
          (CatalogoFailure f) => f.codigo,
          'codigo',
          CatalogoErrorCodigo.sinPermiso,
        ),
      ),
    );
  });
}
