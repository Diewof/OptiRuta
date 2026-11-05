import 'package:equatable/equatable.dart';

import '../../../clientes/domain/entities/cliente.dart';
import '../../../conductores/domain/entities/conductor.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/ruta_estimada.dart';
import '../../domain/entities/viaje.dart';

sealed class AgendarViajeState extends Equatable {
  const AgendarViajeState();

  @override
  List<Object?> get props => <Object?>[];
}

class AgendarViajeCargando extends AgendarViajeState {
  const AgendarViajeCargando();
}

class AgendarViajeErrorCatalogos extends AgendarViajeState {
  const AgendarViajeErrorCatalogos(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class AgendarViajeListo extends AgendarViajeState {
  const AgendarViajeListo({
    required this.clientes,
    required this.vehiculos,
    required this.conductores,
    this.ruta,
    this.estimandoRuta = false,
    this.errorRuta,
    this.acpmEstimado,
    this.estimandoAcpm = false,
    this.errorAcpm,
    this.enviando = false,
    this.errorEnvio,
    this.avisosVehiculos = const <String, AvisoDisponibilidad>{},
    this.avisosConductores = const <String, AvisoDisponibilidad>{},
  });

  final List<Cliente> clientes;
  final List<Vehiculo> vehiculos;
  final List<Conductor> conductores;

  final RutaEstimada? ruta;
  final bool estimandoRuta;
  final String? errorRuta;

  final double? acpmEstimado;
  final bool estimandoAcpm;
  final String? errorAcpm;

  final bool enviando;
  final String? errorEnvio;

  /// Aviso de documentos y cruces por id, para la fecha elegida. Vacíos hasta
  /// que se elige la fecha.
  final Map<String, AvisoDisponibilidad> avisosVehiculos;
  final Map<String, AvisoDisponibilidad> avisosConductores;

  AgendarViajeListo copiarCon({
    RutaEstimada? ruta,
    bool limpiarRuta = false,
    bool? estimandoRuta,
    String? errorRuta,
    bool limpiarErrorRuta = false,
    double? acpmEstimado,
    bool limpiarAcpm = false,
    bool? estimandoAcpm,
    String? errorAcpm,
    bool limpiarErrorAcpm = false,
    bool? enviando,
    String? errorEnvio,
    bool limpiarErrorEnvio = false,
    Map<String, AvisoDisponibilidad>? avisosVehiculos,
    Map<String, AvisoDisponibilidad>? avisosConductores,
  }) {
    return AgendarViajeListo(
      clientes: clientes,
      vehiculos: vehiculos,
      conductores: conductores,
      ruta: limpiarRuta ? null : (ruta ?? this.ruta),
      estimandoRuta: estimandoRuta ?? this.estimandoRuta,
      errorRuta: limpiarErrorRuta ? null : (errorRuta ?? this.errorRuta),
      acpmEstimado: limpiarAcpm ? null : (acpmEstimado ?? this.acpmEstimado),
      estimandoAcpm: estimandoAcpm ?? this.estimandoAcpm,
      errorAcpm: limpiarErrorAcpm ? null : (errorAcpm ?? this.errorAcpm),
      enviando: enviando ?? this.enviando,
      errorEnvio: limpiarErrorEnvio ? null : (errorEnvio ?? this.errorEnvio),
      avisosVehiculos: avisosVehiculos ?? this.avisosVehiculos,
      avisosConductores: avisosConductores ?? this.avisosConductores,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    clientes,
    vehiculos,
    conductores,
    ruta,
    estimandoRuta,
    errorRuta,
    acpmEstimado,
    estimandoAcpm,
    errorAcpm,
    enviando,
    errorEnvio,
    avisosVehiculos,
    avisosConductores,
  ];
}

class AgendarViajeExito extends AgendarViajeState {
  const AgendarViajeExito(this.viaje);

  final Viaje viaje;

  @override
  List<Object?> get props => <Object?>[viaje];
}
