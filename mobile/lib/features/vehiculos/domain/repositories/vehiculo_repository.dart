import 'package:equatable/equatable.dart';

import '../entities/tipo_vehiculo.dart';
import '../entities/vehiculo.dart';

/// Una pagina de resultados paginados de `public.vehiculo`.
class PaginaVehiculos extends Equatable {
  const PaginaVehiculos({required this.vehiculos, required this.hayMas});

  final List<Vehiculo> vehiculos;

  /// `true` si existe al menos una fila mas alla de esta pagina.
  final bool hayMas;

  @override
  List<Object?> get props => <Object?>[vehiculos, hayMas];
}

/// Contrato de acceso a `public.vehiculo` para la capa de dominio. La
/// implementacion vive en `data` sobre `supabase_flutter`.
///
/// Todos los metodos que fallan lanzan `CatalogoFailure` (nunca el error
/// crudo del proveedor). Escritura solo para ADMINISTRADOR: lo garantiza RLS,
/// esta interfaz no repite esa regla.
abstract interface class VehiculoRepository {
  Future<PaginaVehiculos> listar({required int pagina, required int tamano});

  Future<Vehiculo> crear({
    required String placa,
    required TipoVehiculo tipo,
    required double capacidadCarga,
    required double rendimientoKmGalon,
  });

  Future<Vehiculo> actualizar({
    required String id,
    required String placa,
    required TipoVehiculo tipo,
    required double capacidadCarga,
    required double rendimientoKmGalon,
  });

  /// Baja logica (`activo = false`). Nunca borra la fila.
  Future<void> inhabilitar(String id);
}
