import 'package:equatable/equatable.dart';

import '../entities/notificacion.dart';

class PaginaNotificaciones extends Equatable {
  const PaginaNotificaciones({
    required this.notificaciones,
    required this.hayMas,
  });

  final List<Notificacion> notificaciones;
  final bool hayMas;

  @override
  List<Object?> get props => <Object?>[notificaciones, hayMas];
}

/// Contrato de acceso a `public.notificacion` para la capa de dominio. Solo
/// ADMINISTRADOR: lo garantiza RLS. La implementación vive en `data` sobre
/// `supabase_flutter`.
abstract interface class NotificacionRepository {
  /// [desde] (inclusive) y [hasta] (exclusive) acotan por fecha de creación;
  /// con [soloNoLeidas] solo trae las pendientes.
  Future<PaginaNotificaciones> listar({
    required int pagina,
    required int tamano,
    DateTime? desde,
    DateTime? hasta,
    bool soloNoLeidas = false,
  });

  Future<void> marcarLeida(String id);

  /// Marca como leídas todas las notificaciones pendientes.
  Future<void> marcarTodasLeidas();
}
