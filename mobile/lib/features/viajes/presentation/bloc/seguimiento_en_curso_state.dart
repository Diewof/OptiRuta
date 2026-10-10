import 'package:equatable/equatable.dart';

import '../../domain/entities/hito.dart';
import '../../domain/entities/tipo_hito.dart';
import '../../domain/entities/viaje_resumen.dart';

/// Un viaje activo (ASIGNADO/EN_CURSO) con sus hitos ya cargados, para el
/// stepper de Seguimiento. `retraso` compara el hito SALIDA + el tiempo
/// estimado contra la hora actual (misma regla que `notificacion_generar`
/// en Postgres, replicada aquí solo para el indicador visual inmediato).
class ViajeActivo extends Equatable {
  const ViajeActivo({
    required this.viaje,
    required this.hitos,
    required this.retraso,
  });

  final ViajeResumen viaje;
  final List<Hito> hitos;
  final bool retraso;

  static bool calcularRetraso(ViajeResumen viaje, List<Hito> hitos) {
    if (viaje.tiempoEstimadoMin == null) return false;
    final bool yaLlego = hitos.any(
      (Hito h) => h.tipo == TipoHito.llegadaDestino,
    );
    if (yaLlego) return false;
    Hito? salida;
    for (final Hito h in hitos) {
      if (h.tipo == TipoHito.salida) salida = h;
    }
    if (salida == null) return false;
    final DateTime estimadaLlegada = salida.fechaHora.add(
      Duration(minutes: viaje.tiempoEstimadoMin!.round()),
    );
    return DateTime.now().isAfter(estimadaLlegada);
  }

  @override
  List<Object?> get props => <Object?>[viaje, hitos, retraso];
}

sealed class SeguimientoEnCursoState extends Equatable {
  const SeguimientoEnCursoState();

  @override
  List<Object?> get props => <Object?>[];
}

class SeguimientoEnCursoCargando extends SeguimientoEnCursoState {
  const SeguimientoEnCursoCargando();
}

class SeguimientoEnCursoError extends SeguimientoEnCursoState {
  const SeguimientoEnCursoError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class SeguimientoEnCursoListo extends SeguimientoEnCursoState {
  const SeguimientoEnCursoListo(this.viajes);

  final List<ViajeActivo> viajes;

  @override
  List<Object?> get props => <Object?>[viajes];
}
