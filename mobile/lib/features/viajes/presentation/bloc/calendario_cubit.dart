import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/usecases/listar_viajes_por_rango_use_case.dart';
import 'calendario_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el grid mensual de Calendario: carga los viajes del mes visible
/// en una sola consulta (`listarPorRango`) y deriva el listado del día
/// seleccionado en memoria (sin una segunda consulta por cada tap).
class CalendarioCubit extends Cubit<CalendarioState> {
  CalendarioCubit({required ListarViajesPorRangoUseCase listarPorRango})
    : _listarPorRango = listarPorRango,
      super(const CalendarioCargando()) {
    final DateTime hoy = DateTime.now();
    _cargarMes(DateTime(hoy.year, hoy.month), diaSeleccionado: hoy);
  }

  final ListarViajesPorRangoUseCase _listarPorRango;

  Future<void> _cargarMes(
    DateTime primerDiaDelMes, {
    required DateTime diaSeleccionado,
  }) async {
    emit(const CalendarioCargando());
    try {
      final DateTime desde = DateTime(
        primerDiaDelMes.year,
        primerDiaDelMes.month,
      );
      final DateTime hasta = DateTime(desde.year, desde.month + 1);
      final viajes = await _listarPorRango(desde: desde, hasta: hasta);
      emit(
        CalendarioListo(
          mesMostrado: desde,
          diaSeleccionado: diaSeleccionado,
          viajesDelMes: viajes,
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(CalendarioError(falla.mensaje));
    }
  }

  Future<void> irAMesAnterior() async {
    final CalendarioState actual = state;
    if (actual is! CalendarioListo) return;
    final DateTime anterior = DateTime(
      actual.mesMostrado.year,
      actual.mesMostrado.month - 1,
    );
    await _cargarMes(anterior, diaSeleccionado: anterior);
  }

  Future<void> irAMesSiguiente() async {
    final CalendarioState actual = state;
    if (actual is! CalendarioListo) return;
    final DateTime siguiente = DateTime(
      actual.mesMostrado.year,
      actual.mesMostrado.month + 1,
    );
    await _cargarMes(siguiente, diaSeleccionado: siguiente);
  }

  void seleccionarDia(DateTime dia) {
    final CalendarioState actual = state;
    if (actual is! CalendarioListo) return;
    emit(actual.copiarCon(diaSeleccionado: dia));
  }

  Future<void> recargar() async {
    final CalendarioState actual = state;
    final DateTime referencia = actual is CalendarioListo
        ? actual.diaSeleccionado
        : DateTime.now();
    await _cargarMes(
      DateTime(referencia.year, referencia.month),
      diaSeleccionado: referencia,
    );
  }
}
