import 'package:equatable/equatable.dart';

import '../../domain/entities/conductor.dart';

sealed class MiConductorState extends Equatable {
  const MiConductorState();

  @override
  List<Object?> get props => <Object?>[];
}

class MiConductorCargando extends MiConductorState {
  const MiConductorCargando();
}

/// [conductor] es `null` cuando el administrador aun no le ha creado el
/// perfil operativo a este usuario.
class MiConductorListo extends MiConductorState {
  const MiConductorListo(this.conductor);

  final Conductor? conductor;

  @override
  List<Object?> get props => <Object?>[conductor];
}

class MiConductorError extends MiConductorState {
  const MiConductorError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}
