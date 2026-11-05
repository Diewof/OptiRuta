import '../entities/hito.dart';
import '../entities/tipo_hito.dart';
import '../repositories/hito_repository.dart';

class RegistrarHitoUseCase {
  const RegistrarHitoUseCase(this._repositorio);

  final HitoRepository _repositorio;

  Future<Hito> call({
    required String viajeId,
    required TipoHito tipo,
    required DateTime fechaHora,
  }) => _repositorio.registrar(
    viajeId: viajeId,
    tipo: tipo,
    fechaHora: fechaHora,
  );
}
