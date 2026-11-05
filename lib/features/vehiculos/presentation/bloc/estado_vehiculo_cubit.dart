// ignore_for_file: prefer_initializing_formals
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/estado_vehiculo.dart';
import '../../domain/repositories/hoja_vida_repository.dart';

/// Estado resumido de un vehículo para su tarjeta en Flota. Si no se puede
/// consultar queda en `null`: la tarjeta simplemente no muestra semáforo.
class EstadoVehiculoCubit extends Cubit<EstadoVehiculo?> {
  EstadoVehiculoCubit({
    required HojaVidaRepository hojaVida,
    required String vehiculoId,
  }) : _hojaVida = hojaVida,
       super(null) {
    _cargar(vehiculoId);
  }

  final HojaVidaRepository _hojaVida;

  Future<void> _cargar(String vehiculoId) async {
    try {
      final hoja = await _hojaVida.obtener(vehiculoId);
      if (!isClosed) emit(estadoDeVehiculo(hoja));
    } on Object {
      // Sin semáforo; el detalle sigue disponible en la hoja de vida.
    }
  }
}
