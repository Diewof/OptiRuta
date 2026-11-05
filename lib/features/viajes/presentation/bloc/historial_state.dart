import 'package:equatable/equatable.dart';

import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/viaje_resumen.dart';

/// Un viaje del historial con su rentabilidad marginal ya resuelta (`null`
/// mientras se calcula o si el viaje no tiene costos registrados todavía).
class ViajeConRentabilidad extends Equatable {
  const ViajeConRentabilidad({required this.viaje, this.rentabilidad});

  final ViajeResumen viaje;
  final double? rentabilidad;

  ViajeConRentabilidad copiarCon({double? rentabilidad}) {
    return ViajeConRentabilidad(
      viaje: viaje,
      rentabilidad: rentabilidad ?? this.rentabilidad,
    );
  }

  @override
  List<Object?> get props => <Object?>[viaje, rentabilidad];
}

sealed class HistorialState extends Equatable {
  const HistorialState();

  @override
  List<Object?> get props => <Object?>[];
}

class HistorialCargando extends HistorialState {
  const HistorialCargando();
}

class HistorialError extends HistorialState {
  const HistorialError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class HistorialListo extends HistorialState {
  const HistorialListo({
    required this.viajes,
    required this.pagina,
    required this.hayMas,
    this.cargandoMas = false,
    this.filtroEstado,
  });

  final List<ViajeConRentabilidad> viajes;
  final int pagina;
  final bool hayMas;
  final bool cargandoMas;
  final EstadoViaje? filtroEstado;

  HistorialListo copiarCon({
    List<ViajeConRentabilidad>? viajes,
    int? pagina,
    bool? hayMas,
    bool? cargandoMas,
  }) {
    return HistorialListo(
      viajes: viajes ?? this.viajes,
      pagina: pagina ?? this.pagina,
      hayMas: hayMas ?? this.hayMas,
      cargandoMas: cargandoMas ?? this.cargandoMas,
      filtroEstado: filtroEstado,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    viajes,
    pagina,
    hayMas,
    cargandoMas,
    filtroEstado,
  ];
}
