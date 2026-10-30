import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../checklist/domain/entities/checklist.dart';
import '../../../combustible/domain/usecases/combustible_use_cases.dart';
import '../../../checklist/domain/usecases/checklist_use_cases.dart';
import '../../domain/entities/costo_viaje.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/descargue_pendiente.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/tipo_hito.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/usecases/actualizar_valor_real_costo_use_case.dart';
import '../../domain/usecases/agregar_costo_viaje_use_case.dart';
import '../../domain/servicios/servicio_ubicacion.dart';
import '../../domain/usecases/iniciar_viaje_use_case.dart';
import '../../domain/usecases/listar_costos_viaje_use_case.dart';
import '../../domain/usecases/listar_hitos_use_case.dart';
import '../../domain/usecases/listar_viajes_activos_use_case.dart';
import '../../domain/usecases/obtener_descargue_pendiente_use_case.dart';
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
    required AgregarCostoViajeUseCase agregarCosto,
    required ObtenerChecklistViajeUseCase obtenerChecklist,
    required ObtenerDescarguePendienteUseCase obtenerDescarguePendiente,
    required RegistrarTanqueoUseCase registrarTanqueo,
  }) : _listarActivos = listarActivos,
       _listarHitos = listarHitos,
       _listarCostos = listarCostos,
       _registrarHito = registrarHito,
       _iniciarViaje = iniciarViaje,
       _ubicacion = ubicacion,
       _actualizarValorReal = actualizarValorReal,
       _agregarCosto = agregarCosto,
       _obtenerChecklist = obtenerChecklist,
       _obtenerDescarguePendiente = obtenerDescarguePendiente,
       _registrarTanqueo = registrarTanqueo,
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
  final AgregarCostoViajeUseCase _agregarCosto;
  final ObtenerChecklistViajeUseCase _obtenerChecklist;
  final ObtenerDescarguePendienteUseCase _obtenerDescarguePendiente;
  final RegistrarTanqueoUseCase _registrarTanqueo;

  /// Con [silencioso] no pasa por «Cargando»: la pantalla conserva lo que ya
  /// muestra y solo cambia lo nuevo (así se pueden animar los cambios).
  Future<void> cargar({bool silencioso = false}) async {
    if (!silencioso) emit(const ConductorViajeCargando());
    try {
      final List<ViajeResumen> viajes = await _listarActivos();
      if (viajes.isEmpty) {
        emit(
          ConductorViajeSinAsignar(
            descarguePendiente: await _descarguePendiente(),
          ),
        );
        return;
      }
      final ViajeResumen viaje = viajes.first;
      final List<Hito> hitos = await _listarHitos(viaje.id);
      final List<CostoViaje> costos = await _listarCostos(viaje.id);
      emit(
        ConductorViajeListo(
          viaje: viaje,
          hitos: hitos,
          costos: costos,
          checklist: await _checklistDe(viaje),
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(ConductorViajeError(falla.mensaje));
    }
  }

  /// El descargue pendiente es un aviso accesorio: si no se puede consultar
  /// se trata como «ninguno» y Inicio sigue como siempre.
  Future<DescarguePendiente?> _descarguePendiente() async {
    try {
      return await _obtenerDescarguePendiente();
    } on Object {
      return null;
    }
  }

  /// El checklist solo importa antes de salir. Si no se puede leer se trata
  /// como «sin checklist»: `viaje_iniciar` es quien manda y avisará.
  Future<ChecklistViaje?> _checklistDe(ViajeResumen viaje) async {
    if (viaje.estado != EstadoViaje.asignado) return null;
    try {
      return await _obtenerChecklist(viaje.id);
    } on CatalogoFailure {
      return null;
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

  /// Registra la salida del descargue del viaje que ya llegó a destino. Deja
  /// que [CatalogoFailure] se propague para que la hoja la muestre.
  Future<void> registrarSalidaDescargue() async {
    final ConductorViajeState actual = state;
    if (actual is! ConductorViajeSinAsignar || actual.procesando) return;
    final DescarguePendiente? pendiente = actual.descarguePendiente;
    if (pendiente == null) return;
    emit(actual.copiarCon(procesando: true));
    try {
      await _registrarHito(
        viajeId: pendiente.viajeId,
        tipo: TipoHito.salidaDescargue,
        fechaHora: DateTime.now(),
      );
      await cargar(silencioso: true);
    } on CatalogoFailure {
      emit(actual.copiarCon(procesando: false));
      rethrow;
    }
  }

  /// Anota un tanqueo del viaje en curso. El servidor suma el valor al ACPM
  /// real. Relanza la falla para que la hoja la muestre.
  Future<void> registrarTanqueo({
    required double galones,
    required double valor,
  }) async {
    final ConductorViajeState actual = state;
    if (actual is! ConductorViajeListo || actual.procesando) return;
    emit(actual.copiarCon(procesando: true));
    try {
      await _registrarTanqueo(
        viajeId: actual.viaje.id,
        galones: galones,
        valor: valor,
      );
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

  /// Anota un costo adicional libre del viaje activo (RF-14), siempre como
  /// valor real. Relanza la falla para que la hoja la muestre.
  Future<void> agregarCostoLibre({
    required String descripcion,
    required double valor,
  }) async {
    final ConductorViajeState actual = state;
    if (actual is! ConductorViajeListo || actual.procesando) return;
    emit(actual.copiarCon(procesando: true));
    try {
      await _agregarCosto(
        viajeId: actual.viaje.id,
        descripcion: descripcion,
        valorReal: valor,
      );
      await cargar(silencioso: true);
    } on Object {
      emit(actual.copiarCon(procesando: false));
      rethrow;
    }
  }
}
