import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:optiruta/features/satisfaccion/domain/repositories/satisfaccion_repository.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/viajes/domain/entities/ajuste_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/categoria_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/costo_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/fuente_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/hito.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_marginal.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_hito.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/ajuste_viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/costo_viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/hito_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/rentabilidad_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/presentation/pages/viaje_detalle_page.dart';

import '../../checklist/sin_checklist_repository.dart';

class _MockViaje extends Mock implements ViajeRepository {}

class _MockHito extends Mock implements HitoRepository {}

class _MockCosto extends Mock implements CostoViajeRepository {}

class _MockRenta extends Mock implements RentabilidadRepository {}

class _MockAjuste extends Mock implements AjusteViajeRepository {}

class _MockSatisfaccion extends Mock implements SatisfaccionRepository {}

ViajeResumen _viaje(EstadoViaje e) => ViajeResumen(
  id: 'v-1',
  remision: 'REM-9',
  origen: 'Medellín',
  destino: 'Cartagena',
  estado: e,
  placaVehiculo: 'SPH092',
  nombreConductor: 'Camilo P.',
  nombreCliente: 'Cementos del Norte',
  fechaCreacion: DateTime(2026, 10, 1),
  distanciaEstimada: 640,
  tiempoEstimadoMin: 690,
  tipoVehiculo: TipoVehiculo.mula,
);

Viaje _cerrado() => Viaje(
  id: 'v-1',
  remision: 'REM-9',
  vehiculoId: 'x',
  conductorId: 'y',
  clienteId: 'z',
  origen: 'Medellín',
  destino: 'Cartagena',
  estado: EstadoViaje.cerrado,
  valorFlete: 9800000,
  valorAnticipo: 0,
  saldoPendiente: 9800000,
  fechaCreacion: DateTime(2026, 10, 1),
);

const CostoViaje _acpm = CostoViaje(
  id: 'c1',
  viajeId: 'v-1',
  categoria: CategoriaCosto.acpm,
  valorEstimado: 3050000,
  valorReal: 3210000,
  fuente: FuenteCosto.manual,
);
const CostoViaje _peaje = CostoViaje(
  id: 'c2',
  viajeId: 'v-1',
  categoria: CategoriaCosto.peaje,
  valorEstimado: 1180000,
  fuente: FuenteCosto.automatico,
);
const CostoViaje _mantenimiento = CostoViaje(
  id: 'c3',
  viajeId: 'v-1',
  categoria: CategoriaCosto.mantenimientoAmortizado,
  valorEstimado: 900000,
  fuente: FuenteCosto.automatico,
);

