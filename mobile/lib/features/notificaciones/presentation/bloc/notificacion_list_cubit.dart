import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/notificacion.dart';
import '../../domain/usecases/listar_notificaciones_use_case.dart';
import '../../domain/usecases/marcar_notificacion_leida_use_case.dart';
import '../../domain/usecases/marcar_todas_notificaciones_leidas_use_case.dart';
import 'notificacion_list_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el listado paginado de notificaciones y marcarlas leídas.
class NotificacionListCubit extends Cubit<NotificacionListState> {
  NotificacionListCubit({
    required ListarNotificacionesUseCase listar,
    required MarcarNotificacionLeidaUseCase marcarLeida,
    required MarcarTodasNotificacionesLeidasUseCase marcarTodasLeidas,
    this.tamanoPagina = 20,
  }) : _listar = listar,
       _marcarLeida = marcarLeida,
       _marcarTodasLeidas = marcarTodasLeidas,
       super(const NotificacionListCargando()) {
    cargarPrimeraPagina();
  }

  final ListarNotificacionesUseCase _listar;
  final MarcarNotificacionLeidaUseCase _marcarLeida;
  final MarcarTodasNotificacionesLeidasUseCase _marcarTodasLeidas;
  final int tamanoPagina;

  Future<void> cargarPrimeraPagina() async {
    emit(const NotificacionListCargando());
    try {
      final pagina = await _listar(pagina: 0, tamano: tamanoPagina);
      emit(
        NotificacionListListo(
          notificaciones: pagina.notificaciones,
          pagina: 0,
          hayMas: pagina.hayMas,
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(NotificacionListError(falla.mensaje));
    }
  }

  Future<void> recargar() => cargarPrimeraPagina();

  Future<void> cargarSiguientePagina() async {
    final NotificacionListState actual = state;
    if (actual is! NotificacionListListo ||
        !actual.hayMas ||
        actual.cargandoMas) {
      return;
    }
    emit(actual.copiarCon(cargandoMas: true));
    try {
      final siguiente = await _listar(
        pagina: actual.pagina + 1,
        tamano: tamanoPagina,
      );
      emit(
        NotificacionListListo(
          notificaciones: <Notificacion>[
            ...actual.notificaciones,
            ...siguiente.notificaciones,
          ],
          pagina: actual.pagina + 1,
          hayMas: siguiente.hayMas,
        ),
      );
    } on CatalogoFailure catch (_) {
      emit(actual.copiarCon(cargandoMas: false));
    }
  }

  Future<void> marcarLeida(String id) async {
    final NotificacionListState actual = state;
    if (actual is! NotificacionListListo) return;
    try {
      await _marcarLeida(id);
      emit(
        actual.copiarCon(
          notificaciones: <Notificacion>[
            for (final Notificacion n in actual.notificaciones)
              if (n.id == id)
                Notificacion(
                  id: n.id,
                  tipo: n.tipo,
                  titulo: n.titulo,
                  mensaje: n.mensaje,
                  leida: true,
                  fechaCreacion: n.fechaCreacion,
                  viajeId: n.viajeId,
                  vehiculoId: n.vehiculoId,
                )
              else
                n,
          ],
        ),
      );
    } on CatalogoFailure catch (_) {
      // La UI ya mostraba el estado anterior; un fallo silencioso aquí no
      // pierde datos, solo deja la notificación como no leída para reintentar.
    }
  }

  Future<void> marcarTodasLeidas() async {
    final NotificacionListState actual = state;
    if (actual is! NotificacionListListo) return;
    try {
      await _marcarTodasLeidas();
      await recargar();
    } on CatalogoFailure catch (_) {
      // Igual que marcarLeida: fallo silencioso, el estado no se corrompe.
    }
  }
}
