import 'package:equatable/equatable.dart';

/// Datos técnicos del vehículo que sirven al mantenimiento y a la
/// trazabilidad (columnas opcionales de `public.vehiculo`).
class FichaTecnica extends Equatable {
  const FichaTecnica({
    this.marca,
    this.linea,
    this.modeloAnio,
    this.vin,
    this.numeroMotor,
    this.numeroEjes,
    this.cantidadLlantas,
    this.pbvKg,
    this.odometroInicialKm = 0,
  });

  static const FichaTecnica vacia = FichaTecnica();

  final String? marca;
  final String? linea;
  final int? modeloAnio;
  final String? vin;
  final String? numeroMotor;
  final int? numeroEjes;
  final int? cantidadLlantas;

  /// Peso bruto vehicular en kg.
  final double? pbvKg;

  /// Lectura del tablero al dar de alta el vehículo en el sistema.
  final double odometroInicialKm;

  /// Marca y línea juntas, p. ej. «Kenworth T800»; nulo si no hay ninguna.
  String? get descripcion {
    final String texto = <String?>[
      marca,
      linea,
    ].whereType<String>().join(' ').trim();
    return texto.isEmpty ? null : texto;
  }

  @override
  List<Object?> get props => <Object?>[
    marca,
    linea,
    modeloAnio,
    vin,
    numeroMotor,
    numeroEjes,
    cantidadLlantas,
    pbvKg,
    odometroInicialKm,
  ];
}
