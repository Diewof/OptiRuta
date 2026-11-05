import 'package:equatable/equatable.dart';

/// Documentos del vehículo que bloquean o alertan. Fuente de verdad: CHECK de
/// `public.documento_vehiculo.tipo`. Tarjeta de operación y pólizas quedaron
/// fuera del alcance.
enum TipoDocumentoVehiculo {
  soat('SOAT', 'SOAT'),
  tecnomecanica('TECNOMECANICA', 'Revisión técnico-mecánica');

  const TipoDocumentoVehiculo(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoDocumentoVehiculo desdeCodigo(String valor) {
    return switch (valor) {
      'SOAT' => TipoDocumentoVehiculo.soat,
      'TECNOMECANICA' => TipoDocumentoVehiculo.tecnomecanica,
      _ => throw ArgumentError.value(
        valor,
        'valor',
        'Tipo de documento no válido',
      ),
    };
  }
}

/// Estado de un documento vigente; lo calcula la vista
/// `documento_vehiculo_vigente` (por vencer = 30 días o menos).
enum EstadoDocumento {
  vigente('VIGENTE', 'Vigente'),
  porVencer('POR_VENCER', 'Por vencer'),
  vencido('VENCIDO', 'Vencido');

  const EstadoDocumento(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static EstadoDocumento desdeCodigo(String valor) {
    return switch (valor) {
      'VIGENTE' => EstadoDocumento.vigente,
      'POR_VENCER' => EstadoDocumento.porVencer,
      'VENCIDO' => EstadoDocumento.vencido,
      _ => throw ArgumentError.value(
        valor,
        'valor',
        'Estado de documento no válido',
      ),
    };
  }
}

/// El documento vigente de un tipo: el de mayor vencimiento.
class DocumentoVehiculo extends Equatable {
  const DocumentoVehiculo({
    required this.id,
    required this.vehiculoId,
    required this.tipo,
    required this.fechaVencimiento,
    required this.diasRestantes,
    required this.estado,
    this.numero,
    this.entidadEmisora,
    this.fechaExpedicion,
  });

  final String id;
  final String vehiculoId;
  final TipoDocumentoVehiculo tipo;
  final DateTime fechaVencimiento;

  /// Negativo si ya venció.
  final int diasRestantes;
  final EstadoDocumento estado;
  final String? numero;

  /// Aseguradora (SOAT) o CDA (tecnomecánica).
  final String? entidadEmisora;
  final DateTime? fechaExpedicion;

  @override
  List<Object?> get props => <Object?>[
    id,
    vehiculoId,
    tipo,
    fechaVencimiento,
    diasRestantes,
    estado,
    numero,
    entidadEmisora,
    fechaExpedicion,
  ];
}
