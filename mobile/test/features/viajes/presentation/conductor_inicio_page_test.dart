import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/viajes/domain/entities/categoria_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/costo_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/fuente_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/hito.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_hito.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/costo_viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/hito_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/servicios/servicio_ubicacion.dart';
import 'package:optiruta/features/viajes/presentation/pages/conductor_inicio_page.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockHitoRepository extends Mock implements HitoRepository {}

class _MockCostoViajeRepository extends Mock implements CostoViajeRepository {}

const Usuario _usuario = Usuario(
  id: 'u-1',
  nombre: 'Carlos Conductor',
  rol: RolUsuario.conductor,
  activo: true,
);

final ViajeResumen _viaje = ViajeResumen(
  id: 'v-1',
  remision: 'REM-1',
  origen: 'Medellín',
  destino: 'Cartagena',
  estado: EstadoViaje.enCurso,
  placaVehiculo: 'SXK418',
  nombreConductor: 'Carlos Conductor',
  nombreCliente: 'Cementos del Norte',
  fechaCreacion: DateTime(2026, 10, 1),
  distanciaEstimada: 640,
  tiempoEstimadoMin: 690,
  tipoVehiculo: TipoVehiculo.dobleTroque,
);

const CostoViaje _acpm = CostoViaje(
  id: 'c-1',
  viajeId: 'v-1',
  categoria: CategoriaCosto.acpm,
  valorEstimado: 1840000,
  fuente: FuenteCosto.automatico,
);

class _MockServicioUbicacion extends Mock implements ServicioUbicacion {}

