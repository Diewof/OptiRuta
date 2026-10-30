import '../entities/descargue_pendiente.dart';
import '../entities/hito.dart';
import '../entities/tipo_hito.dart';

/// Contrato de acceso a `public.hito_viaje`: lectura para Administrador y
/// Conductor (RLS a sus propios viajes) y registro (`registrar`) exclusivo
/// del Conductor autenticado sobre sus propios viajes (RLS
/// `hito_viaje_insert_conductor_propio`).
abstract interface class HitoRepository {
  Future<List<Hito>> listarPorViaje(String viajeId);

  /// Registra un hito del viaje propio del conductor autenticado.
  /// [fechaHora] es el momento real en que ocurrió el hito, capturado por el
  /// conductor en campo (no la hora de envío al servidor).
  Future<Hito> registrar({
    required String viajeId,
    required TipoHito tipo,
    required DateTime fechaHora,
  });

  /// Viaje finalizado del conductor que espera la salida del descargue, o
  /// `null` si no hay ninguno.
  Future<DescarguePendiente?> descarguePendiente();
}
