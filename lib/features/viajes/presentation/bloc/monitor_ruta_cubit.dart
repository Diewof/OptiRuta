import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/detector_fatiga.dart';
import '../../domain/detector_ruta.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/tipo_alerta_viaje.dart';
import '../../domain/servicios/servicio_ubicacion.dart';
import '../../domain/usecases/pausa_activa_use_cases.dart';
import '../../domain/usecases/registrar_alerta_viaje_use_case.dart';
import '../../domain/usecases/ubicacion_viaje_use_cases.dart';
import 'monitor_ruta_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Sigue la posición del conductor mientras el viaje está EN_CURSO y la app
/// está abierta. La posición solo vive en este estado: lo único que sale del
/// teléfono es el evento puntual de parada o desvío, vía
/// [RegistrarAlertaViajeUseCase].
///
/// También vigila la conducción continua ([DetectorFatiga]): a las 4 h sin
/// parar activa `pausaActiva` (la pantalla muestra la card, vibra y suena) y,
/// si el conductor sigue en movimiento tras la gracia, avisa al administrador.
/// Consulta cada pocos segundos si el administrador lanzó una prueba.
class MonitorRutaCubit extends Cubit<MonitorRutaState> {
  MonitorRutaCubit({
    required String viajeId,
    required ServicioUbicacion ubicacion,
    required DetectorRuta detector,
    required RegistrarAlertaViajeUseCase registrarAlerta,
    required ConsultarConsentimientoUbicacionUseCase consultarConsentimiento,
    required ResponderConsentimientoUbicacionUseCase responderConsentimiento,
    required RegistrarUbicacionViajeUseCase registrarUbicacion,
    required RegistrarPausaIgnoradaUseCase registrarPausaIgnorada,
    required ConsumirPausaPruebaUseCase consumirPausaPrueba,
    DetectorFatiga? detectorFatiga,
    Duration consultaPrueba = const Duration(seconds: 20),
    DateTime Function() ahora = DateTime.now,
    Duration revision = const Duration(minutes: 1),
    Duration intervaloRegistro = const Duration(minutes: 5),
  }) : _viajeId = viajeId,
       _ubicacion = ubicacion,
       _detector = detector,
       _registrarAlerta = registrarAlerta,
       _consultarConsentimiento = consultarConsentimiento,
       _responderConsentimiento = responderConsentimiento,
       _registrarUbicacion = registrarUbicacion,
       _registrarPausaIgnorada = registrarPausaIgnorada,
       _consumirPausaPrueba = consumirPausaPrueba,
       _fatiga = detectorFatiga ?? DetectorFatiga(),
       _consultaPrueba = consultaPrueba,
       _intervaloRegistro = intervaloRegistro,
       _ahora = ahora,
       _revision = revision,
       super(const MonitorRutaIniciando());

  final String _viajeId;
  final ServicioUbicacion _ubicacion;
  final DetectorRuta _detector;
  final RegistrarAlertaViajeUseCase _registrarAlerta;
  final ConsultarConsentimientoUbicacionUseCase _consultarConsentimiento;
  final ResponderConsentimientoUbicacionUseCase _responderConsentimiento;
  final RegistrarUbicacionViajeUseCase _registrarUbicacion;
  final RegistrarPausaIgnoradaUseCase _registrarPausaIgnorada;
  final ConsumirPausaPruebaUseCase _consumirPausaPrueba;
  final DetectorFatiga _fatiga;
  final Duration _consultaPrueba;
  final Duration _intervaloRegistro;
  final DateTime Function() _ahora;
  final Duration _revision;

  StreamSubscription<Coordenada>? _suscripcion;
  Timer? _temporizador;
  Timer? _temporizadorRegistro;
  Timer? _temporizadorPrueba;
  Coordenada? _ultima;
  bool _consentimiento = false;
  bool _consentimientoConsultado = false;

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

    try {
      _consentimiento = await _consultarConsentimiento();
      _consentimientoConsultado = true;
    } on Object {
      // Sin red no se pregunta ni se registra: el mapa sigue funcionando.
    }
    if (isClosed) return;

