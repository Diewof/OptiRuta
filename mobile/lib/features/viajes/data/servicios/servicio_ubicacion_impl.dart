import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/coordenada.dart';
import '../../domain/servicios/servicio_ubicacion.dart';

/// Posición del dispositivo con `geolocator`. En Android el seguimiento corre
/// como servicio en primer plano (notificación fija) para seguir con la
/// pantalla bloqueada o la app minimizada; solo vive mientras haya un oyente.
class ServicioUbicacionImpl implements ServicioUbicacion {
  const ServicioUbicacionImpl();

  @override
  Future<EstadoPermisoUbicacion> solicitarPermiso() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return EstadoPermisoUbicacion.bloqueado;
    }
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    return switch (permiso) {
      LocationPermission.always ||
      LocationPermission.whileInUse => EstadoPermisoUbicacion.concedido,
      LocationPermission.deniedForever => EstadoPermisoUbicacion.bloqueado,
      _ => EstadoPermisoUbicacion.denegado,
    };
  }

  @override
  Future<Coordenada> posicionActual() async {
    final Position p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return Coordenada(p.latitude, p.longitude);
  }

  @override
  Stream<Coordenada> posiciones() {
    // 25 m evita ruido de GPS parado y ahorra batería; la parada se detecta
    // por tiempo sin salir de un radio, no por frecuencia de muestras.
    final LocationSettings ajustes =
        defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'OptiRuta · viaje en curso',
              notificationText: 'Compartiendo tu ubicación con la empresa mientras dure el viaje.',
              notificationChannelName: 'Viaje en curso',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
          );
    return Geolocator.getPositionStream(locationSettings: ajustes)
        .map((Position p) => Coordenada(p.latitude, p.longitude));
  }
}
