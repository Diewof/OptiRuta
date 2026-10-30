import 'package:equatable/equatable.dart';

/// Ajuste registrado sobre un viaje CERRADO (tabla append-only
/// `ajuste_viaje`), con motivo obligatorio. El flete y los costos originales
/// quedan congelados; el ajuste suma [monto] (diferencia firmada) al
/// [concepto] (`FLETE` o una categoría de costo) en la rentabilidad.
class AjusteViaje extends Equatable {
  const AjusteViaje({
    required this.id,
    required this.viajeId,
    required this.motivo,
    required this.fecha,
    this.campoModificado,
    this.valorAnterior,
    this.valorNuevo,
    this.concepto,
    this.monto,
  });

  final String id;
  final String viajeId;
  final String motivo;
  final DateTime fecha;
  final String? campoModificado;
  final String? valorAnterior;
  final String? valorNuevo;

  /// Nulos en los ajustes antiguos, que eran solo informativos.
  final String? concepto;
  final double? monto;

  @override
  List<Object?> get props => <Object?>[
    id,
    viajeId,
    motivo,
    fecha,
    campoModificado,
    valorAnterior,
    valorNuevo,
    concepto,
    monto,
  ];
}
