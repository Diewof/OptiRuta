import '../routing/app_routes.dart';

/// Los 5 destinos de la barra inferior del Administrador (rediseño v2).
enum AdminDestino {
  resumen('Resumen', AppRoutes.adminAnalitica),
  viajes('Viajes', AppRoutes.adminCalendario),
  flota('Flota', AppRoutes.adminFlota),
  personas('Personas', AppRoutes.adminConductores),
  mas('Más', AppRoutes.adminPerfil);

  const AdminDestino(this.etiqueta, this.rutaInicial);

  final String etiqueta;

  /// Pantalla a la que lleva el destino al tocarlo.
  final String rutaInicial;
}

/// Pantallas de nivel superior del panel de Administrador. Cada una pertenece
/// a un [AdminDestino]; las de un mismo destino se alternan con la
/// sub-navegación (p. ej. Viajes: Calendario ↔ Seguimiento).
enum AdminSection {
  analitica(AdminDestino.resumen, 'Costos', AppRoutes.adminAnalitica),
  satisfaccion(
    AdminDestino.resumen,
    'Satisfacción',
    AppRoutes.adminSatisfaccion,
  ),
  calendario(AdminDestino.viajes, 'Calendario', AppRoutes.adminCalendario),
  seguimiento(AdminDestino.viajes, 'Seguimiento', AppRoutes.adminSeguimiento),
  flota(AdminDestino.flota, 'Flota', AppRoutes.adminFlota),
  conductores(AdminDestino.personas, 'Conductores', AppRoutes.adminConductores),
  clientes(AdminDestino.personas, 'Clientes', AppRoutes.adminClientes),
  perfil(AdminDestino.mas, 'Perfil', AppRoutes.adminPerfil),
  notificaciones(
    AdminDestino.mas,
    'Notificaciones',
    AppRoutes.adminNotificaciones,
  ),
  tarifas(AdminDestino.mas, 'Tarifas ACPM', AppRoutes.adminTarifas),
  reportes(AdminDestino.mas, 'Reportes', AppRoutes.adminReportes);

  const AdminSection(this.destino, this.etiqueta, this.ruta);

  final AdminDestino destino;
  final String etiqueta;
  final String ruta;

  /// Secciones hermanas dentro del mismo destino (para la sub-navegación).
  List<AdminSection> get hermanas => AdminSection.values
      .where((AdminSection s) => s.destino == destino)
      .toList();
}
