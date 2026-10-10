import '../entities/cliente.dart';
import '../limpiar_texto.dart';
import '../repositories/cliente_repository.dart';

class ActualizarClienteUseCase {
  const ActualizarClienteUseCase(this._repositorio);

  final ClienteRepository _repositorio;

  Future<Cliente> call({
    required String id,
    required String nombre,
    String? documento,
    String? telefono,
    String? correo,
    String? direccion,
  }) {
    return _repositorio.actualizar(
      id: id,
      nombre: nombre.trim(),
      documento: limpiarTextoOpcional(documento),
      telefono: limpiarTextoOpcional(telefono),
      correo: limpiarTextoOpcional(correo),
      direccion: limpiarTextoOpcional(direccion),
    );
  }
}
