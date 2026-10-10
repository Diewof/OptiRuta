import '../entities/conductor.dart';
import '../entities/tipo_pago.dart';
import '../repositories/conductor_repository.dart';

class ActualizarConductorUseCase {
  const ActualizarConductorUseCase(this._repositorio);

  final ConductorRepository _repositorio;

  Future<Conductor> call({
    required String id,
    required String licencia,
    required DateTime fechaVencimientoLicencia,
    required TipoPago tipoPago,
    required double porcentajeComision,
    required double sueldoBase,
  }) {
    return _repositorio.actualizar(
      id: id,
      licencia: licencia.trim(),
      fechaVencimientoLicencia: fechaVencimientoLicencia,
      tipoPago: tipoPago,
      porcentajeComision: porcentajeComision,
      sueldoBase: sueldoBase,
    );
  }
}
