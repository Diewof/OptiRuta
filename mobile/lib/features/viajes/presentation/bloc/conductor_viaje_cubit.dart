import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/costo_viaje.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/tipo_hito.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/usecases/actualizar_valor_real_costo_use_case.dart';
import '../../domain/servicios/servicio_ubicacion.dart';
import '../../domain/usecases/iniciar_viaje_use_case.dart';
import '../../domain/usecases/listar_costos_viaje_use_case.dart';
import '../../domain/usecases/listar_hitos_use_case.dart';
import '../../domain/usecases/listar_viajes_activos_use_case.dart';
import '../../domain/usecases/registrar_hito_use_case.dart';
import 'conductor_viaje_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el único viaje activo (ASIGNADO/EN_CURSO) del conductor
/// autenticado: lo usan tanto Inicio como la Planilla de viaje, para no
/// repetir la misma carga en dos cubits. RLS ya filtra `listarActivos` a los
/// viajes del conductor; si hay más de uno (no debería, un conductor opera
/// un vehículo a la vez), se toma el primero.
class ConductorViajeCubit extends Cubit<ConductorViajeState> {
  ConductorViajeCubit({
    required ListarViajesActivosUseCase listarActivos,
    required ListarHitosUseCase listarHitos,
    required ListarCostosViajeUseCase listarCostos,
    required RegistrarHitoUseCase registrarHito,
    required IniciarViajeUseCase iniciarViaje,
    required ServicioUbicacion ubicacion,
    required ActualizarValorRealCostoUseCase actualizarValorReal,
  }) : _listarActivos = listarActivos,
       _listarHitos = listarHitos,
       _listarCostos = listarCostos,
       _registrarHito = registrarHito,
       _iniciarViaje = iniciarViaje,
       _ubicacion = ubicacion,
       _actualizarValorReal = actualizarValorReal,
       super(const ConductorViajeCargando()) {
    cargar();
  }

  final ListarViajesActivosUseCase _listarActivos;
  final ListarHitosUseCase _listarHitos;
  final ListarCostosViajeUseCase _listarCostos;
  final RegistrarHitoUseCase _registrarHito;
  final IniciarViajeUseCase _iniciarViaje;
  final ServicioUbicacion _ubicacion;
  final ActualizarValorRealCostoUseCase _actualizarValorReal;

  /// Con [silencioso] no pasa por «Cargando»: la pantalla conserva lo que ya
  /// muestra y solo cambia lo nuevo (así se pueden animar los cambios).
  Future<void> cargar({bool silencioso = false}) async {
    if (!silencioso) emit(const ConductorViajeCargando());
    try {
      final List<ViajeResumen> viajes = await _listarActivos();
      if (viajes.isEmpty) {
        emit(const ConductorViajeSinAsignar());
        return;
      }
      final ViajeResumen viaje = viajes.first;
      final List<Hito> hitos = await _listarHitos(viaje.id);
      final List<CostoViaje> costos = await _listarCostos(viaje.id);
      emit(ConductorViajeListo(viaje: viaje, hitos: hitos, costos: costos));
    } on CatalogoFailure catch (falla) {
      emit(ConductorViajeError(falla.mensaje));
    }
  }

  /// Registra [tipo] con la hora actual. La salida pasa por `viaje_iniciar`:
  /// el servidor exige estar a 500 m del origen y deja el viaje EN_CURSO. Deja que [CatalogoFailure] se
  /// propague: la pantalla la atrapa para mostrar el error puntual sin
  /// perder el resto del estado cargado.
  Future<void> registrarHito(TipoHito tipo) async {
    final ConductorViajeState actual = state;
    if (actual is! ConductorViajeListo || actual.procesando) return;
    emit(actual.copiarCon(procesando: true));
    try {
      if (tipo == TipoHito.salida) {
        await _iniciarViaje(
          viajeId: actual.viaje.id,
          ubicacion: await _leerUbicacion(),
          fechaHora: DateTime.now(),
        );
      } else {
        await _registrarHito(
          viajeId: actual.viaje.id,
          tipo: tipo,
          fechaHora: DateTime.now(),
        );
      }
      await cargar(silencioso: true);
    } on CatalogoFailure {
      emit(actual.copiarCon(procesando: false));
      rethrow;
    }
  }

  Future<Coordenada> _leerUbicacion() async {
    const String sinUbicacion =
        'No se pudo leer tu ubicación. Activa el GPS y su permiso para esta '
        'app e intenta de nuevo.';
    if (await _ubicacion.solicitarPermiso() !=
        EstadoPermisoUbicacion.concedido) {
      throw const CatalogoFailure(
        CatalogoErrorCodigo.desconocido,
        sinUbicacion,
      );
    }
    try {
      return await _ubicacion.posicionActual();
    } on Object {
      throw const CatalogoFailure(
        CatalogoErrorCodigo.desconocido,
        sinUbicacion,
      );
    }
  }

  Future<void> confirmarValorReal({
    required String costoId,
    required double valorReal,
  }) async {
    final ConductorViajeState actual = state;
    if (actual is! ConductorViajeListo || actual.procesando) return;
    emit(actual.copiarCon(procesando: true));
    try {
      await _actualizarValorReal(costoId: costoId, valorReal: valorReal);
      await cargar(silencioso: true);
    } on CatalogoFailure {
      emit(actual.copiarCon(procesando: false));
      rethrow;
    }
  }
}
