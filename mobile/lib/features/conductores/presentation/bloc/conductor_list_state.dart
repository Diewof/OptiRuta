import 'package:equatable/equatable.dart';

import '../../domain/entities/conductor.dart';

sealed class ConductorListState extends Equatable {
  const ConductorListState();

  @override
  List<Object?> get props => <Object?>[];
}

class ConductorListCargando extends ConductorListState {
  const ConductorListCargando();
}

class ConductorListListo extends ConductorListState {
  const ConductorListListo({
    required this.conductores,
    required this.pagina,
    required this.hayMas,
    this.cargandoMas = false,
  });

  final List<Conductor> conductores;
  final int pagina;
  final bool hayMas;
  final bool cargandoMas;

  ConductorListListo copiarCon({
    List<Conductor>? conductores,
    int? pagina,
    bool? hayMas,
    bool? cargandoMas,
  }) {
    return ConductorListListo(
      conductores: conductores ?? this.conductores,
      pagina: pagina ?? this.pagina,
      hayMas: hayMas ?? this.hayMas,
      cargandoMas: cargandoMas ?? this.cargandoMas,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    conductores,
    pagina,
    hayMas,
    cargandoMas,
  ];
}

class ConductorListError extends ConductorListState {
  const ConductorListError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}
