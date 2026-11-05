import 'package:equatable/equatable.dart';

/// Cliente de la empresa (quien paga el flete). Sin borrado fisico: la baja
/// se hace con `activo = false` (FK de `viaje` con `ON DELETE RESTRICT`).
class Cliente extends Equatable {
  const Cliente({
    required this.id,
    required this.nombre,
    required this.documento,
    required this.telefono,
    required this.correo,
    required this.direccion,
    required this.activo,
  });

  final String id;
  final String nombre;

  /// NIT o cedula. Opcional: la bitacora historica no siempre lo registra.
  final String? documento;
  final String? telefono;
  final String? correo;
  final String? direccion;
  final bool activo;

  @override
  List<Object?> get props => <Object?>[
    id,
    nombre,
    documento,
    telefono,
    correo,
    direccion,
    activo,
  ];
}
