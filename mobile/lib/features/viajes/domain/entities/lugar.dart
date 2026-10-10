import 'package:equatable/equatable.dart';

import 'coordenada.dart';

/// Ubicación elegida por el administrador como origen o destino: el nombre
/// que se guarda en `viaje.origen`/`destino` y su coordenada en el mapa.
class Lugar extends Equatable {
  const Lugar({required this.nombre, required this.coordenada});

  final String nombre;
  final Coordenada coordenada;

  @override
  List<Object?> get props => <Object?>[nombre, coordenada];
}
