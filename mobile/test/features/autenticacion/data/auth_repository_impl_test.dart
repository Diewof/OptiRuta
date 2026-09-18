import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/autenticacion/data/datasources/auth_remote_data_source.dart';
import 'package:optiruta/features/autenticacion/data/repositories/auth_repository_impl.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/sesion.dart';
import 'package:optiruta/features/autenticacion/domain/errores/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

User _user(String id, Map<String, dynamic> appMetadata) =>
    User.fromJson(<String, dynamic>{
      'id': id,
      'app_metadata': appMetadata,
      'user_metadata': <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    })!;

Session _session(User user) =>
    Session(accessToken: 'token', tokenType: 'bearer', user: user);

void main() {
  late _MockRemote remote;
  late AuthRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = AuthRepositoryImpl(remote);
    when(() => remote.cerrarSesion()).thenAnswer((_) async {});
  });

  void stubLogin(User user) {
    when(
      () => remote.iniciarSesion(
        correo: any(named: 'correo'),
        contrasena: any(named: 'contrasena'),
      ),
    ).thenAnswer((_) async => AuthResponse(user: user));
  }

  test('login OK: rol desde el JWT y perfil desde la tabla', () async {
    stubLogin(_user('u-1', <String, dynamic>{'rol': 'ADMINISTRADOR'}));
    when(() => remote.obtenerPerfil('u-1')).thenAnswer(
      (_) async => <String, dynamic>{
        'id': 'u-1',
        'nombre': 'Admin Prueba',
        'documento': 'CC-1000',
        'activo': true,
      },
    );

    final Sesion sesion = await repo.iniciarSesion(
      correo: 'admin@optiruta.test',
      contrasena: 'Admin123!',
    );

    expect(sesion.usuario.rol, RolUsuario.administrador);
    expect(sesion.usuario.nombre, 'Admin Prueba');
    expect(sesion.usuario.documento, 'CC-1000');
  });

  test('mapea el rol CONDUCTOR del JWT', () async {
    stubLogin(_user('u-2', <String, dynamic>{'rol': 'CONDUCTOR'}));
    when(() => remote.obtenerPerfil('u-2')).thenAnswer(
      (_) async => <String, dynamic>{
        'id': 'u-2',
        'nombre': 'Conductor Prueba',
        'activo': true,
      },
    );

    final Sesion sesion = await repo.iniciarSesion(
      correo: 'conductor@optiruta.test',
      contrasena: 'Conductor123!',
    );

    expect(sesion.usuario.rol, RolUsuario.conductor);
  });

  test(
    'credenciales invalidas del proveedor -> AuthFailure traducido',
    () async {
      when(
        () => remote.iniciarSesion(
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenThrow(const AuthException('Invalid login credentials'));

      await expectLater(
        repo.iniciarSesion(correo: 'x@y.com', contrasena: 'mala'),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure f) => f.codigo,
            'codigo',
            AuthErrorCodigo.credencialesInvalidas,
          ),
        ),
      );
    },
  );

  test('sin fila de perfil -> PERFIL_NO_ENCONTRADO', () async {
    stubLogin(_user('u-3', <String, dynamic>{'rol': 'CONDUCTOR'}));
    when(() => remote.obtenerPerfil('u-3')).thenAnswer((_) async => null);

    await expectLater(
      repo.iniciarSesion(correo: 'x@y.com', contrasena: 'Secreta123'),
      throwsA(
        isA<AuthFailure>().having(
          (AuthFailure f) => f.codigo,
          'codigo',
          AuthErrorCodigo.perfilNoEncontrado,
        ),
      ),
    );
  });

  test('rol ausente en JWT y en la fila -> PERFIL_NO_ENCONTRADO', () async {
    stubLogin(_user('u-4', <String, dynamic>{}));
    when(() => remote.obtenerPerfil('u-4')).thenAnswer(
      (_) async => <String, dynamic>{
        'id': 'u-4',
        'nombre': 'Sin Rol',
        'activo': true,
      },
    );

    await expectLater(
      repo.iniciarSesion(correo: 'x@y.com', contrasena: 'Secreta123'),
      throwsA(
        isA<AuthFailure>().having(
          (AuthFailure f) => f.codigo,
          'codigo',
          AuthErrorCodigo.perfilNoEncontrado,
        ),
      ),
    );
  });

  test('usuario inactivo -> USUARIO_INACTIVO y cierra la sesion', () async {
    stubLogin(_user('u-5', <String, dynamic>{'rol': 'CONDUCTOR'}));
    when(() => remote.obtenerPerfil('u-5')).thenAnswer(
      (_) async => <String, dynamic>{
        'id': 'u-5',
        'nombre': 'Inactivo',
        'activo': false,
      },
    );

    await expectLater(
      repo.iniciarSesion(correo: 'x@y.com', contrasena: 'Secreta123'),
      throwsA(
        isA<AuthFailure>().having(
          (AuthFailure f) => f.codigo,
          'codigo',
          AuthErrorCodigo.usuarioInactivo,
        ),
      ),
    );
    verify(() => remote.cerrarSesion()).called(1);
  });

  group('registrarse', () {
    void stubRegistro(AuthResponse resp) {
      when(
        () => remote.registrarse(
          nombre: any(named: 'nombre'),
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenAnswer((_) async => resp);
    }

    test('alta con sesion inmediata -> Sesion rol CONDUCTOR', () async {
      final User u = _user('n-1', <String, dynamic>{'rol': 'CONDUCTOR'});
      stubRegistro(AuthResponse(session: _session(u), user: u));
      when(() => remote.obtenerPerfil('n-1')).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'n-1',
          'nombre': 'Nuevo Conductor',
          'activo': true,
          'rol': 'CONDUCTOR',
        },
      );

      final Sesion? s = await repo.registrarse(
        nombre: 'Nuevo Conductor',
        correo: 'nuevo@optiruta.test',
        contrasena: 'Conductor123!',
      );

      expect(s?.usuario.rol, RolUsuario.conductor);
    });

    test('si el JWT aun no trae rol, cae en la columna de la fila', () async {
      final User u = _user('n-2', <String, dynamic>{});
      stubRegistro(AuthResponse(session: _session(u), user: u));
      when(() => remote.obtenerPerfil('n-2')).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'n-2',
          'nombre': 'Nuevo Conductor',
          'activo': true,
          'rol': 'CONDUCTOR',
        },
      );

      final Sesion? s = await repo.registrarse(
        nombre: 'Nuevo Conductor',
        correo: 'nuevo2@optiruta.test',
        contrasena: 'Conductor123!',
      );

      expect(s?.usuario.rol, RolUsuario.conductor);
    });

    test('sin sesion (confirmacion pendiente) -> null', () async {
      final User u = _user('n-3', <String, dynamic>{'rol': 'CONDUCTOR'});
      stubRegistro(AuthResponse(user: u));

      final Sesion? s = await repo.registrarse(
        nombre: 'Nuevo Conductor',
        correo: 'nuevo3@optiruta.test',
        contrasena: 'Conductor123!',
      );

      expect(s, isNull);
    });

    test('correo ya registrado -> AuthFailure traducido', () async {
      when(
        () => remote.registrarse(
          nombre: any(named: 'nombre'),
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenThrow(const AuthException('User already registered'));

      await expectLater(
        repo.registrarse(
          nombre: 'X',
          correo: 'dup@optiruta.test',
          contrasena: 'Conductor123!',
        ),
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

  group('enviarRecuperacion', () {
    test('llama al datasource con el correo', () async {
      when(() => remote.enviarRecuperacion('a@b.com')).thenAnswer((_) async {});
      await repo.enviarRecuperacion(correo: 'a@b.com');
      verify(() => remote.enviarRecuperacion('a@b.com')).called(1);
    });

    test('no revela errores de dominio del proveedor', () async {
      when(() => remote.enviarRecuperacion(any()))
          .thenThrow(const AuthException('rate limit'));

      await expectLater(repo.enviarRecuperacion(correo: 'a@b.com'), completes);
    });
  });
}
