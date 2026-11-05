import 'package:equatable/equatable.dart';

import '../../../reportes/domain/entities/reporte.dart';
import '../../domain/entities/metricas.dart';
import '../../../notificaciones/domain/entities/notificacion.dart';
import '../../../viajes/domain/entities/rentabilidad_consolidada.dart';
import '../../../viajes/domain/entities/viaje_resumen.dart';

sealed class AnaliticaState extends Equatable {
  const AnaliticaState();

  @override
  List<Object?> get props => <Object?>[];
}

class AnaliticaCargando extends AnaliticaState {
  const AnaliticaCargando();
}

class AnaliticaError extends AnaliticaState {
  const AnaliticaError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class AnaliticaListo extends AnaliticaState {
  const AnaliticaListo({
    required this.mes,
    required this.rentabilidad,
    required this.vehiculosEnRuta,
    required this.vehiculosDisponibles,
    required this.totalVehiculosActivos,
    required this.metricas,
    required this.filtro,
    this.opciones = const OpcionesReporte(),
    this.rendimiento = const <DimensionMetrica, List<MetricaDimension>>{},
    this.alertas = const <Notificacion>[],
    this.viajesActivos = const <ViajeResumen>[],
  });

  /// Primer día del mes mostrado.
  final DateTime mes;
  final RentabilidadConsolidada rentabilidad;
  final int vehiculosEnRuta;
  final int vehiculosDisponibles;
  final int totalVehiculosActivos;

  /// Viajes ASIGNADO/EN_CURSO (los mismos con los que se calcula la flota).
  final List<ViajeResumen> viajesActivos;

  /// Filtros activos (fechas + cliente/conductor/vehículo/ruta). El mes que
  /// se muestra en el selector es el de `filtro.desde`.
  final FiltroReporte filtro;
  final OpcionesReporte opciones;

  /// Costo por km, cumplimiento y utilización del período (RF-24/25).
  final MetricasPeriodo metricas;

  /// Rendimiento del período por ruta, cliente y conductor (RF-25).
  final Map<DimensionMetrica, List<MetricaDimension>> rendimiento;

  /// Alertas sin leer: vencimientos, retrasos, paradas y desvíos (RF-26).
  final List<Notificacion> alertas;

  @override
  List<Object?> get props => <Object?>[
    mes,
    rentabilidad,
    vehiculosEnRuta,
    vehiculosDisponibles,
    totalVehiculosActivos,
    viajesActivos,
    metricas,
    filtro,
    opciones,
    rendimiento,
    alertas,
  ];
}
