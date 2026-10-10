import 'package:equatable/equatable.dart';

import '../../domain/entities/vehiculo.dart';

sealed class VehiculoListState extends Equatable {
  const VehiculoListState();

  @override
  List<Object?> get props => <Object?>[];
}

class VehiculoListCargando extends VehiculoListState {
  const VehiculoListCargando();
}

class VehiculoListListo extends VehiculoListState {
  const VehiculoListListo({
    required this.vehiculos,
    required this.pagina,
    required this.hayMas,
    this.cargandoMas = false,
  });

  final List<Vehiculo> vehiculos;
  final int pagina;
  final bool hayMas;
  final bool cargandoMas;

  VehiculoListListo copiarCon({
    List<Vehiculo>? vehiculos,
    int? pagina,
    bool? hayMas,
    bool? cargandoMas,
  }) {
    return VehiculoListListo(
      vehiculos: vehiculos ?? this.vehiculos,
      pagina: pagina ?? this.pagina,
      hayMas: hayMas ?? this.hayMas,
      cargandoMas: cargandoMas ?? this.cargandoMas,
    );
  }

  @override
  List<Object?> get props => <Object?>[vehiculos, pagina, hayMas, cargandoMas];
}

class VehiculoListError extends VehiculoListState {
  const VehiculoListError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}
