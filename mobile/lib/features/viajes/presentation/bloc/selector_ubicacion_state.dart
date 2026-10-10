import 'package:equatable/equatable.dart';

import '../../domain/entities/lugar.dart';

class SelectorUbicacionState extends Equatable {
  const SelectorUbicacionState({
    this.resultados = const <Lugar>[],
    this.buscando = false,
    this.resolviendo = false,
    this.seleccion,
    this.error,
    this.busquedaSinResultados = false,
  });

  /// Sugerencias del autocompletado para el texto escrito (ya con coordenada).
  final List<Lugar> resultados;
  final bool buscando;

  /// Se está obteniendo el nombre del punto donde quedó el pin.
  final bool resolviendo;

  /// Lugar que se guardará al confirmar; `null` mientras no se haya elegido.
  final Lugar? seleccion;
  final String? error;
  final bool busquedaSinResultados;

  SelectorUbicacionState copiarCon({
    List<Lugar>? resultados,
    bool? buscando,
    bool? resolviendo,
    Lugar? seleccion,
    String? error,
    bool limpiarError = false,
    bool? busquedaSinResultados,
  }) {
    return SelectorUbicacionState(
      resultados: resultados ?? this.resultados,
      buscando: buscando ?? this.buscando,
      resolviendo: resolviendo ?? this.resolviendo,
      seleccion: seleccion ?? this.seleccion,
      error: limpiarError ? null : (error ?? this.error),
      busquedaSinResultados:
          busquedaSinResultados ?? this.busquedaSinResultados,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    resultados,
    buscando,
    resolviendo,
    seleccion,
    error,
    busquedaSinResultados,
  ];
}
