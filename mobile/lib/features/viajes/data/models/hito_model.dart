import '../../domain/entities/hito.dart';
import '../../domain/entities/tipo_hito.dart';

abstract final class HitoModel {
  static Hito aEntidad(Map<String, dynamic> fila) {
    return Hito(
      id: fila['id'] as String,
      viajeId: fila['viaje_id'] as String,
      tipo: TipoHito.desdeCodigo(fila['tipo'] as String),
      fechaHora: DateTime.parse(fila['fecha_hora'] as String),
    );
  }
}
