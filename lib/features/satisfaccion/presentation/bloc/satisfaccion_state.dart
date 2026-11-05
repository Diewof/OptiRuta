import 'package:equatable/equatable.dart';

import '../../../dashboard/domain/entities/metricas.dart';
import '../../../reportes/domain/entities/reporte.dart';
import '../../domain/entities/satisfaccion.dart';

sealed class SatisfaccionState extends Equatable {
  const SatisfaccionState();

  @override
  List<Object?> get props => <Object?>[];
}

class SatisfaccionCargando extends SatisfaccionState {
  const SatisfaccionCargando();
}

class SatisfaccionError extends SatisfaccionState {
  const SatisfaccionError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class SatisfaccionListo extends SatisfaccionState {
  const SatisfaccionListo({
    required this.filtro,
    required this.opciones,
    required this.resumen,
    required this.porDimension,
    required this.comentarios,
  });

  final FiltroReporte filtro;
  final OpcionesReporte opciones;
  final ResumenSatisfaccion resumen;

  /// Ruta, cliente y conductor, de menor a mayor satisfacción.
  final Map<DimensionMetrica, List<SatisfaccionDimension>> porDimension;
  final List<ComentarioSatisfaccion> comentarios;

  @override
  List<Object?> get props => <Object?>[
    filtro,
    opciones,
    resumen,
    porDimension,
    comentarios,
  ];
}
