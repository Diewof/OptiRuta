import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/autenticacion/presentation/pages/perfil_admin_page.dart';

void main() {
  testWidgets('muestra nombre, iniciales y datos reales del usuario', (
    WidgetTester tester,
  ) async {
    const Usuario usuario = Usuario(
      id: 'u-1',
      nombre: 'Ana Gómez',
      documento: '1234567',
      rol: RolUsuario.administrador,
      activo: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const PerfilAdminPage(usuario: usuario),
      ),
    );

    expect(find.text('Ana Gómez'), findsWidgets);
    expect(find.text('AG'), findsOneWidget);
    expect(find.text('1234567'), findsOneWidget);
    expect(find.text('Administrador'), findsWidgets);
  });

  testWidgets('muestra "No registrado" cuando no hay documento', (
    WidgetTester tester,
  ) async {
    const Usuario usuario = Usuario(
      id: 'u-1',
      nombre: 'Ana',
      rol: RolUsuario.administrador,
      activo: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const PerfilAdminPage(usuario: usuario),
      ),
    );

    expect(find.text('No registrado'), findsOneWidget);
  });
}
