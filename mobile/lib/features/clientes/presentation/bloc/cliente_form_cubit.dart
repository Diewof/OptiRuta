import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/usecases/actualizar_cliente_use_case.dart';
import '../../domain/usecases/crear_cliente_use_case.dart';
import 'cliente_form_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Alta/edicion de un cliente. `idExistente == null` => crear.
class ClienteFormCubit extends Cubit<ClienteFormState> {
  ClienteFormCubit({
    required CrearClienteUseCase crear,
    required ActualizarClienteUseCase actualizar,
  }) : _crear = crear,
       _actualizar = actualizar,
       super(const ClienteFormInicial());

  final CrearClienteUseCase _crear;
  final ActualizarClienteUseCase _actualizar;

  Future<void> guardar({
    String? idExistente,
    required String nombre,
    String? documento,
    String? telefono,
    String? correo,
    String? direccion,
  }) async {
    emit(const ClienteFormEnviando());
    try {
      if (idExistente == null) {
        await _crear(
          nombre: nombre,
          documento: documento,
          telefono: telefono,
          correo: correo,
          direccion: direccion,
        );
      } else {
        await _actualizar(
          id: idExistente,
          nombre: nombre,
          documento: documento,
          telefono: telefono,
          correo: correo,
          direccion: direccion,
        );
      }
      emit(const ClienteFormExito());
    } on CatalogoFailure catch (falla) {
      emit(ClienteFormError(falla.mensaje));
    }
  }
}
