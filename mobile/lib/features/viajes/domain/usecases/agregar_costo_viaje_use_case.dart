import '../entities/costo_viaje.dart';
import '../repositories/costo_viaje_repository.dart';

/// Agrega un costo adicional libre a un viaje (RF-14). La descripción es
/// obligatoria y al menos un valor debe ser positivo; el resto (quién puede
/// fijar qué) lo garantiza RLS.
class AgregarCostoViajeUseCase {
  const AgregarCostoViajeUseCase(this._repositorio);

  final CostoViajeRepository _repositorio;

  Future<CostoViaje> call({
    required String viajeId,
    required String descripcion,
    double valorEstimado = 0,
    double? valorReal,
  }) {
    final String limpia = descripcion.trim();
    if (limpia.isEmpty || limpia.length > 120) {
      throw ArgumentError.value(
        descripcion,
        'descripcion',
        'La descripción debe tener entre 1 y 120 caracteres.',
      );
    }
    if (valorEstimado < 0 || (valorReal != null && valorReal < 0)) {
      throw ArgumentError('Los valores no pueden ser negativos.');
    }
    if (valorEstimado == 0 && (valorReal == null || valorReal == 0)) {
      throw ArgumentError('Debe indicar un valor mayor a 0.');
    }
    return _repositorio.agregarOtro(
      viajeId: viajeId,
      descripcion: limpia,
      valorEstimado: valorEstimado,
      valorReal: valorReal,
    );
  }
}
