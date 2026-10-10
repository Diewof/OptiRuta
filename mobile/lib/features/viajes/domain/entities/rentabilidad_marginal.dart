import 'package:equatable/equatable.dart';

/// Resultado de la RPC `rentabilidad_marginal(p_viaje_id)`: valor_flete -
/// costos directos del viaje (sin mantenimiento amortizado).
class RentabilidadMarginal extends Equatable {
  const RentabilidadMarginal({
    required this.valorFlete,
    required this.costosTotales,
    required this.rentabilidad,
  });

  final double valorFlete;
  final double costosTotales;
  final double rentabilidad;

  @override
  List<Object?> get props => <Object?>[valorFlete, costosTotales, rentabilidad];
}
