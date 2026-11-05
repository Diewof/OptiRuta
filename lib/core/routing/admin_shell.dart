import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/autenticacion/domain/entities/usuario.dart';
import '../../features/autenticacion/presentation/pages/perfil_admin_page.dart';
import '../../features/calidad/presentation/pages/calidad_page.dart';
import '../../features/clientes/presentation/pages/clientes_list_page.dart';
import '../../features/combustible/presentation/pages/combustible_page.dart';
import '../../features/conductores/presentation/pages/conductores_list_page.dart';
import '../../features/dashboard/presentation/pages/analitica_page.dart';
import '../../features/dashboard/presentation/pages/inicio_page.dart';
import '../../features/esperas/presentation/pages/esperas_page.dart';
import '../../features/notificaciones/domain/repositories/notificacion_repository.dart';
import '../../features/notificaciones/presentation/pages/notificaciones_page.dart';
import '../../features/reportes/presentation/pages/reportes_page.dart';
import '../../features/satisfaccion/presentation/pages/satisfaccion_page.dart';
import '../../features/tarifas/presentation/pages/tarifas_page.dart';
import '../../features/vehiculos/presentation/pages/vehiculos_list_page.dart';
import '../../features/viajes/presentation/pages/seguimiento_page.dart';
import '../../features/viajes/presentation/pages/viajes_page.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/admin_section.dart';
import '../widgets/admin_shell_scope.dart';

/// Armazón del Administrador: una sola barra inferior y las pantallas de cada
/// sección vivas entre cambios de pestaña (mes elegido, filtros, scroll). Cada
/// sección se construye la primera vez que se visita.
class AdminShell extends StatefulWidget {
  const AdminShell({
    required this.usuario,
    this.inicial = AdminSection.inicio,
    super.key,
  });

  final Usuario usuario;
  final AdminSection inicial;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const int _maxNoLeidas = 99;

  late final ValueNotifier<AdminSection> _actual = ValueNotifier<AdminSection>(
    widget.inicial,
  );
  final ValueNotifier<int> _noLeidas = ValueNotifier<int>(0);
  final Map<AdminSection, Widget> _paginas = <AdminSection, Widget>{};
  final Map<AdminDestino, AdminSection> _ultimaPorDestino =
      <AdminDestino, AdminSection>{};
  AdminSection? _previa;

  @override
  void initState() {
    super.initState();
    _abrir(widget.inicial);
    _refrescarNoLeidas();
  }

  @override
  void dispose() {
    _actual.dispose();
    _noLeidas.dispose();
    super.dispose();
  }

  void _abrir(AdminSection s) {
    _paginas.putIfAbsent(
      s,
      () => KeyedSubtree(
        key: ValueKey<AdminSection>(s),
        child: _construir(s, widget.usuario),
      ),
    );
    _ultimaPorDestino[s.destino] = s;
  }

  void _irA(AdminSection destino) {
    if (destino == _actual.value) return;
    setState(() {
      _previa = _actual.value;
      _abrir(destino);
      _actual.value = destino;
    });
    _refrescarNoLeidas();
  }

  void _volver() {
    final AdminSection? p = _previa;
    _irA(p == null || p == _actual.value ? AdminSection.inicio : p);
  }

  Future<void> _refrescarNoLeidas() async {
    try {
      final PaginaNotificaciones pagina = await context
          .read<NotificacionRepository>()
          .listar(pagina: 0, tamano: _maxNoLeidas, soloNoLeidas: true);
      if (mounted) _noLeidas.value = pagina.notificaciones.length;
    } on Object {
      // Sin contador la campana queda sin número; no es motivo para fallar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminSection actual = _actual.value;

    return AdminShellScope(
      irA: _irA,
      volver: _volver,
      puedeVolver: _previa != null,
      noLeidas: _noLeidas,
      actual: _actual,
      child: PopScope(
        canPop: actual == AdminSection.inicio,
        onPopInvokedWithResult: (bool pop, Object? _) {
          if (pop) return;
          if (actual == AdminSection.notificaciones) {
            _volver();
          } else {
            _irA(AdminSection.inicio);
          }
        },
        child: Scaffold(
          body: IndexedStack(
            index: actual.index,
            children: <Widget>[
              for (final AdminSection s in AdminSection.values)
                _paginas[s] ?? const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: AdminBarraInferior(
            actual: actual.destino,
            onSeleccionar: (AdminDestino d) {
              if (d == actual.destino) return;
              _irA(
                _ultimaPorDestino[d] ?? AdminSection.dePorRuta(d.rutaInicial)!,
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _construir(AdminSection s, Usuario u) => switch (s) {
    AdminSection.inicio => InicioPage(usuario: u),
    AdminSection.viajes => ViajesPage(usuario: u),
    AdminSection.seguimiento => SeguimientoPage(usuario: u),
    AdminSection.historial => HistorialPage(usuario: u),
    AdminSection.flota => VehiculosListPage(usuario: u),
    AdminSection.conductores => ConductoresListPage(usuario: u),
    AdminSection.clientes => ClientesListPage(
      esAdministrador: true,
      usuario: u,
    ),
    AdminSection.analitica => AnaliticaPage(usuario: u),
    AdminSection.satisfaccion => SatisfaccionPage(usuario: u),
    AdminSection.calidad => CalidadPage(usuario: u),
    AdminSection.combustible => CombustiblePage(usuario: u),
    AdminSection.esperas => EsperasPage(usuario: u),
    AdminSection.reportes => ReportesPage(usuario: u),
    AdminSection.perfil => PerfilAdminPage(usuario: u),
    AdminSection.notificaciones => NotificacionesPage(usuario: u),
    AdminSection.tarifas => TarifasPage(usuario: u),
  };
}
