import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/rol_usuario.dart';
import '../../domain/entities/usuario.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';
import '../pages/home_admin_page.dart';
import '../pages/home_conductor_page.dart';
import '../pages/login_page.dart';

/// Widget raiz: enruta segun el estado de autenticacion y el rol.
///
/// Denegar por defecto: sin sesion solo se puede ver el login. La comprobacion
/// de rol aqui es solo para elegir vista; la autorizacion real la imponen las
/// politicas RLS del lado servidor.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (BuildContext context, AuthState estado) {
        return switch (estado) {
          AuthDesconocido() => const _CargandoSesion(),
          AuthAutenticado(:final Usuario usuario) => switch (usuario.rol) {
            RolUsuario.administrador => HomeAdminPage(usuario: usuario),
            RolUsuario.conductor => HomeConductorPage(usuario: usuario),
          },
          AuthAutenticando() ||
          AuthNoAutenticado() ||
          AuthError() => const LoginPage(),
        };
      },
    );
  }
}

class _CargandoSesion extends StatelessWidget {
  const _CargandoSesion();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}
