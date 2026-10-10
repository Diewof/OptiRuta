import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/autenticacion/domain/entities/usuario.dart';
import '../routing/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'admin_section.dart';
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

  void _ir(BuildContext context, String ruta) {
    Navigator.of(context).pushReplacementNamed(ruta);
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminSection> hermanas = seccionActual.hermanas;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onNavy,
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.x4,
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
          if (mostrarCampana && seccionActual != AdminSection.notificaciones)
            _CampanaNotificaciones(contador: notificacionesNoLeidas),
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
              onSeleccionar: (AdminSection s) => _ir(context, s.ruta),
            ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: _BarraInferior(
        actual: seccionActual.destino,
        pendientes: notificacionesNoLeidas,
        onSeleccionar: (AdminDestino d) {
          if (d != seccionActual.destino) _ir(context, d.rutaInicial);
        },
      ),
    );
  }
}

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
        child: Row(
          children: <Widget>[
            for (final AdminSection s in secciones)
              Expanded(
                child: Semantics(
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
              ),
          ],
        ),
      ),
    );
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({
    required this.actual,
    required this.pendientes,
    required this.onSeleccionar,
  });

  final AdminDestino actual;
  final int pendientes;
  final ValueChanged<AdminDestino> onSeleccionar;

  static const Map<AdminDestino, MarcaIconos> _iconos =
      <AdminDestino, MarcaIconos>{
        AdminDestino.resumen: MarcaIconos.resumen,
        AdminDestino.viajes: MarcaIconos.ruta,
        AdminDestino.flota: MarcaIconos.dobleTroque,
        AdminDestino.personas: MarcaIconos.personas,
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
              for (final AdminDestino d in AdminDestino.values)
                Expanded(
                  child: _ItemNav(
                    destino: d,
                    icono: _iconos[d],
                    activo: d == actual,
                    contador: d == AdminDestino.mas ? pendientes : 0,
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
    required this.contador,
    required this.onTap,
  });

  final AdminDestino destino;
  final MarcaIconos? icono;
  final bool activo;
  final int contador;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = activo ? AppColors.brandRed : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: activo,
      label: contador > 0
          ? '${destino.etiqueta}, $contador sin leer'
          : destino.etiqueta,
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
                      if (contador > 0)
                        Positioned(
                          top: -4,
                          right: -8,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 16),
                            height: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: AppRadius.pillAll,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$contador',
                              style: const TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onPrimary,
                              ),
                            ),
                          ),
                        ),
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
  const _CampanaNotificaciones({required this.contador});

  final int contador;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: contador > 0
          ? 'Notificaciones, $contador sin leer'
          : 'Notificaciones',
      onPressed: () =>
          Navigator.of(context)
              .pushReplacementNamed(AppRoutes.adminNotificaciones),
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
