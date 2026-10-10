import 'package:equatable/equatable.dart';

sealed class VehiculoFormState extends Equatable {
  const VehiculoFormState();

  @override
  List<Object?> get props => <Object?>[];
}

class VehiculoFormInicial extends VehiculoFormState {
  const VehiculoFormInicial();
}

class VehiculoFormEnviando extends VehiculoFormState {
  const VehiculoFormEnviando();
}

class VehiculoFormExito extends VehiculoFormState {
  const VehiculoFormExito();
}

class VehiculoFormError extends VehiculoFormState {
  const VehiculoFormError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}
