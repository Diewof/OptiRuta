import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:optiruta/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:optiruta/features/conductores/domain/repositories/conductor_repository.dart';
import 'package:optiruta/features/combustible/domain/repositories/combustible_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/pausa_activa_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/ubicacion_viaje_repository.dart';
import 'package:optiruta/features/viajes/presentation/bloc/monitor_ruta_registro.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/sesion.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/autenticacion/domain/repositories/auth_repository.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/cerrar_sesion_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/iniciar_con_google_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/iniciar_sesion_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/observar_sesion_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/recuperar_password_use_case.dart';
import 'package:optiruta/features/autenticacion/domain/usecases/registrarse_use_case.dart';
import 'package:optiruta/features/autenticacion/presentation/bloc/auth_cubit.dart';
import 'package:optiruta/features/autenticacion/presentation/widgets/auth_gate.dart';
import 'package:optiruta/features/dashboard/domain/entities/metricas.dart';
import 'package:optiruta/features/dashboard/domain/repositories/metricas_repository.dart';
import 'package:optiruta/features/notificaciones/domain/repositories/notificacion_repository.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/vehiculo_repository.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_consolidada.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/costo_viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/hito_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/rentabilidad_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/servicios/servicio_ubicacion.dart';

import '../../checklist/sin_checklist_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockVehiculoRepository extends Mock implements VehiculoRepository {}

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockRentabilidadRepository extends Mock
    implements RentabilidadRepository {}

class _MockMetricasRepository extends Mock implements MetricasRepository {}

class _MockNotificacionRepository extends Mock
    implements NotificacionRepository {}

class _MockHitoRepository extends Mock implements HitoRepository {}

class _MockCombustibleRepository extends Mock
    implements CombustibleRepository {}

class _MockCostoViajeRepository extends Mock implements CostoViajeRepository {}

const Usuario _admin = Usuario(
  id: 'u-1',
  nombre: 'Ana Admin',
  rol: RolUsuario.administrador,
  activo: true,
);

const Usuario _conductor = Usuario(
  id: 'u-2',
  nombre: 'Carlos Conductor',
  rol: RolUsuario.conductor,
  activo: true,
);

class _MockServicioUbicacion extends Mock implements ServicioUbicacion {}

class _MockPausaActivaRepository extends Mock
    implements PausaActivaRepository {}

class _MockUbicacionViajeRepository extends Mock
    implements UbicacionViajeRepository {}

class _MockClienteRepository extends Mock implements ClienteRepository {}

class _MockConductorRepository extends Mock implements ConductorRepository {}

