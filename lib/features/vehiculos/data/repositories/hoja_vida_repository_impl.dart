import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/documento_vehiculo.dart';
import '../../domain/entities/hoja_vida.dart';
import '../../domain/repositories/hoja_vida_repository.dart';

/// Hoja de vida sobre PostgREST: la vista `documento_vehiculo_vigente` y las
/// RPC `vehiculo_resumen`, `plan_mantenimiento_estado` y `vehiculo_hoja_vida`
/// (todas de solo administrador).
class HojaVidaRepositoryImpl implements HojaVidaRepository {
  HojaVidaRepositoryImpl(this._client);

  final SupabaseClient _client;

  static String _fecha(DateTime f) => f.toIso8601String().split('T').first;

  static DocumentoVehiculo documentoAEntidad(Map<String, dynamic> f) {
    return DocumentoVehiculo(
      id: f['id'] as String,
      vehiculoId: f['vehiculo_id'] as String,
      tipo: TipoDocumentoVehiculo.desdeCodigo(f['tipo'] as String),
      fechaVencimiento: DateTime.parse(f['fecha_vencimiento'] as String),
      diasRestantes: (f['dias_restantes'] as num).toInt(),
      estado: EstadoDocumento.desdeCodigo(f['estado'] as String),
      numero: f['numero'] as String?,
      entidadEmisora: f['entidad_emisora'] as String?,
      fechaExpedicion: f['fecha_expedicion'] == null
          ? null
          : DateTime.parse(f['fecha_expedicion'] as String),
    );
  }

  static EventoHojaVida eventoAEntidad(Map<String, dynamic> f) {
    return EventoHojaVida(
      fecha: DateTime.parse(f['fecha'] as String).toLocal(),
      tipo: TipoEventoHojaVida.desdeCodigo(f['tipo'] as String),
      titulo: f['titulo'] as String,
      detalle: f['detalle'] as String?,
      km: (f['km'] as num?)?.toDouble(),
    );
  }

  static ItemPlanMantenimiento planAEntidad(Map<String, dynamic> f) {
    return ItemPlanMantenimiento(
      tipoNombre: f['tipo_nombre'] as String,
      estado: EstadoPlanMantenimiento.desdeCodigo(f['estado'] as String),
      intervaloKm: (f['intervalo_km'] as num?)?.toDouble(),
      intervaloDias: (f['intervalo_dias'] as num?)?.toInt(),
      ultimoFecha: f['ultimo_fecha'] == null
          ? null
          : DateTime.parse(f['ultimo_fecha'] as String),
      kmRestantes: (f['km_restantes'] as num?)?.toDouble(),
      diasRestantes: (f['dias_restantes'] as num?)?.toInt(),
    );
  }

  @override
  Future<HojaVida> obtener(String vehiculoId) {
    return ejecutarCatalogo(() async {
      final List<Object> r = await Future.wait<Object>(<Future<Object>>[
        _client
            .from('documento_vehiculo_vigente')
            .select()
            .eq('vehiculo_id', vehiculoId),
        _client.rpc<List<dynamic>>(
          'vehiculo_resumen',
          params: <String, dynamic>{'p_vehiculo_id': vehiculoId},
        ),
        _client.rpc<List<dynamic>>(
          'plan_mantenimiento_estado',
          params: <String, dynamic>{'p_vehiculo_id': vehiculoId},
        ),
        _client.rpc<List<dynamic>>(
          'vehiculo_hoja_vida',
          params: <String, dynamic>{'p_vehiculo_id': vehiculoId},
        ),
      ]);
      final List<dynamic> resumen = r[1] as List<dynamic>;
      return HojaVida(
        odometroKm: resumen.isEmpty
            ? 0
            : ((resumen.first as Map<String, dynamic>)['odometro_km'] as num)
                  .toDouble(),
        documentos: (r[0] as List<dynamic>)
            .map((dynamic f) => documentoAEntidad(f as Map<String, dynamic>))
            .toList(),
        plan: (r[2] as List<dynamic>)
            .map((dynamic f) => planAEntidad(f as Map<String, dynamic>))
            .toList(),
        eventos: (r[3] as List<dynamic>)
            .map((dynamic f) => eventoAEntidad(f as Map<String, dynamic>))
            .toList(),
      );
    });
  }

  @override
  Future<void> registrarDocumento({
    required String vehiculoId,
    required TipoDocumentoVehiculo tipo,
    required DateTime fechaVencimiento,
    String? numero,
    String? entidadEmisora,
    DateTime? fechaExpedicion,
  }) {
    return ejecutarCatalogo(() async {
      // La RPC registra y genera las alertas al instante (sin esperar al cron).
      await _client.rpc<Map<String, dynamic>>(
        'documento_vehiculo_registrar',
        params: <String, dynamic>{
          'p_vehiculo_id': vehiculoId,
          'p_tipo': tipo.codigo,
          'p_fecha_vencimiento': _fecha(fechaVencimiento),
          'p_numero': numero,
          'p_entidad_emisora': entidadEmisora,
          'p_fecha_expedicion': fechaExpedicion == null
              ? null
              : _fecha(fechaExpedicion),
        },
      );
    });
  }
}