void main() {
  late _MockViaje viajeRepo;
  late _MockHito hitoRepo;
  late _MockCosto costoRepo;
  late _MockRenta rentaRepo;
  late _MockAjuste ajusteRepo;
  late _MockSatisfaccion satisfaccionRepo;
  late List<AjusteViaje> ajustes;

  setUp(() {
    viajeRepo = _MockViaje();
    hitoRepo = _MockHito();
    costoRepo = _MockCosto();
    rentaRepo = _MockRenta();
    ajusteRepo = _MockAjuste();
    satisfaccionRepo = _MockSatisfaccion();
    when(() => satisfaccionRepo.encuestaDeViaje(any()))
        .thenAnswer((_) async => null);
    ajustes = <AjusteViaje>[];

    when(() => hitoRepo.listarPorViaje('v-1')).thenAnswer(
      (_) async => <Hito>[
        Hito(
          id: 'h1',
          viajeId: 'v-1',
          tipo: TipoHito.salida,
          fechaHora: DateTime(2026, 10, 7, 5, 42),
        ),
      ],
    );
    when(() => costoRepo.listarPorViaje('v-1')).thenAnswer(
      (_) async => const <CostoViaje>[_acpm, _peaje, _mantenimiento],
    );
    when(() => rentaRepo.marginal('v-1')).thenAnswer(
      (_) async => const RentabilidadMarginal(
        valorFlete: 9800000,
        costosTotales: 4390000,
        rentabilidad: 5410000,
      ),
    );
    when(() => ajusteRepo.listarPorViaje('v-1'))
        .thenAnswer((_) async => ajustes);
  });

  Future<void> montar(
    WidgetTester tester,
    EstadoViaje estado, {
    bool admin = true,
    double escala = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ViajeRepository>.value(value: viajeRepo),
          RepositoryProvider<HitoRepository>.value(value: hitoRepo),
          RepositoryProvider<CostoViajeRepository>.value(value: costoRepo),
          RepositoryProvider<RentabilidadRepository>.value(value: rentaRepo),
          RepositoryProvider<AjusteViajeRepository>.value(value: ajusteRepo),
          RepositoryProvider<SatisfaccionRepository>.value(
            value: satisfaccionRepo,
          ),
          RepositoryProvider<ChecklistRepository>.value(
            value: const SinChecklistRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (BuildContext c, Widget? w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: w!,
          ),
          home: ViajeDetallePage(viaje: _viaje(estado), puedeCerrar: admin),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra la rentabilidad marginal sin mantenimiento ni sueldo', (
    WidgetTester tester,
  ) async {
    await montar(tester, EstadoViaje.finalizado);

    expect(find.text('Viaje REM-9'), findsOneWidget);
    expect(find.text('Rentabilidad del viaje · marginal'), findsOneWidget);
    expect(find.text(r'$ 5,41 M'), findsOneWidget);
    expect(find.text('Margen 55,2 %'), findsOneWidget);
    expect(
      find.text('Parcial'),
      findsNWidgets(2),
    ); // chip de base + leyenda (peaje estimado)
    // El flete es un valor pactado, no un par estimado/real.
    expect(find.text('Pactado'), findsOneWidget);
    // El mantenimiento amortizado no aparece en el desglose del viaje.
    expect(find.text('Mantenimiento amortizado'), findsNothing);
    expect(find.text('GoPass · esperando'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('se apila al 130 % de texto sin desbordar', (
    WidgetTester tester,
  ) async {
    await montar(tester, EstadoViaje.finalizado, escala: 1.3);

    expect(find.text('Estimado vs. real'), findsOneWidget);
    expect(find.text('Estimado'), findsWidgets); // rótulos de la fila apilada
    expect(tester.takeException(), isNull);
  });

  testWidgets('cerrar pide confirmación, avisa lo estimado y cierra', (
    WidgetTester tester,
  ) async {
    when(() => viajeRepo.cerrar('v-1')).thenAnswer((_) async => _cerrado());
    await montar(tester, EstadoViaje.finalizado);

    await tester.tap(find.text('Cerrar viaje'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar el viaje REM-9?'), findsOneWidget);
    expect(find.textContaining('Un costo sigue estimado'), findsOneWidget);
    verifyNever(() => viajeRepo.cerrar(any()));

    await tester.tap(find.text('Cerrar viaje').last);
    await tester.pumpAndSettle();

    verify(() => viajeRepo.cerrar('v-1')).called(1);
    expect(find.text('Viaje REM-9 cerrado'), findsOneWidget);
    expect(find.textContaining('solo se corrige con ajustes'), findsOneWidget);

    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    // Ya cerrado: la acción pasa a ser registrar un ajuste.
    expect(find.text('Registrar ajuste'), findsOneWidget);
    expect(find.text('Cerrar viaje'), findsNothing);
  });

  testWidgets('un error al cerrar se explica en la hoja y permite reintentar', (
    WidgetTester tester,
  ) async {
    when(() => viajeRepo.cerrar('v-1')).thenThrow(CatalogoFailure.sinPermiso());
    await montar(tester, EstadoViaje.finalizado);

    await tester.tap(find.text('Cerrar viaje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar viaje').last);
    await tester.pumpAndSettle();

    expect(
      find.text('No tienes permiso para realizar esta acción.'),
      findsOneWidget,
    );
    expect(find.text('¿Cerrar el viaje REM-9?'), findsOneWidget);
  });

  testWidgets('el ajuste exige motivo y queda en el registro', (
    WidgetTester tester,
  ) async {
    when(
      () => ajusteRepo.registrar(
        viajeId: any(named: 'viajeId'),
        motivo: any(named: 'motivo'),
        campoModificado: any(named: 'campoModificado'),
        valorAnterior: any(named: 'valorAnterior'),
        valorNuevo: any(named: 'valorNuevo'),
      ),
    ).thenAnswer((Invocation i) async {
      final AjusteViaje a = AjusteViaje(
        id: 'a-1',
        viajeId: 'v-1',
        motivo: i.namedArguments[#motivo] as String,
        fecha: DateTime(2026, 10, 8, 15),
        campoModificado: i.namedArguments[#campoModificado] as String?,
        valorAnterior: i.namedArguments[#valorAnterior] as String?,
        valorNuevo: i.namedArguments[#valorNuevo] as String?,
      );
      ajustes = <AjusteViaje>[a];
      return a;
    });
    await montar(tester, EstadoViaje.cerrado);

    await tester.tap(find.text('Registrar ajuste'));
    await tester.pumpAndSettle();
    expect(find.text('Sin motivo no se puede guardar.'), findsOneWidget);

    // Sin motivo, el botón está deshabilitado.
    final Finder guardar = find.widgetWithText(
      ElevatedButton,
      'Guardar ajuste',
    );
    expect(tester.widget<ElevatedButton>(guardar).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '3300000');
    await tester.enterText(
      find.byType(TextField).last,
      'El recibo llegó con otro valor',
    );
    await tester.pump();
    expect(tester.widget<ElevatedButton>(guardar).onPressed, isNotNull);

    await tester.tap(guardar);
    await tester.pumpAndSettle();

    verify(
      () => ajusteRepo.registrar(
        viajeId: 'v-1',
        motivo: 'El recibo llegó con otro valor',
        campoModificado: 'ACPM',
        valorAnterior: r'$3.210.000',
        valorNuevo: '3300000',
      ),
    ).called(1);
    await tester.scrollUntilVisible(find.text('Ajustes registrados'), 300);
    expect(find.text('Ajustes registrados'), findsOneWidget);
    expect(find.textContaining('recibo llegó con otro valor'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ajustada'), -300);
    expect(find.text('Ajustada'), findsOneWidget);
  });

  testWidgets('quien no es administrador no ve cerrar ni ajustar', (
    WidgetTester tester,
  ) async {
    await montar(tester, EstadoViaje.finalizado, admin: false);

    expect(find.text('Cerrar viaje'), findsNothing);
    expect(find.text('Registrar ajuste'), findsNothing);
  });
}
