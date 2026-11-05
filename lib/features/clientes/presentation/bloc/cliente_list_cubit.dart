import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/cliente.dart';
import '../../domain/usecases/inhabilitar_cliente_use_case.dart';
import '../../domain/usecases/listar_clientes_use_case.dart';
import 'cliente_list_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el listado paginado de clientes y la baja logica desde la lista.
/// La alta/edicion vive en [ClienteFormCubit]. Lectura para ADMINISTRADOR y
/// CONDUCTOR (RLS); [inhabilitar] solo la invoca la UI para ADMINISTRADOR.
class ClienteListCubit extends Cubit<ClienteListState> {
  ClienteListCubit({
    required ListarClientesUseCase listar,
    required InhabilitarClienteUseCase inhabilitar,
    this.tamanoPagina = 20,
  }) : _listar = listar,
       _inhabilitar = inhabilitar,
       super(const ClienteListCargando()) {
    cargarPrimeraPagina();
  }

  final ListarClientesUseCase _listar;
  final InhabilitarClienteUseCase _inhabilitar;
  final int tamanoPagina;

  Future<void> cargarPrimeraPagina() async {
    emit(const ClienteListCargando());
    try {
      final pagina = await _listar(pagina: 0, tamano: tamanoPagina);
      emit(
        ClienteListListo(
          clientes: pagina.clientes,
          pagina: 0,
          hayMas: pagina.hayMas,
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(ClienteListError(falla.mensaje));
    }
  }

  Future<void> recargar() => cargarPrimeraPagina();

  Future<void> cargarSiguientePagina() async {
    final ClienteListState actual = state;
    if (actual is! ClienteListListo || !actual.hayMas || actual.cargandoMas) {
      return;
    }
    emit(actual.copiarCon(cargandoMas: true));
    try {
      final siguiente = await _listar(
        pagina: actual.pagina + 1,
        tamano: tamanoPagina,
      );
      emit(
        ClienteListListo(
          clientes: <Cliente>[...actual.clientes, ...siguiente.clientes],
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
