import 'package:optiruta/features/checklist/domain/entities/checklist.dart';
import 'package:optiruta/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';

/// Doble para las pruebas de pantallas que solo necesitan que el viaje no
/// tenga checklist (detalle del administrador, home del conductor).
class SinChecklistRepository implements ChecklistRepository {
  const SinChecklistRepository();

  @override
  Future<ChecklistViaje?> ultimoDelViaje(String viajeId) async => null;

  @override
  Future<List<ItemChecklist>> listarItems(TipoVehiculo tipo) =>
      throw UnimplementedError();

  @override
  Future<ChecklistViaje> registrar({
    required String viajeId,
    required List<ItemChecklist> items,
    required List<RespuestaChecklist> respuestas,
    String? observaciones,
  }) => throw UnimplementedError();

  @override
  Future<void> autorizarSalida({
    required String viajeId,
    required String motivo,
  }) => throw UnimplementedError();
}
