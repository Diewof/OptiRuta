import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/autenticacion/domain/entities/rol_usuario.dart';
import '../../features/autenticacion/domain/entities/usuario.dart';
import '../../features/autenticacion/presentation/bloc/auth_cubit.dart';
import '../../features/autenticacion/presentation/bloc/auth_state.dart';
import '../../features/autenticacion/presentation/pages/home_admin_page.dart';
import '../../features/autenticacion/presentation/pages/home_conductor_page.dart';
import '../../features/autenticacion/presentation/pages/login_page.dart';
import '../../features/autenticacion/presentation/pages/perfil_admin_page.dart';
import '../../features/autenticacion/presentation/pages/recuperar_password_page.dart';
import '../../features/autenticacion/presentation/pages/registro_page.dart';
import '../../features/clientes/presentation/pages/clientes_list_page.dart';
import '../../features/conductores/presentation/pages/conductores_list_page.dart';
import '../../features/dashboard/presentation/pages/analitica_page.dart';
import '../../features/notificaciones/presentation/pages/notificaciones_page.dart';
import '../../features/reportes/presentation/pages/reportes_page.dart';
import '../../features/satisfaccion/presentation/pages/satisfaccion_page.dart';
import '../../features/tarifas/presentation/pages/tarifas_page.dart';
import '../../features/vehiculos/presentation/pages/vehiculos_list_page.dart';
import '../../features/viajes/presentation/pages/calendario_page.dart';
import '../../features/viajes/presentation/pages/conductor_historial_page.dart';
import '../../features/viajes/presentation/pages/conductor_inicio_page.dart';
import '../../features/viajes/presentation/pages/conductor_manual_page.dart';
import '../../features/viajes/presentation/pages/conductor_perfil_page.dart';
import '../../features/viajes/presentation/pages/seguimiento_page.dart';
import '../pages/work_in_progress_page.dart';

