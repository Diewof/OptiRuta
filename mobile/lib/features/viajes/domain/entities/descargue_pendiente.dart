import 'package:equatable/equatable.dart';

/// Viaje ya FINALIZADO al que el conductor aún no le registró la salida del
/// descargue (RPC `viaje_descargue_pendiente`, últimas 24 h).
class DescarguePendiente extends Equatable {
  const DescarguePendiente({
    required this.viajeId,
    required this.destino,
    required this.cliente,
    required this.llegada,
  });

  final String viajeId;
  final String destino;
  final String cliente;
  final DateTime llegada;

  @override
  List<Object?> get props => <Object?>[viajeId, destino, cliente, llegada];
}
