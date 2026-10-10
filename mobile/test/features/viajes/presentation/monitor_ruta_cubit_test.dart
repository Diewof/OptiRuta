import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/domain/detector_ruta.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_alerta_viaje.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/servicios/servicio_ubicacion.dart';
import 'package:optiruta/features/viajes/domain/usecases/registrar_alerta_viaje_use_case.dart';
import 'package:optiruta/features/viajes/presentation/bloc/monitor_ruta_cubit.dart';
import 'package:optiruta/features/viajes/presentation/bloc/monitor_ruta_state.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _ServicioFalso implements ServicioUbicacion {
  _ServicioFalso(this.permiso);

  final EstadoPermisoUbicacion permiso;
  final StreamController<Coordenada> controlador =
      StreamController<Coordenada>();

  @override
  Future<EstadoPermisoUbicacion> solicitarPermiso() async => permiso;

  @override
  Future<Coordenada> posicionActual() async => _aqui;

  @override
  Stream<Coordenada> posiciones() => controlador.stream;
}

const Coordenada _aqui = Coordenada(0, 0.5);
const List<Coordenada> _ruta = <Coordenada>[Coordenada(0, 0), Coordenada(0, 1)];

void main() {
  late _MockViajeRepository repo;
  late DateTime reloj;

  setUp(() {
    repo = _MockViajeRepository();
    reloj = DateTime(2026, 10, 8, 8);
    registerFallbackValue(TipoAlertaViaje.paradaProlongada);
    registerFallbackValue(_aqui);
    when(
      () => repo.registrarAlerta(
        viajeId: any(named: 'viajeId'),
        tipo: any(named: 'tipo'),
        ubicacion: any(named: 'ubicacion'),
      ),
    ).thenAnswer((_) async => true);
  });

  MonitorRutaCubit crear(_ServicioFalso servicio) => MonitorRutaCubit(
    viajeId: 'v-1',
    ubicacion: servicio,
    detector: DetectorRuta(ruta: _ruta),
    registrarAlerta: RegistrarAlertaViajeUseCase(repo),
    ahora: () => reloj,
  );

  Future<void> emitir(_ServicioFalso servicio, Coordenada posicion) async {
    servicio.controlador.add(posicion);
    await Future<void>.delayed(Duration.zero);
  }

  test('permiso denegado: estado sin permiso, no bloqueado', () async {
    final cubit = crear(_ServicioFalso(EstadoPermisoUbicacion.denegado));
    addTearDown(cubit.close);

    await cubit.iniciar();

    expect(cubit.state, const MonitorRutaSinPermiso(bloqueado: false));
  });

  test('permiso bloqueado: pide ir a los ajustes', () async {
    final cubit = crear(_ServicioFalso(EstadoPermisoUbicacion.bloqueado));
    addTearDown(cubit.close);

    await cubit.iniciar();

    expect(cubit.state, const MonitorRutaSinPermiso(bloqueado: true));
  });

  test('cada posición mueve el marcador sin enviar nada al servidor', () async {
    final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
    final cubit = crear(servicio);
    addTearDown(cubit.close);
    await cubit.iniciar();

    await emitir(servicio, _aqui);

    expect(cubit.state, const MonitorRutaActivo(posicion: _aqui));
    verifyNever(
      () => repo.registrarAlerta(
        viajeId: any(named: 'viajeId'),
        tipo: any(named: 'tipo'),
        ubicacion: any(named: 'ubicacion'),
      ),
    );
  });

  test('30 minutos quieto: avisa al conductor y registra UN evento', () async {
    final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
    final cubit = crear(servicio);
    addTearDown(cubit.close);
    await cubit.iniciar();

    await emitir(servicio, _aqui);
    reloj = reloj.add(const Duration(minutes: 30));
    await emitir(servicio, _aqui);

    expect(
      (cubit.state as MonitorRutaActivo).alerta,
      TipoAlertaViaje.paradaProlongada,
    );
    verify(
      () => repo.registrarAlerta(
        viajeId: 'v-1',
        tipo: TipoAlertaViaje.paradaProlongada,
        ubicacion: _aqui,
      ),
    ).called(1);
  });

  test('si el servidor falla, el aviso local se mantiene', () async {
    when(
      () => repo.registrarAlerta(
        viajeId: any(named: 'viajeId'),
        tipo: any(named: 'tipo'),
        ubicacion: any(named: 'ubicacion'),
      ),
    ).thenThrow(Exception('sin red'));
    final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
    final cubit = crear(servicio);
    addTearDown(cubit.close);
    await cubit.iniciar();

    await emitir(servicio, _aqui);
    reloj = reloj.add(const Duration(minutes: 30));
    await emitir(servicio, _aqui);

    expect(
      (cubit.state as MonitorRutaActivo).alerta,
      TipoAlertaViaje.paradaProlongada,
    );
  });

  test('descartarAlerta oculta el aviso y conserva la posición', () async {
    final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
    final cubit = crear(servicio);
    addTearDown(cubit.close);
    await cubit.iniciar();
    await emitir(servicio, _aqui);
    reloj = reloj.add(const Duration(minutes: 30));
    await emitir(servicio, _aqui);

    cubit.descartarAlerta();

    expect(cubit.state, const MonitorRutaActivo(posicion: _aqui));
  });
}
