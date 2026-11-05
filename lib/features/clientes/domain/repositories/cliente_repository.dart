import 'package:equatable/equatable.dart';

import '../entities/cliente.dart';

class PaginaClientes extends Equatable {
  const PaginaClientes({required this.clientes, required this.hayMas});

  final List<Cliente> clientes;
  final bool hayMas;

  @override
  List<Object?> get props => <Object?>[clientes, hayMas];
}

/// Contrato de acceso a `public.cliente` para la capa de dominio. La
/// implementacion vive en `data` sobre `supabase_flutter`.
///
/// Todos los metodos que fallan lanzan `CatalogoFailure`. Lectura para
/// ADMINISTRADOR y CONDUCTOR; escritura solo ADMINISTRADOR: lo garantiza RLS,
/// esta interfaz no repite esa regla.
abstract interface class ClienteRepository {
  Future<PaginaClientes> listar({required int pagina, required int tamano});

  Future<Cliente> crear({
    required String nombre,
    String? documento,
    String? telefono,
    String? correo,
    String? direccion,
  });

  Future<Cliente> actualizar({
    required String id,
    required String nombre,
    String? documento,
    String? telefono,
    String? correo,
    String? direccion,
  });

  /// Baja logica (`activo = false`). Nunca borra la fila.
  Future<void> inhabilitar(String id);
}
