import '../entities/documento_vehiculo.dart';
import '../entities/hoja_vida.dart';

/// Contrato de la hoja de vida del vehículo: documentos vigentes, plan de
/// mantenimiento y línea de tiempo. Solo ADMINISTRADOR (lo garantizan las RPC y
/// RLS). Las fallas se lanzan como `CatalogoFailure`.
abstract interface class HojaVidaRepository {
  Future<HojaVida> obtener(String vehiculoId);

  /// Renovar es registrar un documento nuevo: el vigente es el de mayor
  /// vencimiento y el anterior queda en el historial.
  Future<void> registrarDocumento({
    required String vehiculoId,
    required TipoDocumentoVehiculo tipo,
    required DateTime fechaVencimiento,
    String? numero,
    String? entidadEmisora,
    DateTime? fechaExpedicion,
  });
}
