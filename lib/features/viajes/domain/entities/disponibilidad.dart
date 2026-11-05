import 'package:equatable/equatable.dart';

import '../../../../core/utils/fecha_utils.dart';
import '../../../conductores/domain/entities/conductor.dart';
import '../../../vehiculos/domain/entities/documento_vehiculo.dart';
import '../../../vehiculos/domain/entities/hoja_vida.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import 'estado_viaje.dart';
import 'viaje_resumen.dart';

/// Qué tan conveniente es asignar un vehículo o conductor a una salida.
/// Solo orienta a quien agenda: crear el viaje nunca se bloquea y la regla
/// real de «no sale con SOAT/tecnomecánica vencidos» vive en `viaje_iniciar`.
enum NivelAviso { ninguno, aviso, critico }

class AvisoDisponibilidad extends Equatable {
  const AvisoDisponibilidad(this.nivel, [this.mensaje]);

  static const AvisoDisponibilidad libre = AvisoDisponibilidad(
    NivelAviso.ninguno,
  );

  final NivelAviso nivel;
  final String? mensaje;

  @override
  List<Object?> get props => <Object?>[nivel, mensaje];
}

/// Horas que se asumen para un viaje sin tiempo estimado.
const int _minutosPorDefecto = 12 * 60;
const int _diasPorVencer = 30;

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

/// Viaje abierto de [placa] o [conductor] que se cruza con el día de [salida].
ViajeResumen? _cruce(
  Iterable<ViajeResumen> viajes,
  DateTime salida,
  bool Function(ViajeResumen) mismoRecurso,
) {
  final DateTime ini = _dia(salida);
  final DateTime fin = ini.add(const Duration(days: 1));
  for (final ViajeResumen v in viajes) {
    final bool abierto =
        v.estado == EstadoViaje.planificado ||
        v.estado == EstadoViaje.asignado ||
        v.estado == EstadoViaje.enCurso;
    final DateTime? inicio = v.fechaSalidaProgramada;
    if (!abierto || inicio == null || !mismoRecurso(v)) continue;
    final DateTime termina = inicio.add(
      Duration(minutes: (v.tiempoEstimadoMin ?? _minutosPorDefecto).round()),
    );
    if (inicio.isBefore(fin) && termina.isAfter(ini)) return v;
  }
  return null;
}

AvisoDisponibilidad _ocupado(ViajeResumen v) => AvisoDisponibilidad(
  NivelAviso.aviso,
  'Ocupado: ${v.origen} → ${v.destino} '
  '(${formatearFecha(v.fechaSalidaProgramada!)})',
);

AvisoDisponibilidad? _avisoDocumento(
  HojaVida hoja,
  TipoDocumentoVehiculo tipo,
  DateTime salida,
) {
  final DocumentoVehiculo? doc = hoja.documento(tipo);
  if (doc == null) {
    return AvisoDisponibilidad(
      NivelAviso.critico,
      'Sin ${tipo.etiqueta} registrado: no podrá salir',
    );
  }
  final DateTime vence = _dia(doc.fechaVencimiento);
  final DateTime dia = _dia(salida);
  if (vence.isBefore(dia)) {
    return AvisoDisponibilidad(
      NivelAviso.critico,
      '${tipo.etiqueta} vence el ${formatearFecha(vence)}: no podrá salir',
    );
  }
  if (vence.difference(dia).inDays <= _diasPorVencer) {
    return AvisoDisponibilidad(
      NivelAviso.aviso,
      '${tipo.etiqueta} vence el ${formatearFecha(vence)}',
    );
  }
  return null;
}

/// Revisa documentos (si se conoce la [hoja] de vida) y cruces de agenda.
AvisoDisponibilidad avisoVehiculo({
  required Vehiculo vehiculo,
  required HojaVida? hoja,
  required List<ViajeResumen> viajes,
  required DateTime salida,
}) {
  final List<AvisoDisponibilidad> avisos = <AvisoDisponibilidad>[
    if (hoja != null)
      for (final TipoDocumentoVehiculo t in TipoDocumentoVehiculo.values)
        ?_avisoDocumento(hoja, t, salida),
  ];
  final ViajeResumen? cruce = _cruce(
    viajes,
    salida,
    (ViajeResumen v) => v.placaVehiculo == vehiculo.placa,
  );
  if (cruce != null) avisos.add(_ocupado(cruce));
  return _masGrave(avisos);
}

AvisoDisponibilidad avisoConductor({
  required Conductor conductor,
  required List<ViajeResumen> viajes,
  required DateTime salida,
}) {
  final List<AvisoDisponibilidad> avisos = <AvisoDisponibilidad>[];
  final DateTime vence = _dia(conductor.fechaVencimientoLicencia);
  final DateTime dia = _dia(salida);
  if (vence.isBefore(dia)) {
    avisos.add(
      AvisoDisponibilidad(
        NivelAviso.critico,
        'Licencia vencida el ${formatearFecha(vence)}',
      ),
    );
  } else if (vence.difference(dia).inDays <= _diasPorVencer) {
    avisos.add(
      AvisoDisponibilidad(
        NivelAviso.aviso,
        'Licencia vence el ${formatearFecha(vence)}',
      ),
    );
  }
  final ViajeResumen? cruce = _cruce(
    viajes,
    salida,
    (ViajeResumen v) => v.nombreConductor == conductor.nombre,
  );
  if (cruce != null) avisos.add(_ocupado(cruce));
  return _masGrave(avisos);
}

AvisoDisponibilidad _masGrave(List<AvisoDisponibilidad> avisos) {
  if (avisos.isEmpty) return AvisoDisponibilidad.libre;
  return avisos.reduce(
    (AvisoDisponibilidad a, AvisoDisponibilidad b) =>
        b.nivel.index > a.nivel.index ? b : a,
  );
}
