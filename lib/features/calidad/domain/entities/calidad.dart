import 'package:equatable/equatable.dart';

/// Nivel de una dimensión o del viaje. Los umbrales los fija el servidor
/// (`viaje_calidad_calcular`); la app solo los dibuja.
enum NivelCalidad {
  verde('VERDE', 'Conforme'),
  ambar('AMBAR', 'Con mejoras'),
  rojo('ROJO', 'Con observación');

  const NivelCalidad(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  /// Nivel de un puntaje promedio de 0 a 100, con los mismos cortes del
  /// servidor (75 / 40). Solo para pintar promedios que la RPC no clasifica.
  static NivelCalidad? dePuntaje(double? puntaje) {
    if (puntaje == null) return null;
    if (puntaje >= 75) return NivelCalidad.verde;
    if (puntaje >= 40) return NivelCalidad.ambar;
    return NivelCalidad.rojo;
  }

  static NivelCalidad? desdeCodigo(String? codigo) {
    for (final NivelCalidad n in NivelCalidad.values) {
      if (n.codigo == codigo) return n;
    }
    return null;
  }
}

/// Calificación de un viaje: 4 dimensiones calculadas con datos del viaje.
/// Una dimensión `null` no se pudo medir (sin hitos, sin encuesta, etc.).
class CalidadViaje extends Equatable {
  const CalidadViaje({
    this.puntualidad,
    this.minutosRetraso,
    this.rentabilidad,
    this.desvioCostosPct,
    this.categoriaMayorDesvio,
    this.satisfaccion,
    this.csatPromedio,
    this.incidencias,
    this.incidenciasTotal = 0,
    this.puntaje,
    this.nivel,
  });

  final NivelCalidad? puntualidad;
  final double? minutosRetraso;
  final NivelCalidad? rentabilidad;
  final double? desvioCostosPct;
  final String? categoriaMayorDesvio;
  final NivelCalidad? satisfaccion;
  final double? csatPromedio;
  final NivelCalidad? incidencias;
  final int incidenciasTotal;

  /// De 0 a 100; nulo si ninguna dimensión se pudo medir.
  final double? puntaje;
  final NivelCalidad? nivel;

  @override
  List<Object?> get props => <Object?>[
    puntualidad,
    minutosRetraso,
    rentabilidad,
    desvioCostosPct,
    categoriaMayorDesvio,
    satisfaccion,
    csatPromedio,
    incidencias,
    incidenciasTotal,
    puntaje,
    nivel,
  ];
}

/// Cifras del período de `calidad_resumen`.
class ResumenCalidad extends Equatable {
  const ResumenCalidad({
    required this.viajesEvaluados,
    required this.verdes,
    required this.ambares,
    required this.rojos,
    required this.puntualidadRojos,
    required this.rentabilidadRojos,
    required this.satisfaccionRojos,
    required this.incidenciasRojos,
    this.puntajePromedio,
  });

  final int viajesEvaluados;
  final int verdes;
  final int ambares;
  final int rojos;
  final double? puntajePromedio;
  final int puntualidadRojos;
  final int rentabilidadRojos;
  final int satisfaccionRojos;
  final int incidenciasRojos;

  /// % de viajes conformes (verdes) sobre los evaluados.
  double? get conformesPct =>
      viajesEvaluados == 0 ? null : verdes / viajesEvaluados * 100;

  @override
  List<Object?> get props => <Object?>[
    viajesEvaluados,
    verdes,
    ambares,
    rojos,
    puntajePromedio,
    puntualidadRojos,
    rentabilidadRojos,
    satisfaccionRojos,
    incidenciasRojos,
  ];
}

/// Eje del ranking de calidad.
enum DimensionCalidad {
  ruta('RUTA', 'Ruta'),
  conductor('CONDUCTOR', 'Conductor'),
  vehiculo('VEHICULO', 'Placa');

  const DimensionCalidad(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;
}

/// Una fila de `calidad_por_dimension`.
class CalidadDimension extends Equatable {
  const CalidadDimension({
    required this.clave,
    required this.viajes,
    required this.rojos,
    required this.puntualidadRojos,
    required this.rentabilidadRojos,
    required this.satisfaccionRojos,
    required this.incidenciasRojos,
    this.puntajePromedio,
  });

  final String clave;
  final int viajes;
  final double? puntajePromedio;
  final int rojos;
  final int puntualidadRojos;
  final int rentabilidadRojos;
  final int satisfaccionRojos;
  final int incidenciasRojos;

  @override
  List<Object?> get props => <Object?>[
    clave,
    viajes,
    puntajePromedio,
    rojos,
    puntualidadRojos,
    rentabilidadRojos,
    satisfaccionRojos,
    incidenciasRojos,
  ];
}

/// Una fila de `calidad_recurrentes`: 3 o más viajes del mes con la misma
/// dimensión en rojo para un conductor, una placa o una ruta.
class AlertaRecurrente extends Equatable {
  const AlertaRecurrente({
    required this.entidad,
    required this.clave,
    required this.dimension,
    required this.viajes,
  });

  /// `CONDUCTOR`, `VEHICULO` o `RUTA`.
  final String entidad;
  final String clave;

  /// `PUNTUALIDAD`, `RENTABILIDAD`, `SATISFACCION` o `INCIDENCIAS`.
  final String dimension;
  final int viajes;

  /// Texto de la alerta para el administrador.
  String get mensaje {
    return switch ((entidad, dimension)) {
      ('VEHICULO', 'INCIDENCIAS') =>
        'Revisar hábitos de conducción en placa $clave',
      ('RUTA', 'RENTABILIDAD') => 'Ruta $clave con sobrecostos frecuentes',
      ('RUTA', 'PUNTUALIDAD') => 'Ruta $clave con retrasos frecuentes',
      (_, 'PUNTUALIDAD') => '${_sujeto()} con retrasos frecuentes',
      (_, 'RENTABILIDAD') => '${_sujeto()} con sobrecostos frecuentes',
      (_, 'SATISFACCION') => '${_sujeto()} con satisfacción baja frecuente',
      _ => '${_sujeto()} con incidencias frecuentes en ruta',
    };
  }

  String _sujeto() => switch (entidad) {
    'VEHICULO' => 'Placa $clave',
    'CONDUCTOR' => 'Conductor $clave',
    _ => 'Ruta $clave',
  };

  @override
  List<Object?> get props => <Object?>[entidad, clave, dimension, viajes];
}
