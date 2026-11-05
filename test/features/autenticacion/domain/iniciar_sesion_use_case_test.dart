import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/sesion.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/autenticacion/domain/errores/auth_failure.dart';
import 'package:optiruta/features/autenticacion/domain/repositories/auth_repository.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/iniciar_sesion_use_case.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repositorio;
  late IniciarSesionUseCase useCase;

  setUp(() {
    repositorio = _MockAuthRepository();
    useCase = IniciarSesionUseCase(repositorio);
  });

  const Sesion sesionAdmin = Sesion(
    usuario: Usuario(
      id: 'u-1',
      nombre: 'Admin Prueba',
      rol: RolUsuario.administrador,
      activo: true,
    ),
  );

  test('login OK devuelve la sesion y normaliza el correo', () async {
    when(
      () => repositorio.iniciarSesion(
        correo: 'admin@optiruta.test',
        contrasena: 'Admin123!',
      ),
    ).thenAnswer((_) async => sesionAdmin);

    final Sesion resultado = await useCase(
      correo: '  admin@optiruta.test  ',
      contrasena: 'Admin123!',
    );

    expect(resultado.usuario.rol, RolUsuario.administrador);
    verify(
      () => repositorio.iniciarSesion(
        correo: 'admin@optiruta.test',
        contrasena: 'Admin123!',
      ),
    ).called(1);
  });

  test('credenciales invalidas propaga AuthFailure', () async {
    when(
      () => repositorio.iniciarSesion(
        correo: any(named: 'correo'),
        contrasena: any(named: 'contrasena'),
      ),
    ).thenThrow(AuthFailure.credencialesInvalidas());

    expect(
      () => useCase(correo: 'x@y.com', contrasena: 'mala'),
      throwsA(
        isA<AuthFailure>().having(
          (AuthFailure f) => f.codigo,
          'codigo',
          AuthErrorCodigo.credencialesInvalidas,
        ),
      ),
    );
  });

  test('sesion expirada propaga AuthFailure con su codigo', () async {
    when(
      () => repositorio.iniciarSesion(
        correo: any(named: 'correo'),
        contrasena: any(named: 'contrasena'),
      ),
    ).thenThrow(AuthFailure.sesionExpirada());

    expect(
      () => useCase(correo: 'x@y.com', contrasena: 'Secreta123'),
      throwsA(
        isA<AuthFailure>().having(
          (AuthFailure f) => f.codigo,
          'codigo',
          AuthErrorCodigo.sesionExpirada,
        ),
      ),
    );
  });
}
