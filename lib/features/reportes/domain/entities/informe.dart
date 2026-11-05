import 'package:equatable/equatable.dart';

import '../../../dashboard/domain/entities/metricas.dart';

/// Filtros opcionales que un informe acepta además de las fechas.
enum CampoFiltro { cliente, conductor, vehiculo, ruta }

const Set<CampoFiltro> _todosLosCampos = <CampoFiltro>{
  CampoFiltro.cliente,
  CampoFiltro.conductor,
  CampoFiltro.vehiculo,
  CampoFiltro.ruta,
};

/// Informes que el administrador puede consultar y exportar. Cada uno declara
/// qué filtros y qué agrupaciones entiende la RPC que lo alimenta; la pantalla
/// solo muestra esos controles.
enum TipoInforme {
  viajes(
    etiqueta: 'Viajes cerrados',
    descripcion: 'Detalle viaje a viaje con flete, costos y rentabilidad.',
    archivo: 'viajes',
    campos: _todosLosCampos,
  ),
  estadoResultados(
    etiqueta: 'Estado de resultados',
    descripcion:
        'Rentabilidad consolidada del período contra el período anterior.',
    archivo: 'estado-de-resultados',
    campos: _todosLosCampos,
  ),
  rentabilidad(
    etiqueta: 'Rentabilidad por ruta, cliente, conductor o placa',
    descripcion: 'Margen de cada grupo; marca los de bajo margen.',
    archivo: 'rentabilidad',
    campos: _todosLosCampos,
    dimensiones: <DimensionMetrica>[
      DimensionMetrica.ruta,
      DimensionMetrica.cliente,
      DimensionMetrica.conductor,
      DimensionMetrica.placa,
    ],
  ),
  costos(
    etiqueta: 'Desglose de costos',
    descripcion: 'Monto y peso de cada categoría de costo del período.',
    archivo: 'costos',
    campos: _todosLosCampos,
  ),
  puntualidad(
    etiqueta: 'Puntualidad y retrasos',
    descripcion: 'Viajes que llegaron a tiempo según los hitos del conductor.',
    archivo: 'puntualidad',
    campos: _todosLosCampos,
    dimensiones: <DimensionMetrica>[
      DimensionMetrica.conductor,
      DimensionMetrica.cliente,
      DimensionMetrica.ruta,
      DimensionMetrica.placa,
    ],
  ),
  esperas(
    etiqueta: 'Tiempos de espera',
    descripcion: 'Horas de espera en cargue y descargue por cliente.',
    archivo: 'tiempos-de-espera',
    campos: <CampoFiltro>{},
  ),
  flota(
    etiqueta: 'Estado de flota y mantenimiento',
    descripcion:
        'Documentos y mantenimientos preventivos de cada vehículo hoy.',
    archivo: 'flota',
    campos: <CampoFiltro>{},
    usaFechas: false,
  ),
  conductores(
    etiqueta: 'Desempeño por conductor',
    descripcion: 'Viajes, margen, puntualidad, calidad y satisfacción de cada conductor.',
    archivo: 'desempeno-conductores',
    campos: <CampoFiltro>{
      CampoFiltro.cliente,
      CampoFiltro.vehiculo,
      CampoFiltro.ruta,
    },
  ),
  satisfaccion(
    etiqueta: 'Satisfacción del cliente',
    descripcion: 'CSAT y NPS de las encuestas respondidas.',
    archivo: 'satisfaccion',
    campos: _todosLosCampos,
    dimensiones: <DimensionMetrica>[
      DimensionMetrica.cliente,
      DimensionMetrica.conductor,
      DimensionMetrica.ruta,
    ],
  ),
  calidad(
    etiqueta: 'Calidad del viaje',
    descripcion: 'Puntaje de calidad por grupo y alertas recurrentes.',
    archivo: 'calidad',
    campos: _todosLosCampos,
    dimensiones: <DimensionMetrica>[
      DimensionMetrica.conductor,
      DimensionMetrica.ruta,
      DimensionMetrica.placa,
    ],
  );

  const TipoInforme({
    required this.etiqueta,
    required this.descripcion,
    required this.archivo,
    required this.campos,
    this.dimensiones = const <DimensionMetrica>[],
    this.usaFechas = true,
  });

  final String etiqueta;
  final String descripcion;

  /// Prefijo del nombre del archivo PDF.
  final String archivo;
  final Set<CampoFiltro> campos;

  /// Agrupaciones que acepta; vacío si el informe no se agrupa.
  final List<DimensionMetrica> dimensiones;
  final bool usaFechas;
}

/// Un informe ya armado y formateado para mostrarlo y exportarlo. Los textos
/// salen listos de los casos de uso: la pantalla y el PDF solo los dibujan.
class Informe extends Equatable {
  const Informe({
    required this.titulo,
    required this.columnas,
    required this.filas,
    this.numericas = const <int>{},
    this.resumen,
    this.notas = const <String>[],
  });

  final String titulo;
  final List<String> columnas;
  final List<List<String>> filas;

  /// Índices de las columnas que se alinean a la derecha.
  final Set<int> numericas;

  /// Línea de totales o de cifras clave.
  final String? resumen;
  final List<String> notas;

  @override
  List<Object?> get props => <Object?>[
    titulo,
    columnas,
    filas,
    numericas,
    resumen,
    notas,
  ];
}
