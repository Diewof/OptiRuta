import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/detector_ruta.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/tipo_alerta_viaje.dart';
import '../../domain/servicios/servicio_ubicacion.dart';
import '../../domain/usecases/registrar_alerta_viaje_use_case.dart';
import 'monitor_ruta_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Sigue la posición del conductor mientras el viaje está EN_CURSO y la app
/// está abierta. La posición solo vive en este estado: lo único que sale del
/// teléfono es el evento puntual de parada o desvío, vía
/// [RegistrarAlertaViajeUseCase].
class MonitorRutaCubit extends Cubit<MonitorRutaState> {
  MonitorRutaCubit({
    required String viajeId,
    required ServicioUbicacion ubicacion,
    required DetectorRuta detector,
    required RegistrarAlertaViajeUseCase registrarAlerta,
    DateTime Function() ahora = DateTime.now,
    Duration revision = const Duration(minutes: 1),
  }) : _viajeId = viajeId,
       _ubicacion = ubicacion,
       _detector = detector,
       _registrarAlerta = registrarAlerta,
       _ahora = ahora,
       _revision = revision,
       super(const MonitorRutaIniciando());

  final String _viajeId;
  final ServicioUbicacion _ubicacion;
  final DetectorRuta _detector;
  final RegistrarAlertaViajeUseCase _registrarAlerta;
  final DateTime Function() _ahora;
  final Duration _revision;

  StreamSubscription<Coordenada>? _suscripcion;
  Timer? _temporizador;
  Coordenada? _ultima;

  Future<void> iniciar() async {
    final EstadoPermisoUbicacion permiso = await _ubicacion.solicitarPermiso();
    if (isClosed) return;
    if (permiso != EstadoPermisoUbicacion.concedido) {
      emit(
        MonitorRutaSinPermiso(
          bloqueado: permiso == EstadoPermisoUbicacion.bloqueado,
        ),
      );
      return;
    }

    emit(const MonitorRutaActivo());
    _suscripcion = _ubicacion.posiciones().listen(
      _alRecibirPosicion,
      // Un fallo del GPS no debe tumbar la pantalla del viaje.
      onError: (Object _) {},
    );
    // El GPS filtrado por distancia no emite estando quieto, justo cuando hay
    // que medir la parada: se re-evalúa la última posición con el reloj.
    _temporizador = Timer.periodic(_revision, (_) {
      final Coordenada? ultima = _ultima;
      if (ultima != null) _evaluar(ultima);
    });
  }

  void _alRecibirPosicion(Coordenada posicion) {
    _ultima = posicion;
    final MonitorRutaState actual = state;
    emit(
      MonitorRutaActivo(
        posicion: posicion,
        alerta: actual is MonitorRutaActivo ? actual.alerta : null,
      ),
    );
    _evaluar(posicion);
  }

  void _evaluar(Coordenada posicion) {
    final TipoAlertaViaje? alerta = _detector.evaluar(posicion, _ahora());
    if (alerta == null || isClosed) return;

    emit(MonitorRutaActivo(posicion: posicion, alerta: alerta));
    unawaited(_notificarServidor(alerta, posicion));
  }

  // Mejor esfuerzo: si no hay red el conductor igual ve el aviso local y la
  // detección vuelve a intentarlo cuando se cumpla otro período.
  Future<void> _notificarServidor(
    TipoAlertaViaje alerta,
    Coordenada posicion,
  ) async {
    try {
      await _registrarAlerta(
        viajeId: _viajeId,
        tipo: alerta,
        ubicacion: posicion,
      );
    } on Object {
      // Intencional: ver comentario arriba.
    }
  }

  void descartarAlerta() {
    final MonitorRutaState actual = state;
    if (actual is MonitorRutaActivo && actual.alerta != null) {
      emit(MonitorRutaActivo(posicion: actual.posicion));
    }
  }

  @override
  Future<void> close() async {
    _temporizador?.cancel();
    await _suscripcion?.cancel();
    return super.close();
  }
}
