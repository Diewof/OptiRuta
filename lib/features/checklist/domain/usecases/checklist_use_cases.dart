import '../../../vehiculos/domain/entities/tipo_vehiculo.dart';
import '../entities/checklist.dart';
import '../repositories/checklist_repository.dart';

class ListarItemsChecklistUseCase {
  const ListarItemsChecklistUseCase(this._repositorio);

  final ChecklistRepository _repositorio;

  Future<List<ItemChecklist>> call(TipoVehiculo tipo) =>
      _repositorio.listarItems(tipo);
}

/// Registra el checklist. Validación de UX: toda falla lleva descripción; el
/// servidor vuelve a exigirlo.
class RegistrarChecklistUseCase {
  const RegistrarChecklistUseCase(this._repositorio);

  final ChecklistRepository _repositorio;

  Future<ChecklistViaje> call({
    required String viajeId,
    required List<ItemChecklist> items,
    required List<RespuestaChecklist> respuestas,
    String? observaciones,
  }) {
    for (final RespuestaChecklist r in respuestas) {
      if (r.falla && (r.observacion?.trim().isEmpty ?? true)) {
        throw ArgumentError.value(
          r.itemId,
          'respuestas',
          'Describe cada falla que marcaste.',
        );
      }
    }
    final String? nota = observaciones?.trim();
    return _repositorio.registrar(
      viajeId: viajeId,
      items: items,
      respuestas: respuestas,
      observaciones: nota == null || nota.isEmpty ? null : nota,
    );
  }
}

class ObtenerChecklistViajeUseCase {
  const ObtenerChecklistViajeUseCase(this._repositorio);

  final ChecklistRepository _repositorio;

  Future<ChecklistViaje?> call(String viajeId) =>
      _repositorio.ultimoDelViaje(viajeId);
}

class AutorizarSalidaChecklistUseCase {
  const AutorizarSalidaChecklistUseCase(this._repositorio);

  final ChecklistRepository _repositorio;

  Future<void> call({required String viajeId, required String motivo}) {
    final String limpio = motivo.trim();
    if (limpio.isEmpty) {
      throw ArgumentError.value(motivo, 'motivo', 'El motivo es obligatorio.');
    }
    return _repositorio.autorizarSalida(viajeId: viajeId, motivo: limpio);
  }
}
