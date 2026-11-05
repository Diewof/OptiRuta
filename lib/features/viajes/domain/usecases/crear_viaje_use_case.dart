import '../entities/lugar.dart';
import '../entities/viaje.dart';
import '../repositories/viaje_repository.dart';

class CrearViajeUseCase {
  const CrearViajeUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<Viaje> call({
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
    return _repositorio.crear(
      remision: remision.trim(),
      vehiculoId: vehiculoId,
      conductorId: conductorId,
      clienteId: clienteId,
      origen: Lugar(
        nombre: origen.nombre.trim(),
        coordenada: origen.coordenada,
      ),
      destino: Lugar(
        nombre: destino.nombre.trim(),
        coordenada: destino.coordenada,
      ),
      rutaPolilinea: rutaPolilinea,
      fechaSalidaProgramada: fechaSalidaProgramada,
      distanciaEstimada: distanciaEstimada,
      tiempoEstimadoMin: tiempoEstimadoMin,
      pesoCarga: pesoCarga,
      valorFlete: valorFlete,
    );
  }
}
