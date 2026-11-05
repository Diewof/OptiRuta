import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/ficha_tecnica.dart';
import '../../domain/entities/tipo_vehiculo.dart';
import '../../domain/usecases/actualizar_vehiculo_use_case.dart';
import '../../domain/usecases/crear_vehiculo_use_case.dart';
import 'vehiculo_form_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Alta/edicion de un vehiculo. `idExistente == null` => crear.
class VehiculoFormCubit extends Cubit<VehiculoFormState> {
  VehiculoFormCubit({
    required CrearVehiculoUseCase crear,
    required ActualizarVehiculoUseCase actualizar,
  }) : _crear = crear,
       _actualizar = actualizar,
       super(const VehiculoFormInicial());

  final CrearVehiculoUseCase _crear;
  final ActualizarVehiculoUseCase _actualizar;

  Future<void> guardar({
    String? idExistente,
    required String placa,
    required TipoVehiculo tipo,
    required double capacidadCarga,
    required double rendimientoKmGalon,
    FichaTecnica ficha = FichaTecnica.vacia,
  }) async {
    emit(const VehiculoFormEnviando());
    try {
      if (idExistente == null) {
        await _crear(
          placa: placa,
          tipo: tipo,
          capacidadCarga: capacidadCarga,
          rendimientoKmGalon: rendimientoKmGalon,
          ficha: ficha,
        );
      } else {
        await _actualizar(
          id: idExistente,
          placa: placa,
          tipo: tipo,
          capacidadCarga: capacidadCarga,
          rendimientoKmGalon: rendimientoKmGalon,
          ficha: ficha,
        );
      }
      emit(const VehiculoFormExito());
    } on CatalogoFailure catch (falla) {
      emit(VehiculoFormError(falla.mensaje));
    }
  }
}
