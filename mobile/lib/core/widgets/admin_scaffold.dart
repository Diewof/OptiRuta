import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/autenticacion/domain/entities/usuario.dart';
import '../routing/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'admin_section.dart';
import 'admin_shell_scope.dart';
import 'brand_mark.dart';
import 'marca_icon.dart';

/// Armazón común de las pantallas de nivel superior del Administrador:
/// barra superior navy con franja roja de marca y campana de notificaciones,
/// sub-navegación entre pantallas hermanas del mismo destino y barra inferior
/// fija de 5 destinos (Resumen · Viajes · Flota · Personas · Más).
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    required this.titulo,
    required this.seccionActual,
    required this.usuario,
    required this.body,
    this.notificacionesNoLeidas = 0,
    this.mostrarCampana = true,
    this.floatingActionButton,
    super.key,
  });

  final String titulo;
  final AdminSection seccionActual;
  final Usuario usuario;
  final Widget body;
  final int notificacionesNoLeidas;
  final bool mostrarCampana;
  final Widget? floatingActionButton;

  void _ir(BuildContext context, AdminSection seccion) {
    final AdminShellScope? shell = AdminShellScope.maybeOf(context);
    if (shell != null) {
      shell.irA(seccion);
    } else {
      Navigator.of(context).pushReplacementNamed(seccion.ruta);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminSection> hermanas = seccionActual.hermanas;
    // Dentro del shell las pantallas se conservan vivas y la barra inferior
    // es única; fuera de él (pruebas, rutas sueltas) cada una trae la suya.
    final AdminShellScope? shell = AdminShellScope.maybeOf(context);
    final bool esNotificaciones = seccionActual == AdminSection.notificaciones;
    final bool puedeVolver =
        esNotificaciones &&
        (shell != null ? shell.puedeVolver : Navigator.of(context).canPop());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onNavy,
        automaticallyImplyLeading: false,
        leading: puedeVolver
            ? IconButton(
                tooltip: 'Volver',
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => shell != null
                    ? shell.volver()
                    : Navigator.of(context).maybePop(),
              )
            : null,
        titleSpacing: puedeVolver ? 0 : AppSpacing.x4,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const BrandMark(size: 28),
            const SizedBox(width: AppSpacing.x2),
            Flexible(
              child: Text(
                titulo,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.subtitle.copyWith(color: AppColors.onNavy),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (mostrarCampana && !esNotificaciones)
            shell == null
                ? _CampanaNotificaciones(
                    contador: notificacionesNoLeidas,
                    onPressed: () =>
                        Navigator.of(context)
                            .pushNamed(AppRoutes.adminNotificaciones),
                  )
                : ValueListenableBuilder<int>(
                    valueListenable: shell.noLeidas,
                    builder: (BuildContext _, int n, Widget? _) =>
                        _CampanaNotificaciones(
                          contador: n,
                          onPressed: () =>
                              shell.irA(AdminSection.notificaciones),
                        ),
                  ),
          if (shell != null && seccionActual.destino != AdminDestino.cuenta)
            IconButton(
              tooltip: 'Mi cuenta',
              icon: const Icon(LucideIcons.circleUser),
              onPressed: () => shell.irA(AdminSection.perfil),
            ),
          const SizedBox(width: AppSpacing.x1),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: ColoredBox(
            color: AppColors.brandRed,
            child: SizedBox(height: 2, width: double.infinity),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          if (hermanas.length > 1)
            _SubNavegacion(
              secciones: hermanas,
              actual: seccionActual,
              onSeleccionar: (AdminSection s) => _ir(context, s),
            ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: shell != null
          ? null
          : AdminBarraInferior(
              actual: seccionActual.destino,
              onSeleccionar: (AdminDestino d) {
                if (d != seccionActual.destino) {
                  Navigator.of(context).pushReplacementNamed(d.rutaInicial);
                }
              },
            ),
    );
  }
}

const int _maxSinDesplazar = 4;

/// Alterna entre pantallas hermanas (p. ej. Calendario | Seguimiento).
class _SubNavegacion extends StatelessWidget {
  const _SubNavegacion({
    required this.secciones,
    required this.actual,
    required this.onSeleccionar,
  });

  final List<AdminSection> secciones;
  final AdminSection actual;
  final ValueChanged<AdminSection> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    // Con muchas hermanas las pestañas no caben y esconderlas en un scroll
    // horizontal oculta opciones: se elige desde una lista.
    if (secciones.length > _maxSinDesplazar) {
      return _SelectorSeccion(
        secciones: secciones,
        actual: actual,
        onSeleccionar: onSeleccionar,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: AppColors.navyTint,
          borderRadius: AppRadius.mdAll,
        ),
        child: _FilaSubNavegacion(
          desplazable: secciones.length > _maxSinDesplazar,
          children: <Widget>[
            for (final AdminSection s in secciones)
              Semantics(
                button: true,
                selected: s == actual,
                label: s.etiqueta,
                excludeSemantics: true,
                onTap: () => s == actual ? null : onSeleccionar(s),
                child: Material(
                  color: s == actual ? AppColors.card : Colors.transparent,
                  borderRadius: AppRadius.smAll,
                  elevation: 0,
                  child: InkWell(
                    borderRadius: AppRadius.smAll,
                    onTap: s == actual ? null : () => onSeleccionar(s),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.etiqueta,
                        style: AppTypography.label.copyWith(
                          fontSize: 13,
                          fontWeight: s == actual
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: s == actual
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Selector de sección para destinos con más de [_maxSinDesplazar] pantallas.
class _SelectorSeccion extends StatelessWidget {
  const _SelectorSeccion({
    required this.secciones,
    required this.actual,
    required this.onSeleccionar,
  });

  final List<AdminSection> secciones;
  final AdminSection actual;
  final ValueChanged<AdminSection> onSeleccionar;

  Future<void> _abrir(BuildContext context) async {
    final AdminSection? elegida = await showModalBottomSheet<AdminSection>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final AdminSection s in secciones)
              ListTile(
                title: Text(s.etiqueta),
                trailing: s == actual
                    ? const Icon(LucideIcons.check, size: 20)
                    : null,
                selected: s == actual,
                onTap: () => Navigator.of(sheet).pop(s),
              ),
          ],
        ),
      ),
    );
    if (elegida != null && elegida != actual) onSeleccionar(elegida);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        0,
      ),
      child: Semantics(
        button: true,
        label: 'Sección: ${actual.etiqueta}. Cambiar sección',
        excludeSemantics: true,
        child: Material(
          color: AppColors.navyTint,
          borderRadius: AppRadius.mdAll,
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () => _abrir(context),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      actual.etiqueta,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${secciones.length} secciones',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  const Icon(LucideIcons.chevronsUpDown, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reparte las pestañas a partes iguales; con más de [_maxSinDesplazar] se
/// desplazan en horizontal para que ninguna etiqueta se corte.
class _FilaSubNavegacion extends StatelessWidget {
  const _FilaSubNavegacion({required this.desplazable, required this.children});

  final bool desplazable;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!desplazable) {
      return Row(
        children: <Widget>[for (final Widget c in children) Expanded(child: c)],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final Widget c in children)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
              child: c,
            ),
        ],
      ),
    );
  }
}

/// Barra inferior fija de los 5 destinos. Pública para que el shell la use.
class AdminBarraInferior extends StatelessWidget {
  const AdminBarraInferior({
    required this.actual,
    required this.onSeleccionar,
    super.key,
  });

  final AdminDestino actual;
  final ValueChanged<AdminDestino> onSeleccionar;

  static const Map<AdminDestino, MarcaIconos> _iconos =
      <AdminDestino, MarcaIconos>{
        AdminDestino.inicio: MarcaIconos.inicio,
        AdminDestino.viajes: MarcaIconos.ruta,
        AdminDestino.flota: MarcaIconos.dobleTroque,
        AdminDestino.personas: MarcaIconos.personas,
        AdminDestino.analisis: MarcaIconos.resumen,
      };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.borderCard)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              for (final AdminDestino d in AdminDestino.values.where(
                (AdminDestino d) => d.enBarra,
              ))
                Expanded(
                  child: _ItemNav(
                    destino: d,
                    icono: _iconos[d],
                    activo: d == actual,
                    onTap: () => onSeleccionar(d),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemNav extends StatelessWidget {
  const _ItemNav({
    required this.destino,
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  final AdminDestino destino;
  final MarcaIconos? icono;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = activo ? AppColors.brandRed : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: activo,
      label: destino.etiqueta,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (activo)
                const Positioned(
                  top: 0,
                  left: 14,
                  right: 14,
                  height: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.brandRed,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      if (icono != null)
                        MarcaIcon(
                          icono!,
                          size: 24,
                          color: color,
                          relleno: activo,
                        )
                      else
                        Icon(LucideIcons.ellipsis, size: 24, color: color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destino.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampanaNotificaciones extends StatelessWidget {
  const _CampanaNotificaciones({
    required this.contador,
    required this.onPressed,
  });

  final int contador;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: contador > 0
          ? 'Notificaciones, $contador sin leer'
          : 'Notificaciones',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Icon(LucideIcons.bell),
          if (contador > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  borderRadius: AppRadius.pillAll,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$contador',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
