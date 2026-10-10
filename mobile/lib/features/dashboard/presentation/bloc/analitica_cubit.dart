import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../../viajes/domain/entities/rentabilidad_consolidada.dart';
import '../../../viajes/domain/entities/viaje_resumen.dart';
import '../../../viajes/domain/usecases/listar_viajes_activos_use_case.dart';
import '../../../viajes/domain/usecases/rentabilidad_consolidada_use_case.dart';
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
  }) : _rentabilidadConsolidada = rentabilidadConsolidada,
       _vehiculoRepository = vehiculoRepository,
       _listarViajesActivos = listarViajesActivos,
       super(const AnaliticaCargando()) {
    final DateTime hoy = DateTime.now();
    _cargarMes(DateTime(hoy.year, hoy.month));
  }

  final RentabilidadConsolidadaUseCase _rentabilidadConsolidada;
  final VehiculoRepository _vehiculoRepository;
  final ListarViajesActivosUseCase _listarViajesActivos;

  static const int _tamanoCatalogoVehiculos = 100;

  Future<void> _cargarMes(DateTime primerDiaDelMes) async {
    emit(const AnaliticaCargando());
    try {
      final DateTime desde = DateTime(
        primerDiaDelMes.year,
        primerDiaDelMes.month,
      );
      final DateTime hasta = DateTime(
        desde.year,
        desde.month + 1,
      ).subtract(const Duration(days: 1));

      final resultados = await Future.wait(<Future<Object>>[
        _rentabilidadConsolidada(desde: desde, hasta: hasta),
        _vehiculoRepository.listar(pagina: 0, tamano: _tamanoCatalogoVehiculos),
        _listarViajesActivos(),
      ]);

      final RentabilidadConsolidada rentabilidad =
          resultados[0] as RentabilidadConsolidada;
      final PaginaVehiculos paginaVehiculos = resultados[1] as PaginaVehiculos;
      final List<ViajeResumen> viajesActivos =
          resultados[2] as List<ViajeResumen>;

      final List<Vehiculo> activos = paginaVehiculos.vehiculos
          .where((Vehiculo v) => v.activo)
          .toList();
      final Set<String> placasEnRuta = viajesActivos
          .map((ViajeResumen v) => v.placaVehiculo)
          .toSet();
      final int enRuta = activos
          .where((Vehiculo v) => placasEnRuta.contains(v.placa))
          .length;

      emit(
        AnaliticaListo(
          mes: desde,
          rentabilidad: rentabilidad,
          vehiculosEnRuta: enRuta,
          vehiculosDisponibles: activos.length - enRuta,
          totalVehiculosActivos: activos.length,
          viajesActivos: viajesActivos,
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(AnaliticaError(falla.mensaje));
    }
  }

  Future<void> irAMesAnterior() async {
    final AnaliticaState actual = state;
    if (actual is! AnaliticaListo) return;
    await _cargarMes(DateTime(actual.mes.year, actual.mes.month - 1));
  }

  Future<void> irAMesSiguiente() async {
    final AnaliticaState actual = state;
    if (actual is! AnaliticaListo) return;
    await _cargarMes(DateTime(actual.mes.year, actual.mes.month + 1));
  }

  Future<void> recargar() async {
    final AnaliticaState actual = state;
    final DateTime referencia = actual is AnaliticaListo
        ? actual.mes
        : DateTime.now();
    await _cargarMes(DateTime(referencia.year, referencia.month));
  }
}