    emit(
      MonitorRutaActivo(
        consentimientoPendiente: _consentimientoConsultado && !_consentimiento,
        registrando: _consentimiento,
      ),
    );
    if (_consentimiento) _programarRegistro();
    _temporizadorPrueba = Timer.periodic(
      _consultaPrueba,
      (_) => unawaited(_consultarPrueba()),
    );
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
    final bool primera = _activo.posicion == null;
    emit(_activo.copiarCon(posicion: posicion, registrando: _consentimiento));
    if (primera && _consentimiento) unawaited(_enviarPunto());
    _evaluar(posicion);
  }

  /// Estado actual como [MonitorRutaActivo]; antes de iniciar, uno vacío.
  MonitorRutaActivo get _activo {
    final MonitorRutaState actual = state;
    return actual is MonitorRutaActivo ? actual : const MonitorRutaActivo();
  }

  void _evaluar(Coordenada posicion) {
    if (isClosed) return;
    _evaluarFatiga(posicion);
    final TipoAlertaViaje? alerta = _detector.evaluar(posicion, _ahora());
    if (alerta == null || isClosed) return;

    emit(
      _activo.copiarCon(
        posicion: posicion,
        alerta: alerta,
        registrando: _consentimiento,
      ),
    );
    unawaited(_notificarServidor(alerta, posicion));
  }

  void _evaluarFatiga(Coordenada posicion) {
    final DateTime ahora = _ahora();
    switch (_fatiga.evaluar(posicion, ahora)) {
      case EventoFatiga.pausaActiva:
        emit(_activo.copiarCon(posicion: posicion, pausaActiva: true));
      case EventoFatiga.pausaIgnorada:
        unawaited(_notificarPausaIgnorada(ahora));
      case null:
        // Una parada de 15 min reinicia la cuenta y retira la card.
        if (_activo.pausaActiva && !_fatiga.avisoVigente) {
          emit(_activo.copiarCon(pausaActiva: false));
        }
    }
  }

  // Mejor esfuerzo: sin red el administrador no se entera de esta vez.
  Future<void> _notificarPausaIgnorada(DateTime ahora) async {
    try {
      await _registrarPausaIgnorada(
        viajeId: _viajeId,
        minutosConduccion: _fatiga.conduccion(ahora).inMinutes,
        minutosIgnorada: _fatiga.tiempoIgnorado(ahora).inMinutes,
        prueba: _fatiga.prueba,
      );
    } on Object {
      // Intencional: ver comentario arriba.
    }
  }

  Future<void> _consultarPrueba() async {
    if (isClosed) return;
    try {
      final bool hay = await _consumirPausaPrueba(viajeId: _viajeId);
      if (!hay || isClosed) return;
      _fatiga.forzarAviso(_ahora());
      emit(_activo.copiarCon(pausaActiva: true));
    } on Object {
      // Sin red se vuelve a preguntar en el siguiente ciclo.
    }
  }

  /// El conductor leyó el aviso: la card se oculta, pero la conducción
  /// continua se sigue midiendo (solo una pausa real la reinicia).
  void descartarPausaActiva() {
    if (_activo.pausaActiva) emit(_activo.copiarCon(pausaActiva: false));
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
    if (_activo.alerta != null) emit(_activo.copiarCon(limpiarAlerta: true));
  }

  /// El conductor acepta o rechaza el registro de su ubicación (RF-23).
  Future<void> responderConsentimiento({required bool acepta}) async {
    final MonitorRutaState actual = state;
    if (actual is! MonitorRutaActivo) return;
    try {
      _consentimiento = await _responderConsentimiento(acepta: acepta);
    } on Object {
      return; // Se mantiene la pregunta para reintentar.
    }
    if (isClosed) return;
    emit(
      actual.copiarCon(
        consentimientoPendiente: false,
        registrando: _consentimiento,
      ),
    );
    if (_consentimiento) {
      _programarRegistro();
      unawaited(_enviarPunto());
    } else {
      _temporizadorRegistro?.cancel();
    }
  }

  void _programarRegistro() {
    _temporizadorRegistro?.cancel();
    _temporizadorRegistro = Timer.periodic(
      _intervaloRegistro,
      (_) => unawaited(_enviarPunto()),
    );
  }

  // Mejor esfuerzo: un punto perdido no afecta al viaje.
  Future<void> _enviarPunto() async {
    final Coordenada? ultima = _ultima;
    if (ultima == null || !_consentimiento || isClosed) return;
    try {
      await _registrarUbicacion(viajeId: _viajeId, posicion: ultima);
    } on Object {
      // Intencional: ver comentario arriba.
    }
  }

  @override
  Future<void> close() async {
    _temporizadorRegistro?.cancel();
    _temporizadorPrueba?.cancel();
    _temporizador?.cancel();
    await _suscripcion?.cancel();
    return super.close();
  }
}
