import 'package:equatable/equatable.dart';

import '../../../viajes/domain/entities/coordenada.dart';
import 'tipo_notificacion.dart';

/// Alerta para el Administrador (documento por vencer, retraso, viaje
/// completado, peajes). Generada automáticamente en Postgres
/// (`notificacion_generar`, vía `pg_cron`); la app solo lista y marca leída.
class Notificacion extends Equatable {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.leida,
    required this.fechaCreacion,
    this.viajeId,
    this.vehiculoId,
    this.ubicacion,
  });

  final String id;
  final TipoNotificacion tipo;
  final String titulo;
  final String mensaje;
  final bool leida;
  final DateTime fechaCreacion;
  final String? viajeId;
  final String? vehiculoId;

  /// Dónde se detectó la parada o el desvío; solo las alertas de ruta la traen.
  final Coordenada? ubicacion;

  @override
  List<Object?> get props => <Object?>[
    id,
    tipo,
    titulo,
    mensaje,
    leida,
    fechaCreacion,
    viajeId,
    vehiculoId,
    ubicacion,
  ];
}
