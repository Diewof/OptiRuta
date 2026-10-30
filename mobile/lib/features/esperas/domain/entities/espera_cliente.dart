import 'package:equatable/equatable.dart';

/// Una fila de `tiempos_espera`: horas de espera promedio de un cliente en
/// cargue y descargue. Solo cuentan esperas completas (hito de llegada y de
/// salida registrados por el conductor); `null` = sin medición.
class EsperaCliente extends Equatable {
  const EsperaCliente({
    required this.cliente,
    required this.viajes,
    required this.carguesMedidos,
    required this.descarguesMedidos,
    required this.esperaTotalH,
    required this.esperaMaximaH,
    required this.viajesSobreUmbral,
    this.esperaCargueH,
    this.esperaDescargueH,
  });

  final String cliente;
  final int viajes;
  final int carguesMedidos;
  final double? esperaCargueH;
  final int descarguesMedidos;
  final double? esperaDescargueH;
  final double esperaTotalH;
  final double esperaMaximaH;

  /// Viajes con alguna espera sobre el umbral que fija el servidor.
  final int viajesSobreUmbral;

  @override
  List<Object?> get props => <Object?>[
    cliente,
    viajes,
    carguesMedidos,
    esperaCargueH,
    descarguesMedidos,
    esperaDescargueH,
    esperaTotalH,
    esperaMaximaH,
    viajesSobreUmbral,
  ];
}
