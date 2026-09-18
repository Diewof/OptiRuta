import 'package:flutter/widgets.dart';

import '../../features/autenticacion/presentation/pages/login_page.dart';
import '../../features/autenticacion/presentation/pages/recuperar_password_page.dart';
import '../../features/autenticacion/presentation/pages/registro_page.dart';
import '../pages/work_in_progress_page.dart';

/// Rutas con nombre de la app. Navegación simple con `Navigator` (sin paquete
/// de routing mientras el alcance sea el diseño de autenticación).
abstract final class AppRoutes {
  static const String login = '/login';
  static const String registro = '/registro';
  static const String recuperarPassword = '/recuperar-password';
  static const String trabajoEnProgreso = '/trabajo-en-progreso';

  static Map<String, WidgetBuilder> get map => <String, WidgetBuilder>{
    login: (_) => const LoginPage(),
    registro: (_) => const RegistroPage(),
    recuperarPassword: (_) => const RecuperarPasswordPage(),
    trabajoEnProgreso: (_) => const WorkInProgressPage(),
  };
}
