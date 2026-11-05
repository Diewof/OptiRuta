import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/catalogo_failure.dart';
import '../domain/mantenimiento.dart';

class MantenimientoRepositoryImpl implements MantenimientoRepository {
  MantenimientoRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const String _columnas =
      'id, vehiculo_id, tipo, costo, fecha, kilometraje, categoria, taller, '
      'descripcion, vehiculo:vehiculo_id(placa)';

  static Mantenimiento aEntidad(Map<String, dynamic> f) {
    final Map<String, dynamic> vehiculo = f['vehiculo'] as Map<String, dynamic>;
    return Mantenimiento(
      id: f['id'] as String,
      vehiculoId: f['vehiculo_id'] as String,
      placa: vehiculo['placa'] as String,
      tipo: f['tipo'] as String,
      costo: (f['costo'] as num).toDouble(),
      fecha: DateTime.parse(f['fecha'] as String),
      kilometraje: (f['kilometraje'] as num?)?.toDouble(),
      categoria: CategoriaMantenimiento.desdeCodigo(f['categoria'] as String?),
      taller: f['taller'] as String?,
      descripcion: f['descripcion'] as String?,
    );
  }

  @override
  Future<List<Mantenimiento>> listar() {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _client
          .from('mantenimiento_vehiculo')
          .select(_columnas)
          .order('fecha', ascending: false)
          .limit(100);
      return filas.map(aEntidad).toList();
    });
  }

  @override
  Future<List<TipoMantenimiento>> listarTipos() {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _client
          .from('tipo_mantenimiento')
          .select('id, nombre, intervalo_km, intervalo_dias')
          .eq('activo', true)
          .order('orden');
      return filas
          .map(
            (Map<String, dynamic> f) => TipoMantenimiento(
              id: f['id'] as String,
              nombre: f['nombre'] as String,
              intervaloKm: (f['intervalo_km'] as num?)?.toDouble(),
              intervaloDias: (f['intervalo_dias'] as num?)?.toInt(),
            ),
          )
          .toList();
    });
  }

  @override
  Future<Mantenimiento> registrar({
    required String vehiculoId,
    required String tipo,
    required double costo,
    required DateTime fecha,
    double? kilometraje,
    String? tipoMantenimientoId,
    CategoriaMantenimiento categoria = CategoriaMantenimiento.preventivo,
    String? taller,
    String? descripcion,
  }) {
    return ejecutarCatalogo(() async {
      // La RPC valida y completa el km con el odómetro; devuelve la fila sin
      // la placa, así que se vuelve a leer con el embed.
      final Map<String, dynamic> creada = await _client
          .rpc<Map<String, dynamic>>(
            'mantenimiento_registrar',
            params: <String, dynamic>{
              'p_vehiculo_id': vehiculoId,
              'p_tipo': tipo,
              'p_costo': costo,
              'p_fecha': fecha.toIso8601String().split('T').first,
              'p_kilometraje': kilometraje,
              'p_tipo_mantenimiento_id': tipoMantenimientoId,
              'p_categoria': categoria.codigo,
              'p_taller': taller,
              'p_descripcion': descripcion,
            },
          );
      final Map<String, dynamic> fila = await _client
          .from('mantenimiento_vehiculo')
          .select(_columnas)
          .eq('id', creada['id'] as String)
          .single();
      return aEntidad(fila);
    });
  }
}
