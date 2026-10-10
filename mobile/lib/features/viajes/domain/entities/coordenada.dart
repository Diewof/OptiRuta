import 'package:equatable/equatable.dart';

/// Punto geográfico (WGS84). Tipo propio del dominio: `domain` no depende de
/// `google_maps_flutter` ni de `geolocator`; la capa de presentación/datos convierte.
class Coordenada extends Equatable {
  const Coordenada(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  List<Object?> get props => <Object?>[lat, lng];
}
