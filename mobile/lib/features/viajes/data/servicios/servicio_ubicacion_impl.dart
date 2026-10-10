import 'package:geolocator/geolocator.dart';

import '../../domain/entities/coordenada.dart';
import '../../domain/servicios/servicio_ubicacion.dart';

/// Posición del dispositivo con `geolocator`. Solo primer plano: no hay
/// servicio en segundo plano, y nada de lo que entrega se guarda.
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
    return Geolocator.getPositionStream(
      // 25 m evita ruido de GPS parado y ahorra batería; la parada se detecta
      // por tiempo sin salir de un radio, no por frecuencia de muestras.
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).map((Position p) => Coordenada(p.latitude, p.longitude));
  }
}
