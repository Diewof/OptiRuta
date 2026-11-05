import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/sesion.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/autenticacion/domain/errores/auth_failure.dart';
import 'package:optiruta/features/autenticacion/domain/repositories/auth_repository.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/recuperar_password_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/registrarse_use_case.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;

  setUp(() => repo = _MockAuthRepository());

  group('RegistrarseUseCase', () {
    late RegistrarseUseCase useCase;
    setUp(() => useCase = RegistrarseUseCase(repo));

    const Sesion sesion = Sesion(
      usuario: Usuario(
        id: 'u-9',
        nombre: 'Nuevo Conductor',
        rol: RolUsuario.conductor,
        activo: true,
      ),
    );

    test('recorta nombre y correo y devuelve la sesion', () async {
      when(
        () => repo.registrarse(
          nombre: 'Nuevo Conductor',
          correo: 'nuevo@optiruta.test',
          contrasena: 'Conductor123!',
        ),
      ).thenAnswer((_) async => sesion);

      final Sesion? r = await useCase(
        nombre: '  Nuevo Conductor  ',
        correo: '  nuevo@optiruta.test ',
        contrasena: 'Conductor123!',
      );

      expect(r, sesion);
      verify(
        () => repo.registrarse(
          nombre: 'Nuevo Conductor',
          correo: 'nuevo@optiruta.test',
          contrasena: 'Conductor123!',
        ),
      ).called(1);
    });

    test('propaga null cuando queda pendiente de confirmacion', () async {
      when(
        () => repo.registrarse(
          nombre: any(named: 'nombre'),
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenAnswer((_) async => null);

      expect(
        await useCase(
          nombre: 'X Y',
          correo: 'x@y.com',
          contrasena: 'Secreta123',
        ),
        isNull,
      );
    });

    test('propaga AuthFailure de correo ya registrado', () {
      when(
        () => repo.registrarse(
          nombre: any(named: 'nombre'),
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenThrow(AuthFailure.correoYaRegistrado());

      expect(
        () =>
            useCase(nombre: 'X Y', correo: 'x@y.com', contrasena: 'Secreta123'),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure f) => f.codigo,
            'codigo',
            AuthErrorCodigo.correoYaRegistrado,
          ),
        ),
      );
    });
  });

  group('RecuperarPasswordUseCase', () {
    late RecuperarPasswordUseCase useCase;
    setUp(() => useCase = RecuperarPasswordUseCase(repo));

    test('recorta el correo antes de enviarlo', () async {
      when(() => repo.enviarRecuperacion(correo: 'a@b.com'))
          .thenAnswer((_) async {});

      await useCase(correo: '  a@b.com  ');

      verify(() => repo.enviarRecuperacion(correo: 'a@b.com')).called(1);
    });
  });
}
