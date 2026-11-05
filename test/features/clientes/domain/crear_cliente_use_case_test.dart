import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/clientes/domain/entities/cliente.dart';
import 'package:optiruta/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:optiruta/features/clientes/domain/usecases/crear_cliente_use_case.dart';

class _MockRepo extends Mock implements ClienteRepository {}

void main() {
  late _MockRepo repo;
  late CrearClienteUseCase caso;

  const Cliente clienteCreado = Cliente(
    id: 'cli-1',
    nombre: 'Cliente Uno',
    documento: null,
    telefono: null,
    correo: null,
    direccion: null,
    activo: true,
  );

  setUp(() {
    repo = _MockRepo();
    caso = CrearClienteUseCase(repo);
    when(
      () => repo.crear(
        nombre: any(named: 'nombre'),
        documento: any(named: 'documento'),
        telefono: any(named: 'telefono'),
        correo: any(named: 'correo'),
        direccion: any(named: 'direccion'),
      ),
    ).thenAnswer((_) async => clienteCreado);
  });

  test(
    'recorta el nombre y convierte campos opcionales vacios en null',
    () async {
      await caso(
        nombre: '  Cliente Uno  ',
        documento: '   ',
        telefono: '',
        correo: null,
        direccion: '  Cra 1 # 1-01  ',
      );

      verify(
        () => repo.crear(
          nombre: 'Cliente Uno',
          documento: null,
          telefono: null,
          correo: null,
          direccion: 'Cra 1 # 1-01',
        ),
      ).called(1);
    },
  );
}
