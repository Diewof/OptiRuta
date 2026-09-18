import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/features/autenticacion/domain/entities/sesion.dart';
import 'package:optiruta/features/autenticacion/domain/repositories/auth_repository.dart';
import 'package:optiruta/main.dart';

/// Doble sin backend: no hay sesion, asi que `AuthGate` debe mostrar el login.
class _AuthRepositoryFalso implements AuthRepository {
  @override
  Stream<Sesion?> observarSesion() => Stream<Sesion?>.value(null);

  @override
  Future<Sesion?> sesionActual() async => null;

  @override
  Future<Sesion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) => throw UnimplementedError();

  @override
  Future<Sesion?> registrarse({
    required String nombre,
    required String correo,
    required String contrasena,
  }) => throw UnimplementedError();

  @override
  Future<void> enviarRecuperacion({required String correo}) async {}

  @override
  Future<void> cerrarSesion() async {}
}

void main() {
  testWidgets('sin sesion, la app muestra la pantalla de inicio de sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      OptiRutaApp(authRepository: _AuthRepositoryFalso()),
    );
    await tester.pump();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
