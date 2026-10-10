import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/lugar.dart';
import '../../domain/entities/tipo_alerta_viaje.dart';
import '../../domain/entities/viaje.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../datasources/viaje_remote_data_source.dart';
import '../models/viaje_model.dart';
import '../models/viaje_resumen_model.dart';

class ViajeRepositoryImpl implements ViajeRepository {
  ViajeRepositoryImpl(this._remote);

  final ViajeRemoteDataSource _remote;

  @override
  Future<Viaje> crear({
    required String remision,
    required String vehiculoId,
    required String conductorId,
    required String clienteId,
    required Lugar origen,
    required Lugar destino,
    required String rutaPolilinea,
    required DateTime fechaSalidaProgramada,
    required double distanciaEstimada,
    required double tiempoEstimadoMin,
    required double pesoCarga,
    required double valorFlete,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.crear(<String, dynamic>{
        'p_remision': remision,
        'p_vehiculo_id': vehiculoId,
        'p_conductor_id': conductorId,
        'p_cliente_id': clienteId,
        'p_origen': origen.nombre,
        'p_destino': destino.nombre,
        'p_origen_lat': origen.coordenada.lat,
        'p_origen_lng': origen.coordenada.lng,
        'p_destino_lat': destino.coordenada.lat,
        'p_destino_lng': destino.coordenada.lng,
        'p_ruta_polilinea': rutaPolilinea,
        'p_fecha_salida_programada': fechaSalidaProgramada.toIso8601String(),
        'p_distancia_estimada': distanciaEstimada,
        'p_tiempo_estimado_min': tiempoEstimadoMin,
        'p_peso_carga': pesoCarga,
        'p_valor_flete': valorFlete,
      });
      return ViajeModel.aEntidad(fila);
    });
  }

  @override
  Future<bool> registrarAlerta({
    required String viajeId,
    required TipoAlertaViaje tipo,
    required Coordenada ubicacion,
  }) {
    return ejecutarCatalogo(
      () => _remote.registrarAlerta(<String, dynamic>{
        'p_viaje_id': viajeId,
        'p_tipo': tipo.codigo,
        'p_lat': ubicacion.lat,
        'p_lng': ubicacion.lng,
      }),
    );
  }

  @override
  Future<Viaje> cambiarEstado({
    required String viajeId,
    required EstadoViaje nuevoEstado,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.cambiarEstado(
        viajeId: viajeId,
        nuevoEstado: nuevoEstado.codigo,
      );
      return ViajeModel.aEntidad(fila);
    });
  }

  @override
  Future<Viaje> iniciar({
    required String viajeId,
    required Coordenada ubicacion,
    required DateTime fechaHora,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.iniciar(<String, dynamic>{
        'p_viaje_id': viajeId,
        'p_lat': ubicacion.lat,
        'p_lng': ubicacion.lng,
        'p_fecha_hora': fechaHora.toIso8601String(),
      });
      return ViajeModel.aEntidad(fila);
    });
  }

  @override
  Future<Viaje> cerrar(String viajeId) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.cerrar(viajeId);
      return ViajeModel.aEntidad(fila);
    });
  }

  @override
  Future<ViajeResumen> obtenerResumen(String viajeId) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.obtenerResumen(viajeId);
      return ViajeResumenModel.aEntidad(fila);
    });
  }

  @override
  Future<double> estimarAcpm({
    required String vehiculoId,
    required double distanciaKm,
    required String ciudad,
  }) {
    return ejecutarCatalogo(
      () => _remote.estimarAcpm(
        vehiculoId: vehiculoId,
        distanciaKm: distanciaKm,
        ciudad: ciudad,
      ),
    );
  }

  @override
  Future<List<ViajeResumen>> listarPorRango({
    required DateTime desde,
    required DateTime hasta,
  }) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listarPorRango(
        desde: desde,
        hasta: hasta,
      );
      return filas.map(ViajeResumenModel.aEntidad).toList();
    });
  }

  @override
  Future<List<ViajeResumen>> listarActivos() {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listarActivos();
      return filas.map(ViajeResumenModel.aEntidad).toList();
    });
  }

  @override
  Future<PaginaViajes> listarHistorial({
    required int pagina,
    required int tamano,
    EstadoViaje? filtroEstado,
  }) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listarHistorial(
        pagina: pagina,
        tamano: tamano,
        filtroEstado: filtroEstado?.codigo,
      );
      final bool hayMas = filas.length > tamano;
      final List<Map<String, dynamic>> filasPagina = hayMas
          ? filas.sublist(0, tamano)
          : filas;
      return PaginaViajes(
        viajes: filasPagina.map(ViajeResumenModel.aEntidad).toList(),
        hayMas: hayMas,
      );
    });
  }
}
