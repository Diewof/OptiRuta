import 'package:equatable/equatable.dart';

import '../../../vehiculos/domain/entities/tipo_vehiculo.dart';
import 'coordenada.dart';
import 'estado_viaje.dart';

/// Fila de listado de viaje (Calendario, Seguimiento, Historial): datos
/// denormalizados por PostgREST resource embedding (placa, nombre de
/// conductor y de cliente) para no armar el join a mano en la app.
class ViajeResumen extends Equatable {
  const ViajeResumen({
    required this.id,
    required this.remision,
    required this.origen,
    required this.destino,
    required this.estado,
    required this.placaVehiculo,
    required this.nombreConductor,
    required this.nombreCliente,
    required this.fechaCreacion,
    this.fechaSalidaProgramada,
    this.tiempoEstimadoMin,
    this.distanciaEstimada,
    this.pesoCarga,
    this.tipoVehiculo,
    this.origenCoordenada,
    this.destinoCoordenada,
    this.rutaPolilinea,
  });

  final String id;
  final String remision;
  final String origen;
  final String destino;
  final EstadoViaje estado;
  final String placaVehiculo;
  final String nombreConductor;
  final String nombreCliente;
  final DateTime? fechaSalidaProgramada;
  final DateTime fechaCreacion;

  /// Minutos estimados de ruta; para detectar retraso en Seguimiento
  /// (comparando el hito SALIDA + este valor contra la hora actual).
  final double? tiempoEstimadoMin;

  final double? distanciaEstimada;
  final double? pesoCarga;

  /// Tipo del vehículo asignado (para la miniatura de marca).
  final TipoVehiculo? tipoVehiculo;

  /// Ubicaciones elegidas en el mapa y trazado de la ruta estimada. Nulos en
  /// los viajes anteriores a los mapas: ahí se muestra la figura estática.
  final Coordenada? origenCoordenada;
  final Coordenada? destinoCoordenada;
  final String? rutaPolilinea;

  bool get tieneMapa => origenCoordenada != null && destinoCoordenada != null;

  @override
  List<Object?> get props => <Object?>[
    id,
    remision,
    origen,
    destino,
    estado,
    placaVehiculo,
    nombreConductor,
    nombreCliente,
    fechaSalidaProgramada,
    fechaCreacion,
    tiempoEstimadoMin,
    distanciaEstimada,
    pesoCarga,
    tipoVehiculo,
    origenCoordenada,
    destinoCoordenada,
    rutaPolilinea,
  ];
}
