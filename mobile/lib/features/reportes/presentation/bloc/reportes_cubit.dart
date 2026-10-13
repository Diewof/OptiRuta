import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/reporte.dart';
import '../../domain/usecases/reporte_use_cases.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

enum EstadoReporte { cargando, listo, error }

class ReportesState extends Equatable {
  const ReportesState({
    required this.filtro,
    this.estado = EstadoReporte.cargando,
    this.filas = const <FilaReporte>[],
    this.opciones = const OpcionesReporte(),
    this.exportando = false,
    this.mensaje,
  });

  final FiltroReporte filtro;
  final EstadoReporte estado;
  final List<FilaReporte> filas;
  final OpcionesReporte opciones;
  final bool exportando;

  /// Error de carga o de exportación para mostrar al usuario.
  final String? mensaje;

  TotalesReporte get totales => TotalesReporte.de(filas);

  /// Texto de los filtros activos, para el encabezado del PDF.
  String get descripcionFiltros {
    String nombre(List<OpcionFiltro> l, String? id) =>
        l
            .where((OpcionFiltro o) => o.id == id)
            .map((o) => o.nombre)
            .firstOrNull ??
        'Todos';
    final String? ruta = filtro.ruta;
    return 'Cliente: ${nombre(opciones.clientes, filtro.clienteId)} · '
        'Conductor: ${nombre(opciones.conductores, filtro.conductorId)} · '
        'Vehículo: ${nombre(opciones.vehiculos, filtro.vehiculoId)} · '
        'Ruta: ${ruta == null || ruta.isEmpty ? 'Todas' : ruta}';
  }

  ReportesState copiarCon({
    FiltroReporte? filtro,
    EstadoReporte? estado,
    List<FilaReporte>? filas,
    OpcionesReporte? opciones,
    bool? exportando,
    String? Function()? mensaje,
  }) {
    return ReportesState(
      filtro: filtro ?? this.filtro,
      estado: estado ?? this.estado,
      filas: filas ?? this.filas,
      opciones: opciones ?? this.opciones,
      exportando: exportando ?? this.exportando,
      mensaje: mensaje != null ? mensaje() : this.mensaje,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    filtro,
    estado,
    filas,
    opciones,
    exportando,
    mensaje,
  ];
}

/// Filtra, lista y exporta el reporte de viajes cerrados (RF-27/28).
class ReportesCubit extends Cubit<ReportesState> {
  ReportesCubit({
    required ObtenerReporteViajesUseCase obtener,
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

  final ObtenerReporteViajesUseCase _obtener;
  final ExportarReportePdfUseCase _exportar;
  final Future<OpcionesReporte> Function() _cargarOpciones;

  Future<void> _iniciar() async {
    try {
      final OpcionesReporte opciones = await _cargarOpciones();
      if (!isClosed) emit(state.copiarCon(opciones: opciones));
    } on Object {
      // Sin opciones los selectores quedan en «Todos»; el reporte sigue.
    }
    await consultar();
  }

  Future<void> consultar() async {
    emit(state.copiarCon(estado: EstadoReporte.cargando, mensaje: () => null));
    try {
      final List<FilaReporte> filas = await _obtener(state.filtro);
      if (isClosed) return;
      emit(state.copiarCon(estado: EstadoReporte.listo, filas: filas));
    } on CatalogoFailure catch (falla) {
      emit(
        state.copiarCon(
          estado: EstadoReporte.error,
          mensaje: () => falla.mensaje,
        ),
      );
    } on ArgumentError {
      emit(
        state.copiarCon(
          estado: EstadoReporte.error,
          mensaje: () => 'La fecha inicial no puede ser posterior a la final.',
        ),
      );
    }
  }

  Future<void> aplicarFiltro(FiltroReporte filtro) {
    emit(state.copiarCon(filtro: filtro));
    return consultar();
  }

  Future<void> exportarPdf() async {
    if (state.exportando) return;
    emit(state.copiarCon(exportando: true, mensaje: () => null));
    try {
      await _exportar(
        filtro: state.filtro,
        descripcionFiltros: state.descripcionFiltros,
        filas: state.filas,
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
