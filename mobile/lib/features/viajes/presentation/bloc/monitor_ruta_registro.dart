// ignore_for_file: prefer_initializing_formals
import '../../domain/detector_ruta.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/repositories/ubicacion_viaje_repository.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../../domain/ruta_geometria.dart';
import '../../domain/servicios/servicio_ubicacion.dart';
import '../../domain/usecases/registrar_alerta_viaje_use_case.dart';
import '../../domain/usecases/ubicacion_viaje_use_cases.dart';
import 'monitor_ruta_cubit.dart';

/// Conserva el [MonitorRutaCubit] del viaje en curso mientras la app siga
/// viva, aunque el conductor cambie de pestaña o bloquee la pantalla (RF-21/22
/// en segundo plano: el servicio en primer plano de Android mantiene el
/// proceso, y este registro mantiene el cubit). Un solo viaje a la vez.
class MonitorRutaRegistro {
  MonitorRutaRegistro({
    required ServicioUbicacion ubicacion,
    required ViajeRepository viajes,
    required UbicacionViajeRepository ubicaciones,
  }) : _ubicacion = ubicacion,
       _viajes = viajes,
       _ubicaciones = ubicaciones;

  final ServicioUbicacion _ubicacion;
  final ViajeRepository _viajes;
  final UbicacionViajeRepository _ubicaciones;

  MonitorRutaCubit? _cubit;
  String? _viajeId;

  /// Devuelve el monitor del viaje, creándolo (y arrancándolo) la primera vez.
  /// Si había uno de otro viaje, lo cierra.
  MonitorRutaCubit obtener(ViajeResumen viaje) {
    if (_cubit != null && _viajeId == viaje.id && !_cubit!.isClosed) {
      return _cubit!;
    }
    liberar();
    _viajeId = viaje.id;
    return _cubit = MonitorRutaCubit(
      viajeId: viaje.id,
      ubicacion: _ubicacion,
      detector: DetectorRuta(
        ruta: decodificarPolilinea(viaje.rutaPolilinea ?? ''),
      ),
      registrarAlerta: RegistrarAlertaViajeUseCase(_viajes),
      consultarConsentimiento: ConsultarConsentimientoUbicacionUseCase(
        _ubicaciones,
      ),
      responderConsentimiento: ResponderConsentimientoUbicacionUseCase(
        _ubicaciones,
      ),
      registrarUbicacion: RegistrarUbicacionViajeUseCase(_ubicaciones),
    )..iniciar();
  }

  /// Detiene el seguimiento (viaje terminado o sesión cerrada).
  void liberar([String? viajeId]) {
    if (viajeId != null && viajeId != _viajeId) return;
    _cubit?.close();
    _cubit = null;
    _viajeId = null;
  }
}