/// Rutas con nombre de la app. Navegación simple con `Navigator` (sin paquete
/// de routing mientras el alcance sea el diseño de autenticación).
///
/// [AuthGate] decide la home inicial directamente segun el rol del estado
/// autenticado (no navega por nombre). `homeAdmin`/`homeConductor` quedan
/// disponibles para volver a la home por nombre desde otras pantallas.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String registro = '/registro';
  static const String recuperarPassword = '/recuperar-password';
  static const String trabajoEnProgreso = '/trabajo-en-progreso';
  static const String homeAdmin = '/home-admin';
  static const String homeConductor = '/home-conductor';

  // Secciones de nivel superior del Administrador (barra inferior de 5). Cada una vuelve
  // a resolver la sesión actual (deny-by-default) en vez de recibir el
  // usuario como argumento de ruta, igual que `homeAdmin`/`homeConductor`.
  static const String adminPerfil = '/admin/perfil';
  static const String adminAnalitica = '/admin/analitica';
  static const String adminSatisfaccion = '/admin/satisfaccion';
  static const String adminCalendario = '/admin/calendario';
  static const String adminSeguimiento = '/admin/seguimiento';
  static const String adminConductores = '/admin/conductores';
  static const String adminClientes = '/admin/clientes';
  static const String adminFlota = '/admin/flota';
  static const String adminNotificaciones = '/admin/notificaciones';
  static const String adminTarifas = '/admin/tarifas';
  static const String adminReportes = '/admin/reportes';

  // Destinos de la barra de navegación inferior del Conductor. Igual que las
  // secciones de administrador, cada una vuelve a resolver la sesión actual
  // en vez de recibir el usuario como argumento de ruta.
  static const String conductorInicio = '/conductor/inicio';
  static const String conductorHistorial = '/conductor/historial';
  static const String conductorManual = '/conductor/manual';
  static const String conductorPerfil = '/conductor/perfil';

  static Map<String, WidgetBuilder> get map => <String, WidgetBuilder>{
    login: (_) => const LoginPage(),
    registro: (_) => const RegistroPage(),
    recuperarPassword: (_) => const RecuperarPasswordPage(),
    trabajoEnProgreso: (_) => const WorkInProgressPage(),
    homeAdmin: (BuildContext context) =>
        _homeSegunSesion(context, (usuario) => HomeAdminPage(usuario: usuario)),
    homeConductor: (BuildContext context) => _homeSegunSesion(
      context,
      (usuario) => HomeConductorPage(usuario: usuario),
    ),
    adminPerfil: (BuildContext context) => _adminSegunSesion(
      context,
      (usuario) => PerfilAdminPage(usuario: usuario),
    ),
    adminAnalitica: (BuildContext context) => _adminSegunSesion(
      context,
      (usuario) => AnaliticaPage(usuario: usuario),
    ),
    adminSatisfaccion: (BuildContext context) => _adminSegunSesion(
      context,
      (usuario) => SatisfaccionPage(usuario: usuario),
    ),
    adminCalendario: (BuildContext context) => _adminSegunSesion(
      context,
      (usuario) => CalendarioPage(usuario: usuario),
    ),
    adminSeguimiento: (BuildContext context) => _adminSegunSesion(
      context,
      (usuario) => SeguimientoPage(usuario: usuario),
    ),
    adminConductores: (BuildContext context) => _adminSegunSesion(
      context,
      (usuario) => ConductoresListPage(usuario: usuario),
    ),
    adminClientes: (BuildContext context) => _adminSegunSesion(
      context,
      (usuario) => ClientesListPage(esAdministrador: true, usuario: usuario),
    ),
    adminFlota: (BuildContext context) => _adminSegunSesion(
      context,
      (usuario) => VehiculosListPage(usuario: usuario),
    ),
    adminNotificaciones: (BuildContext context) => _adminSegunSesion(
      context,
      (usuario) => NotificacionesPage(usuario: usuario),
    ),
    adminTarifas: (BuildContext context) =>
        _adminSegunSesion(context, (usuario) => TarifasPage(usuario: usuario)),
    adminReportes: (BuildContext context) =>
        _adminSegunSesion(context, (usuario) => ReportesPage(usuario: usuario)),
    conductorInicio: (BuildContext context) => _conductorSegunSesion(
      context,
      (usuario) => ConductorInicioPage(usuario: usuario),
    ),
    conductorHistorial: (BuildContext context) => _conductorSegunSesion(
      context,
      (usuario) => ConductorHistorialPage(usuario: usuario),
    ),
    conductorManual: (BuildContext context) => _conductorSegunSesion(
      context,
      (usuario) => ConductorManualPage(usuario: usuario),
    ),
    conductorPerfil: (BuildContext context) => _conductorSegunSesion(
      context,
      (usuario) => ConductorPerfilPage(usuario: usuario),
    ),
  };

  /// Construye la home a partir de la sesion actual del [AuthCubit]. Si no
  /// hay sesion autenticada (ruta empujada fuera de flujo), cae al login:
  /// denegar por defecto tambien en la navegacion por nombre.
  static Widget _homeSegunSesion(
    BuildContext context,
    Widget Function(Usuario usuario) construir,
  ) {
    final AuthState estado = context.read<AuthCubit>().state;
    return estado is AuthAutenticado
        ? construir(estado.usuario)
        : const LoginPage();
  }

  /// Igual que [_homeSegunSesion], pero además exige rol ADMINISTRADOR: estas
  /// rutas son destinos de la barra inferior del administrador. RLS es la defensa real;
  /// esto solo evita construir la pantalla equivocada del lado del cliente.
  static Widget _adminSegunSesion(
    BuildContext context,
    Widget Function(Usuario usuario) construir,
  ) {
    final AuthState estado = context.read<AuthCubit>().state;
    return estado is AuthAutenticado &&
            estado.usuario.rol == RolUsuario.administrador
        ? construir(estado.usuario)
        : const LoginPage();
  }

  /// Igual que [_adminSegunSesion], pero exige rol CONDUCTOR: estas rutas
  /// son los destinos de la barra de navegación inferior del conductor.
  static Widget _conductorSegunSesion(
    BuildContext context,
    Widget Function(Usuario usuario) construir,
  ) {
    final AuthState estado = context.read<AuthCubit>().state;
    return estado is AuthAutenticado &&
            estado.usuario.rol == RolUsuario.conductor
        ? construir(estado.usuario)
        : const LoginPage();
  }
}
