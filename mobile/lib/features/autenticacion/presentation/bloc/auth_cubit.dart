import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/sesion.dart';
import '../../domain/errores/auth_failure.dart';
import '../../domain/usecases/cerrar_sesion_use_case.dart';
import '../../domain/usecases/iniciar_sesion_use_case.dart';
import '../../domain/usecases/observar_sesion_use_case.dart';
import '../../domain/usecases/recuperar_password_use_case.dart';
import '../../domain/usecases/registrarse_use_case.dart';
import 'auth_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el estado de autenticacion de la app.
///
/// La fuente de verdad del "estoy o no autenticado" es el stream
/// [ObservarSesionUseCase] (alimentado por Supabase Auth). [iniciarSesion],
/// [registrarse] y [cerrarSesion] solo disparan la operacion; la transicion a
/// autenticado/no-autenticado llega por el stream.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required IniciarSesionUseCase iniciarSesion,
    required RegistrarseUseCase registrarse,
    required CerrarSesionUseCase cerrarSesion,
    required ObservarSesionUseCase observarSesion,
    required RecuperarPasswordUseCase recuperarPassword,
  }) : _iniciarSesion = iniciarSesion,
       _registrarse = registrarse,
       _cerrarSesion = cerrarSesion,
       _observarSesion = observarSesion,
       _recuperarPassword = recuperarPassword,
       super(const AuthDesconocido()) {
    _suscripcion = _observarSesion().listen(
      _alCambiarSesion,
      onError: (_) {
        _ocupado = false;
        emit(const AuthNoAutenticado());
      },
    );
  }

  final IniciarSesionUseCase _iniciarSesion;
  final RegistrarseUseCase _registrarse;
  final CerrarSesionUseCase _cerrarSesion;
  final ObservarSesionUseCase _observarSesion;
  final RecuperarPasswordUseCase _recuperarPassword;

  StreamSubscription<Sesion?>? _suscripcion;
  bool _ocupado = false;

  void _alCambiarSesion(Sesion? sesion) {
    // No pisar el spinner de un login/registro en curso con un estado intermedio.
    if (_ocupado && sesion == null) return;
    _ocupado = false;
    emit(
      sesion == null
          ? const AuthNoAutenticado()
          : AuthAutenticado(sesion.usuario),
    );
  }

  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    _ocupado = true;
    emit(const AuthAutenticando());
    try {
      await _iniciarSesion(correo: correo, contrasena: contrasena);
      // El estado AuthAutenticado lo emite _alCambiarSesion via el stream.
    } on AuthFailure catch (falla) {
      _fallarOperacion(falla);
    } catch (_) {
      _fallarOperacion(AuthFailure.desconocido());
    }
  }

  Future<void> registrarse({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    _ocupado = true;
    emit(const AuthAutenticando());
    try {
      final Sesion? sesion = await _registrarse(
        nombre: nombre,
        correo: correo,
        contrasena: contrasena,
      );
      if (sesion == null) {
        // El proyecto exige confirmar el correo antes de entrar.
        _ocupado = false;
        emit(
          const AuthError(
            'CONFIRMA_CORREO',
            'Te enviamos un correo para confirmar tu cuenta. '
                'Confirmalo e inicia sesion.',
          ),
        );
        emit(const AuthNoAutenticado());
      }
      // Si hay sesion, AuthAutenticado llega por el stream.
    } on AuthFailure catch (falla) {
      _fallarOperacion(falla);
    } catch (_) {
      _fallarOperacion(AuthFailure.desconocido());
    }
  }

  /// Envia el correo de recuperacion. No cambia el estado de autenticacion:
  /// la pantalla muestra su propia confirmacion. Propaga `AuthFailure` (p. ej.
  /// sin conexion) para que la UI lo traduzca.
  Future<void> recuperarPassword({required String correo}) {
    return _recuperarPassword(correo: correo);
  }

  Future<void> cerrarSesion() async {
    try {
      await _cerrarSesion();
      // AuthNoAutenticado llega por el stream.
    } on AuthFailure catch (falla) {
      emit(AuthError.desde(falla));
    }
  }

  void _fallarOperacion(AuthFailure falla) {
    _ocupado = false;
    emit(AuthError.desde(falla));
    emit(const AuthNoAutenticado());
  }

  @override
  Future<void> close() {
    _suscripcion?.cancel();
    return super.close();
  }
}
