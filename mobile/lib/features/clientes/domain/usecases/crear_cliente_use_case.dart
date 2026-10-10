import '../entities/cliente.dart';
import '../limpiar_texto.dart';
import '../repositories/cliente_repository.dart';

/// Crea un cliente. Recorta los campos de texto y convierte cadenas vacias
/// opcionales en `null` antes de enviarlos.
class CrearClienteUseCase {
  const CrearClienteUseCase(this._repositorio);

  final ClienteRepository _repositorio;

  Future<Cliente> call({
    required String nombre,
    String? documento,
    String? telefono,
    String? correo,
    String? direccion,
  }) {
    return _repositorio.crear(
      nombre: nombre.trim(),
      documento: limpiarTextoOpcional(documento),
      telefono: limpiarTextoOpcional(telefono),
      correo: limpiarTextoOpcional(correo),
      direccion: limpiarTextoOpcional(direccion),
    );
  }
}
