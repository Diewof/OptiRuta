import 'package:equatable/equatable.dart';

/// Precio del galón de ACPM de una ciudad desde una fecha (RF-12). La
/// estimación de ACPM de un viaje usa la tarifa vigente más reciente cuyo
/// nombre de ciudad esté contenido en el origen del viaje.
class TarifaCombustible extends Equatable {
  const TarifaCombustible({
    required this.id,
    required this.ciudad,
    required this.precioGalon,
    required this.fechaVigenciaDesde,
    required this.automatica,
  });

  final String id;
  final String ciudad;
  final double precioGalon;
  final DateTime fechaVigenciaDesde;

  /// `true` si la cargó el scraper mensual; `false` si la capturó un admin.
  final bool automatica;

  @override
  List<Object?> get props => <Object?>[
    id,
    ciudad,
    precioGalon,
    fechaVigenciaDesde,
    automatica,
  ];
}
