import 'package:equatable/equatable.dart';

import '../entities/conductor.dart';
import '../entities/tipo_pago.dart';
import '../entities/usuario_disponible.dart';

class PaginaConductores extends Equatable {
  const PaginaConductores({required this.conductores, required this.hayMas});

  final List<Conductor> conductores;
  final bool hayMas;

  @override
  List<Object?> get props => <Object?>[conductores, hayMas];
}

/// Contrato de acceso a `public.conductor` (mas el `usuario` asociado) para
/// la capa de dominio. La implementacion vive en `data` sobre
/// `supabase_flutter`.
///
/// Todos los metodos que fallan lanzan `CatalogoFailure`. Escritura y lectura
/// de todas las filas solo para ADMINISTRADOR: lo garantiza RLS: un
/// conductor solo puede leer [obtenerPropio] (su propia fila).
abstract interface class ConductorRepository {
  Future<PaginaConductores> listar({required int pagina, required int tamano});

  /// Perfil de conductor del usuario autenticado, o `null` si el
  /// administrador aun no se lo ha creado.
  Future<Conductor?> obtenerPropio(String usuarioId);

  /// Usuarios con rol CONDUCTOR que aun no tienen perfil, para el selector
  /// del formulario de alta.
  Future<List<UsuarioDisponible>> listarUsuariosDisponibles();

  Future<Conductor> crear({
    required String usuarioId,
    required String licencia,
    required DateTime fechaVencimientoLicencia,
    required TipoPago tipoPago,
    required double porcentajeComision,
    required double sueldoBase,
  });

  Future<Conductor> actualizar({
    required String id,
    required String licencia,
    required DateTime fechaVencimientoLicencia,
    required TipoPago tipoPago,
    required double porcentajeComision,
    required double sueldoBase,
  });

  /// Baja logica (`activo = false`). Nunca borra la fila.
  Future<void> inhabilitar(String id);
}
