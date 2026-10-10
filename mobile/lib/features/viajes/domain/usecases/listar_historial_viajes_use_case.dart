import '../entities/estado_viaje.dart';
import '../repositories/viaje_repository.dart';

class ListarHistorialViajesUseCase {
  const ListarHistorialViajesUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<PaginaViajes> call({
    required int pagina,
    int tamano = 20,
    EstadoViaje? filtroEstado,
  }) => _repositorio.listarHistorial(
    pagina: pagina,
    tamano: tamano,
    filtroEstado: filtroEstado,
  );
}
