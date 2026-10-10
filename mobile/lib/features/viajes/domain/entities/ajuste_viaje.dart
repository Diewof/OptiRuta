import 'package:equatable/equatable.dart';

/// Ajuste registrado sobre un viaje CERRADO (tabla append-only
/// `ajuste_viaje`). Es un registro auditable con motivo obligatorio: no
/// modifica los costos del viaje, que quedan congelados al cerrarlo.
class AjusteViaje extends Equatable {
  const AjusteViaje({
    required this.id,
    required this.viajeId,
    required this.motivo,
    required this.fecha,
    this.campoModificado,
    this.valorAnterior,
    this.valorNuevo,
  });

  final String id;
  final String viajeId;
  final String motivo;
  final DateTime fecha;
  final String? campoModificado;
  final String? valorAnterior;
  final String? valorNuevo;

  @override
  List<Object?> get props => <Object?>[
    id,
    viajeId,
    motivo,
    fecha,
    campoModificado,
    valorAnterior,
    valorNuevo,
  ];
}
