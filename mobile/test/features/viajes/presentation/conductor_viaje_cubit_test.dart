import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/viajes/domain/entities/categoria_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/costo_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/fuente_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/hito.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_hito.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/costo_viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/hito_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/servicios/servicio_ubicacion.dart';
import 'package:optiruta/features/viajes/domain/usecases/actualizar_valor_real_costo_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/iniciar_viaje_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_costos_viaje_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_hitos_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_viajes_activos_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/registrar_hito_use_case.dart';
import 'package:optiruta/features/viajes/presentation/bloc/conductor_viaje_cubit.dart';
import 'package:optiruta/features/viajes/presentation/bloc/conductor_viaje_state.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockHitoRepository extends Mock implements HitoRepository {}

class _MockCostoViajeRepository extends Mock implements CostoViajeRepository {}

class _MockServicioUbicacion extends Mock implements ServicioUbicacion {}

const Coordenada _aqui = Coordenada(6.2442, -75.5812);

final ViajeResumen _viaje = ViajeResumen(
  id: 'v-1',
  remision: 'REM-1',
  origen: 'Bogotá',
  destino: 'Barranquilla',
  estado: EstadoViaje.enCurso,
  placaVehiculo: 'TKM218',
  nombreConductor: 'Luis Herrera',
  nombreCliente: 'Distribuidora Andina',
  fechaCreacion: DateTime.now(),
);

