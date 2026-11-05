import '../../../vehiculos/domain/entities/tipo_vehiculo.dart';
import '../entities/checklist.dart';

/// Contrato del checklist pre-viaje. Las fallas se lanzan como
/// `CatalogoFailure`. Las reglas (ítems completos, falla con descripción,
/// bloqueo) las hacen cumplir las RPC `checklist_registrar` y `viaje_iniciar`.
abstract interface class ChecklistRepository {
  /// Ítems activos que aplican a [tipo], en el orden de la planilla.
  Future<List<ItemChecklist>> listarItems(TipoVehiculo tipo);

  /// Solo el conductor del viaje, con el viaje ASIGNADO.
  Future<ChecklistViaje> registrar({
    required String viajeId,
    required List<ItemChecklist> items,
    required List<RespuestaChecklist> respuestas,
    String? observaciones,
  });

  /// El checklist más reciente del viaje, o `null` si no tiene.
  Future<ChecklistViaje?> ultimoDelViaje(String viajeId);

  /// Solo administrador, con motivo.
  Future<void> autorizarSalida({
    required String viajeId,
    required String motivo,
  });
}
