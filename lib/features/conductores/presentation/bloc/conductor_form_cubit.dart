import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/tipo_pago.dart';
import '../../domain/usecases/actualizar_conductor_use_case.dart';
import '../../domain/usecases/crear_conductor_use_case.dart';
import '../../domain/usecases/listar_usuarios_disponibles_use_case.dart';
import 'conductor_form_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Alta/edicion de un conductor. `idExistente == null` => crear (requiere
/// elegir un usuario sin perfil); en edicion, `usuariosDisponibles` no se
/// carga porque el usuario ya esta fijado.
class ConductorFormCubit extends Cubit<ConductorFormState> {
  ConductorFormCubit({
    required CrearConductorUseCase crear,
    required ActualizarConductorUseCase actualizar,
    required ListarUsuariosDisponiblesUseCase listarUsuariosDisponibles,
    required bool esEdicion,
  }) : _crear = crear,
       _actualizar = actualizar,
       _listarUsuariosDisponibles = listarUsuariosDisponibles,
       super(const ConductorFormCargandoUsuarios()) {
    if (esEdicion) {
      emit(const ConductorFormListo());
    } else {
      _cargarUsuariosDisponibles();
    }
  }

  final CrearConductorUseCase _crear;
  final ActualizarConductorUseCase _actualizar;
  final ListarUsuariosDisponiblesUseCase _listarUsuariosDisponibles;

  Future<void> _cargarUsuariosDisponibles() async {
    try {
      final usuarios = await _listarUsuariosDisponibles();
      emit(ConductorFormListo(usuariosDisponibles: usuarios));
    } on CatalogoFailure catch (falla) {
      emit(ConductorFormError(falla.mensaje));
    }
  }

  Future<void> crear({
    required String usuarioId,
    required String licencia,
    required DateTime fechaVencimientoLicencia,
    required TipoPago tipoPago,
    required double porcentajeComision,
    required double sueldoBase,
  }) async {
    emit(const ConductorFormEnviando());
    try {
      await _crear(
        usuarioId: usuarioId,
        licencia: licencia,
        fechaVencimientoLicencia: fechaVencimientoLicencia,
        tipoPago: tipoPago,
        porcentajeComision: porcentajeComision,
        sueldoBase: sueldoBase,
      );
      emit(const ConductorFormExito());
    } on CatalogoFailure catch (falla) {
      emit(ConductorFormError(falla.mensaje));
    }
  }

  Future<void> actualizar({
    required String id,
    required String licencia,
    required DateTime fechaVencimientoLicencia,
    required TipoPago tipoPago,
    required double porcentajeComision,
    required double sueldoBase,
  }) async {
    emit(const ConductorFormEnviando());
    try {
      await _actualizar(
        id: id,
        licencia: licencia,
        fechaVencimientoLicencia: fechaVencimientoLicencia,
        tipoPago: tipoPago,
        porcentajeComision: porcentajeComision,
        sueldoBase: sueldoBase,
      );
      emit(const ConductorFormExito());
    } on CatalogoFailure catch (falla) {
      emit(ConductorFormError(falla.mensaje));
    }
  }
}
