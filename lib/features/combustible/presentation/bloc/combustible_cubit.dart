import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/rendimiento_combustible.dart';
import '../../domain/usecases/combustible_use_cases.dart';
import 'combustible_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que el campo privado
// se asigna en la lista de inicializacion.
// ignore_for_file: prefer_initializing_formals

/// Orquesta la pestaña «Combustible» del Resumen: rendimiento km/galón del
/// mes por vehículo y por ruta, contra los 3 meses anteriores.
class CombustibleCubit extends Cubit<CombustibleState> {
  CombustibleCubit({required ObtenerRendimientoCombustibleUseCase obtener})
    : _obtener = obtener,
      super(const CombustibleCargando()) {
    final DateTime hoy = DateTime.now();
    _cargar(DateTime(hoy.year, hoy.month));
  }

  final ObtenerRendimientoCombustibleUseCase _obtener;
  DateTime? _mes;

  Future<void> _cargar(DateTime mes) async {
    _mes = mes;
    emit(const CombustibleCargando());
    try {
      final DateTime hasta = DateTime(
        mes.year,
        mes.month + 1,
      ).subtract(const Duration(days: 1));
      final List<List<RendimientoCombustible>> filas = await Future.wait(
        <Future<List<RendimientoCombustible>>>[
          for (final DimensionCombustible d in DimensionCombustible.values)
            _obtener(desde: mes, hasta: hasta, dimension: d),
        ],
      );
      if (isClosed) return;
      emit(
        CombustibleListo(
          mes: mes,
          porDimension: <DimensionCombustible, List<RendimientoCombustible>>{
            for (int i = 0; i < DimensionCombustible.values.length; i++)
              DimensionCombustible.values[i]: filas[i],
          },
        ),
      );
    } on CatalogoFailure catch (falla) {
      if (!isClosed) emit(CombustibleError(falla.mensaje));
    }
  }

  Future<void> irAMesAnterior() {
    final DateTime? mes = _mes;
    return mes == null
        ? Future<void>.value()
        : _cargar(DateTime(mes.year, mes.month - 1));
  }

  Future<void> irAMesSiguiente() {
    final DateTime? mes = _mes;
    return mes == null
        ? Future<void>.value()
        : _cargar(DateTime(mes.year, mes.month + 1));
  }

  Future<void> recargar() =>
      _mes == null ? Future<void>.value() : _cargar(_mes!);
}
