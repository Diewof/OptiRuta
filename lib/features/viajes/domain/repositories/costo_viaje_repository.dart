import '../entities/costo_viaje.dart';

/// Contrato de acceso a `public.costo_viaje`. Lectura para Administrador y
/// Conductor (RLS a sus propios viajes); escritura limitada a
/// `actualizarValorReal`, el único campo que el conductor puede tocar sobre
/// filas existentes (trigger `costo_viaje_restringir_conductor`), y
/// `agregarOtro` para costos libres. Las categorías fijas las crea el flujo
/// de planeación del viaje.
abstract interface class CostoViajeRepository {
  Future<List<CostoViaje>> listarPorViaje(String viajeId);

  /// Agrega un costo adicional libre (RF-14): categoría OTRO con descripción.
  /// El conductor lo anota siempre como valor real (RLS) con estimado 0; el
  /// administrador puede fijar el estimado.
  Future<CostoViaje> agregarOtro({
    required String viajeId,
    required String descripcion,
    double valorEstimado = 0,
    double? valorReal,
  });

  /// Corrige el valor estimado de un costo (solo ADMINISTRADOR, RLS).
  Future<CostoViaje> actualizarEstimado({
    required String costoId,
    required double valorEstimado,
  });

  Future<CostoViaje> actualizarValorReal({
    required String costoId,
    required double valorReal,
  });
}
