import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/core/widgets/app_text_field.dart';

import 'package:optiruta/features/clientes/domain/entities/cliente.dart';
import 'package:optiruta/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:optiruta/features/conductores/domain/entities/conductor.dart';
import 'package:optiruta/features/conductores/domain/entities/tipo_pago.dart';
import 'package:optiruta/features/conductores/domain/repositories/conductor_repository.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/hoja_vida_repository.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/vehiculo_repository.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/lugar.dart';
import 'package:optiruta/features/viajes/domain/entities/ruta_estimada.dart';
import 'package:optiruta/features/viajes/domain/repositories/ruta_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/presentation/pages/agendar_viaje_page.dart';

class _MockClienteRepository extends Mock implements ClienteRepository {}

class _MockVehiculoRepository extends Mock implements VehiculoRepository {}

class _MockConductorRepository extends Mock implements ConductorRepository {}

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockHojaVidaRepository extends Mock implements HojaVidaRepository {}

class _MockRutaRepository extends Mock implements RutaRepository {}

const Coordenada _bogota = Coordenada(4.711, -74.0721);
const Coordenada _barranquilla = Coordenada(10.9685, -74.7813);

/// Abre el selector del siguiente campo vacío, busca [consulta], elige [resultado] y
/// confirma.
Future<void> _elegirUbicacion(
  WidgetTester tester,
  String consulta,
  String resultado,
) async {
  // El campo ya elegido deja de mostrar el marcador, así que el primero que
  // lo muestra es el que toca elegir ahora.
  final Finder vacio = find.text('Buscar o elegir en el mapa').first;
  await tester.ensureVisible(vacio);
  await tester.pumpAndSettle();
  await tester.tap(vacio);
  await tester.pumpAndSettle();
  expect(find.text('Confirmar ubicación'), findsOneWidget);
  await tester.enterText(find.byType(TextField).last, consulta);
  // El buscador espera 400 ms sin teclear antes de consultar.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
  await tester.tap(find.text(resultado));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirmar ubicación'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(_bogota));

  testWidgets('muestra el formulario con el botón de calcular ruta', (
    WidgetTester tester,
  ) async {
    final clienteRepo = _MockClienteRepository();
    final vehiculoRepo = _MockVehiculoRepository();
    final conductorRepo = _MockConductorRepository();
    final viajeRepo = _MockViajeRepository();
    final rutaRepo = _MockRutaRepository();

    when(() => clienteRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaClientes(
        clientes: <Cliente>[
          Cliente(
            id: 'cli-1',
            nombre: 'Distribuidora Andina',
            documento: null,
            telefono: null,
            correo: null,
            direccion: null,
            activo: true,
          ),
        ],
        hayMas: false,
      ),
    );
    when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaVehiculos(
        vehiculos: <Vehiculo>[
          Vehiculo(
            id: 'veh-1',
            placa: 'UFH664',
            tipo: TipoVehiculo.dobleTroque,
            capacidadCarga: 17,
            rendimientoKmGalon: 9,
            activo: true,
          ),
        ],
        hayMas: false,
      ),
    );
    when(() => conductorRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => PaginaConductores(
        conductores: <Conductor>[
          Conductor(
            id: 'con-1',
            usuarioId: 'u-1',
            nombre: 'Camilo Rojas',
            documento: null,
            licencia: 'LIC-1',
            fechaVencimientoLicencia: DateTime(2030),
            tipoPago: TipoPago.comision,
            porcentajeComision: 10,
            sueldoBase: 0,
            activo: true,
          ),
        ],
        hayMas: false,
      ),
    );
    when(
      () => rutaRepo.estimar(
        origen: any(named: 'origen'),
        destino: any(named: 'destino'),
      ),
    ).thenAnswer(
      (_) async => const RutaEstimada(distanciaKm: 1012, duracionMin: 1080),
    );
    when(() => rutaRepo.buscarLugares('Bogotá')).thenAnswer(
      (_) async => const <Lugar>[
        Lugar(nombre: 'Bogotá, Cundinamarca', coordenada: _bogota),
      ],
    );
    when(() => rutaRepo.buscarLugares('Barranquilla')).thenAnswer(
      (_) async => const <Lugar>[
        Lugar(nombre: 'Barranquilla, Atlántico', coordenada: _barranquilla),
      ],
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ClienteRepository>.value(value: clienteRepo),
          RepositoryProvider<VehiculoRepository>.value(value: vehiculoRepo),
          RepositoryProvider<ConductorRepository>.value(value: conductorRepo),
          RepositoryProvider<ViajeRepository>.value(value: viajeRepo),
          RepositoryProvider<HojaVidaRepository>.value(
            value: _MockHojaVidaRepository(),
          ),
          RepositoryProvider<RutaRepository>.value(value: rutaRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AgendarViajePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agendar viaje'), findsWidgets);
    expect(find.text('Calcular distancia y tiempo'), findsOneWidget);

    // Sin ubicaciones elegidas todavía no se puede calcular la ruta.
    expect(find.text('Buscar o elegir en el mapa'), findsNWidgets(2));

    await _elegirUbicacion(tester, 'Bogotá', 'Bogotá, Cundinamarca');
    expect(find.text('Bogotá, Cundinamarca'), findsOneWidget);
    // Con solo el origen no se calcula nada.
    verifyNever(
      () => rutaRepo.estimar(
        origen: any(named: 'origen'),
        destino: any(named: 'destino'),
      ),
    );

    await _elegirUbicacion(tester, 'Barranquilla', 'Barranquilla, Atlántico');

    // Al tener los dos puntos la ruta se calcula sola.
    verify(() => rutaRepo.estimar(origen: _bogota, destino: _barranquilla))
        .called(1);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.text('Distancia'), findsOneWidget);
    expect(find.text('1012 km'), findsOneWidget);
  });

  testWidgets('el asistente avanza por pasos y explica lo que falta', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final clienteRepo = _MockClienteRepository();
    final vehiculoRepo = _MockVehiculoRepository();
    final conductorRepo = _MockConductorRepository();
    final viajeRepo = _MockViajeRepository();
    final rutaRepo = _MockRutaRepository();

    when(() => clienteRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaClientes(
        clientes: <Cliente>[
          Cliente(
            id: 'cli-1',
            nombre: 'Distribuidora Andina',
            documento: null,
            telefono: null,
            correo: null,
            direccion: null,
            activo: true,
          ),
        ],
        hayMas: false,
      ),
    );
    when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async =>
          const PaginaVehiculos(vehiculos: <Vehiculo>[], hayMas: false),
    );
    when(() => conductorRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async =>
          const PaginaConductores(conductores: <Conductor>[], hayMas: false),
    );
    when(
      () => rutaRepo.estimar(
        origen: any(named: 'origen'),
        destino: any(named: 'destino'),
      ),
    ).thenAnswer(
      (_) async => const RutaEstimada(distanciaKm: 1012, duracionMin: 1080),
    );
    when(() => rutaRepo.buscarLugares('Bogotá')).thenAnswer(
      (_) async => const <Lugar>[
        Lugar(nombre: 'Bogotá, Cundinamarca', coordenada: _bogota),
      ],
    );
    when(() => rutaRepo.buscarLugares('Barranquilla')).thenAnswer(
      (_) async => const <Lugar>[
        Lugar(nombre: 'Barranquilla, Atlántico', coordenada: _barranquilla),
      ],
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<ClienteRepository>.value(value: clienteRepo),
          RepositoryProvider<VehiculoRepository>.value(value: vehiculoRepo),
          RepositoryProvider<ConductorRepository>.value(value: conductorRepo),
          RepositoryProvider<ViajeRepository>.value(value: viajeRepo),
          RepositoryProvider<HojaVidaRepository>.value(
            value: _MockHojaVidaRepository(),
          ),
          RepositoryProvider<RutaRepository>.value(value: rutaRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AgendarViajePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Paso 1 incompleto: no deja avanzar y dice por qué.
    expect(find.text('1. Ruta y carga'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Completa cliente, origen, destino, carga y flete.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Seleccionar cliente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distribuidora Andina'));
    await tester.pumpAndSettle();
    await _elegirUbicacion(tester, 'Bogotá', 'Bogotá, Cundinamarca');
    await _elegirUbicacion(tester, 'Barranquilla', 'Barranquilla, Atlántico');
    await tester.enterText(
      find.descendant(
        of: find.byType(AppTextField).at(0),
        matching: find.byType(TextField),
      ),
      '17',
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(AppTextField).at(1),
        matching: find.byType(TextField),
      ),
      '18500000',
    );

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    // Paso 2: nada preseleccionado, fecha y hora hay que elegirlas.
    expect(find.text('Elegir fecha'), findsOneWidget);
    expect(find.text('Elegir hora'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Elige la fecha y la hora de salida.'), findsOneWidget);

    // Volver conserva lo capturado.
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text('Distribuidora Andina'), findsOneWidget);
    expect(find.text('Bogotá, Cundinamarca'), findsOneWidget);
  });
}
