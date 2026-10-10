import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../clientes/domain/entities/cliente.dart';
import '../../../clientes/domain/repositories/cliente_repository.dart';
import '../../../conductores/domain/entities/conductor.dart';
import '../../../conductores/domain/repositories/conductor_repository.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/lugar.dart';
import '../../domain/usecases/crear_viaje_use_case.dart';
import '../../domain/usecases/estimar_acpm_use_case.dart';
import '../../domain/usecases/estimar_ruta_use_case.dart';
import 'agendar_viaje_state.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Orquesta el formulario de Agendar viaje: catálogos (cliente/vehículo/
/// conductor activos), estimación de ruta (Edge Function) y de ACPM (RPC), y
/// el envío final a `viaje_crear`.
class AgendarViajeCubit extends Cubit<AgendarViajeState> {
  AgendarViajeCubit({
    required ClienteRepository clienteRepository,
    required VehiculoRepository vehiculoRepository,
    required ConductorRepository conductorRepository,
    required CrearViajeUseCase crear,
    required EstimarRutaUseCase estimarRuta,
    required EstimarAcpmUseCase estimarAcpm,
  }) : _clienteRepository = clienteRepository,
       _vehiculoRepository = vehiculoRepository,
       _conductorRepository = conductorRepository,
       _crear = crear,
       _estimarRuta = estimarRuta,
       _estimarAcpm = estimarAcpm,
       super(const AgendarViajeCargando()) {
    _cargarCatalogos();
  }

  final ClienteRepository _clienteRepository;
  final VehiculoRepository _vehiculoRepository;
  final ConductorRepository _conductorRepository;
  final CrearViajeUseCase _crear;
  final EstimarRutaUseCase _estimarRuta;
  final EstimarAcpmUseCase _estimarAcpm;

  static const int _tamanoCatalogo = 100;

  Future<void> _cargarCatalogos() async {
    try {
      final resultados = await Future.wait(<Future<Object>>[
        _clienteRepository.listar(pagina: 0, tamano: _tamanoCatalogo),
        _vehiculoRepository.listar(pagina: 0, tamano: _tamanoCatalogo),
        _conductorRepository.listar(pagina: 0, tamano: _tamanoCatalogo),
      ]);

      final PaginaClientes paginaClientes = resultados[0] as PaginaClientes;
      final PaginaVehiculos paginaVehiculos = resultados[1] as PaginaVehiculos;
      final PaginaConductores paginaConductores =
          resultados[2] as PaginaConductores;

      emit(
        AgendarViajeListo(
          clientes: paginaClientes.clientes
              .where((Cliente c) => c.activo)
              .toList(),
          vehiculos: paginaVehiculos.vehiculos
              .where((Vehiculo v) => v.activo)
              .toList(),
          conductores: paginaConductores.conductores
              .where((Conductor c) => c.activo)
              .toList(),
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(AgendarViajeErrorCatalogos(falla.mensaje));
    }
  }

  Future<void> estimarRuta({
    required Coordenada origen,
    required Coordenada destino,
  }) async {
    final AgendarViajeState actual = state;
    if (actual is! AgendarViajeListo) return;

    emit(
      actual.copiarCon(
        estimandoRuta: true,
        limpiarErrorRuta: true,
        limpiarRuta: true,
        limpiarAcpm: true,
        limpiarErrorAcpm: true,
      ),
    );
    try {
      final ruta = await _estimarRuta(origen: origen, destino: destino);
      final AgendarViajeState despues = state;
      if (despues is! AgendarViajeListo) return;
      emit(despues.copiarCon(ruta: ruta, estimandoRuta: false));
    } on CatalogoFailure catch (falla) {
      final AgendarViajeState despues = state;
      if (despues is! AgendarViajeListo) return;
      emit(despues.copiarCon(estimandoRuta: false, errorRuta: falla.mensaje));
    }
  }

  Future<void> estimarAcpm({
    required String vehiculoId,
    required double distanciaKm,
    required String ciudad,
  }) async {
    final AgendarViajeState actual = state;
    if (actual is! AgendarViajeListo) return;

    emit(
      actual.copiarCon(
        estimandoAcpm: true,
        limpiarErrorAcpm: true,
        limpiarAcpm: true,
      ),
    );
    try {
      final double valor = await _estimarAcpm(
        vehiculoId: vehiculoId,
        distanciaKm: distanciaKm,
        ciudad: ciudad,
      );
      final AgendarViajeState despues = state;
      if (despues is! AgendarViajeListo) return;
      emit(despues.copiarCon(acpmEstimado: valor, estimandoAcpm: false));
    } on CatalogoFailure catch (falla) {
      final AgendarViajeState despues = state;
      if (despues is! AgendarViajeListo) return;
      emit(despues.copiarCon(estimandoAcpm: false, errorAcpm: falla.mensaje));
    }
  }

  Future<void> crear({
    required String remision,
    required String vehiculoId,
    required String conductorId,
    required String clienteId,
    required Lugar origen,
    required Lugar destino,
    required String rutaPolilinea,
    required DateTime fechaSalidaProgramada,
    required double distanciaEstimada,
    required double tiempoEstimadoMin,
    required double pesoCarga,
    required double valorFlete,
  }) async {
    final AgendarViajeState actual = state;
    if (actual is! AgendarViajeListo) return;

    emit(actual.copiarCon(enviando: true, limpiarErrorEnvio: true));
    try {
      final viaje = await _crear(
        remision: remision,
        vehiculoId: vehiculoId,
        conductorId: conductorId,
        clienteId: clienteId,
        origen: origen,
        destino: destino,
        rutaPolilinea: rutaPolilinea,
        fechaSalidaProgramada: fechaSalidaProgramada,
        distanciaEstimada: distanciaEstimada,
        tiempoEstimadoMin: tiempoEstimadoMin,
        pesoCarga: pesoCarga,
        valorFlete: valorFlete,
      );
      emit(AgendarViajeExito(viaje));
    } on CatalogoFailure catch (falla) {
      final AgendarViajeState despues = state;
      if (despues is! AgendarViajeListo) return;
      emit(despues.copiarCon(enviando: false, errorEnvio: falla.mensaje));
    }
  }
}
