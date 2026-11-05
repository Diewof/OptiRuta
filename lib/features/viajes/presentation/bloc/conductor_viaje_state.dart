import 'package:equatable/equatable.dart';

import '../../../checklist/domain/entities/checklist.dart';
import '../../domain/entities/costo_viaje.dart';
import '../../domain/entities/descargue_pendiente.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/viaje_resumen.dart';

sealed class ConductorViajeState extends Equatable {
  const ConductorViajeState();

  @override
  List<Object?> get props => <Object?>[];
}

class ConductorViajeCargando extends ConductorViajeState {
  const ConductorViajeCargando();
}

class ConductorViajeError extends ConductorViajeState {
  const ConductorViajeError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

/// Sin viaje ASIGNADO/EN_CURSO para el conductor autenticado (RLS ya filtra
/// a sus propios viajes). Si acaba de llegar a destino y aún no registró la
/// salida del descargue, [descarguePendiente] lo ofrece en Inicio.
class ConductorViajeSinAsignar extends ConductorViajeState {
  const ConductorViajeSinAsignar({
    this.descarguePendiente,
    this.procesando = false,
  });

  final DescarguePendiente? descarguePendiente;
  final bool procesando;

  ConductorViajeSinAsignar copiarCon({bool? procesando}) {
    return ConductorViajeSinAsignar(
      descarguePendiente: descarguePendiente,
      procesando: procesando ?? this.procesando,
    );
  }

  @override
  List<Object?> get props => <Object?>[descarguePendiente, procesando];
}

class ConductorViajeListo extends ConductorViajeState {
  const ConductorViajeListo({
    required this.viaje,
    required this.hitos,
    required this.costos,
    this.checklist,
    this.procesando = false,
  });

  final ViajeResumen viaje;

  final List<Hito> hitos;
  final List<CostoViaje> costos;

  /// Checklist más reciente del viaje; solo se consulta con el viaje
  /// ASIGNADO (antes de salir). Nulo = todavía no lo hizo.
  final ChecklistViaje? checklist;

  /// `true` mientras una acción de escritura (registrar hito, confirmar
  /// valor real) está en vuelo, para deshabilitar el control que la disparó.
  final bool procesando;

  ConductorViajeListo copiarCon({bool? procesando}) {
    return ConductorViajeListo(
      viaje: viaje,
      hitos: hitos,
      costos: costos,
      checklist: checklist,
      procesando: procesando ?? this.procesando,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    viaje,
    hitos,
    costos,
    checklist,
    procesando,
  ];
}
