import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/tarifa_combustible.dart';
import '../../domain/usecases/tarifa_use_cases.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

sealed class TarifaListState extends Equatable {
  const TarifaListState();

  @override
  List<Object?> get props => <Object?>[];
}

class TarifaListCargando extends TarifaListState {
  const TarifaListCargando();
}

class TarifaListListo extends TarifaListState {
  const TarifaListListo(this.tarifas);

  final List<TarifaCombustible> tarifas;

  /// Tarifa vigente hoy por ciudad: la de fecha más reciente que ya empezó.
  List<TarifaCombustible> vigentes(DateTime hoy) {
    final Map<String, TarifaCombustible> porCiudad =
        <String, TarifaCombustible>{};
    for (final TarifaCombustible t in tarifas) {
      if (t.fechaVigenciaDesde.isAfter(hoy)) continue;
      final TarifaCombustible? actual = porCiudad[t.ciudad.toLowerCase()];
      if (actual == null ||
          t.fechaVigenciaDesde.isAfter(actual.fechaVigenciaDesde)) {
        porCiudad[t.ciudad.toLowerCase()] = t;
      }
    }
    return porCiudad.values.toList();
  }

  @override
  List<Object?> get props => <Object?>[tarifas];
}

class TarifaListError extends TarifaListState {
  const TarifaListError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

/// Lista, registra y corrige las tarifas de ACPM (RF-12). Las fallas de
/// escritura se relanzan para que la hoja de captura las muestre.
class TarifaListCubit extends Cubit<TarifaListState> {
  TarifaListCubit({
    required ListarTarifasUseCase listar,
    required RegistrarTarifaUseCase registrar,
    required ActualizarPrecioTarifaUseCase actualizarPrecio,
  }) : _listar = listar,
       _registrar = registrar,
       _actualizarPrecio = actualizarPrecio,
       super(const TarifaListCargando()) {
    cargar();
  }

  final ListarTarifasUseCase _listar;
  final RegistrarTarifaUseCase _registrar;
  final ActualizarPrecioTarifaUseCase _actualizarPrecio;

  Future<void> cargar() async {
    emit(const TarifaListCargando());
    await _refrescar();
  }

  Future<void> _refrescar() async {
    try {
      emit(TarifaListListo(await _listar()));
    } on CatalogoFailure catch (falla) {
      emit(TarifaListError(falla.mensaje));
    }
  }

  Future<void> registrar({
    required String ciudad,
    required double precioGalon,
    required DateTime fechaVigenciaDesde,
  }) async {
    await _registrar(
      ciudad: ciudad,
      precioGalon: precioGalon,
      fechaVigenciaDesde: fechaVigenciaDesde,
    );
    await _refrescar();
  }

  Future<void> actualizarPrecio({
    required String id,
    required double precioGalon,
  }) async {
    await _actualizarPrecio(id: id, precioGalon: precioGalon);
    await _refrescar();
  }
}
