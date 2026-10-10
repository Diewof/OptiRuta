import '../entities/costo_viaje.dart';

/// Contrato de acceso a `public.costo_viaje`. Lectura para Administrador y
/// Conductor (RLS a sus propios viajes); escritura limitada a
/// `actualizarValorReal`, el único campo que el conductor puede tocar
/// (trigger `costo_viaje_restringir_conductor`). No hay creación de filas
/// desde la app: las categorías de costo las crea el flujo de planeación del
/// viaje, no el conductor en campo.
abstract interface class CostoViajeRepository {
  Future<List<CostoViaje>> listarPorViaje(String viajeId);

  Future<CostoViaje> actualizarValorReal({
    required String costoId,
    required double valorReal,
  });
}
