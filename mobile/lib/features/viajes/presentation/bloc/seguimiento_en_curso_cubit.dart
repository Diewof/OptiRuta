import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/usecases/listar_hitos_use_case.dart';
import '../../domain/usecases/listar_viajes_activos_use_case.dart';
import 'seguimiento_en_curso_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta la pestaña "En curso" de Seguimiento: viajes ASIGNADO/EN_CURSO
/// con sus hitos (una consulta de hitos por viaje activo, en paralelo -- la
/// flota es pequeña, no hace falta paginar).
class SeguimientoEnCursoCubit extends Cubit<SeguimientoEnCursoState> {
  SeguimientoEnCursoCubit({
    required ListarViajesActivosUseCase listarActivos,
    required ListarHitosUseCase listarHitos,
  }) : _listarActivos = listarActivos,
       _listarHitos = listarHitos,
       super(const SeguimientoEnCursoCargando()) {
    cargar();
  }

  final ListarViajesActivosUseCase _listarActivos;
  final ListarHitosUseCase _listarHitos;

  Future<void> cargar() async {
    emit(const SeguimientoEnCursoCargando());
    try {
      final List<ViajeResumen> viajes = await _listarActivos();
      final List<List<Hito>> hitosPorViaje = await Future.wait(
        viajes.map((ViajeResumen v) => _listarHitos(v.id)),
      );

      final List<ViajeActivo> resultado = <ViajeActivo>[
        for (int i = 0; i < viajes.length; i++)
          ViajeActivo(
            viaje: viajes[i],
            hitos: hitosPorViaje[i],
            retraso: ViajeActivo.calcularRetraso(viajes[i], hitosPorViaje[i]),
          ),
      ];

      emit(SeguimientoEnCursoListo(resultado));
    } on CatalogoFailure catch (falla) {
      emit(SeguimientoEnCursoError(falla.mensaje));
    }
  }
}
