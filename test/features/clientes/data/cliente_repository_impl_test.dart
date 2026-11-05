import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/clientes/data/datasources/cliente_remote_data_source.dart';
import 'package:optiruta/features/clientes/data/repositories/cliente_repository_impl.dart';
import 'package:optiruta/features/clientes/domain/entities/cliente.dart';
import 'package:optiruta/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemote extends Mock implements ClienteRemoteDataSource {}

Map<String, dynamic> _fila({
  String nombre = 'Cliente Uno',
  bool activo = true,
}) => <String, dynamic>{
  'id': 'cli-1',
  'nombre': nombre,
  'documento': '900111222-1',
  'telefono': '3001112233',
  'correo': null,
  'direccion': 'Cra 1 # 1-01',
  'activo': activo,
};

void main() {
  late _MockRemote remote;
  late ClienteRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = ClienteRepositoryImpl(remote);
  });

  test('listar: mapea filas y detecta hayMas cuando llega tamano+1', () async {
    when(() => remote.listar(pagina: 0, tamano: 1)).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        _fila(nombre: 'A'),
        _fila(nombre: 'B'),
      ],
    );

    final PaginaClientes pagina = await repo.listar(pagina: 0, tamano: 1);

    expect(pagina.clientes, hasLength(1));
    expect(pagina.hayMas, isTrue);
    expect(pagina.clientes.first.nombre, 'A');
    expect(pagina.clientes.first.direccion, 'Cra 1 # 1-01');
  });

  test('crear: mapea la fila creada a la entidad', () async {
    when(() => remote.crear(any()))
        .thenAnswer((_) async => _fila(nombre: 'Cliente Nuevo'));

    final Cliente cliente = await repo.crear(nombre: 'Cliente Nuevo');

    expect(cliente.nombre, 'Cliente Nuevo');
  });

  test('inhabilitar: RLS (42501) se traduce a SIN_PERMISO', () async {
    when(() => remote.inhabilitar(any())).thenThrow(
      const PostgrestException(message: 'permission denied', code: '42501'),
    );

    await expectLater(
      repo.inhabilitar('cli-1'),
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
