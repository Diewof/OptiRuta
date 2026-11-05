import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/vehiculo.dart';
import '../../domain/usecases/inhabilitar_vehiculo_use_case.dart';
import '../../domain/usecases/listar_vehiculos_use_case.dart';
import 'vehiculo_list_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el listado paginado de vehiculos y la baja logica desde la lista.
/// La alta/edicion vive en [VehiculoFormCubit]; al volver del formulario, la
/// pagina llama [recargar].
class VehiculoListCubit extends Cubit<VehiculoListState> {
  VehiculoListCubit({
    required ListarVehiculosUseCase listar,
    required InhabilitarVehiculoUseCase inhabilitar,
    this.tamanoPagina = 20,
  }) : _listar = listar,
       _inhabilitar = inhabilitar,
       super(const VehiculoListCargando()) {
    cargarPrimeraPagina();
  }

  final ListarVehiculosUseCase _listar;
  final InhabilitarVehiculoUseCase _inhabilitar;
  final int tamanoPagina;

  Future<void> cargarPrimeraPagina() async {
    emit(const VehiculoListCargando());
    try {
      final pagina = await _listar(pagina: 0, tamano: tamanoPagina);
      emit(
        VehiculoListListo(
          vehiculos: pagina.vehiculos,
          pagina: 0,
          hayMas: pagina.hayMas,
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(VehiculoListError(falla.mensaje));
    }
  }

  Future<void> recargar() => cargarPrimeraPagina();

  Future<void> cargarSiguientePagina() async {
    final VehiculoListState actual = state;
    if (actual is! VehiculoListListo || !actual.hayMas || actual.cargandoMas) {
      return;
    }
    emit(actual.copiarCon(cargandoMas: true));
    try {
      final siguiente = await _listar(
        pagina: actual.pagina + 1,
        tamano: tamanoPagina,
      );
      emit(
        VehiculoListListo(
          vehiculos: <Vehiculo>[...actual.vehiculos, ...siguiente.vehiculos],
          pagina: actual.pagina + 1,
          hayMas: siguiente.hayMas,
        ),
      );
    } on CatalogoFailure catch (_) {
      // Se mantiene la pagina actual visible; solo se apaga el spinner de
      // "cargando mas" para permitir reintentar con scroll.
      emit(actual.copiarCon(cargandoMas: false));
    }
  }

  Future<bool> inhabilitar(String id) async {
    try {
      await _inhabilitar(id);
      await recargar();
      return true;
    } on CatalogoFailure catch (_) {
      return false;
    }
  }
}
