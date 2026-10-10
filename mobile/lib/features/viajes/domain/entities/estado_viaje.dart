/// Ciclo de vida del viaje. Fuente de verdad: CHECK de `public.viaje.estado`
/// y el trigger `viaje_validar_transicion`.
enum EstadoViaje {
  planificado('PLANIFICADO', 'Planificado'),
  asignado('ASIGNADO', 'Asignado'),
  enCurso('EN_CURSO', 'En curso'),
  finalizado('FINALIZADO', 'Finalizado'),
  cerrado('CERRADO', 'Cerrado');

  const EstadoViaje(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static EstadoViaje desdeCodigo(String valor) {
    return switch (valor) {
      'PLANIFICADO' => EstadoViaje.planificado,
      'ASIGNADO' => EstadoViaje.asignado,
      'EN_CURSO' => EstadoViaje.enCurso,
      'FINALIZADO' => EstadoViaje.finalizado,
      'CERRADO' => EstadoViaje.cerrado,
      _ => throw ArgumentError.value(
        valor,
        'valor',
        'Estado de viaje no válido',
      ),
    };
  }
}
