import 'package:equatable/equatable.dart';

import 'estado_viaje.dart';

/// Viaje completo, tal como lo devuelve `viaje_crear`/`viaje_cambiar_estado`
/// (sin denormalizar nombres de cliente/vehículo/conductor: eso es
/// [ViajeResumen], para listados).
class Viaje extends Equatable {
  const Viaje({
    required this.id,
    required this.remision,
    required this.vehiculoId,
    required this.conductorId,
    required this.clienteId,
    required this.origen,
    required this.destino,
    required this.estado,
    required this.valorFlete,
    required this.valorAnticipo,
    required this.saldoPendiente,
    required this.fechaCreacion,
    this.fechaSalidaProgramada,
    this.distanciaEstimada,
    this.tiempoEstimadoMin,
    this.pesoCarga,
    this.fechaCierre,
  });

  final String id;
  final String remision;
  final String vehiculoId;
  final String conductorId;
  final String clienteId;
  final String origen;
  final String destino;
  final DateTime? fechaSalidaProgramada;
  final double? distanciaEstimada;
  final double? tiempoEstimadoMin;
  final double? pesoCarga;
  final EstadoViaje estado;
  final double valorFlete;
  final double valorAnticipo;
  final double saldoPendiente;
  final DateTime? fechaCierre;
  final DateTime fechaCreacion;

  @override
  List<Object?> get props => <Object?>[
    id,
    remision,
    vehiculoId,
    conductorId,
    clienteId,
    origen,
    destino,
    fechaSalidaProgramada,
    distanciaEstimada,
    tiempoEstimadoMin,
    pesoCarga,
    estado,
    valorFlete,
    valorAnticipo,
    saldoPendiente,
    fechaCierre,
    fechaCreacion,
  ];
}
