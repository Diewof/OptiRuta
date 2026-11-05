import 'package:equatable/equatable.dart';

import '../../../reportes/domain/entities/reporte.dart';
import '../../domain/entities/calidad.dart';

sealed class CalidadState extends Equatable {
  const CalidadState();

  @override
  List<Object?> get props => <Object?>[];
}

class CalidadCargando extends CalidadState {
  const CalidadCargando();
}

class CalidadError extends CalidadState {
  const CalidadError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class CalidadListo extends CalidadState {
  const CalidadListo({
    required this.filtro,
    required this.opciones,
    required this.resumen,
    required this.porDimension,
    required this.recurrentes,
  });

  final FiltroReporte filtro;
  final OpcionesReporte opciones;
  final ResumenCalidad resumen;

  /// Ruta, conductor y placa, de menor a mayor puntaje.
  final Map<DimensionCalidad, List<CalidadDimension>> porDimension;
  final List<AlertaRecurrente> recurrentes;

  @override
  List<Object?> get props => <Object?>[
    filtro,
    opciones,
    resumen,
    porDimension,
    recurrentes,
  ];
}
