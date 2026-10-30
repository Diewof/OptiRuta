import 'package:optiruta/core/widgets/chip_opcion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/notificaciones/domain/entities/notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/entities/tipo_notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/repositories/notificacion_repository.dart';
import 'package:optiruta/features/notificaciones/presentation/pages/notificaciones_page.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';

class _MockNotificacionRepository extends Mock
    implements NotificacionRepository {}

class _MockViajeRepository extends Mock implements ViajeRepository {}

const Usuario _admin = Usuario(
  id: 'u-1',
  nombre: 'Ana Admin',
  rol: RolUsuario.administrador,
  activo: true,
);

Notificacion _notificacion({
  required String id,
  required DateTime fechaCreacion,
  bool leida = false,
}) {
  return Notificacion(
    id: id,
    tipo: TipoNotificacion.viajeCompletado,
    titulo: 'Viaje completado',
    mensaje: 'Medellín → Cali llegó a destino.',
    leida: leida,
    fechaCreacion: fechaCreacion,
  );
}

void main() {
  late _MockNotificacionRepository repo;
  late _MockViajeRepository viajes;

  setUp(() {
    repo = _MockNotificacionRepository();
    viajes = _MockViajeRepository();
  });

  Future<void> montar(WidgetTester tester, List<Notificacion> filas) {
    when(
      () => repo.listar(
        pagina: any(named: 'pagina'),
        tamano: any(named: 'tamano'),
      ),
    ).thenAnswer(
      (_) async => PaginaNotificaciones(notificaciones: filas, hayMas: false),
    );

    return tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object>>[
          RepositoryProvider<NotificacionRepository>.value(value: repo),
          RepositoryProvider<ViajeRepository>.value(value: viajes),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificacionesPage(usuario: _admin),
        ),
      ),
    );
  }

  testWidgets('agrupa por Hoy y Ayer', (WidgetTester tester) async {
    final DateTime ahora = DateTime.now();
    await montar(tester, <Notificacion>[
      _notificacion(id: 'n-1', fechaCreacion: ahora),
      _notificacion(
        id: 'n-2',
        fechaCreacion: ahora.subtract(const Duration(days: 1)),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
  });

  testWidgets('muestra estado vacío cuando no hay notificaciones', (
    WidgetTester tester,
  ) async {
    await montar(tester, <Notificacion>[]);
    await tester.pumpAndSettle();

    expect(find.text('Sin notificaciones'), findsOneWidget);
  });

  testWidgets('tocar una notificacion no leida la marca como leida', (
    WidgetTester tester,
  ) async {
    when(() => repo.marcarLeida('n-1')).thenAnswer((_) async {});

    await montar(tester, <Notificacion>[
      _notificacion(id: 'n-1', fechaCreacion: DateTime.now()),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Viaje completado'));
    await tester.pumpAndSettle();

    verify(() => repo.marcarLeida('n-1')).called(1);
  });

  testWidgets('tocar una notificación común no consulta el viaje', (
    WidgetTester tester,
  ) async {
    when(() => repo.marcarLeida('n-1')).thenAnswer((_) async {});
    await montar(tester, <Notificacion>[
      _notificacion(id: 'n-1', fechaCreacion: DateTime.now()),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Viaje completado'));
    await tester.pumpAndSettle();

    verifyNever(() => viajes.obtenerResumen(any()));
  });

  testWidgets('tocar una alerta de ruta marca leída y busca su viaje', (
    WidgetTester tester,
  ) async {
    when(() => repo.marcarLeida('n-2')).thenAnswer((_) async {});
    when(() => viajes.obtenerResumen('v-1'))
        .thenThrow(CatalogoFailure.sinConexion());
    await montar(tester, <Notificacion>[
      Notificacion(
        id: 'n-2',
        tipo: TipoNotificacion.paradaProlongada,
        titulo: 'Parada prolongada',
        mensaje: 'Medellín → Cali: el conductor lleva mucho tiempo detenido.',
        leida: false,
        fechaCreacion: DateTime.now(),
        viajeId: 'v-1',
        ubicacion: const Coordenada(6.2, -75.5),
      ),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parada prolongada'));
    await tester.pumpAndSettle();

    verify(() => repo.marcarLeida('n-2')).called(1);
    verify(() => viajes.obtenerResumen('v-1')).called(1);
    // Si no se puede cargar el viaje se explica, sin romper la lista.
    expect(find.text(CatalogoFailure.sinConexion().mensaje), findsOneWidget);
  });

  testWidgets('marcar todas como leidas llama al repositorio y recarga', (
    WidgetTester tester,
  ) async {
    when(() => repo.marcarTodasLeidas()).thenAnswer((_) async {});

    await montar(tester, <Notificacion>[
      _notificacion(id: 'n-1', fechaCreacion: DateTime.now()),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marcar todas como leídas'));
    await tester.pumpAndSettle();

    verify(() => repo.marcarTodasLeidas()).called(1);
    verify(
      () => repo.listar(
        pagina: any(named: 'pagina'),
        tamano: any(named: 'tamano'),
      ),
    ).called(greaterThan(1));
  });

  testWidgets('los chips filtran la bandeja y la tarjeta anuncia su acción', (
    WidgetTester tester,
  ) async {
    await montar(tester, <Notificacion>[
      Notificacion(
        id: 'n-1',
        tipo: TipoNotificacion.mantenimientoVencido,
        titulo: 'Mantenimiento vencido',
        mensaje: 'UFH664 pasó el cambio de aceite.',
        leida: false,
        fechaCreacion: DateTime.now(),
      ),
      _notificacion(id: 'n-2', fechaCreacion: DateTime.now()),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Ver flota ›'), findsOneWidget);
    expect(find.text('Viaje completado'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChipOpcion, 'Flota'));
    await tester.pumpAndSettle();
    expect(find.text('Mantenimiento vencido'), findsOneWidget);
    expect(find.text('Viaje completado'), findsNothing);

    await tester.ensureVisible(find.widgetWithText(ChipOpcion, 'Clientes'));
    await tester.tap(find.widgetWithText(ChipOpcion, 'Clientes'));
    await tester.pumpAndSettle();
    expect(find.text('No hay notificaciones con este filtro.'), findsOneWidget);
  });
}
