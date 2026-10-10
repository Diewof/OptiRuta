import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/sesion.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/autenticacion/domain/errores/auth_failure.dart';
import 'package:optiruta/features/autenticacion/domain/repositories/auth_repository.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/cerrar_sesion_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/iniciar_con_google_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/iniciar_sesion_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/observar_sesion_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/recuperar_password_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/registrarse_use_case.dart';
import 'package:optiruta/features/autenticacion/presentation/bloc/auth_cubit.dart';
import 'package:optiruta/features/autenticacion/presentation/bloc/auth_state.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const Usuario _usuarioConductor = Usuario(
  id: 'u-2',
  nombre: 'Conductor Prueba',
  rol: RolUsuario.conductor,
  activo: true,
);
const Sesion _sesionConductor = Sesion(usuario: _usuarioConductor);

void main() {
  late _MockAuthRepository repo;
  late StreamController<Sesion?> streamSesion;

  AuthCubit crear() => AuthCubit(
    iniciarSesion: IniciarSesionUseCase(repo),
    iniciarConGoogle: IniciarConGoogleUseCase(repo),
    registrarse: RegistrarseUseCase(repo),
    cerrarSesion: CerrarSesionUseCase(repo),
    observarSesion: ObservarSesionUseCase(repo),
    recuperarPassword: RecuperarPasswordUseCase(repo),
  );

  setUp(() {
    repo = _MockAuthRepository();
    streamSesion = StreamController<Sesion?>.broadcast();
    when(repo.observarSesion).thenAnswer((_) => streamSesion.stream);
  });

  tearDown(() => streamSesion.close());

  blocTest<AuthCubit, AuthState>(
    'el stream emite una sesion -> AuthAutenticado',
    build: crear,
    act: (_) => streamSesion.add(_sesionConductor),
    expect: () => <AuthState>[const AuthAutenticado(_usuarioConductor)],
  );

  blocTest<AuthCubit, AuthState>(
    'el stream emite null -> AuthNoAutenticado',
    build: crear,
    act: (_) => streamSesion.add(null),
    expect: () => <AuthState>[const AuthNoAutenticado()],
  );

  blocTest<AuthCubit, AuthState>(
    'iniciarSesion con fallo -> [Autenticando, Error, NoAutenticado]',
    build: crear,
    setUp: () {
      when(
        () => repo.iniciarSesion(
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenThrow(AuthFailure.credencialesInvalidas());
    },
    act: (AuthCubit cubit) =>
        cubit.iniciarSesion(correo: 'x@y.com', contrasena: 'mala'),
    expect: () => <Matcher>[
      isA<AuthAutenticando>(),
      isA<AuthError>().having(
        (AuthError e) => e.codigo,
        'codigo',
        AuthErrorCodigo.credencialesInvalidas.codigo,
      ),
      isA<AuthNoAutenticado>(),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'iniciarSesion OK -> Autenticando y luego Autenticado cuando el stream emite',
    build: crear,
    setUp: () {
      when(
        () => repo.iniciarSesion(
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenAnswer((_) async {
        streamSesion.add(_sesionConductor);
        return _sesionConductor;
      });
    },
    act: (AuthCubit cubit) => cubit.iniciarSesion(
      correo: 'conductor@optiruta.test',
      contrasena: 'Conductor123!',
    ),
    expect: () => <AuthState>[
      const AuthAutenticando(),
      const AuthAutenticado(_usuarioConductor),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'iniciarConGoogle OK -> no emite nada hasta que el stream traiga la sesion',
    build: crear,
    setUp: () {
      when(repo.iniciarConGoogle).thenAnswer((_) async {});
    },
    act: (AuthCubit cubit) => cubit.iniciarConGoogle(),
    expect: () => <AuthState>[],
    verify: (_) => verify(repo.iniciarConGoogle).called(1),
  );

  blocTest<AuthCubit, AuthState>(
    'iniciarConGoogle con fallo -> [Error, NoAutenticado]',
    build: crear,
    setUp: () {
      when(repo.iniciarConGoogle).thenThrow(AuthFailure.sinConexion());
    },
    act: (AuthCubit cubit) => cubit.iniciarConGoogle(),
    expect: () => <Matcher>[isA<AuthError>(), isA<AuthNoAutenticado>()],
  );

  blocTest<AuthCubit, AuthState>(
    'registrarse con sesion inmediata -> [Autenticando, Autenticado]',
    build: crear,
    setUp: () {
      when(
        () => repo.registrarse(
          nombre: any(named: 'nombre'),
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenAnswer((_) async {
        streamSesion.add(_sesionConductor);
        return _sesionConductor;
      });
    },
    act: (AuthCubit cubit) => cubit.registrarse(
      nombre: 'Nuevo Conductor',
      correo: 'nuevo@optiruta.test',
      contrasena: 'Conductor123!',
    ),
    expect: () => <AuthState>[
      const AuthAutenticando(),
      const AuthAutenticado(_usuarioConductor),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'registrarse pendiente de confirmacion -> [Autenticando, Error, NoAutenticado]',
    build: crear,
    setUp: () {
      when(
        () => repo.registrarse(
          nombre: any(named: 'nombre'),
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenAnswer((_) async => null);
    },
    act: (AuthCubit cubit) => cubit.registrarse(
      nombre: 'Nuevo Conductor',
      correo: 'nuevo@optiruta.test',
      contrasena: 'Conductor123!',
    ),
    expect: () => <Matcher>[
      isA<AuthAutenticando>(),
      isA<AuthError>().having(
        (AuthError e) => e.codigo,
        'codigo',
        'CONFIRMA_CORREO',
      ),
      isA<AuthNoAutenticado>(),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'registrarse con correo ya registrado -> Error CORREO_YA_REGISTRADO',
    build: crear,
    setUp: () {
      when(
        () => repo.registrarse(
          nombre: any(named: 'nombre'),
          correo: any(named: 'correo'),
          contrasena: any(named: 'contrasena'),
        ),
      ).thenThrow(AuthFailure.correoYaRegistrado());
    },
    act: (AuthCubit cubit) => cubit.registrarse(
      nombre: 'Nuevo Conductor',
      correo: 'dup@optiruta.test',
      contrasena: 'Conductor123!',
    ),
    expect: () => <Matcher>[
      isA<AuthAutenticando>(),
      isA<AuthError>().having(
        (AuthError e) => e.codigo,
        'codigo',
        AuthErrorCodigo.correoYaRegistrado.codigo,
      ),
      isA<AuthNoAutenticado>(),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'cerrarSesion -> el stream emite null -> AuthNoAutenticado',
    build: crear,
    setUp: () {
      when(() => repo.cerrarSesion()).thenAnswer((_) async {
        streamSesion.add(null);
      });
    },
    seed: () => const AuthAutenticado(_usuarioConductor),
    act: (AuthCubit cubit) => cubit.cerrarSesion(),
    expect: () => <AuthState>[const AuthNoAutenticado()],
  );
}
