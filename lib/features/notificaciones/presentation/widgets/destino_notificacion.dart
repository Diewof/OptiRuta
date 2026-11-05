import '../../../../core/widgets/admin_section.dart';
import '../../domain/entities/notificacion.dart';
import '../../domain/entities/tipo_notificacion.dart';

/// A dónde lleva tocar una notificación y con qué verbo se le anuncia al
/// administrador. [abreViaje] tiene prioridad sobre [seccion] cuando la
/// notificación trae el viaje.
class DestinoNotificacion {
  const DestinoNotificacion({
    required this.verbo,
    this.seccion,
    this.abreViaje = false,
  });

  final String verbo;
  final AdminSection? seccion;
  final bool abreViaje;

  static const DestinoNotificacion _viaje = DestinoNotificacion(
    verbo: 'Ver viaje',
    abreViaje: true,
  );

  /// `null` cuando solo informa y no hay nada que abrir.
  static DestinoNotificacion? de(Notificacion n) {
    if (n.viajeId != null && _abreViaje(n.tipo)) return _viaje;
    return switch (n.tipo) {
      TipoNotificacion.documentoPorVencer ||
      TipoNotificacion.documentoVencido ||
      TipoNotificacion.mantenimientoProximo ||
      TipoNotificacion.mantenimientoVencido => const DestinoNotificacion(
        verbo: 'Ver flota',
        seccion: AdminSection.flota,
      ),
      TipoNotificacion.satisfaccionBaja => const DestinoNotificacion(
        verbo: 'Ver satisfacción',
        seccion: AdminSection.satisfaccion,
      ),
      TipoNotificacion.calidadRecurrente => const DestinoNotificacion(
        verbo: 'Ver calidad',
        seccion: AdminSection.calidad,
      ),
      TipoNotificacion.rendimientoBajo => const DestinoNotificacion(
        verbo: 'Ver combustible',
        seccion: AdminSection.combustible,
      ),
      TipoNotificacion.esperaExcesiva => const DestinoNotificacion(
        verbo: 'Ver esperas',
        seccion: AdminSection.esperas,
      ),
      _ => null,
    };
  }

  static bool _abreViaje(TipoNotificacion t) =>
      t != TipoNotificacion.documentoPorVencer &&
      t != TipoNotificacion.documentoVencido &&
      t != TipoNotificacion.mantenimientoProximo &&
      t != TipoNotificacion.mantenimientoVencido &&
      t != TipoNotificacion.calidadRecurrente &&
      t != TipoNotificacion.rendimientoBajo;
}

/// Filtros de la bandeja (chips). Se aplican sobre lo ya cargado.
enum FiltroNotificacion {
  todas('Todas'),
  sinLeer('Sin leer'),
  requierenAccion('Requieren acción'),
  ruta('Ruta'),
  flota('Flota'),
  clientes('Clientes');

  const FiltroNotificacion(this.etiqueta);

  final String etiqueta;

  bool acepta(Notificacion n) => switch (this) {
    FiltroNotificacion.todas => true,
    FiltroNotificacion.sinLeer => !n.leida,
    FiltroNotificacion.requierenAccion => n.tipo.requiereAccion,
    FiltroNotificacion.ruta => n.tipo.categoria == CategoriaNotificacion.ruta,
    FiltroNotificacion.flota => n.tipo.categoria == CategoriaNotificacion.flota,
    FiltroNotificacion.clientes =>
      n.tipo.categoria == CategoriaNotificacion.cliente,
  };
}
