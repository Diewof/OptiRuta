import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../domain/entities/rol_usuario.dart';
import '../../domain/entities/usuario.dart';
import '../bloc/auth_cubit.dart';

/// Marcador de posicion de la vista posterior al login.
///
/// El dashboard y las vistas por rol estan fuera del alcance de esta tarea;
/// aqui solo se confirma que el enrutamiento por rol funciona y se ofrece
/// cerrar sesion.
class SesionIniciadaPage extends StatelessWidget {
  const SesionIniciadaPage({required this.usuario, super.key});

  final Usuario usuario;

  String get _rolLegible => switch (usuario.rol) {
    RolUsuario.administrador => 'Administrador',
    RolUsuario.conductor => 'Conductor',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onNavy,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const BrandMark(size: 26),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'OptiRuta',
              style: AppTypography.subtitle.copyWith(
                color: AppColors.onNavy,
                fontWeight: FontWeight.w700,
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
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    'Sesión iniciada',
                    textAlign: TextAlign.center,
                    style: AppTypography.title,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  '${usuario.nombre} — $_rolLegible',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),
                SecondaryButton(
                  label: 'Cerrar sesión',
                  onPressed: () => context.read<AuthCubit>().cerrarSesion(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
