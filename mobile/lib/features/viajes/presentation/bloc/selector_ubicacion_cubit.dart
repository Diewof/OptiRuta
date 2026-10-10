import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/lugar.dart';
import '../../domain/usecases/buscar_lugares_use_case.dart';
import '../../domain/usecases/lugar_en_coordenada_use_case.dart';
import 'selector_ubicacion_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el selector de ubicación del administrador: autocompletado
/// (resultados), pin movido a mano (nombre del punto) y el lugar elegido.
class SelectorUbicacionCubit extends Cubit<SelectorUbicacionState> {
  SelectorUbicacionCubit({
    required BuscarLugaresUseCase buscar,
    required LugarEnCoordenadaUseCase lugarEn,
    Lugar? inicial,
  }) : _buscar = buscar,
       _lugarEn = lugarEn,
       super(SelectorUbicacionState(seleccion: inicial));

  final BuscarLugaresUseCase _buscar;
  final LugarEnCoordenadaUseCase _lugarEn;

  // Descarta respuestas que llegan tarde: solo vale la última petición.
  int _ultimaBusqueda = 0;
  int _ultimaResolucion = 0;

  Future<void> buscar(String consulta) async {
    final int token = ++_ultimaBusqueda;
    if (consulta.trim().length < BuscarLugaresUseCase.minimoCaracteres) {
      emit(
        state.copiarCon(
          resultados: const <Lugar>[],
          buscando: false,
          busquedaSinResultados: false,
          limpiarError: true,
        ),
      );
      return;
    }

    emit(state.copiarCon(buscando: true, limpiarError: true));
    try {
      final List<Lugar> lugares = await _buscar(consulta);
      if (token != _ultimaBusqueda || isClosed) return;
      emit(
        state.copiarCon(
          resultados: lugares,
          buscando: false,
          busquedaSinResultados: lugares.isEmpty,
        ),
      );
    } on CatalogoFailure catch (falla) {
      if (token != _ultimaBusqueda || isClosed) return;
      emit(state.copiarCon(buscando: false, error: falla.mensaje));
    }
  }

  /// El administrador tocó una sugerencia de la lista.
  void elegirResultado(Lugar lugar) {
    _ultimaResolucion++;
    emit(
      state.copiarCon(
        seleccion: lugar,
        resultados: const <Lugar>[],
        busquedaSinResultados: false,
        resolviendo: false,
        limpiarError: true,
      ),
    );
  }

  /// El administrador movió el mapa: el pin (centro) cayó en [coordenada].
  Future<void> moverPin(Coordenada coordenada) async {
    final int token = ++_ultimaResolucion;
    emit(
      state.copiarCon(
        resolviendo: true,
        resultados: const <Lugar>[],
        busquedaSinResultados: false,
        limpiarError: true,
      ),
    );
    try {
      final Lugar lugar = await _lugarEn(coordenada);
      if (token != _ultimaResolucion || isClosed) return;
      emit(state.copiarCon(seleccion: lugar, resolviendo: false));
    } on CatalogoFailure catch (falla) {
      if (token != _ultimaResolucion || isClosed) return;
      // Sin nombre el punto sigue siendo válido: se conserva la coordenada.
      emit(
        state.copiarCon(
          seleccion: Lugar(
            nombre:
                '${coordenada.lat.toStringAsFixed(4)}, '
                '${coordenada.lng.toStringAsFixed(4)}',
            coordenada: coordenada,
          ),
          resolviendo: false,
          error: falla.mensaje,
        ),
      );
    }
  }
}
