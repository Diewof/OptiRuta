import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../clientes/domain/entities/cliente.dart';
import '../../../clientes/domain/repositories/cliente_repository.dart';
import '../../../conductores/domain/entities/conductor.dart';
import '../../../conductores/domain/repositories/conductor_repository.dart';
import '../../../vehiculos/domain/entities/hoja_vida.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../../vehiculos/domain/repositories/hoja_vida_repository.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/lugar.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/repositories/viaje_repository.dart';
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
    HojaVidaRepository? hojaVidaRepository,
    ViajeRepository? viajeRepository,
  }) : _hojaVidaRepository = hojaVidaRepository,
       _viajeRepository = viajeRepository,
       _clienteRepository = clienteRepository,
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

  /// Opcionales: sin ellos no se calculan avisos de disponibilidad.
  final HojaVidaRepository? _hojaVidaRepository;
  final ViajeRepository? _viajeRepository;
  final Map<String, HojaVida?> _hojas = <String, HojaVida?>{};

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

  /// Avisos de documentos y cruces de agenda de cada vehículo y conductor
  /// para la [salida] elegida. Los fallos de red no impiden agendar: sin dato
  /// simplemente no hay aviso.
  Future<void> cargarDisponibilidad(DateTime salida) async {
    final AgendarViajeState actual = state;
    final ViajeRepository? viajes = _viajeRepository;
    final HojaVidaRepository? hojas = _hojaVidaRepository;
    if (actual is! AgendarViajeListo || viajes == null) return;

    try {
      final DateTime dia = DateTime(salida.year, salida.month, salida.day);
      final List<List<ViajeResumen>> listas = await Future.wait(
        <Future<List<ViajeResumen>>>[
          viajes.listarPorRango(
            desde: dia.subtract(const Duration(days: 7)),
            hasta: dia.add(const Duration(days: 1)),
          ),
          viajes.listarActivos(),
        ],
      );
      final List<ViajeResumen> abiertos = <ViajeResumen>[
        ...listas[0],
        ...listas[1],
      ];
      if (hojas != null) {
        await Future.wait(<Future<void>>[
          for (final Vehiculo v in actual.vehiculos)
            if (!_hojas.containsKey(v.id))
              hojas
                  .obtener(v.id)
                  .then<void>(
                    (HojaVida h) => _hojas[v.id] = h,
                    onError: (Object _) => _hojas[v.id] = null,
                  ),
        ]);
      }
      final AgendarViajeState despues = state;
      if (despues is! AgendarViajeListo) return;
      emit(
        despues.copiarCon(
          avisosVehiculos: <String, AvisoDisponibilidad>{
            for (final Vehiculo v in despues.vehiculos)
              v.id: avisoVehiculo(
                vehiculo: v,
                hoja: _hojas[v.id],
                viajes: abiertos,
                salida: salida,
              ),
          },
          avisosConductores: <String, AvisoDisponibilidad>{
            for (final Conductor c in despues.conductores)
              c.id: avisoConductor(
                conductor: c,
                viajes: abiertos,
                salida: salida,
              ),
          },
        ),
      );
    } on CatalogoFailure {
      // Sin avisos: la validación real ocurre al salir.
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
