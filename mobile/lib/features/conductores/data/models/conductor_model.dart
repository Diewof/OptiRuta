import '../../domain/entities/conductor.dart';
import '../../domain/entities/tipo_pago.dart';

/// Mapea una fila de `public.conductor` con su `usuario` embebido
/// (`usuario:usuario_id(nombre, documento)`, PostgREST resource embedding) a
/// la entidad de dominio, y construye los mapas de insercion/actualizacion.
abstract final class ConductorModel {
  static Conductor aEntidad(Map<String, dynamic> fila) {
    final Map<String, dynamic> usuario =
        fila['usuario'] as Map<String, dynamic>;
    return Conductor(
      id: fila['id'] as String,
      usuarioId: fila['usuario_id'] as String,
      nombre: usuario['nombre'] as String,
      documento: usuario['documento'] as String?,
      licencia: fila['licencia'] as String,
      fechaVencimientoLicencia: DateTime.parse(
        fila['fecha_vencimiento_licencia'] as String,
      ),
      tipoPago: TipoPago.desdeCodigo(fila['tipo_pago'] as String),
      porcentajeComision: (fila['porcentaje_comision'] as num).toDouble(),
      sueldoBase: (fila['sueldo_base'] as num).toDouble(),
      activo: fila['activo'] as bool,
    );
  }

  static Map<String, dynamic> aFila({
    required String licencia,
    required DateTime fechaVencimientoLicencia,
    required TipoPago tipoPago,
    required double porcentajeComision,
    required double sueldoBase,
  }) {
    return <String, dynamic>{
      'licencia': licencia,
      'fecha_vencimiento_licencia': fechaVencimientoLicencia
          .toIso8601String()
          .split('T')
          .first,
      'tipo_pago': tipoPago.codigo,
      'porcentaje_comision': porcentajeComision,
      'sueldo_base': sueldoBase,
    };
  }
}
