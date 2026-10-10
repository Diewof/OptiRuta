import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/ajuste_viaje.dart';
import '../../domain/entities/costo_viaje.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/rentabilidad_marginal.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/usecases/cerrar_viaje_use_case.dart';
import '../../domain/usecases/listar_ajustes_viaje_use_case.dart';
import '../../domain/usecases/listar_costos_viaje_use_case.dart';
import '../../domain/usecases/listar_hitos_use_case.dart';
import '../../domain/usecases/registrar_ajuste_viaje_use_case.dart';
import '../../domain/usecases/rentabilidad_marginal_use_case.dart';
import 'viaje_detalle_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el detalle de un viaje: hitos, costos (estimado/real), la
/// rentabilidad **marginal** (RPC), los ajustes y las dos acciones del
/// administrador: cerrar (`viaje_cerrar`) y registrar un ajuste con motivo
/// (`viaje_registrar_ajuste`). Las reglas viven en Postgres; aquí solo se
/// invoca y se recarga.
class ViajeDetalleCubit extends Cubit<ViajeDetalleState> {
  ViajeDetalleCubit({
    required ViajeResumen viaje,
    required ListarHitosUseCase listarHitos,
    required ListarCostosViajeUseCase listarCostos,
    required RentabilidadMarginalUseCase rentabilidadMarginal,
    required ListarAjustesViajeUseCase listarAjustes,
    required CerrarViajeUseCase cerrarViaje,
    required RegistrarAjusteViajeUseCase registrarAjuste,
  }) : _viaje = viaje,
       _listarHitos = listarHitos,
       _listarCostos = listarCostos,
       _rentabilidadMarginal = rentabilidadMarginal,
       _listarAjustes = listarAjustes,
       _cerrarViaje = cerrarViaje,
       _registrarAjuste = registrarAjuste,
       _estado = viaje.estado,
       super(const ViajeDetalleCargando()) {
    cargar();
  }

  final ViajeResumen _viaje;
  final ListarHitosUseCase _listarHitos;
  final ListarCostosViajeUseCase _listarCostos;
  final RentabilidadMarginalUseCase _rentabilidadMarginal;
  final ListarAjustesViajeUseCase _listarAjustes;
  final CerrarViajeUseCase _cerrarViaje;
  final RegistrarAjusteViajeUseCase _registrarAjuste;
  EstadoViaje _estado;

  Future<void> cargar({bool silencioso = false}) async {
    if (!silencioso) emit(const ViajeDetalleCargando());
    try {
      final List<Object> r = await Future.wait(<Future<Object>>[
        _listarHitos(_viaje.id),
        _listarCostos(_viaje.id),
        _rentabilidadMarginal(_viaje.id),
        _listarAjustes(_viaje.id),
      ]);
      emit(
        ViajeDetalleListo(
          viaje: _viaje,
          estado: _estado,
          hitos: r[0] as List<Hito>,
          costos: r[1] as List<CostoViaje>,
          marginal: r[2] as RentabilidadMarginal,
          ajustes: r[3] as List<AjusteViaje>,
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(ViajeDetalleError(falla.mensaje));
    }
  }

  /// Cierra el viaje (FINALIZADO → CERRADO). Deja propagar [CatalogoFailure]
  /// para que la hoja de confirmación explique el error y permita reintentar.
  Future<void> cerrar() async {
    final ViajeDetalleState actual = state;
    if (actual is! ViajeDetalleListo || actual.procesando) return;
    emit(actual.copiarCon(procesando: true));
    try {
      _estado = (await _cerrarViaje(_viaje.id)).estado;
      await cargar(silencioso: true);
    } on CatalogoFailure {
      emit(actual.copiarCon(procesando: false));
      rethrow;
    }
  }

  /// Registra un ajuste sobre un viaje cerrado. El motivo es obligatorio
  /// (también lo exige la RPC). No cambia los costos: queda en el registro.
  Future<void> registrarAjuste({
    required String motivo,
    String? campoModificado,
    String? valorAnterior,
    String? valorNuevo,
  }) async {
    final ViajeDetalleState actual = state;
    if (actual is! ViajeDetalleListo || actual.procesando) return;
    emit(actual.copiarCon(procesando: true));
    try {
      await _registrarAjuste(
        viajeId: _viaje.id,
        motivo: motivo,
        campoModificado: campoModificado,
        valorAnterior: valorAnterior,
        valorNuevo: valorNuevo,
      );
      await cargar(silencioso: true);
    } on CatalogoFailure {
      emit(actual.copiarCon(procesando: false));
      rethrow;
    }
  }
}
