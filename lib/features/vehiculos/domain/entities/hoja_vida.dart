import 'package:equatable/equatable.dart';

import 'documento_vehiculo.dart';

/// Tipo de evento de la línea de tiempo de la hoja de vida (RPC
/// `vehiculo_hoja_vida`).
enum TipoEventoHojaVida {
  viaje('VIAJE', 'Viaje'),
  mantenimiento('MANTENIMIENTO', 'Mantenimiento'),
  checklist('CHECKLIST', 'Checklist'),
  documento('DOCUMENTO', 'Documento');

  const TipoEventoHojaVida(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoEventoHojaVida desdeCodigo(String valor) {
    return switch (valor) {
      'VIAJE' => TipoEventoHojaVida.viaje,
      'MANTENIMIENTO' => TipoEventoHojaVida.mantenimiento,
      'CHECKLIST' => TipoEventoHojaVida.checklist,
      'DOCUMENTO' => TipoEventoHojaVida.documento,
      _ => throw ArgumentError.value(valor, 'valor', 'Evento no válido'),
    };
  }
}

class EventoHojaVida extends Equatable {
  const EventoHojaVida({
    required this.fecha,
    required this.tipo,
    required this.titulo,
    this.detalle,
    this.km,
  });

  final DateTime fecha;
  final TipoEventoHojaVida tipo;
  final String titulo;
  final String? detalle;
  final double? km;

  @override
  List<Object?> get props => <Object?>[fecha, tipo, titulo, detalle, km];
}

/// Qué tan cerca está un mantenimiento preventivo (RPC
/// `plan_mantenimiento_estado`). El servidor decide el estado.
enum EstadoPlanMantenimiento {
  alDia('AL_DIA', 'Al día'),
  proximo('PROXIMO', 'Próximo'),
  vencido('VENCIDO', 'Vencido');

  const EstadoPlanMantenimiento(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static EstadoPlanMantenimiento desdeCodigo(String valor) {
    return switch (valor) {
      'AL_DIA' => EstadoPlanMantenimiento.alDia,
      'PROXIMO' => EstadoPlanMantenimiento.proximo,
      'VENCIDO' => EstadoPlanMantenimiento.vencido,
      _ => throw ArgumentError.value(valor, 'valor', 'Estado no válido'),
    };
  }
}

class ItemPlanMantenimiento extends Equatable {
  const ItemPlanMantenimiento({
    required this.tipoNombre,
    required this.estado,
    this.intervaloKm,
    this.intervaloDias,
    this.ultimoFecha,
    this.kmRestantes,
    this.diasRestantes,
  });

  final String tipoNombre;
  final EstadoPlanMantenimiento estado;
  final double? intervaloKm;
  final int? intervaloDias;
  final DateTime? ultimoFecha;

  /// Negativo si ya se pasó del intervalo.
  final double? kmRestantes;
  final int? diasRestantes;

  @override
  List<Object?> get props => <Object?>[
    tipoNombre,
    estado,
    intervaloKm,
    intervaloDias,
    ultimoFecha,
    kmRestantes,
    diasRestantes,
  ];
}

/// Odómetro (aproximado, derivado del GPS) y estado de los dos documentos.
class ResumenVehiculo extends Equatable {
  const ResumenVehiculo({required this.odometroKm, this.soat, this.rtm});

  final double odometroKm;
  final DocumentoVehiculo? soat;
  final DocumentoVehiculo? rtm;

  @override
  List<Object?> get props => <Object?>[odometroKm, soat, rtm];
}

/// Todo lo que muestra la pantalla de hoja de vida de un vehículo.
class HojaVida extends Equatable {
  const HojaVida({
    required this.odometroKm,
    required this.documentos,
    required this.plan,
    required this.eventos,
  });

  final double odometroKm;

  /// Los documentos vigentes (uno por tipo registrado).
  final List<DocumentoVehiculo> documentos;
  final List<ItemPlanMantenimiento> plan;
  final List<EventoHojaVida> eventos;

  DocumentoVehiculo? documento(TipoDocumentoVehiculo tipo) {
    for (final DocumentoVehiculo d in documentos) {
      if (d.tipo == tipo) return d;
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[odometroKm, documentos, plan, eventos];
}