void main() {
  late _MockAuthRepository repo;
  late _MockVehiculoRepository vehiculoRepo;
  late _MockViajeRepository viajeRepo;
  late _MockRentabilidadRepository rentabilidadRepo;
  late _MockHitoRepository hitoRepo;
  late _MockCostoViajeRepository costoViajeRepo;
  late _MockMetricasRepository metricasRepo;
  late _MockNotificacionRepository notificacionRepo;
  late StreamController<Sesion?> streamSesion;

  AuthCubit crear() => AuthCubit(
    iniciarSesion: IniciarSesionUseCase(repo),
    iniciarConGoogle: IniciarConGoogleUseCase(repo),
    registrarse: RegistrarseUseCase(repo),
    cerrarSesion: CerrarSesionUseCase(repo),
    observarSesion: ObservarSesionUseCase(repo),
    recuperarPassword: RecuperarPasswordUseCase(repo),
  );

  setUp(() {
    repo = _MockAuthRepository();
    streamSesion = StreamController<Sesion?>.broadcast();
    when(() => repo.observarSesion()).thenAnswer((_) => streamSesion.stream);

    // AnaliticaPage (vista inicial del admin) carga estos datos al montar.
    vehiculoRepo = _MockVehiculoRepository();
    viajeRepo = _MockViajeRepository();
    rentabilidadRepo = _MockRentabilidadRepository();
    // ConductorInicioPage (vista inicial del conductor) también carga el
    // viaje activo propio al montar; sin viajes activos, no llega a pedir
    // hitos ni costos, pero los repos deben existir en el árbol de widgets.
    hitoRepo = _MockHitoRepository();
    costoViajeRepo = _MockCostoViajeRepository();
    metricasRepo = _MockMetricasRepository();
    notificacionRepo = _MockNotificacionRepository();
    registerFallbackValue(DimensionMetrica.ruta);
    when(
      () => metricasRepo.periodo(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer(
      (_) async => const MetricasPeriodo(
        viajesCerrados: 0,
        kmTotal: 0,
        costosDirectos: 0,
        viajesATiempo: 0,
        viajesMedidos: 0,
        utilizacionFlotaPct: 0,
      ),
    );
    when(
      () => metricasRepo.porDimension(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        dimension: any(named: 'dimension'),
      ),
    ).thenAnswer((_) async => const <MetricaDimension>[]);
    when(
      () => notificacionRepo.listar(
        pagina: 0,
        tamano: any(named: 'tamano'),
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        soloNoLeidas: any(named: 'soloNoLeidas'),
      ),
    ).thenAnswer(
      (_) async =>
          const PaginaNotificaciones(notificaciones: [], hayMas: false),
    );
    when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaVehiculos(vehiculos: [], hayMas: false),
    );
    when(() => viajeRepo.listarActivos())
        .thenAnswer((_) async => const <ViajeResumen>[]);
    when(
      () => rentabilidadRepo.consolidada(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer(
      (_) async => const RentabilidadConsolidada(
        totalFlete: 0,
        totalCostosDirectos: 0,
        mantenimientoAmortizado: 0,
        sueldoFijoProrrateado: 0,
        rentabilidadConsolidada: 0,
        viajesIncluidos: 0,
      ),
    );
  });

  tearDown(() => streamSesion.close());

  Future<void> montar(WidgetTester tester, AuthCubit cubit) {
    return tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ClienteRepository>.value(
            value: _MockClienteRepository(),
          ),
          RepositoryProvider<ConductorRepository>.value(
            value: _MockConductorRepository(),
          ),
          RepositoryProvider<VehiculoRepository>.value(value: vehiculoRepo),
          RepositoryProvider<ViajeRepository>.value(value: viajeRepo),
          RepositoryProvider<ServicioUbicacion>.value(
            value: _MockServicioUbicacion(),
          ),
          RepositoryProvider<RentabilidadRepository>.value(
            value: rentabilidadRepo,
          ),
          RepositoryProvider<MetricasRepository>.value(value: metricasRepo),
          RepositoryProvider<NotificacionRepository>.value(
            value: notificacionRepo,
          ),
          RepositoryProvider<MonitorRutaRegistro>.value(
            value: MonitorRutaRegistro(
              ubicacion: _MockServicioUbicacion(),
              viajes: viajeRepo,
              ubicaciones: _MockUbicacionViajeRepository(),
              pausaActiva: _MockPausaActivaRepository(),
            ),
          ),
          RepositoryProvider<HitoRepository>.value(value: hitoRepo),
          RepositoryProvider<CombustibleRepository>.value(
            value: _MockCombustibleRepository(),
          ),
          RepositoryProvider<CostoViajeRepository>.value(value: costoViajeRepo),
          RepositoryProvider<ChecklistRepository>.value(
            value: const SinChecklistRepository(),
          ),
        ],
        child: BlocProvider<AuthCubit>.value(
          value: cubit,
          child: const MaterialApp(home: AuthGate()),
        ),
      ),
    );
  }

  testWidgets('usuario ADMINISTRADOR ve la home de administrador', (
    tester,
  ) async {
    final AuthCubit cubit = crear();
    addTearDown(cubit.close);

    await montar(tester, cubit);
    streamSesion.add(const Sesion(usuario: _admin));
    await tester.pumpAndSettle();

    expect(find.text('Viajes en curso'), findsWidgets);
    expect(find.text('Hoy no tienes viaje asignado'), findsNothing);
  });

  testWidgets('usuario CONDUCTOR ve la home de conductor', (tester) async {
    final AuthCubit cubit = crear();
    addTearDown(cubit.close);

    await montar(tester, cubit);
    streamSesion.add(const Sesion(usuario: _conductor));
    await tester.pumpAndSettle();

    expect(find.text('Hoy no tienes viaje asignado'), findsOneWidget);
    expect(find.text('Viajes en curso'), findsNothing);
  });
}
