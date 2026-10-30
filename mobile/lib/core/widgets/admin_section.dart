import '../routing/app_routes.dart';

/// Los 5 destinos de la barra inferior del Administrador. [cuenta] no está en
/// la barra: se llega desde la barra superior (perfil, notificaciones, tarifas).
enum AdminDestino {
  inicio('Inicio', AppRoutes.adminInicio),
  viajes('Viajes', AppRoutes.adminViajes),
  flota('Flota', AppRoutes.adminFlota),
  personas('Personas', AppRoutes.adminConductores),
  analisis('Análisis', AppRoutes.adminAnalitica),
  cuenta('Cuenta', AppRoutes.adminPerfil, enBarra: false);

  const AdminDestino(this.etiqueta, this.rutaInicial, {this.enBarra = true});

  final String etiqueta;
  final bool enBarra;

  /// Pantalla a la que lleva el destino al tocarlo por primera vez.
  final String rutaInicial;
}

/// Pantallas de nivel superior del panel de Administrador. Cada una pertenece
/// a un [AdminDestino]; las de un mismo destino se alternan con la
/// sub-navegación (p. ej. Análisis: Costos ↔ Calidad).
enum AdminSection {
  inicio(AdminDestino.inicio, 'Inicio', AppRoutes.adminInicio),
  viajes(AdminDestino.viajes, 'Viajes', AppRoutes.adminViajes),
  seguimiento(AdminDestino.viajes, 'Seguimiento', AppRoutes.adminSeguimiento),
  historial(AdminDestino.viajes, 'Historial', AppRoutes.adminHistorial),
  flota(AdminDestino.flota, 'Flota', AppRoutes.adminFlota),
  conductores(AdminDestino.personas, 'Conductores', AppRoutes.adminConductores),
  clientes(AdminDestino.personas, 'Clientes', AppRoutes.adminClientes),
  analitica(AdminDestino.analisis, 'Costos', AppRoutes.adminAnalitica),
  satisfaccion(
    AdminDestino.analisis,
    'Satisfacción',
    AppRoutes.adminSatisfaccion,
  ),
  calidad(AdminDestino.analisis, 'Calidad', AppRoutes.adminCalidad),
  combustible(AdminDestino.analisis, 'Combustible', AppRoutes.adminCombustible),
  esperas(AdminDestino.analisis, 'Esperas', AppRoutes.adminEsperas),
  reportes(AdminDestino.analisis, 'Reportes', AppRoutes.adminReportes),
  perfil(AdminDestino.cuenta, 'Perfil', AppRoutes.adminPerfil),
  notificaciones(
    AdminDestino.cuenta,
    'Notificaciones',
    AppRoutes.adminNotificaciones,
  ),
  tarifas(AdminDestino.cuenta, 'Tarifas ACPM', AppRoutes.adminTarifas);

  const AdminSection(this.destino, this.etiqueta, this.ruta);

  final AdminDestino destino;
  final String etiqueta;
  final String ruta;

  /// Secciones hermanas dentro del mismo destino (para la sub-navegación).
  List<AdminSection> get hermanas => AdminSection.values
      .where((AdminSection s) => s.destino == destino)
      .toList();

  static AdminSection? dePorRuta(String ruta) {
    for (final AdminSection s in AdminSection.values) {
      if (s.ruta == ruta) return s;
    }
    return null;
  }
}
