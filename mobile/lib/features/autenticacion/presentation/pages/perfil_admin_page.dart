import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/cerrar_sesion.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/pages/work_in_progress_page.dart';
import '../../domain/entities/rol_usuario.dart';
import '../../domain/entities/usuario.dart';

/// Perfil de solo lectura del Administrador: nombre, rol y estado (Usuario)
/// más las acciones de cuenta disponibles hoy.
///
/// El correo, el teléfono y el último acceso del mockup no están en la
/// entidad [Usuario] (solo vive en Supabase Auth y no se expone todavía por
/// el dominio); "Editar perfil" tampoco tiene caso de uso. Se documentan como
/// pendientes en vez de inventar datos o saltarse la capa de dominio.
class PerfilAdminPage extends StatelessWidget {
  const PerfilAdminPage({required this.usuario, super.key});

  final Usuario usuario;

  String get _iniciales {
    final List<String> partes = usuario.nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    final String primera = partes.first.substring(0, 1);
    final String ultima = partes.length > 1 ? partes.last.substring(0, 1) : '';
    return (primera + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Perfil',
      seccionActual: AdminSection.perfil,
      usuario: usuario,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          AppCard(
            stripe: AppCardStripe.top,
            stripeColor: AppColors.brandRed,
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Row(
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _iniciales,
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onNavy,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(usuario.nombre, style: AppTypography.title),
                      const SizedBox(height: AppSpacing.x2),
                      Wrap(
                        spacing: AppSpacing.x2,
                        runSpacing: AppSpacing.x2,
                        children: <Widget>[
                          const _RolBadge(),
                          StatusBadge.activo(usuario.activo),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          _Seccion(
            titulo: 'Datos personales',
            filas: <_Dato>[
              _Dato(
                icono: LucideIcons.user,
                etiqueta: 'Nombre completo',
                valor: usuario.nombre,
              ),
              _Dato(
                icono: LucideIcons.idCard,
                etiqueta: 'Documento',
                valor: usuario.documento ?? 'No registrado',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          _Seccion(
            titulo: 'Cuenta',
            filas: <_Dato>[
              _Dato(
                icono: LucideIcons.shieldCheck,
                etiqueta: 'Rol',
                valor: usuario.rol == RolUsuario.administrador
                    ? 'Administrador'
                    : 'Conductor',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          _Seccion(
            titulo: 'Seguridad',
            filas: const <_Dato>[],
            filaNavegable: _FilaNavegable(
              icono: LucideIcons.lock,
              etiqueta: 'Cambiar contraseña',
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          SecondaryButton(
            label: 'Cerrar sesión',
            leadingIcon: LucideIcons.logOut,
            onPressed: () => cerrarSesionConConfirmacion(
              context,
              mensaje:
                  'Tendrás que ingresar de nuevo con tu correo y contraseña '
                  'para acceder al panel.',
            ),
          ),
        ],
      ),
    );
  }
}

class _RolBadge extends StatelessWidget {
  const _RolBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Administrador',
        style: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.onNavy,
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.filas,
    this.filaNavegable,
  });

  final String titulo;
  final List<_Dato> filas;
  final _FilaNavegable? filaNavegable;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
            child: Text(titulo, style: AppTypography.subtitle),
          ),
          for (final _Dato dato in filas) dato,
          ?filaNavegable,
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.dividerTable)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icono, size: 20, color: AppColors.slate),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  etiqueta,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(valor, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaNavegable extends StatelessWidget {
  const _FilaNavegable({required this.icono, required this.etiqueta});

  final IconData icono;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const WorkInProgressPage()),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.dividerTable)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icono, size: 20, color: AppColors.slate),
              const SizedBox(width: AppSpacing.x3),
              Expanded(child: Text(etiqueta, style: AppTypography.body)),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