void main() {
  late _MockViajeRepository viajeRepo;
  late _MockHitoRepository hitoRepo;
  late _MockCostoViajeRepository costoRepo;
  late _MockServicioUbicacion ubicacion;

  ConductorViajeCubit crear() => ConductorViajeCubit(
    listarActivos: ListarViajesActivosUseCase(viajeRepo),
    listarHitos: ListarHitosUseCase(hitoRepo),
    listarCostos: ListarCostosViajeUseCase(costoRepo),
    registrarHito: RegistrarHitoUseCase(hitoRepo),
    iniciarViaje: IniciarViajeUseCase(viajeRepo),
    ubicacion: ubicacion,
    actualizarValorReal: ActualizarValorRealCostoUseCase(costoRepo),
  );

  setUp(() {
    viajeRepo = _MockViajeRepository();
    hitoRepo = _MockHitoRepository();
    costoRepo = _MockCostoViajeRepository();
    ubicacion = _MockServicioUbicacion();
    registerFallbackValue(_aqui);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(TipoHito.salida);
    when(() => ubicacion.solicitarPermiso())
        .thenAnswer((_) async => EstadoPermisoUbicacion.concedido);
    when(() => ubicacion.posicionActual()).thenAnswer((_) async => _aqui);
  });

  test('sin viajes activos emite ConductorViajeSinAsignar', () async {
    when(() => viajeRepo.listarActivos()).thenAnswer((_) async => []);

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<ConductorViajeSinAsignar>());
  });

  test('con un viaje activo carga sus hitos y costos', () async {
    when(() => viajeRepo.listarActivos()).thenAnswer((_) async => [_viaje]);
    when(() => hitoRepo.listarPorViaje('v-1'))
        .thenAnswer((_) async => const <Hito>[]);
    when(() => costoRepo.listarPorViaje('v-1')).thenAnswer(
      (_) async => const <CostoViaje>[
        CostoViaje(
          id: 'c-1',
          viajeId: 'v-1',
          categoria: CategoriaCosto.acpm,
          valorEstimado: 1840000,
          fuente: FuenteCosto.automatico,
        ),
      ],
    );

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final ConductorViajeListo estado = cubit.state as ConductorViajeListo;
    expect(estado.viaje.id, 'v-1');
    expect(estado.costos, hasLength(1));
  });

  test('registrarHito registra con la hora actual y recarga', () async {
    when(() => viajeRepo.listarActivos()).thenAnswer((_) async => [_viaje]);
    when(() => hitoRepo.listarPorViaje('v-1'))
        .thenAnswer((_) async => const <Hito>[]);
    when(() => costoRepo.listarPorViaje('v-1'))
        .thenAnswer((_) async => const <CostoViaje>[]);
    when(
      () => hitoRepo.registrar(
        viajeId: 'v-1',
        tipo: TipoHito.llegadaCargue,
        fechaHora: any(named: 'fechaHora'),
      ),
    ).thenAnswer(
      (_) async => Hito(
        id: 'h-1',
        viajeId: 'v-1',
        tipo: TipoHito.llegadaCargue,
        fechaHora: DateTime.now(),
      ),
    );

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.registrarHito(TipoHito.llegadaCargue);

    verify(
      () => hitoRepo.registrar(
        viajeId: 'v-1',
        tipo: TipoHito.llegadaCargue,
        fechaHora: any(named: 'fechaHora'),
      ),
    ).called(1);
    verify(() => viajeRepo.listarActivos()).called(2);
  });

  test('confirmarValorReal propaga la falla y deja de procesar', () async {
    when(() => viajeRepo.listarActivos()).thenAnswer((_) async => [_viaje]);
    when(() => hitoRepo.listarPorViaje('v-1'))
        .thenAnswer((_) async => const <Hito>[]);
    when(() => costoRepo.listarPorViaje('v-1'))
        .thenAnswer((_) async => const <CostoViaje>[]);
    when(() => costoRepo.actualizarValorReal(costoId: 'c-1', valorReal: 100))
        .thenThrow(CatalogoFailure.sinPermiso());

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      () => cubit.confirmarValorReal(costoId: 'c-1', valorReal: 100),
      throwsA(isA<CatalogoFailure>()),
    );

    final ConductorViajeListo estado = cubit.state as ConductorViajeListo;
    expect(estado.procesando, isFalse);
  });

  test('registrarHito recarga sin pasar por «Cargando» (la UI conserva lo '
      'que muestra y anima solo lo nuevo)', () async {
    when(() => viajeRepo.listarActivos()).thenAnswer((_) async => [_viaje]);
    when(() => hitoRepo.listarPorViaje('v-1'))
        .thenAnswer((_) async => const <Hito>[]);
    when(() => costoRepo.listarPorViaje('v-1'))
        .thenAnswer((_) async => const <CostoViaje>[]);
    when(
      () => hitoRepo.registrar(
        viajeId: 'v-1',
        tipo: TipoHito.llegadaCargue,
        fechaHora: any(named: 'fechaHora'),
      ),
    ).thenAnswer(
      (_) async => Hito(
        id: 'h-1',
        viajeId: 'v-1',
        tipo: TipoHito.llegadaCargue,
        fechaHora: DateTime.now(),
      ),
    );

    final cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final emitidos = <ConductorViajeState>[];
    final sub = cubit.stream.listen(emitidos.add);
    addTearDown(sub.cancel);

    await cubit.registrarHito(TipoHito.llegadaCargue);

    expect(emitidos.whereType<ConductorViajeCargando>(), isEmpty);
    expect(emitidos.last, isA<ConductorViajeListo>());
  });

  group('comenzar el viaje (salida)', () {
    final Viaje iniciado = Viaje(
      id: 'v-1',
      remision: 'REM-1',
      vehiculoId: 'veh-1',
      conductorId: 'con-1',
      clienteId: 'cli-1',
      origen: 'Medellín',
      destino: 'Bogotá',
      estado: EstadoViaje.enCurso,
      valorFlete: 1000,
      valorAnticipo: 0,
      saldoPendiente: 1000,
      fechaCreacion: DateTime(2026, 10, 10),
    );

    void cargarViaje() {
      when(() => viajeRepo.listarActivos()).thenAnswer((_) async => [_viaje]);
      when(() => hitoRepo.listarPorViaje('v-1'))
          .thenAnswer((_) async => const <Hito>[]);
      when(() => costoRepo.listarPorViaje('v-1'))
          .thenAnswer((_) async => const <CostoViaje>[]);
    }

    test('envía la posición del teléfono a viaje_iniciar, no registra el hito '
        'directo', () async {
      cargarViaje();
      when(
        () => viajeRepo.iniciar(
          viajeId: 'v-1',
          ubicacion: _aqui,
          fechaHora: any(named: 'fechaHora'),
        ),
      ).thenAnswer((_) async => iniciado);

      final cubit = crear();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      await cubit.registrarHito(TipoHito.salida);

      verify(
        () => viajeRepo.iniciar(
          viajeId: 'v-1',
          ubicacion: _aqui,
          fechaHora: any(named: 'fechaHora'),
        ),
      ).called(1);
      verifyNever(
        () => hitoRepo.registrar(
          viajeId: any(named: 'viajeId'),
          tipo: any(named: 'tipo'),
          fechaHora: any(named: 'fechaHora'),
        ),
      );
    });

    test('sin permiso de ubicación falla y no llama al servidor', () async {
      cargarViaje();
      when(() => ubicacion.solicitarPermiso())
          .thenAnswer((_) async => EstadoPermisoUbicacion.denegado);

      final cubit = crear();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        () => cubit.registrarHito(TipoHito.salida),
        throwsA(isA<CatalogoFailure>()),
      );

      verifyNever(
        () => viajeRepo.iniciar(
          viajeId: any(named: 'viajeId'),
          ubicacion: any(named: 'ubicacion'),
          fechaHora: any(named: 'fechaHora'),
        ),
      );
      expect((cubit.state as ConductorViajeListo).procesando, isFalse);
    });

    test('si el servidor rechaza por distancia, propaga la falla', () async {
      cargarViaje();
      when(
        () => viajeRepo.iniciar(
          viajeId: any(named: 'viajeId'),
          ubicacion: any(named: 'ubicacion'),
          fechaHora: any(named: 'fechaHora'),
        ),
      ).thenThrow(
        const CatalogoFailure(
          CatalogoErrorCodigo.desconocido,
          'Debes estar a menos de 500 m del punto de inicio.',
        ),
      );

      final cubit = crear();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        () => cubit.registrarHito(TipoHito.salida),
        throwsA(isA<CatalogoFailure>()),
      );
      expect((cubit.state as ConductorViajeListo).procesando, isFalse);
    });
  });
}
