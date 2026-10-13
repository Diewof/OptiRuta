import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../notificaciones/domain/entities/notificacion.dart';
import '../../../notificaciones/domain/usecases/listar_notificaciones_use_case.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../../notificaciones/domain/repositories/notificacion_repository.dart';
import '../../../viajes/domain/entities/rentabilidad_consolidada.dart';
import '../../../viajes/domain/entities/viaje_resumen.dart';
import '../../../viajes/domain/usecases/listar_viajes_activos_use_case.dart';
import '../../../viajes/domain/usecases/rentabilidad_consolidada_use_case.dart';
import '../../../reportes/domain/entities/reporte.dart';
import '../../domain/entities/metricas.dart';
import '../../domain/usecases/metricas_use_cases.dart';
import 'analitica_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el dashboard de Analítica: KPIs + rentabilidad consolidada del
/// mes (RPC `rentabilidad_consolidada`) y estado de flota (vehículos activos
/// cruzados con los viajes ASIGNADO/EN_CURSO).
///
/// Alcance real de esta versión: los KPIs de Ingresos/Costos/Rentabilidad/
/// Envíos y la dona de flota (En ruta/Disponible) tienen fuente de datos
/// real. Las tendencias mensuales del mockup (tiempos de entrega, consumo de
/// combustible, rendimiento de viajes correctos/con retraso/fallidos) NO se
/// implementan: no existe ninguna RPC que agregue esos datos por mes, ni un
/// estado "fallido" en `viaje.estado`, ni un total de galones de ACPM
/// consumidos por período. Construirlas requeriría nuevas RPC/columnas, una
/// decisión de esquema que no se toma aquí (ver CLAUDE.md "ante información
/// faltante, no inventes").
class AnaliticaCubit extends Cubit<AnaliticaState> {
  AnaliticaCubit({
    required RentabilidadConsolidadaUseCase rentabilidadConsolidada,
    required VehiculoRepository vehiculoRepository,
    required ListarViajesActivosUseCase listarViajesActivos,
    required ObtenerMetricasPeriodoUseCase metricasPeriodo,
    required ObtenerMetricasPorDimensionUseCase metricasPorDimension,
    required ListarNotificacionesUseCase listarNotificaciones,
    required Future<OpcionesReporte> Function() cargarOpciones,
  }) : _rentabilidadConsolidada = rentabilidadConsolidada,
       _vehiculoRepository = vehiculoRepository,
       _listarViajesActivos = listarViajesActivos,
       _metricasPeriodo = metricasPeriodo,
       _metricasPorDimension = metricasPorDimension,
       _listarNotificaciones = listarNotificaciones,
       _cargarOpciones = cargarOpciones,
       super(const AnaliticaCargando()) {
    final DateTime hoy = DateTime.now();
    _cargar(_filtroDelMes(DateTime(hoy.year, hoy.month)));
  }

  final RentabilidadConsolidadaUseCase _rentabilidadConsolidada;
  final VehiculoRepository _vehiculoRepository;
  final ListarViajesActivosUseCase _listarViajesActivos;
  final ObtenerMetricasPeriodoUseCase _metricasPeriodo;
  final ObtenerMetricasPorDimensionUseCase _metricasPorDimension;
  final ListarNotificacionesUseCase _listarNotificaciones;
  final Future<OpcionesReporte> Function() _cargarOpciones;
  OpcionesReporte _opciones = const OpcionesReporte();
  bool _opcionesCargadas = false;
  FiltroReporte? _filtro;

  static const int _tamanoCatalogoVehiculos = 100;
  static const int _tamanoAlertas = 50;

