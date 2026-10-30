import 'package:equatable/equatable.dart';

import '../../domain/entities/espera_cliente.dart';

sealed class EsperasState extends Equatable {
  const EsperasState();

  @override
  List<Object?> get props => <Object?>[];
}

class EsperasCargando extends EsperasState {
  const EsperasCargando();
}

class EsperasError extends EsperasState {
  const EsperasError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class EsperasListo extends EsperasState {
  const EsperasListo({required this.mes, required this.clientes});

  /// Primer día del mes mostrado.
  final DateTime mes;
  final List<EsperaCliente> clientes;

  @override
  List<Object?> get props => <Object?>[mes, clientes];
}
