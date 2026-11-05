import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/conductor.dart';
import '../../domain/usecases/inhabilitar_conductor_use_case.dart';
import '../../domain/usecases/listar_conductores_use_case.dart';
import 'conductor_list_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el listado paginado de conductores y la baja logica desde la
/// lista. La alta/edicion vive en [ConductorFormCubit].
class ConductorListCubit extends Cubit<ConductorListState> {
  ConductorListCubit({
    required ListarConductoresUseCase listar,
    required InhabilitarConductorUseCase inhabilitar,
    this.tamanoPagina = 20,
  }) : _listar = listar,
       _inhabilitar = inhabilitar,
       super(const ConductorListCargando()) {
    cargarPrimeraPagina();
  }

  final ListarConductoresUseCase _listar;
  final InhabilitarConductorUseCase _inhabilitar;
  final int tamanoPagina;

  Future<void> cargarPrimeraPagina() async {
    emit(const ConductorListCargando());
    try {
      final pagina = await _listar(pagina: 0, tamano: tamanoPagina);
      emit(
        ConductorListListo(
          conductores: pagina.conductores,
          pagina: 0,
          hayMas: pagina.hayMas,
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(ConductorListError(falla.mensaje));
    }
  }

  Future<void> recargar() => cargarPrimeraPagina();

  Future<void> cargarSiguientePagina() async {
    final ConductorListState actual = state;
    if (actual is! ConductorListListo || !actual.hayMas || actual.cargandoMas) {
      return;
    }
    emit(actual.copiarCon(cargandoMas: true));
    try {
      final siguiente = await _listar(
        pagina: actual.pagina + 1,
        tamano: tamanoPagina,
      );
      emit(
        ConductorListListo(
          conductores: <Conductor>[
            ...actual.conductores,
            ...siguiente.conductores,
          ],
          pagina: actual.pagina + 1,
          hayMas: siguiente.hayMas,
        ),
      );
    } on CatalogoFailure catch (_) {
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