void main() {
  late _MockViajeRepository viajeRepo;
  late _MockHitoRepository hitoRepo;
  late _MockCostoViajeRepository costoRepo;
  late _MockServicioUbicacion ubicacion;
  late List<Hito> hitos;
  late List<CostoViaje> costos;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(TipoHito.salida);
    registerFallbackValue(const Coordenada(0, 0));
  });

  setUp(() {
    viajeRepo = _MockViajeRepository();
    hitoRepo = _MockHitoRepository();
    costoRepo = _MockCostoViajeRepository();
    ubicacion = _MockServicioUbicacion();
    when(() => ubicacion.solicitarPermiso())
        .thenAnswer((_) async => EstadoPermisoUbicacion.concedido);
    when(() => ubicacion.posicionActual())
        .thenAnswer((_) async => const Coordenada(0, 0));
    hitos = <Hito>[];
    costos = <CostoViaje>[_acpm];

    when(() => viajeRepo.listarActivos()).thenAnswer((_) async => [_viaje]);
    when(() => hitoRepo.listarPorViaje('v-1')).thenAnswer((_) async => hitos);
    when(() => costoRepo.listarPorViaje('v-1')).thenAnswer((_) async => costos);
    when(
      () => hitoRepo.registrar(
        viajeId: any(named: 'viajeId'),
        tipo: any(named: 'tipo'),
        fechaHora: any(named: 'fechaHora'),
      ),
    ).thenAnswer((Invocation i) async {
      final Hito h = Hito(
        id: 'h-${hitos.length}',
        viajeId: 'v-1',
        tipo: i.namedArguments[#tipo] as TipoHito,
        fechaHora: i.namedArguments[#fechaHora] as DateTime,
      );
      hitos = <Hito>[...hitos, h];
      return h;
    });
    // La salida pasa por viaje_iniciar (valida los 500 m en el servidor).
    when(
      () => viajeRepo.iniciar(
        viajeId: any(named: 'viajeId'),
        ubicacion: any(named: 'ubicacion'),
        fechaHora: any(named: 'fechaHora'),
      ),
    ).thenAnswer((Invocation i) async {
      hitos = <Hito>[
        ...hitos,
        Hito(
          id: 'h-${hitos.length}',
          viajeId: 'v-1',
          tipo: TipoHito.salida,
          fechaHora: i.namedArguments[#fechaHora] as DateTime,
        ),
      ];
      return Viaje(
        id: 'v-1',
        remision: 'REM-1',
        vehiculoId: 'veh-1',
        conductorId: 'con-1',
        clienteId: 'cli-1',
        origen: 'Bogotá',
        destino: 'Barranquilla',
        estado: EstadoViaje.enCurso,
        valorFlete: 1000,
        valorAnticipo: 0,
        saldoPendiente: 1000,
        fechaCreacion: DateTime(2026, 10, 10),
      );
    });
    when(
      () => costoRepo.actualizarValorReal(
        costoId: any(named: 'costoId'),
        valorReal: any(named: 'valorReal'),
      ),
    ).thenAnswer((Invocation i) async {
      costos = <CostoViaje>[
        CostoViaje(
          id: 'c-1',
          viajeId: 'v-1',
          categoria: CategoriaCosto.acpm,
          valorEstimado: 1840000,
          valorReal: i.namedArguments[#valorReal] as double,
          fuente: FuenteCosto.automatico,
        ),
      ];
      return costos.first;
    });
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ViajeRepository>.value(value: viajeRepo),
          RepositoryProvider<ServicioUbicacion>.value(value: ubicacion),
          RepositoryProvider<HitoRepository>.value(value: hitoRepo),
          RepositoryProvider<CostoViajeRepository>.value(value: costoRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ConductorInicioPage(usuario: _usuario),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el viaje activo: ruta estimada, hitos y costos', (
    WidgetTester tester,
  ) async {
    await montar(tester);

    expect(find.text('Hola, Carlos'), findsOneWidget);
    expect(find.text('Medellín'), findsOneWidget);
    expect(find.text('Cartagena'), findsOneWidget);
    expect(find.textContaining('640 km'), findsOneWidget);
    expect(find.text('Avance del viaje'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
    expect(find.text('Registrar salida'), findsOneWidget);
    // Estimado (no real) se distingue por el prefijo y la etiqueta.
    expect(find.text(r'≈ $1.840.000'), findsOneWidget);
    expect(find.text('Est.'), findsOneWidget);
    expect(find.text('Agregar real'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registrar un hito toma dos toques y avanza al siguiente', (
    WidgetTester tester,
  ) async {
    await montar(tester);

    await tester.tap(find.text('Registrar salida')); // toque 1
    await tester.pumpAndSettle();
    expect(find.text('Confirmar'), findsOneWidget);

    await tester.tap(find.text('Confirmar')); // toque 2
    await tester.pumpAndSettle();

    verify(
      () => viajeRepo.iniciar(
        viajeId: 'v-1',
        ubicacion: any(named: 'ubicacion'),
        fechaHora: any(named: 'fechaHora'),
      ),
    ).called(1);
    expect(find.text('Confirmar'), findsNothing);
    expect(find.text('Registrar llegada a cargue'), findsOneWidget);
    expect(find.text('Real'), findsOneWidget);
  });

  testWidgets('un error al registrar se explica dentro de la hoja', (
    WidgetTester tester,
  ) async {
    when(
      () => viajeRepo.iniciar(
        viajeId: any(named: 'viajeId'),
        ubicacion: any(named: 'ubicacion'),
        fechaHora: any(named: 'fechaHora'),
      ),
    ).thenThrow(CatalogoFailure.sinPermiso());
    await montar(tester);

    await tester.tap(find.text('Registrar salida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar'), findsOneWidget); // la hoja sigue abierta
    expect(find.byType(SnackBar), findsNothing);
    expect(hitos, isEmpty);
  });

  testWidgets('confirmar el valor real pasa de estimado a real', (
    WidgetTester tester,
  ) async {
    await montar(tester);

    await tester.ensureVisible(find.text('Agregar real'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar real'));
    await tester.pumpAndSettle();
    // Valor precargado y visiblemente automático.
    expect(
      find.text('Estimado por el sistema. Cámbialo por lo que pagaste.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '1950000');
    await tester.pump();
    expect(find.text('Este valor quedará como real.'), findsOneWidget);

    await tester.tap(find.text('Guardar como real'));
    await tester.pumpAndSettle();

    verify(
      () => costoRepo.actualizarValorReal(costoId: 'c-1', valorReal: 1950000),
    ).called(1);
    expect(find.text(r'$1.950.000'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
  });

  testWidgets('no guarda un valor real vacío', (WidgetTester tester) async {
    await montar(tester);

    await tester.ensureVisible(find.text('Agregar real'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar real'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Guardar como real'));
    await tester.pumpAndSettle();

    expect(
      find.text('Escribe el valor que pagaste para guardarlo.'),
      findsOneWidget,
    );
    verifyNever(
      () => costoRepo.actualizarValorReal(
        costoId: any(named: 'costoId'),
        valorReal: any(named: 'valorReal'),
      ),
    );
  });

  testWidgets('sin viaje asignado muestra el estado vacío con ilustración', (
    WidgetTester tester,
  ) async {
    when(() => viajeRepo.listarActivos()).thenAnswer((_) async => []);
    await montar(tester);

    expect(find.text('Hoy no tienes viaje asignado'), findsOneWidget);
    expect(find.text('Ver mis viajes anteriores'), findsOneWidget);
    expect(find.text('Registrar salida'), findsNothing);
  });

  testWidgets('si falla la carga ofrece reintentar', (
    WidgetTester tester,
  ) async {
    when(() => viajeRepo.listarActivos())
        .thenThrow(CatalogoFailure.sinPermiso());
    await montar(tester);

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Lo que registraste sigue guardado'), findsOneWidget);
  });
}
