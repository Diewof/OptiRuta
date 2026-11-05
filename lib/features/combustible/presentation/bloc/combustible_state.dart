import 'package:equatable/equatable.dart';

import '../../domain/entities/rendimiento_combustible.dart';

sealed class CombustibleState extends Equatable {
  const CombustibleState();

  @override
  List<Object?> get props => <Object?>[];
}

class CombustibleCargando extends CombustibleState {
  const CombustibleCargando();
}

class CombustibleError extends CombustibleState {
  const CombustibleError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class CombustibleListo extends CombustibleState {
  const CombustibleListo({required this.mes, required this.porDimension});

  /// Primer día del mes mostrado.
  final DateTime mes;
  final Map<DimensionCombustible, List<RendimientoCombustible>> porDimension;

  @override
  List<Object?> get props => <Object?>[mes, porDimension];
}
