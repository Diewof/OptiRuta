import '../entities/documento_vehiculo.dart';
import '../repositories/hoja_vida_repository.dart';

/// Registra (o renueva) el SOAT o la tecnomecánica. Higiene del dato antes de
/// enviarlo; la regla real de vigencia la hace cumplir `viaje_iniciar`.
class RegistrarDocumentoVehiculoUseCase {
  const RegistrarDocumentoVehiculoUseCase(this._repositorio);

  final HojaVidaRepository _repositorio;

  Future<void> call({
    required String vehiculoId,
    required TipoDocumentoVehiculo tipo,
    required DateTime fechaVencimiento,
    String? numero,
    String? entidadEmisora,
    DateTime? fechaExpedicion,
  }) {
    if (fechaExpedicion != null && fechaExpedicion.isAfter(fechaVencimiento)) {
      throw ArgumentError.value(
        fechaExpedicion,
        'fechaExpedicion',
        'La expedición no puede ser posterior al vencimiento.',
      );
    }
    return _repositorio.registrarDocumento(
      vehiculoId: vehiculoId,
      tipo: tipo,
      fechaVencimiento: fechaVencimiento,
      numero: _limpio(numero),
      entidadEmisora: _limpio(entidadEmisora),
      fechaExpedicion: fechaExpedicion,
    );
  }

  static String? _limpio(String? texto) {
    final String? limpio = texto?.trim();
    return limpio == null || limpio.isEmpty ? null : limpio;
  }
}
