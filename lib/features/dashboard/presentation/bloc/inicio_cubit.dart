import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../notificaciones/domain/entities/notificacion.dart';
import '../../../notificaciones/domain/repositories/notificacion_repository.dart';
import '../../../notificaciones/domain/usecases/listar_notificaciones_use_case.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../../viajes/domain/entities/viaje_resumen.dart';
import '../../../viajes/domain/usecases/listar_viajes_activos_use_case.dart';

sealed class InicioState extends Equatable {
  const InicioState();

  @override
  List<Object?> get props => <Object?>[];
}

class InicioCargando extends InicioState {
  const InicioCargando();
}

class InicioError extends InicioState {
  const InicioError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class InicioListo extends InicioState {
  const InicioListo({
    required this.alertas,
    required this.viajesActivos,
    required this.vehiculosEnRuta,
    required this.totalVehiculos,
  });

  final List<Notificacion> alertas;
  final List<ViajeResumen> viajesActivos;
  final int vehiculosEnRuta;
  final int totalVehiculos;

  @override
  List<Object?> get props => <Object?>[
    alertas,
    viajesActivos,
    vehiculosEnRuta,
    totalVehiculos,
  ];
}

/// Lo que el administrador necesita ver al abrir la app: alertas sin leer,
/// viajes en curso y cuánta flota está en ruta. Sin histórico ni filtros.
class InicioCubit extends Cubit<InicioState> {
  InicioCubit({
    required this.listarNotificaciones,
    required this.listarViajesActivos,
    required this.vehiculoRepository,
  }) : super(const InicioCargando()) {
    cargar();
  }

  static const int _tamanoAlertas = 50;
  static const int _tamanoCatalogoVehiculos = 100;

  final ListarNotificacionesUseCase listarNotificaciones;
  final ListarViajesActivosUseCase listarViajesActivos;
  final VehiculoRepository vehiculoRepository;

  /// [silencioso] refresca sin volver al esqueleto (al regresar a la pestaña).
  Future<void> cargar({bool silencioso = false}) async {
    if (!silencioso || state is! InicioListo) emit(const InicioCargando());
    try {
      final PaginaNotificaciones alertas = await listarNotificaciones(
        pagina: 0,
        tamano: _tamanoAlertas,
        soloNoLeidas: true,
      );
      final List<ViajeResumen> viajes = await listarViajesActivos();
      final PaginaVehiculos vehiculos = await vehiculoRepository.listar(
        pagina: 0,
        tamano: _tamanoCatalogoVehiculos,
      );

      final List<Vehiculo> activos = vehiculos.vehiculos
          .where((Vehiculo v) => v.activo)
          .toList();
      final Set<String> placasEnRuta = viajes
          .map((ViajeResumen v) => v.placaVehiculo)
          .toSet();

      if (isClosed) return;
      emit(
        InicioListo(
          alertas: alertas.notificaciones,
          viajesActivos: viajes,
          vehiculosEnRuta: activos
              .where((Vehiculo v) => placasEnRuta.contains(v.placa))
              .length,
          totalVehiculos: activos.length,
        ),
      );
    } on CatalogoFailure catch (falla) {
      if (!isClosed && state is! InicioListo) emit(InicioError(falla.mensaje));
    }
  }
}
