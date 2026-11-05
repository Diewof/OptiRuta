import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../dashboard/domain/entities/metricas.dart';
import '../../../reportes/domain/entities/reporte.dart';
import '../../domain/entities/satisfaccion.dart';
import '../../domain/usecases/satisfaccion_use_cases.dart';
import 'satisfaccion_state.dart';

// Los campos privados se asignan en la lista de inicializacion porque los
// parametros con nombre no pueden empezar por "_".
// ignore_for_file: prefer_initializing_formals

/// Orquesta la pestaña «Satisfacción» del Resumen: resumen del período,
/// ranking por ruta/cliente/conductor y comentarios, con los mismos filtros
/// que el Resumen de costos.
class SatisfaccionCubit extends Cubit<SatisfaccionState> {
  SatisfaccionCubit({
    required ObtenerResumenSatisfaccionUseCase resumen,
    required ObtenerSatisfaccionPorDimensionUseCase porDimension,
    required ListarComentariosSatisfaccionUseCase comentarios,
    required Future<OpcionesReporte> Function() cargarOpciones,
  }) : _resumen = resumen,
       _porDimension = porDimension,
       _comentarios = comentarios,
       _cargarOpciones = cargarOpciones,
       super(const SatisfaccionCargando()) {
    final DateTime hoy = DateTime.now();
    _cargar(_filtroDelMes(DateTime(hoy.year, hoy.month)));
  }

  final ObtenerResumenSatisfaccionUseCase _resumen;
  final ObtenerSatisfaccionPorDimensionUseCase _porDimension;
  final ListarComentariosSatisfaccionUseCase _comentarios;
  final Future<OpcionesReporte> Function() _cargarOpciones;
  OpcionesReporte _opciones = const OpcionesReporte();
  bool _opcionesCargadas = false;
  FiltroReporte? _filtro;

  FiltroReporte _filtroDelMes(DateTime primerDia) {
    final DateTime desde = DateTime(primerDia.year, primerDia.month);
    final DateTime hasta = DateTime(
      desde.year,
      desde.month + 1,
    ).subtract(const Duration(days: 1));
    final FiltroReporte? actual = _filtro;
    return actual == null
        ? FiltroReporte(desde: desde, hasta: hasta)
        : actual.copiarCon(desde: desde, hasta: hasta);
  }

  Future<void> _cargar(FiltroReporte filtro) async {
    _filtro = filtro;
    emit(const SatisfaccionCargando());
    try {
      if (!_opcionesCargadas) {
        try {
          _opciones = await _cargarOpciones();
          _opcionesCargadas = true;
        } on Object {
          // Sin opciones los selectores quedan en «Todos»; la pantalla sigue.
        }
      }

      final List<Object> resultados = await Future.wait(<Future<Object>>[
        _resumen(filtro),
        _comentarios(filtro),
        for (final DimensionMetrica d in dimensionesSatisfaccion)
          _porDimension(filtro, d),
      ]);

      if (isClosed) return;
      emit(
        SatisfaccionListo(
          filtro: filtro,
          opciones: _opciones,
          resumen: resultados[0] as ResumenSatisfaccion,
          comentarios: resultados[1] as List<ComentarioSatisfaccion>,
          porDimension: <DimensionMetrica, List<SatisfaccionDimension>>{
            for (int i = 0; i < dimensionesSatisfaccion.length; i++)
              dimensionesSatisfaccion[i]:
                  resultados[2 + i] as List<SatisfaccionDimension>,
          },
        ),
      );
    } on CatalogoFailure catch (falla) {
      if (!isClosed) emit(SatisfaccionError(falla.mensaje));
    }
  }

  Future<void> irAMesAnterior() async {
    final DateTime? desde = _filtro?.desde;
    if (desde == null) return;
    await _cargar(_filtroDelMes(DateTime(desde.year, desde.month - 1)));
  }

  Future<void> irAMesSiguiente() async {
    final DateTime? desde = _filtro?.desde;
    if (desde == null) return;
    await _cargar(_filtroDelMes(DateTime(desde.year, desde.month + 1)));
  }

  Future<void> aplicarFiltro(FiltroReporte filtro) => _cargar(filtro);

  Future<void> recargar() {
    final FiltroReporte? actual = _filtro;
    if (actual != null) return _cargar(actual);
    final DateTime hoy = DateTime.now();
    return _cargar(_filtroDelMes(DateTime(hoy.year, hoy.month)));
  }
}
