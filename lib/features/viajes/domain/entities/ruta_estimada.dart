import 'package:equatable/equatable.dart';

/// Resultado de la Edge Function `rutas`: distancia y tiempo estimados por
/// carretera entre origen y destino (proveedor externo, no vive en Postgres),
/// más el trazado codificado para dibujarlo en el mapa.
class RutaEstimada extends Equatable {
  const RutaEstimada({
    required this.distanciaKm,
    required this.duracionMin,
    this.polilinea = '',
  });

  final double distanciaKm;
  final double duracionMin;

  /// Polilínea codificada (precisión 5) tal como la entrega el proveedor.
  final String polilinea;

  @override
  List<Object?> get props => <Object?>[distanciaKm, duracionMin, polilinea];
}
