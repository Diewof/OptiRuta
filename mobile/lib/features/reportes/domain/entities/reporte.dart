import 'package:equatable/equatable.dart';

/// Filtros del reporte de viajes (RF-27). Los nulos no filtran.
class FiltroReporte extends Equatable {
  const FiltroReporte({
    required this.desde,
    required this.hasta,
    this.clienteId,
    this.conductorId,
    this.vehiculoId,
    this.ruta,
  });

  final DateTime desde;
  final DateTime hasta;
  final String? clienteId;
  final String? conductorId;
  final String? vehiculoId;

  /// Texto contenido en «origen → destino».
  final String? ruta;

  FiltroReporte copiarCon({
    DateTime? desde,
    DateTime? hasta,
    String? Function()? clienteId,
    String? Function()? conductorId,
    String? Function()? vehiculoId,
    String? Function()? ruta,
  }) {
    return FiltroReporte(
      desde: desde ?? this.desde,
      hasta: hasta ?? this.hasta,
      clienteId: clienteId != null ? clienteId() : this.clienteId,
      conductorId: conductorId != null ? conductorId() : this.conductorId,
      vehiculoId: vehiculoId != null ? vehiculoId() : this.vehiculoId,
      ruta: ruta != null ? ruta() : this.ruta,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    desde,
    hasta,
    clienteId,
    conductorId,
    vehiculoId,
    ruta,
  ];
}

/// Un viaje cerrado del reporte. [aTiempo] es nulo si no hay hitos de salida
/// y llegada para medirlo.
class FilaReporte extends Equatable {
  const FilaReporte({
    required this.viajeId,
    required this.remision,
    required this.fechaCierre,
    required this.ruta,
    required this.cliente,
    required this.conductor,
    required this.placa,
    required this.km,
    required this.valorFlete,
    required this.costos,
    required this.rentabilidad,
    this.aTiempo,
  });

  final String viajeId;
  final String remision;
  final DateTime fechaCierre;
  final String ruta;
  final String cliente;
  final String conductor;
  final String placa;
  final double km;
  final double valorFlete;
  final double costos;
  final double rentabilidad;
  final bool? aTiempo;

  @override
  List<Object?> get props => <Object?>[
    viajeId,
    remision,
    fechaCierre,
    ruta,
    cliente,
    conductor,
    placa,
    km,
    valorFlete,
    costos,
    rentabilidad,
    aTiempo,
  ];
}

/// Totales de un conjunto de filas.
class TotalesReporte extends Equatable {
  const TotalesReporte({
    required this.viajes,
    required this.km,
    required this.valorFlete,
    required this.costos,
    required this.rentabilidad,
  });

  factory TotalesReporte.de(List<FilaReporte> filas) {
    return TotalesReporte(
      viajes: filas.length,
      km: filas.fold(0, (double a, FilaReporte f) => a + f.km),
      valorFlete: filas.fold(0, (double a, FilaReporte f) => a + f.valorFlete),
      costos: filas.fold(0, (double a, FilaReporte f) => a + f.costos),
      rentabilidad: filas.fold(
        0,
        (double a, FilaReporte f) => a + f.rentabilidad,
      ),
    );
  }

  final int viajes;
  final double km;
  final double valorFlete;
  final double costos;
  final double rentabilidad;

  @override
  List<Object?> get props => <Object?>[
    viajes,
    km,
    valorFlete,
    costos,
    rentabilidad,
  ];
}

/// Opción de un filtro (cliente, conductor o vehículo).
class OpcionFiltro extends Equatable {
  const OpcionFiltro(this.id, this.nombre);

  final String id;
  final String nombre;

  @override
  List<Object?> get props => <Object?>[id, nombre];
}

/// Opciones de los selectores de filtro.
class OpcionesReporte extends Equatable {
  const OpcionesReporte({
    this.clientes = const <OpcionFiltro>[],
    this.conductores = const <OpcionFiltro>[],
    this.vehiculos = const <OpcionFiltro>[],
  });

  final List<OpcionFiltro> clientes;
  final List<OpcionFiltro> conductores;
  final List<OpcionFiltro> vehiculos;

  @override
  List<Object?> get props => <Object?>[clientes, conductores, vehiculos];
}
