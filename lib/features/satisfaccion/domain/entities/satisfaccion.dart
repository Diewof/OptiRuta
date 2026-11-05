import 'package:equatable/equatable.dart';

import '../../../dashboard/domain/entities/metricas.dart';

/// Dimensiones que `satisfaccion_por_dimension` acepta. La encuesta no
/// registra la placa por separado, así que `PLACA` (que sí existe en las
/// métricas de rentabilidad) el servidor la rechaza.
const List<DimensionMetrica> dimensionesSatisfaccion = <DimensionMetrica>[
  DimensionMetrica.ruta,
  DimensionMetrica.cliente,
  DimensionMetrica.conductor,
];

/// Nivel de satisfacción para dibujar el semáforo. Umbrales (decisión del
/// dueño, 2026-10-12): CSAT verde ≥ 4,2; ámbar de 3,5 a 4,2; rojo < 3,5.
/// NPS verde ≥ 50; ámbar de 0 a 50; rojo < 0.
enum NivelSatisfaccion {
  bueno('Bueno'),
  regular('Regular'),
  bajo('Bajo'),
  sinDatos('Sin datos suficientes');

  const NivelSatisfaccion(this.etiqueta);

  final String etiqueta;

  static NivelSatisfaccion deCsat(double? csat) {
    if (csat == null) return NivelSatisfaccion.sinDatos;
    if (csat >= 4.2) return NivelSatisfaccion.bueno;
    if (csat >= 3.5) return NivelSatisfaccion.regular;
    return NivelSatisfaccion.bajo;
  }

  static NivelSatisfaccion deNps(double? nps) {
    if (nps == null) return NivelSatisfaccion.sinDatos;
    if (nps >= 50) return NivelSatisfaccion.bueno;
    if (nps >= 0) return NivelSatisfaccion.regular;
    return NivelSatisfaccion.bajo;
  }
}

/// Resultado de la RPC `satisfaccion_resumen` para el período y filtros.
class ResumenSatisfaccion extends Equatable {
  const ResumenSatisfaccion({
    required this.encuestasTotal,
    required this.respondidas,
    required this.pendientes,
    required this.sinContacto,
    required this.vencidas,
    required this.promotores,
    required this.pasivos,
    required this.detractores,
    required this.viajesMedidos,
    required this.viajesATiempo,
    required this.puntualidadPercibida,
    this.csatEntrega,
    this.csatServicio,
    this.csatAtencion,
    this.csatPuntualidad,
    this.csatGlobal,
    this.nps,
  });

  /// Con menos respuestas los promedios no se consideran representativos.
  static const int minimoRespuestas = 5;

  final int encuestasTotal;
  final int respondidas;
  final int pendientes;
  final int sinContacto;
  final int vencidas;
  final double? csatEntrega;
  final double? csatServicio;
  final double? csatAtencion;
  final double? csatPuntualidad;
  final double? csatGlobal;

  /// De -100 a 100.
  final double? nps;
  final int promotores;
  final int pasivos;
  final int detractores;

  /// Respuestas cuyo viaje tiene tiempos reales para compararlos con lo
  /// estimado, y cuántas llegaron dentro del margen.
  final int viajesMedidos;
  final int viajesATiempo;

  /// Respuestas que calificaron la puntualidad con 4 o 5.
  final int puntualidadPercibida;

  bool get hayDatosSuficientes => respondidas >= minimoRespuestas;

  /// % de encuestas respondidas sobre las generadas en el período.
  double? get tasaRespuestaPct =>
      encuestasTotal == 0 ? null : respondidas / encuestasTotal * 100;

  double? get puntualidadRealPct =>
      viajesMedidos == 0 ? null : viajesATiempo / viajesMedidos * 100;

  double? get puntualidadPercibidaPct =>
      respondidas == 0 ? null : puntualidadPercibida / respondidas * 100;

  @override
  List<Object?> get props => <Object?>[
    encuestasTotal,
    respondidas,
    pendientes,
    sinContacto,
    vencidas,
    csatEntrega,
    csatServicio,
    csatAtencion,
    csatPuntualidad,
    csatGlobal,
    nps,
    promotores,
    pasivos,
    detractores,
    viajesMedidos,
    viajesATiempo,
    puntualidadPercibida,
  ];
}

/// Una fila de `satisfaccion_por_dimension`: ruta, cliente o conductor.
class SatisfaccionDimension extends Equatable {
  const SatisfaccionDimension({
    required this.clave,
    required this.respondidas,
    this.csatGlobal,
    this.nps,
  });

  final String clave;
  final int respondidas;
  final double? csatGlobal;
  final double? nps;

  @override
  List<Object?> get props => <Object?>[clave, respondidas, csatGlobal, nps];
}

/// Un comentario de cliente (`satisfaccion_comentarios`).
class ComentarioSatisfaccion extends Equatable {
  const ComentarioSatisfaccion({
    required this.fechaRespuesta,
    required this.cliente,
    required this.conductor,
    required this.ruta,
    required this.csatGlobal,
    required this.nps,
    required this.comentario,
  });

  final DateTime fechaRespuesta;
  final String cliente;
  final String conductor;
  final String ruta;
  final double csatGlobal;
  final int nps;
  final String comentario;

  @override
  List<Object?> get props => <Object?>[
    fechaRespuesta,
    cliente,
    conductor,
    ruta,
    csatGlobal,
    nps,
    comentario,
  ];
}

/// Estado de la encuesta de un viaje (`encuesta_satisfaccion.estado`).
enum EstadoEncuesta {
  pendiente('PENDIENTE', 'Por enviar'),
  enviada('ENVIADA', 'Enviada, esperando respuesta'),
  respondida('RESPONDIDA', 'Respondida'),
  vencida('VENCIDA', 'Vencida sin respuesta'),
  sinContacto('SIN_CONTACTO', 'Cliente sin correo');

  const EstadoEncuesta(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static EstadoEncuesta desdeCodigo(String valor) =>
      EstadoEncuesta.values.firstWhere((EstadoEncuesta e) => e.codigo == valor);
}

/// La encuesta de un viaje finalizado, para el detalle del viaje.
class EncuestaViaje extends Equatable {
  const EncuestaViaje({
    required this.estado,
    this.enlace,
    this.destinatario,
    this.csatGlobal,
    this.nps,
  });

  final EstadoEncuesta estado;

  /// Enlace prellenado del formulario; lo guarda Apps Script al prepararla.
  final String? enlace;
  final String? destinatario;
  final double? csatGlobal;
  final int? nps;

  /// Se puede compartir a mano (WhatsApp) mientras nadie la haya respondido.
  bool get compartible =>
      enlace != null &&
      (estado == EstadoEncuesta.pendiente ||
          estado == EstadoEncuesta.enviada ||
          estado == EstadoEncuesta.sinContacto);

  @override
  List<Object?> get props => <Object?>[
    estado,
    enlace,
    destinatario,
    csatGlobal,
    nps,
  ];
}
