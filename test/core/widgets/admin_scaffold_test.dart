import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:optiruta/core/routing/app_routes.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/core/widgets/admin_scaffold.dart';
import 'package:optiruta/core/widgets/admin_section.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';

const Usuario _admin = Usuario(
  id: 'u-1',
  nombre: 'Ana Admin',
  rol: RolUsuario.administrador,
  activo: true,
);

Widget _envolver(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    home: home,
    routes: <String, WidgetBuilder>{
      for (final String ruta in <String>[
        AppRoutes.adminAnalitica,
        AppRoutes.adminSatisfaccion,
        AppRoutes.adminViajes,
        AppRoutes.adminHistorial,
        AppRoutes.adminSeguimiento,
        AppRoutes.adminFlota,
        AppRoutes.adminConductores,
        AppRoutes.adminClientes,
        AppRoutes.adminPerfil,
        AppRoutes.adminNotificaciones,
      ])
        ruta: (_) => Scaffold(body: Text('Destino $ruta')),
    },
  );
}

void main() {
  testWidgets('muestra el título y los 5 destinos de la barra inferior', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        const AdminScaffold(
          titulo: 'Panel de análisis',
          seccionActual: AdminSection.analitica,
          usuario: _admin,
          body: SizedBox.shrink(),
        ),
      ),
    );

    for (final String d in <String>[
      'Inicio',
      'Viajes',
      'Flota',
      'Personas',
      'Análisis',
    ]) {
      expect(find.text(d), findsOneWidget);
    }
    // Análisis tiene 6 secciones: se elige desde un selector, no en pestañas.
    expect(find.text('Costos'), findsOneWidget);
    expect(find.text('Satisfacción'), findsNothing);
    expect(find.text('6 secciones'), findsOneWidget);
    expect(find.text('Seguimiento'), findsNothing);
  });

  testWidgets('tocar un destino abre su pantalla inicial', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        const AdminScaffold(
          titulo: 'Panel de análisis',
          seccionActual: AdminSection.analitica,
          usuario: _admin,
          body: SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.text('Flota'));
    await tester.pumpAndSettle();

    expect(find.text('Destino ${AppRoutes.adminFlota}'), findsOneWidget);
  });

  testWidgets(
    'Viajes alterna Viajes, Seguimiento e Historial con la sub-navegación',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _envolver(
          const AdminScaffold(
            titulo: 'Viajes',
            seccionActual: AdminSection.viajes,
            usuario: _admin,
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('Seguimiento'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);

      await tester.tap(find.text('Seguimiento'));
      await tester.pumpAndSettle();

      expect(
        find.text('Destino ${AppRoutes.adminSeguimiento}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Análisis cambia de sección desde el selector', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        const AdminScaffold(
          titulo: 'Panel de análisis',
          seccionActual: AdminSection.analitica,
          usuario: _admin,
          body: SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.text('6 secciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satisfacción'));
    await tester.pumpAndSettle();

    expect(find.text('Destino ${AppRoutes.adminSatisfaccion}'), findsOneWidget);
  });

  testWidgets('no muestra la campana en la propia pantalla de notificaciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        const AdminScaffold(
          titulo: 'Notificaciones',
          seccionActual: AdminSection.notificaciones,
          usuario: _admin,
          body: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.bell), findsNothing);
  });

  testWidgets('muestra el contador de notificaciones sin leer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _envolver(
        const AdminScaffold(
          titulo: 'Panel de análisis',
          seccionActual: AdminSection.analitica,
          usuario: _admin,
          notificacionesNoLeidas: 3,
          body: SizedBox.shrink(),
        ),
      ),
    );

    // Solo la campana lleva el contador: «Más» no promete nada ambiguo.
    expect(find.text('3'), findsOneWidget);
  });
}
