import 'package:equatable/equatable.dart';

import '../../domain/entities/coordenada.dart';
import '../../domain/entities/tipo_alerta_viaje.dart';

sealed class MonitorRutaState extends Equatable {
  const MonitorRutaState();

  @override
  List<Object?> get props => <Object?>[];
}

/// Pidiendo el permiso o esperando la primera posición.
class MonitorRutaIniciando extends MonitorRutaState {
  const MonitorRutaIniciando();
}

/// Sin permiso de ubicación: el mapa sigue mostrando la ruta, sin marcador.
class MonitorRutaSinPermiso extends MonitorRutaState {
  const MonitorRutaSinPermiso({required this.bloqueado});

  /// `true` si hay que ir a los ajustes del sistema (negado para siempre o
  /// GPS apagado).
  final bool bloqueado;

  @override
  List<Object?> get props => <Object?>[bloqueado];
}

class MonitorRutaActivo extends MonitorRutaState {
  const MonitorRutaActivo({
    this.posicion,
    this.alerta,
    this.consentimientoPendiente = false,
    this.registrando = false,
    this.pausaActiva = false,
  });

  final Coordenada? posicion;

  /// El conductor aún no decidió si acepta el registro de ubicación (RF-23).
  final bool consentimientoPendiente;

  /// Hay consentimiento: la posición se envía cada pocos minutos (RF-21).
  final bool registrando;

  /// Última situación detectada; se limpia cuando el conductor la descarta.
  final TipoAlertaViaje? alerta;

  /// Se cumplieron las horas máximas al volante (o el administrador lanzó la
  /// prueba): la pantalla del conductor muestra la card de pausa activa.
  final bool pausaActiva;

  MonitorRutaActivo copiarCon({
    Coordenada? posicion,
    TipoAlertaViaje? alerta,
    bool limpiarAlerta = false,
    bool? consentimientoPendiente,
    bool? registrando,
    bool? pausaActiva,
  }) {
    return MonitorRutaActivo(
      posicion: posicion ?? this.posicion,
      alerta: limpiarAlerta ? null : alerta ?? this.alerta,
      consentimientoPendiente:
          consentimientoPendiente ?? this.consentimientoPendiente,
      registrando: registrando ?? this.registrando,
      pausaActiva: pausaActiva ?? this.pausaActiva,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    posicion,
    alerta,
    consentimientoPendiente,
    registrando,
    pausaActiva,
  ];
}
