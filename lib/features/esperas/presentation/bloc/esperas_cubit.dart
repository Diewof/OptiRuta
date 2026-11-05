import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/espera_cliente.dart';
import '../../domain/usecases/obtener_esperas_use_case.dart';
import 'esperas_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que el campo privado
// se asigna en la lista de inicializacion.
// ignore_for_file: prefer_initializing_formals

/// Orquesta la pestaña «Esperas» del Resumen: horas de espera de cargue y
/// descargue por cliente en el mes mostrado.
class EsperasCubit extends Cubit<EsperasState> {
  EsperasCubit({required ObtenerEsperasPorClienteUseCase obtener})
    : _obtener = obtener,
      super(const EsperasCargando()) {
    final DateTime hoy = DateTime.now();
    _cargar(DateTime(hoy.year, hoy.month));
  }

  final ObtenerEsperasPorClienteUseCase _obtener;
  DateTime? _mes;

  Future<void> _cargar(DateTime mes) async {
    _mes = mes;
    emit(const EsperasCargando());
    try {
      final DateTime hasta = DateTime(
        mes.year,
        mes.month + 1,
      ).subtract(const Duration(days: 1));
      final List<EsperaCliente> clientes = await _obtener(
        desde: mes,
        hasta: hasta,
      );
      if (!isClosed) emit(EsperasListo(mes: mes, clientes: clientes));
    } on CatalogoFailure catch (falla) {
      if (!isClosed) emit(EsperasError(falla.mensaje));
    }
  }

  Future<void> irAMesAnterior() {
    final DateTime? mes = _mes;
    return mes == null
        ? Future<void>.value()
        : _cargar(DateTime(mes.year, mes.month - 1));
  }

  Future<void> irAMesSiguiente() {
    final DateTime? mes = _mes;
    return mes == null
        ? Future<void>.value()
        : _cargar(DateTime(mes.year, mes.month + 1));
  }

  Future<void> recargar() =>
      _mes == null ? Future<void>.value() : _cargar(_mes!);
}
