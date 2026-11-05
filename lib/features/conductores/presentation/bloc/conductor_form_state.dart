import 'package:equatable/equatable.dart';

import '../../domain/entities/usuario_disponible.dart';

sealed class ConductorFormState extends Equatable {
  const ConductorFormState();

  @override
  List<Object?> get props => <Object?>[];
}

/// Solo aplica al alta: cargando la lista de usuarios sin perfil para el
/// selector. La edicion arranca directo en [ConductorFormListo].
class ConductorFormCargandoUsuarios extends ConductorFormState {
  const ConductorFormCargandoUsuarios();
}

class ConductorFormListo extends ConductorFormState {
  const ConductorFormListo({
    this.usuariosDisponibles = const <UsuarioDisponible>[],
  });

  final List<UsuarioDisponible> usuariosDisponibles;

  @override
  List<Object?> get props => <Object?>[usuariosDisponibles];
}

class ConductorFormEnviando extends ConductorFormState {
  const ConductorFormEnviando();
}

class ConductorFormExito extends ConductorFormState {
  const ConductorFormExito();
}

class ConductorFormError extends ConductorFormState {
  const ConductorFormError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}
