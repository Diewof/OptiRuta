import 'package:equatable/equatable.dart';

sealed class ClienteFormState extends Equatable {
  const ClienteFormState();

  @override
  List<Object?> get props => <Object?>[];
}

class ClienteFormInicial extends ClienteFormState {
  const ClienteFormInicial();
}

class ClienteFormEnviando extends ClienteFormState {
  const ClienteFormEnviando();
}

class ClienteFormExito extends ClienteFormState {
  const ClienteFormExito();
}

class ClienteFormError extends ClienteFormState {
  const ClienteFormError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}