  /// Mes completo con los filtros de cliente, conductor, vehículo y ruta que
  /// ya estén aplicados.
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
    emit(const AnaliticaCargando());
    try {
      if (!_opcionesCargadas) {
        try {
          _opciones = await _cargarOpciones();
          _opcionesCargadas = true;
        } on Object {
          // Sin opciones los selectores quedan en «Todos»; el resumen sigue.
        }
      }
      final DateTime desde = filtro.desde;
      final DateTime hasta = filtro.hasta;
      final String? cliente = filtro.clienteId;
      final String? conductor = filtro.conductorId;
      final String? vehiculo = filtro.vehiculoId;
      final String? ruta = filtro.ruta;

      final resultados = await Future.wait(<Future<Object>>[
        _rentabilidadConsolidada(
          desde: desde,
          hasta: hasta,
          clienteId: cliente,
          conductorId: conductor,
          vehiculoId: vehiculo,
          ruta: ruta,
        ),
        _vehiculoRepository.listar(pagina: 0, tamano: _tamanoCatalogoVehiculos),
        _listarViajesActivos(),
        _metricasPeriodo(
          desde: desde,
          hasta: hasta,
          clienteId: cliente,
          conductorId: conductor,
          vehiculoId: vehiculo,
          ruta: ruta,
        ),
        // Solo lo pendiente del período que se está viendo: [hasta] es el
        // último día, la consulta es exclusiva hasta el día siguiente.
        _listarNotificaciones(
          pagina: 0,
          tamano: _tamanoAlertas,
          desde: desde,
          hasta: DateTime(hasta.year, hasta.month, hasta.day + 1),
          soloNoLeidas: true,
        ),
        for (final DimensionMetrica d in DimensionMetrica.values)
          _metricasPorDimension(
            desde: desde,
            hasta: hasta,
            dimension: d,
            clienteId: cliente,
            conductorId: conductor,
            vehiculoId: vehiculo,
            ruta: ruta,
          ),
      ]);

      final RentabilidadConsolidada rentabilidad =
          resultados[0] as RentabilidadConsolidada;
      final PaginaVehiculos paginaVehiculos = resultados[1] as PaginaVehiculos;
      final List<ViajeResumen> viajesActivos =
          resultados[2] as List<ViajeResumen>;

      final MetricasPeriodo metricas = resultados[3] as MetricasPeriodo;
      final List<Notificacion> alertas =
          (resultados[4] as PaginaNotificaciones).notificaciones;
      final Map<DimensionMetrica, List<MetricaDimension>> rendimiento =
          <DimensionMetrica, List<MetricaDimension>>{
            for (int i = 0; i < DimensionMetrica.values.length; i++)
              DimensionMetrica.values[i]:
                  resultados[5 + i] as List<MetricaDimension>,
          };

      final List<Vehiculo> activos = paginaVehiculos.vehiculos
          .where((Vehiculo v) => v.activo)
          .toList();
      final Set<String> placasEnRuta = viajesActivos
          .map((ViajeResumen v) => v.placaVehiculo)
          .toSet();
      final int enRuta = activos
          .where((Vehiculo v) => placasEnRuta.contains(v.placa))
          .length;

      if (isClosed) return;
      emit(
        AnaliticaListo(
          mes: desde,
          rentabilidad: rentabilidad,
          vehiculosEnRuta: enRuta,
          vehiculosDisponibles: activos.length - enRuta,
          totalVehiculosActivos: activos.length,
          viajesActivos: viajesActivos,
          metricas: metricas,
          filtro: filtro,
          opciones: _opciones,
          rendimiento: rendimiento,
          alertas: alertas,
        ),
      );
    } on CatalogoFailure catch (falla) {
      if (!isClosed) emit(AnaliticaError(falla.mensaje));
    }
  }

  Future<void> irAMesAnterior() async {
    final AnaliticaState actual = state;
    if (actual is! AnaliticaListo) return;
    await _cargar(
      _filtroDelMes(DateTime(actual.mes.year, actual.mes.month - 1)),
    );
  }

  Future<void> irAMesSiguiente() async {
    final AnaliticaState actual = state;
    if (actual is! AnaliticaListo) return;
    await _cargar(
      _filtroDelMes(DateTime(actual.mes.year, actual.mes.month + 1)),
    );
  }

  /// Aplica fechas y filtros del panel del Resumen.
  Future<void> aplicarFiltro(FiltroReporte filtro) => _cargar(filtro);

  Future<void> recargar() async {
    final FiltroReporte? actual = _filtro;
    if (actual != null) return _cargar(actual);
    final DateTime hoy = DateTime.now();
    return _cargar(_filtroDelMes(DateTime(hoy.year, hoy.month)));
  }
}
