import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/routing/admin_shell.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/notificaciones/domain/entities/notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/entities/tipo_notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/repositories/notificacion_repository.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/vehiculo_repository.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';

class _MockVehiculoRepository extends Mock implements VehiculoRepository {}

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockNotificacionRepository extends Mock
    implements NotificacionRepository {}

const Usuario _admin = Usuario(
  id: 'u-1',
  nombre: 'Ana Admin',
  rol: RolUsuario.administrador,
  activo: true,
);

ViajeResumen _viaje(String id, String origen, String placa) => ViajeResumen(
  id: id,
  remision: 'REM-$id',
  origen: origen,
  destino: 'Cali',
  estado: EstadoViaje.enCurso,
  placaVehiculo: placa,
  nombreConductor: 'Camilo Rojas',
  nombreCliente: 'Distribuidora Andina',
  fechaCreacion: DateTime.now(),
);

void main() {
  late _MockVehiculoRepository vehiculos;
  late _MockViajeRepository viajes;
  late _MockNotificacionRepository notificaciones;

  setUp(() {
    vehiculos = _MockVehiculoRepository();
    viajes = _MockViajeRepository();
    notificaciones = _MockNotificacionRepository();

    when(() => vehiculos.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaVehiculos(
        vehiculos: <Vehiculo>[
          Vehiculo(
            id: 'v-1',
            placa: 'UFH664',
            tipo: TipoVehiculo.dobleTroque,
            capacidadCarga: 17,
            rendimientoKmGalon: 9,
            activo: true,
          ),
          Vehiculo(
            id: 'v-2',
            placa: 'TPK320',
            tipo: TipoVehiculo.mula,
            capacidadCarga: 32,
            rendimientoKmGalon: 7,
            activo: true,
          ),
        ],
        hayMas: false,
      ),
    );
    when(() => viajes.listarActivos()).thenAnswer(
      (_) async => <ViajeResumen>[
        _viaje('1', 'Bogotá', 'UFH664'),
        _viaje('2', 'Medellín', 'TPK320'),
      ],
    );
    when(
      () => notificaciones.listar(
        pagina: any(named: 'pagina'),
        tamano: any(named: 'tamano'),
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        soloNoLeidas: any(named: 'soloNoLeidas'),
      ),
    ).thenAnswer(
      (_) async => PaginaNotificaciones(
        notificaciones: <Notificacion>[
          Notificacion(
            id: 'n-1',
            tipo: TipoNotificacion.desvioRuta,
            titulo: 'Desvío de ruta',
            mensaje: 'El conductor se desvió.',
            leida: false,
            fechaCreacion: DateTime.now(),
          ),
        ],
        hayMas: false,
      ),
    );
  });

  Future<void> montar(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<VehiculoRepository>.value(value: vehiculos),
          RepositoryProvider<ViajeRepository>.value(value: viajes),
          RepositoryProvider<NotificacionRepository>.value(
            value: notificaciones,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AdminShell(usuario: _admin),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Inicio muestra todos los viajes en curso, la flota y las alertas',
    (WidgetTester tester) async {
      await montar(tester);

      expect(find.text('Bogotá → Cali'), findsOneWidget);
      expect(find.text('Medellín → Cali'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget); // flota en ruta
      expect(find.text('1 alerta activa'), findsOneWidget);
      for (final String d in <String>[
        'Inicio',
        'Viajes',
        'Flota',
        'Personas',
        'Análisis',
      ]) {
        expect(find.text(d), findsWidgets);
      }
    },
  );

  testWidgets('la campana abre Notificaciones y la flecha vuelve a Inicio', (
    WidgetTester tester,
  ) async {
    await montar(tester);

    await tester.tap(find.byTooltip('Notificaciones, 1 sin leer'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Volver'), findsOneWidget);
    expect(find.byIcon(LucideIcons.bell), findsNothing);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Volver'), findsNothing);
    expect(find.text('Bogotá → Cali'), findsOneWidget);
  });

  testWidgets('volver a Inicio refresca sin mostrar el esqueleto', (
    WidgetTester tester,
  ) async {
    await montar(tester);
    clearInteractions(viajes);

    await tester.tap(find.byTooltip('Notificaciones, 1 sin leer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pump();

    // Mientras refresca, el contenido anterior sigue en pantalla.
    expect(find.text('Bogotá → Cali'), findsOneWidget);
    await tester.pumpAndSettle();
    verify(() => viajes.listarActivos()).called(1);
  });
}
