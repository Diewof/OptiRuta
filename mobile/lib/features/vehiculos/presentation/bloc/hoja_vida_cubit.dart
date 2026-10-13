import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../mantenimiento/domain/mantenimiento.dart';
import '../../domain/entities/documento_vehiculo.dart';
import '../../domain/entities/hoja_vida.dart';
import '../../domain/usecases/obtener_hoja_vida_use_case.dart';
import '../../domain/usecases/registrar_documento_vehiculo_use_case.dart';

sealed class HojaVidaState extends Equatable {
  const HojaVidaState();

  @override
  List<Object?> get props => <Object?>[];
}

class HojaVidaCargando extends HojaVidaState {
  const HojaVidaCargando();
}

class HojaVidaListo extends HojaVidaState {
  const HojaVidaListo(this.hojaVida);

  final HojaVida hojaVida;

  @override
  List<Object?> get props => <Object?>[hojaVida];
}

class HojaVidaError extends HojaVidaState {
  const HojaVidaError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Hoja de vida de un vehículo: la carga y el registro de documentos. Las
/// fallas de escritura se relanzan para que la hoja inferior las muestre.
class HojaVidaCubit extends Cubit<HojaVidaState> {
  HojaVidaCubit({
    required String vehiculoId,
    required ObtenerHojaVidaUseCase obtener,
    required RegistrarDocumentoVehiculoUseCase registrarDocumento,
    required RegistrarMantenimientoUseCase registrarMantenimiento,
    required ListarTiposMantenimientoUseCase listarTipos,
  }) : _vehiculoId = vehiculoId,
       _obtener = obtener,
       _registrarDocumento = registrarDocumento,
       _registrarMantenimiento = registrarMantenimiento,
       _listarTipos = listarTipos,
       super(const HojaVidaCargando()) {
    cargar();
  }

  final String _vehiculoId;
  final ObtenerHojaVidaUseCase _obtener;
  final RegistrarDocumentoVehiculoUseCase _registrarDocumento;
  final RegistrarMantenimientoUseCase _registrarMantenimiento;
  final ListarTiposMantenimientoUseCase _listarTipos;

  /// Catálogo de tipos preventivos para la hoja de registrar mantenimiento.
  Future<List<TipoMantenimiento>> tipos() => _listarTipos();

  /// Con [silencioso] no vuelve al esqueleto: la pantalla conserva lo que
  /// muestra y solo cambia lo nuevo.
  Future<void> cargar({bool silencioso = false}) async {
    if (!silencioso || state is! HojaVidaListo) emit(const HojaVidaCargando());
    await _refrescar();
  }

  Future<void> _refrescar() async {
    try {
      emit(HojaVidaListo(await _obtener(_vehiculoId)));
    } on CatalogoFailure catch (falla) {
      emit(HojaVidaError(falla.mensaje));
    }
  }

  Future<void> registrarDocumento({
    required TipoDocumentoVehiculo tipo,
    required DateTime fechaVencimiento,
    String? numero,
    String? entidadEmisora,
    DateTime? fechaExpedicion,
  }) async {
    await _registrarDocumento(
      vehiculoId: _vehiculoId,
      tipo: tipo,
      fechaVencimiento: fechaVencimiento,
      numero: numero,
      entidadEmisora: entidadEmisora,
      fechaExpedicion: fechaExpedicion,
    );
    await _refrescar();
  }

  /// Registra un mantenimiento de este vehículo y recarga la hoja: el plan y la
  /// línea de tiempo reflejan el cambio al instante. Relanza las fallas.
  Future<void> registrarMantenimiento({
    required String tipo,
    required double costo,
    required DateTime fecha,
    double? kilometraje,
    String? tipoMantenimientoId,
    CategoriaMantenimiento categoria = CategoriaMantenimiento.preventivo,
    String? taller,
    String? descripcion,
  }) async {
    await _registrarMantenimiento(
      vehiculoId: _vehiculoId,
      tipo: tipo,
      costo: costo,
      fecha: fecha,
      kilometraje: kilometraje,
      tipoMantenimientoId: tipoMantenimientoId,
      categoria: categoria,
      taller: taller,
      descripcion: descripcion,
    );
    await _refrescar();
  }
}
