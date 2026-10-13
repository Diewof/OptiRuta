import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/usecases/listar_historial_viajes_use_case.dart';
import '../../domain/usecases/rentabilidad_marginal_use_case.dart';
import 'historial_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el historial paginado de viajes, con filtro de estado y
/// rentabilidad marginal resuelta en paralelo para los viajes de cada
/// página (no bloquea el listado: llega justo después, por fila).
class HistorialCubit extends Cubit<HistorialState> {
  HistorialCubit({
    required ListarHistorialViajesUseCase listar,
    required RentabilidadMarginalUseCase rentabilidadMarginal,
    this.tamanoPagina = 20,
  }) : _listar = listar,
       _rentabilidadMarginal = rentabilidadMarginal,
       super(const HistorialCargando()) {
    cargarPrimeraPagina();
  }

  final ListarHistorialViajesUseCase _listar;
  final RentabilidadMarginalUseCase _rentabilidadMarginal;
  final int tamanoPagina;

  Future<void> cargarPrimeraPagina({EstadoViaje? filtroEstado}) async {
    emit(const HistorialCargando());
    try {
      final pagina = await _listar(pagina: 0, filtroEstado: filtroEstado);
      emit(
        HistorialListo(
          viajes: pagina.viajes
              .map((ViajeResumen v) => ViajeConRentabilidad(viaje: v))
              .toList(),
          pagina: 0,
          hayMas: pagina.hayMas,
          filtroEstado: filtroEstado,
        ),
      );
      unawaited(_cargarRentabilidades(pagina.viajes));
    } on CatalogoFailure catch (falla) {
      emit(HistorialError(falla.mensaje));
    }
  }

  Future<void> recargar() => cargarPrimeraPagina(filtroEstado: _filtroActual());

  EstadoViaje? _filtroActual() {
    final HistorialState actual = state;
    return actual is HistorialListo ? actual.filtroEstado : null;
  }

  Future<void> cargarSiguientePagina() async {
    final HistorialState actual = state;
    if (actual is! HistorialListo || !actual.hayMas || actual.cargandoMas) {
      return;
    }
    emit(actual.copiarCon(cargandoMas: true));
    try {
      final siguiente = await _listar(
        pagina: actual.pagina + 1,
        filtroEstado: actual.filtroEstado,
      );
      emit(
        actual.copiarCon(
          viajes: <ViajeConRentabilidad>[
            ...actual.viajes,
            ...siguiente.viajes.map(
              (ViajeResumen v) => ViajeConRentabilidad(viaje: v),
            ),
          ],
          pagina: actual.pagina + 1,
          hayMas: siguiente.hayMas,
          cargandoMas: false,
        ),
      );
      unawaited(_cargarRentabilidades(siguiente.viajes));
    } on CatalogoFailure catch (_) {
      emit(actual.copiarCon(cargandoMas: false));
    }
  }

  Future<void> _cargarRentabilidades(List<ViajeResumen> viajes) async {
    for (final ViajeResumen v in viajes) {
      try {
        final double valor = await _rentabilidadMarginal(v.id)
            .then((r) => r.rentabilidad);
        // El usuario pudo salir de la pantalla mientras llegaban las
        // rentabilidades: un cubit cerrado ya no admite estados.
        if (isClosed) return;
        final HistorialState actual = state;
        if (actual is! HistorialListo) return;
        emit(
          actual.copiarCon(
            viajes: <ViajeConRentabilidad>[
              for (final ViajeConRentabilidad vr in actual.viajes)
                if (vr.viaje.id == v.id)
                  vr.copiarCon(rentabilidad: valor)
                else
                  vr,
            ],
          ),
        );
      } on CatalogoFailure catch (_) {
        // Si falla un viaje puntual, el resto de la página sigue intentando;
        // esa fila simplemente queda sin rentabilidad visible.
      }
    }
  }
}
