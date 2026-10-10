import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/autenticacion/domain/entities/usuario.dart';
import '../routing/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'brand_mark.dart';
import 'cerrar_sesion.dart';
import 'conductor_section.dart';
import 'marca_icon.dart';

/// Armazón común de las pantallas del Conductor: barra de navegación inferior
/// fija de 4 destinos (icono + texto, activo con rojo de marca e icono
/// relleno) y, opcionalmente, una acción principal fija sobre la barra, al
/// alcance del pulgar.
///
/// Las pantallas llevan por defecto una barra superior navy con la franja
/// roja de marca; Inicio la reemplaza por su propia cabecera ([conAppBar]).
class ConductorScaffold extends StatelessWidget {
  const ConductorScaffold({
    required this.titulo,
    required this.seccionActual,
    required this.usuario,
    required this.body,
    this.conAppBar = true,
    this.accion,
    super.key,
  });

  final String titulo;
  final ConductorSection seccionActual;
  final Usuario usuario;
  final Widget body;
  final bool conAppBar;

  /// Acción principal fija sobre la navegación (p. ej. registrar el hito).
  final Widget? accion;

  static const Map<ConductorSection, String> _rutas =
      <ConductorSection, String>{
        ConductorSection.inicio: AppRoutes.conductorInicio,
        ConductorSection.historial: AppRoutes.conductorHistorial,
        ConductorSection.manual: AppRoutes.conductorManual,
        ConductorSection.perfil: AppRoutes.conductorPerfil,
      };

  void _ir(BuildContext context, ConductorSection destino) {
    if (destino == seccionActual) return;
    Navigator.of(context).pushReplacementNamed(_rutas[destino]!);
  }

  /// Confirma y cierra la sesión (se usa desde Perfil).
  static Future<void> cerrarSesion(BuildContext context) =>
      cerrarSesionConConfirmacion(
        context,
        mensaje:
            'Si tienes un viaje en curso, tus datos guardados localmente se '
            'sincronizarán antes de salir.',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: conAppBar
          ? AppBar(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.onNavy,
              titleSpacing: AppSpacing.x4,
              automaticallyImplyLeading: false,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const BrandMark(size: 26),
                  const SizedBox(width: AppSpacing.x2),
                  Text(
                    titulo,
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.onNavy,
                    ),
                  ),
                ],
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: ColoredBox(
                  color: AppColors.brandRed,
                  child: SizedBox(height: 2, width: double.infinity),
                ),
              ),
            )
          : null,
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (accion != null)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.dividerTable)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x3,
                  AppSpacing.x4,
                  AppSpacing.x3,
                ),
                child: accion,
              ),
            ),
          _ConductorBottomNav(
            seccionActual: seccionActual,
            onSeleccionar: (ConductorSection s) => _ir(context, s),
          ),
        ],
      ),
    );
  }
}

class _ItemNav {
  const _ItemNav(this.seccion, this.etiqueta, {this.marca, this.lucide});

  final ConductorSection seccion;
  final String etiqueta;
  final MarcaIconos? marca;
  final IconData? lucide;
}

class _ConductorBottomNav extends StatelessWidget {
  const _ConductorBottomNav({
    required this.seccionActual,
    required this.onSeleccionar,
  });

  final ConductorSection seccionActual;
  final ValueChanged<ConductorSection> onSeleccionar;

  static const List<_ItemNav> _items = <_ItemNav>[
    _ItemNav(ConductorSection.inicio, 'Inicio', marca: MarcaIconos.inicio),
    _ItemNav(ConductorSection.historial, 'Mis viajes', marca: MarcaIconos.ruta),
    _ItemNav(ConductorSection.manual, 'Manual', lucide: LucideIcons.bookOpen),
    _ItemNav(ConductorSection.perfil, 'Perfil', marca: MarcaIconos.perfil),
  ];

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
              for (final _ItemNav item in _items)
                Expanded(
                  child: _NavItem(
                    item: item,
                    activo: seccionActual == item.seccion,
                    onTap: () => onSeleccionar(item.seccion),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.activo,
    required this.onTap,
  });

  final _ItemNav item;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = activo ? AppColors.brandRed : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: activo,
      label: item.etiqueta,
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
                  left: 20,
                  right: 20,
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
                  if (item.marca != null)
                    MarcaIcon(
                      item.marca!,
                      size: 24,
                      color: color,
                      relleno: activo,
                    )
                  else
                    Icon(item.lucide, size: 24, color: color),
                  const SizedBox(height: 4),
                  Text(
                    item.etiqueta,
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
