// ignore_for_file: prefer_initializing_formals
import '../../../clientes/domain/entities/cliente.dart';
import '../../../clientes/domain/repositories/cliente_repository.dart';
import '../../../conductores/domain/entities/conductor.dart';
import '../../../conductores/domain/repositories/conductor_repository.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../entities/reporte.dart';

/// Carga las opciones de los selectores de filtro (clientes, conductores y
/// vehículos). Compartido por Reportes y por el Resumen.
class CargarOpcionesReporteUseCase {
  const CargarOpcionesReporteUseCase({
    required ClienteRepository clientes,
    required ConductorRepository conductores,
    required VehiculoRepository vehiculos,
  }) : _clientes = clientes,
       _conductores = conductores,
       _vehiculos = vehiculos;

  final ClienteRepository _clientes;
  final ConductorRepository _conductores;
  final VehiculoRepository _vehiculos;

  static const int _tamano = 100;

  Future<OpcionesReporte> call() async {
    final List<Object> r = await Future.wait(<Future<Object>>[
      _clientes.listar(pagina: 0, tamano: _tamano),
      _conductores.listar(pagina: 0, tamano: _tamano),
      _vehiculos.listar(pagina: 0, tamano: _tamano),
    ]);
    return OpcionesReporte(
      clientes: (r[0] as PaginaClientes).clientes
          .map((Cliente c) => OpcionFiltro(c.id, c.nombre))
          .toList(),
      conductores: (r[1] as PaginaConductores).conductores
          .map((Conductor c) => OpcionFiltro(c.id, c.nombre))
          .toList(),
      vehiculos: (r[2] as PaginaVehiculos).vehiculos
          .map((Vehiculo v) => OpcionFiltro(v.id, v.placa))
          .toList(),
    );
  }
}
