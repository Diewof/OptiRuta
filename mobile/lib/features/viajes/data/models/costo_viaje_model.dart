import '../../domain/entities/categoria_costo.dart';
import '../../domain/entities/costo_viaje.dart';
import '../../domain/entities/fuente_costo.dart';

abstract final class CostoViajeModel {
  static CostoViaje aEntidad(Map<String, dynamic> fila) {
    return CostoViaje(
      id: fila['id'] as String,
      viajeId: fila['viaje_id'] as String,
      categoria: CategoriaCosto.desdeCodigo(fila['categoria'] as String),
      valorEstimado: (fila['valor_estimado'] as num).toDouble(),
      valorReal: (fila['valor_real'] as num?)?.toDouble(),
      fuente: FuenteCosto.desdeCodigo(fila['fuente'] as String),
    );
  }
}
