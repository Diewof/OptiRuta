import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../dashboard/domain/entities/metricas.dart';
import '../../domain/entities/informe.dart';
import '../../domain/entities/reporte.dart';
import '../../domain/usecases/informes_use_cases.dart';
import '../../domain/usecases/reporte_use_cases.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

enum EstadoReporte { cargando, listo, error }

class ReportesState extends Equatable {
  const ReportesState({
    required this.filtro,
    this.tipo = TipoInforme.viajes,
    this.dimension = DimensionMetrica.ruta,
    this.estado = EstadoReporte.cargando,
    this.informe,
    this.opciones = const OpcionesReporte(),
    this.exportando = false,
    this.mensaje,
  });

  final FiltroReporte filtro;
  final TipoInforme tipo;

  /// Agrupación del informe; solo aplica si [TipoInforme.dimensiones] no es
  /// vacío.
  final DimensionMetrica dimension;
  final EstadoReporte estado;
  final Informe? informe;
  final OpcionesReporte opciones;
  final bool exportando;

  /// Error de carga o de exportación para mostrar al usuario.
  final String? mensaje;

  /// Texto de los filtros activos, para el encabezado del PDF. Solo nombra
  /// los que el informe usa.
  String get descripcionFiltros {
    String nombre(List<OpcionFiltro> l, String? id) =>
        l
            .where((OpcionFiltro o) => o.id == id)
            .map((OpcionFiltro o) => o.nombre)
            .firstOrNull ??
        'Todos';
    final String? ruta = filtro.ruta;
    return <String>[
      if (tipo.usaFechas)
        '${formatearFecha(filtro.desde)} a ${formatearFecha(filtro.hasta)}'
      else
        'Al ${formatearFecha(DateTime.now())}',
      if (tipo.dimensiones.isNotEmpty) 'Agrupado por: ${dimension.etiqueta}',
      if (tipo.campos.contains(CampoFiltro.cliente))
        'Cliente: ${nombre(opciones.clientes, filtro.clienteId)}',
      if (tipo.campos.contains(CampoFiltro.conductor))
        'Conductor: ${nombre(opciones.conductores, filtro.conductorId)}',
      if (tipo.campos.contains(CampoFiltro.vehiculo))
        'Vehículo: ${nombre(opciones.vehiculos, filtro.vehiculoId)}',
      if (tipo.campos.contains(CampoFiltro.ruta))
        'Ruta: ${ruta == null || ruta.isEmpty ? 'Todas' : ruta}',
    ].join(' · ');
  }

  String get nombreArchivo {
    String iso(DateTime f) => f.toIso8601String().split('T').first;
    return tipo.usaFechas
        ? 'informe-${tipo.archivo}-${iso(filtro.desde)}_${iso(filtro.hasta)}.pdf'
        : 'informe-${tipo.archivo}-${iso(DateTime.now())}.pdf';
  }

  ReportesState copiarCon({
    FiltroReporte? filtro,
    TipoInforme? tipo,
    DimensionMetrica? dimension,
    EstadoReporte? estado,
    Informe? informe,
    OpcionesReporte? opciones,
    bool? exportando,
    String? Function()? mensaje,
  }) {
    return ReportesState(
      filtro: filtro ?? this.filtro,
      tipo: tipo ?? this.tipo,
      dimension: dimension ?? this.dimension,
      estado: estado ?? this.estado,
      informe: informe ?? this.informe,
      opciones: opciones ?? this.opciones,
      exportando: exportando ?? this.exportando,
      mensaje: mensaje != null ? mensaje() : this.mensaje,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    filtro,
    tipo,
    dimension,
    estado,
    informe,
    opciones,
    exportando,
    mensaje,
  ];
}

/// Elige el informe, lo filtra, lo lista y lo exporta (RF-27/28).
class ReportesCubit extends Cubit<ReportesState> {
  ReportesCubit({
    required ObtenerInformeUseCase obtener,
    required ExportarReportePdfUseCase exportar,
    required Future<OpcionesReporte> Function() cargarOpciones,
    required DateTime hoy,
  }) : _obtener = obtener,
       _exportar = exportar,
       _cargarOpciones = cargarOpciones,
       super(
         ReportesState(
           filtro: FiltroReporte(
             desde: DateTime(hoy.year, hoy.month),
             hasta: DateTime(hoy.year, hoy.month, hoy.day),
           ),
         ),
       ) {
    _iniciar();
  }

  final ObtenerInformeUseCase _obtener;
  final ExportarReportePdfUseCase _exportar;
  final Future<OpcionesReporte> Function() _cargarOpciones;

  /// Descarta la respuesta de una consulta vieja si el usuario ya cambió de
  /// informe o de filtros.
  int _consulta = 0;

  Future<void> _iniciar() async {
    try {
      final OpcionesReporte opciones = await _cargarOpciones();
      if (!isClosed) emit(state.copiarCon(opciones: opciones));
    } on Object {
      // Sin opciones los selectores quedan en «Todos»; el informe sigue.
    }
    await consultar();
  }

  Future<void> consultar() async {
    final int numero = ++_consulta;
    emit(state.copiarCon(estado: EstadoReporte.cargando, mensaje: () => null));
    try {
      final Informe informe = await _obtener(
        state.tipo,
        state.filtro,
        state.dimension,
      );
      if (isClosed || numero != _consulta) return;
      emit(state.copiarCon(estado: EstadoReporte.listo, informe: informe));
    } on CatalogoFailure catch (falla) {
      _error(numero, falla.mensaje);
    } on ArgumentError {
      _error(numero, 'La fecha inicial no puede ser posterior a la final.');
    } on Object {
      _error(numero, 'No se pudo cargar el informe. Intenta de nuevo.');
    }
  }

  void _error(int numero, String mensaje) {
    if (isClosed || numero != _consulta) return;
    emit(state.copiarCon(estado: EstadoReporte.error, mensaje: () => mensaje));
  }

  Future<void> aplicarFiltro(FiltroReporte filtro) {
    emit(state.copiarCon(filtro: filtro));
    return consultar();
  }

  Future<void> cambiarTipo(TipoInforme tipo) {
    if (tipo == state.tipo) return Future<void>.value();
    emit(
      state.copiarCon(
        tipo: tipo,
        dimension: tipo.dimensiones.contains(state.dimension)
            ? state.dimension
            : (tipo.dimensiones.firstOrNull ?? state.dimension),
      ),
    );
    return consultar();
  }

  Future<void> cambiarDimension(DimensionMetrica dimension) {
    if (dimension == state.dimension) return Future<void>.value();
    emit(state.copiarCon(dimension: dimension));
    return consultar();
  }

  Future<void> exportarPdf() async {
    final Informe? informe = state.informe;
    if (state.exportando || informe == null) return;
    emit(state.copiarCon(exportando: true, mensaje: () => null));
    try {
      await _exportar(
        informe: informe,
        descripcionFiltros: state.descripcionFiltros,
        nombreArchivo: state.nombreArchivo,
      );
      emit(state.copiarCon(exportando: false));
    } on Object {
      emit(
        state.copiarCon(
          exportando: false,
          mensaje: () => 'No se pudo generar el PDF. Intenta de nuevo.',
        ),
      );
    }
  }
}
