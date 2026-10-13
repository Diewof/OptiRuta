import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/checklist.dart';
import '../../domain/usecases/checklist_use_cases.dart';

sealed class ChecklistViajeState extends Equatable {
  const ChecklistViajeState();

  @override
  List<Object?> get props => <Object?>[];
}

class ChecklistViajeCargando extends ChecklistViajeState {
  const ChecklistViajeCargando();
}

/// [checklist] nulo = el viaje no tiene checklist todavía.
class ChecklistViajeListo extends ChecklistViajeState {
  const ChecklistViajeListo(this.checklist);

  final ChecklistViaje? checklist;

  @override
  List<Object?> get props => <Object?>[checklist];
}

class ChecklistViajeError extends ChecklistViajeState {
  const ChecklistViajeError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// El checklist de un viaje visto por el administrador, con la acción de
/// autorizar la salida cuando quedó bloqueado por una falla crítica.
class ChecklistViajeCubit extends Cubit<ChecklistViajeState> {
  ChecklistViajeCubit({
    required String viajeId,
    required ObtenerChecklistViajeUseCase obtener,
    required AutorizarSalidaChecklistUseCase autorizar,
  }) : _viajeId = viajeId,
       _obtener = obtener,
       _autorizar = autorizar,
       super(const ChecklistViajeCargando()) {
    cargar();
  }

  final String _viajeId;
  final ObtenerChecklistViajeUseCase _obtener;
  final AutorizarSalidaChecklistUseCase _autorizar;

  Future<void> cargar() async {
    emit(const ChecklistViajeCargando());
    await _refrescar();
  }

  Future<void> _refrescar() async {
    try {
      emit(ChecklistViajeListo(await _obtener(_viajeId)));
    } on CatalogoFailure catch (falla) {
      emit(ChecklistViajeError(falla.mensaje));
    }
  }

  /// Relanza las fallas de escritura para que la hoja las muestre.
  Future<void> autorizarSalida(String motivo) async {
    await _autorizar(viajeId: _viajeId, motivo: motivo);
    await _refrescar();
  }
}
