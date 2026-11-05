import 'package:equatable/equatable.dart';

/// Preventivo (del plan del vehículo) o correctivo (una reparación).
enum CategoriaMantenimiento {
  preventivo('PREVENTIVO', 'Preventivo'),
  correctivo('CORRECTIVO', 'Correctivo');

  const CategoriaMantenimiento(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static CategoriaMantenimiento? desdeCodigo(String? valor) {
    return switch (valor) {
      'PREVENTIVO' => CategoriaMantenimiento.preventivo,
      'CORRECTIVO' => CategoriaMantenimiento.correctivo,
      _ => null,
    };
  }
}

/// Tipo del catálogo de mantenimientos preventivos
/// (`public.tipo_mantenimiento`): registrar uno reinicia su contador en el
/// plan del vehículo.
class TipoMantenimiento extends Equatable {
  const TipoMantenimiento({
    required this.id,
    required this.nombre,
    this.intervaloKm,
    this.intervaloDias,
  });

  final String id;
  final String nombre;
  final double? intervaloKm;
  final int? intervaloDias;

  @override
  List<Object?> get props => <Object?>[id, nombre, intervaloKm, intervaloDias];
}

/// Mantenimiento de un vehículo (RF-17: entra al costo consolidado del
/// período; nunca a la rentabilidad marginal de un viaje).
class Mantenimiento extends Equatable {
  const Mantenimiento({
    required this.id,
    required this.vehiculoId,
    required this.placa,
    required this.tipo,
    required this.costo,
    required this.fecha,
    this.kilometraje,
    this.categoria,
    this.taller,
    this.descripcion,
  });

  final String id;
  final String vehiculoId;
  final String placa;
  final String tipo;
  final double costo;
  final DateTime fecha;
  final double? kilometraje;

  /// Nulo en los mantenimientos anteriores a la clasificación.
  final CategoriaMantenimiento? categoria;
  final String? taller;
  final String? descripcion;

  @override
  List<Object?> get props => <Object?>[
    id,
    vehiculoId,
    placa,
    tipo,
    costo,
    fecha,
    kilometraje,
    categoria,
    taller,
    descripcion,
  ];
}

/// Contrato de acceso a `public.mantenimiento_vehiculo` (solo ADMINISTRADOR,
/// lo garantiza RLS).
abstract interface class MantenimientoRepository {
  /// Los más recientes primero.
  Future<List<Mantenimiento>> listar();

  /// Catálogo de tipos preventivos, en el orden del plan.
  Future<List<TipoMantenimiento>> listarTipos();

  /// Con [tipoMantenimientoId] el servidor reinicia el contador de ese tipo en
  /// el plan; un mantenimiento de hoy sin [kilometraje] toma el odómetro.
  Future<Mantenimiento> registrar({
    required String vehiculoId,
    required String tipo,
    required double costo,
    required DateTime fecha,
    double? kilometraje,
    String? tipoMantenimientoId,
    CategoriaMantenimiento categoria = CategoriaMantenimiento.preventivo,
    String? taller,
    String? descripcion,
  });
}

class ListarMantenimientosUseCase {
  const ListarMantenimientosUseCase(this._repositorio);

  final MantenimientoRepository _repositorio;

  Future<List<Mantenimiento>> call() => _repositorio.listar();
}

class ListarTiposMantenimientoUseCase {
  const ListarTiposMantenimientoUseCase(this._repositorio);

  final MantenimientoRepository _repositorio;

  Future<List<TipoMantenimiento>> call() => _repositorio.listarTipos();
}

class RegistrarMantenimientoUseCase {
  const RegistrarMantenimientoUseCase(this._repositorio);

  final MantenimientoRepository _repositorio;

  /// [tipo] puede ir vacío si se elige un [tipoMantenimientoId] del catálogo:
  /// el servidor usa su nombre.
  Future<Mantenimiento> call({
    required String vehiculoId,
    required String tipo,
    required double costo,
    required DateTime fecha,
    double? kilometraje,
    String? tipoMantenimientoId,
    CategoriaMantenimiento categoria = CategoriaMantenimiento.preventivo,
    String? taller,
    String? descripcion,
  }) {
    final String limpio = tipo.trim();
    if (limpio.isEmpty && tipoMantenimientoId == null) {
      throw ArgumentError.value(tipo, 'tipo', 'El tipo es obligatorio.');
    }
    if (costo <= 0) {
      throw ArgumentError.value(costo, 'costo', 'El costo debe ser > 0.');
    }
    if (kilometraje != null && kilometraje < 0) {
      throw ArgumentError.value(kilometraje, 'kilometraje', 'Debe ser >= 0.');
    }
    return _repositorio.registrar(
      vehiculoId: vehiculoId,
      tipo: limpio,
      costo: costo,
      fecha: fecha,
      kilometraje: kilometraje,
      tipoMantenimientoId: tipoMantenimientoId,
      categoria: categoria,
      taller: _limpio(taller),
      descripcion: _limpio(descripcion),
    );
  }

  static String? _limpio(String? texto) {
    final String? limpio = texto?.trim();
    return limpio == null || limpio.isEmpty ? null : limpio;
  }
}
