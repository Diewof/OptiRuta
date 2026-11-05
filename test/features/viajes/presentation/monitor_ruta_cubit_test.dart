import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/domain/detector_fatiga.dart';
import 'package:optiruta/features/viajes/domain/detector_ruta.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_alerta_viaje.dart';
import 'package:optiruta/features/viajes/domain/repositories/pausa_activa_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/ubicacion_viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/servicios/servicio_ubicacion.dart';
import 'package:optiruta/features/viajes/domain/usecases/pausa_activa_use_cases.dart';
import 'package:optiruta/features/viajes/domain/usecases/registrar_alerta_viaje_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/ubicacion_viaje_use_cases.dart';
import 'package:optiruta/features/viajes/presentation/bloc/monitor_ruta_cubit.dart';
import 'package:optiruta/features/viajes/presentation/bloc/monitor_ruta_state.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockPausaActivaRepository extends Mock
    implements PausaActivaRepository {}

class _MockUbicacionRepository extends Mock
    implements UbicacionViajeRepository {}

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
  late _MockUbicacionRepository ubicacionRepo;
  late _MockPausaActivaRepository pausaRepo;

  setUp(() {
    repo = _MockViajeRepository();
    ubicacionRepo = _MockUbicacionRepository();
    pausaRepo = _MockPausaActivaRepository();
    when(() => pausaRepo.consumirPrueba(viajeId: any(named: 'viajeId')))
        .thenAnswer((_) async => false);
    when(
      () => pausaRepo.registrarIgnorada(
        viajeId: any(named: 'viajeId'),
        minutosConduccion: any(named: 'minutosConduccion'),
        minutosIgnorada: any(named: 'minutosIgnorada'),
        prueba: any(named: 'prueba'),
      ),
    ).thenAnswer((_) async => true);
    registerFallbackValue(_aqui);
    when(() => ubicacionRepo.consentimientoVigente())
        .thenAnswer((_) async => true);
    when(
      () => ubicacionRepo.registrarPunto(
        viajeId: any(named: 'viajeId'),
        posicion: any(named: 'posicion'),
      ),
    ).thenAnswer((_) async => true);
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

  MonitorRutaCubit crear(
    _ServicioFalso servicio, {
    DetectorFatiga? fatiga,
    Duration? consultaPrueba,
  }) => MonitorRutaCubit(
    viajeId: 'v-1',
    ubicacion: servicio,
    detector: DetectorRuta(ruta: _ruta),
    registrarAlerta: RegistrarAlertaViajeUseCase(repo),
    consultarConsentimiento: ConsultarConsentimientoUbicacionUseCase(
      ubicacionRepo,
    ),
    responderConsentimiento: ResponderConsentimientoUbicacionUseCase(
      ubicacionRepo,
    ),
    registrarUbicacion: RegistrarUbicacionViajeUseCase(ubicacionRepo),
    registrarPausaIgnorada: RegistrarPausaIgnoradaUseCase(pausaRepo),
    consumirPausaPrueba: ConsumirPausaPruebaUseCase(pausaRepo),
    detectorFatiga: fatiga,
    consultaPrueba: consultaPrueba ?? const Duration(seconds: 20),
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

    expect(
      cubit.state,
      const MonitorRutaActivo(posicion: _aqui, registrando: true),
    );
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

    expect(
      cubit.state,
      const MonitorRutaActivo(posicion: _aqui, registrando: true),
    );
  });

  test(
    'RF-21: con consentimiento envía el punto al recibir la primera posición',
    () async {
      final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
      final cubit = crear(servicio);
      addTearDown(cubit.close);

      await cubit.iniciar();
      await emitir(servicio, _aqui);

      verify(
        () => ubicacionRepo.registrarPunto(viajeId: 'v-1', posicion: _aqui),
      ).called(1);
      expect((cubit.state as MonitorRutaActivo).registrando, isTrue);
    },
  );

  test('RF-23: sin consentimiento pregunta y no envía ningún punto', () async {
    when(() => ubicacionRepo.consentimientoVigente())
        .thenAnswer((_) async => false);
    final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
    final cubit = crear(servicio);
    addTearDown(cubit.close);

    await cubit.iniciar();
    await emitir(servicio, _aqui);

    final MonitorRutaActivo estado = cubit.state as MonitorRutaActivo;
    expect(estado.consentimientoPendiente, isTrue);
    expect(estado.registrando, isFalse);
    verifyNever(
      () => ubicacionRepo.registrarPunto(
        viajeId: any(named: 'viajeId'),
        posicion: any(named: 'posicion'),
      ),
    );
  });

  group('pausa activa', () {
    DetectorFatiga fatiga() =>
        DetectorFatiga(conduccionMaxima: const Duration(hours: 1));

    test(
      'a las horas máximas muestra la card y luego se puede descartar',
      () async {
        final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
        final cubit = crear(servicio, fatiga: fatiga());
        addTearDown(cubit.close);
        await cubit.iniciar();

        await emitir(servicio, const Coordenada(0, 0.1));
        expect((cubit.state as MonitorRutaActivo).pausaActiva, isFalse);

        reloj = reloj.add(const Duration(hours: 1));
        await emitir(servicio, const Coordenada(0, 0.2));
        expect((cubit.state as MonitorRutaActivo).pausaActiva, isTrue);

        cubit.descartarPausaActiva();
        expect((cubit.state as MonitorRutaActivo).pausaActiva, isFalse);
      },
    );

    test(
      'si sigue conduciendo tras la gracia notifica al administrador',
      () async {
        final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
        final cubit = crear(servicio, fatiga: fatiga());
        addTearDown(cubit.close);
        await cubit.iniciar();
        await emitir(servicio, const Coordenada(0, 0.1));
        reloj = reloj.add(const Duration(hours: 1));
        await emitir(servicio, const Coordenada(0, 0.2));
        reloj = reloj.add(const Duration(minutes: 15));
        await emitir(servicio, const Coordenada(0, 0.3));

        verify(
          () => pausaRepo.registrarIgnorada(
            viajeId: 'v-1',
            minutosConduccion: 75,
            minutosIgnorada: 15,
            prueba: false,
          ),
        ).called(1);
      },
    );

    test('la prueba del administrador activa la card', () async {
      when(() => pausaRepo.consumirPrueba(viajeId: 'v-1'))
          .thenAnswer((_) async => true);
      final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
      final cubit = crear(
        servicio,
        consultaPrueba: const Duration(milliseconds: 10),
      );
      addTearDown(cubit.close);

      await cubit.iniciar();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((cubit.state as MonitorRutaActivo).pausaActiva, isTrue);
    });
  });

  test(
    'RF-23: al aceptar se guarda el consentimiento y empieza a enviar',
    () async {
      when(() => ubicacionRepo.consentimientoVigente())
          .thenAnswer((_) async => false);
      when(() => ubicacionRepo.responderConsentimiento(acepta: true))
          .thenAnswer((_) async => true);
      final servicio = _ServicioFalso(EstadoPermisoUbicacion.concedido);
      final cubit = crear(servicio);
      addTearDown(cubit.close);

      await cubit.iniciar();
      await emitir(servicio, _aqui);
      await cubit.responderConsentimiento(acepta: true);

      final MonitorRutaActivo estado = cubit.state as MonitorRutaActivo;
      expect(estado.consentimientoPendiente, isFalse);
      expect(estado.registrando, isTrue);
      verify(
        () => ubicacionRepo.registrarPunto(viajeId: 'v-1', posicion: _aqui),
      ).called(1);
    },
  );
}
