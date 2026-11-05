import 'package:equatable/equatable.dart';

import 'tipo_pago.dart';

/// Perfil de conductor: extiende la fila de `public.usuario` (rol CONDUCTOR)
/// con los datos operativos que solo importan para asignar viajes y calcular
/// la comision/sueldo. `nombre`/`documento` vienen del `usuario` asociado
/// (join de solo lectura), no de esta tabla.
class Conductor extends Equatable {
  const Conductor({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.documento,
    required this.licencia,
    required this.fechaVencimientoLicencia,
    required this.tipoPago,
    required this.porcentajeComision,
    required this.sueldoBase,
    required this.activo,
  });

  final String id;
  final String usuarioId;
  final String nombre;
  final String? documento;
  final String licencia;
  final DateTime fechaVencimientoLicencia;
  final TipoPago tipoPago;
  final double porcentajeComision;
  final double sueldoBase;
  final bool activo;

  @override
  List<Object?> get props => <Object?>[
    id,
    usuarioId,
    nombre,
    documento,
    licencia,
    fechaVencimientoLicencia,
    tipoPago,
    porcentajeComision,
    sueldoBase,
    activo,
  ];
}
