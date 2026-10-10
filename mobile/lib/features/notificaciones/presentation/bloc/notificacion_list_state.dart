import 'package:equatable/equatable.dart';

import '../../domain/entities/notificacion.dart';

sealed class NotificacionListState extends Equatable {
  const NotificacionListState();

  @override
  List<Object?> get props => <Object?>[];
}

class NotificacionListCargando extends NotificacionListState {
  const NotificacionListCargando();
}

class NotificacionListListo extends NotificacionListState {
  const NotificacionListListo({
    required this.notificaciones,
    required this.pagina,
    required this.hayMas,
    this.cargandoMas = false,
  });

  final List<Notificacion> notificaciones;
  final int pagina;
  final bool hayMas;
  final bool cargandoMas;

  NotificacionListListo copiarCon({
    List<Notificacion>? notificaciones,
    int? pagina,
    bool? hayMas,
    bool? cargandoMas,
  }) {
    return NotificacionListListo(
      notificaciones: notificaciones ?? this.notificaciones,
      pagina: pagina ?? this.pagina,
      hayMas: hayMas ?? this.hayMas,
      cargandoMas: cargandoMas ?? this.cargandoMas,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    notificaciones,
    pagina,
    hayMas,
    cargandoMas,
  ];
}

class NotificacionListError extends NotificacionListState {
  const NotificacionListError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}
