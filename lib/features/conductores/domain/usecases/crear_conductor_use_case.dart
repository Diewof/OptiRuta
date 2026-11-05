import '../entities/conductor.dart';
import '../entities/tipo_pago.dart';
import '../repositories/conductor_repository.dart';

class CrearConductorUseCase {
  const CrearConductorUseCase(this._repositorio);

  final ConductorRepository _repositorio;

  Future<Conductor> call({
    required String usuarioId,
    required String licencia,
    required DateTime fechaVencimientoLicencia,
    required TipoPago tipoPago,
    required double porcentajeComision,
    required double sueldoBase,
  }) {
    return _repositorio.crear(
      usuarioId: usuarioId,
      licencia: licencia.trim(),
      fechaVencimientoLicencia: fechaVencimientoLicencia,
      tipoPago: tipoPago,
      porcentajeComision: porcentajeComision,
      sueldoBase: sueldoBase,
    );
  }
}
