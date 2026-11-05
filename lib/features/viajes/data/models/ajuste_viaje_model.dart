import '../../domain/entities/ajuste_viaje.dart';

abstract final class AjusteViajeModel {
  static AjusteViaje aEntidad(Map<String, dynamic> fila) {
    return AjusteViaje(
      id: fila['id'] as String,
      viajeId: fila['viaje_id'] as String,
      motivo: fila['motivo'] as String,
      fecha: DateTime.parse(fila['fecha'] as String).toLocal(),
      campoModificado: fila['campo_modificado'] as String?,
      valorAnterior: fila['valor_anterior'] as String?,
      valorNuevo: fila['valor_nuevo'] as String?,
      concepto: fila['concepto'] as String?,
      monto: (fila['monto'] as num?)?.toDouble(),
    );
  }
}
