import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/usecases/obtener_mi_conductor_use_case.dart';
import 'mi_conductor_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

class MiConductorCubit extends Cubit<MiConductorState> {
  MiConductorCubit({
    required ObtenerMiConductorUseCase obtenerMiConductor,
    required String usuarioId,
  }) : _obtenerMiConductor = obtenerMiConductor,
       _usuarioId = usuarioId,
       super(const MiConductorCargando()) {
    cargar();
  }

  final ObtenerMiConductorUseCase _obtenerMiConductor;
  final String _usuarioId;

  Future<void> cargar() async {
    emit(const MiConductorCargando());
    try {
      final conductor = await _obtenerMiConductor(_usuarioId);
      emit(MiConductorListo(conductor));
    } on CatalogoFailure catch (falla) {
      emit(MiConductorError(falla.mensaje));
    }
  }
}
