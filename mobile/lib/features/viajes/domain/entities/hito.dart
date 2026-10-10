import 'package:equatable/equatable.dart';

import 'tipo_hito.dart';

/// Hito de un viaje, registrado por el conductor desde su celular (o
/// manualmente por el administrador vía `origen_dato = MANUAL`).
class Hito extends Equatable {
  const Hito({
    required this.id,
    required this.viajeId,
    required this.tipo,
    required this.fechaHora,
  });

  final String id;
  final String viajeId;
  final TipoHito tipo;
  final DateTime fechaHora;

  @override
  List<Object?> get props => <Object?>[id, viajeId, tipo, fechaHora];
}
