import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/autenticacion/presentation/bloc/auth_cubit.dart';
import 'confirm_dialog.dart';

/// Pide confirmación y cierra la sesión (`supabase.auth.signOut()` vía
/// [AuthCubit]). Compartido por Perfil del conductor y del administrador.
Future<void> cerrarSesionConConfirmacion(
  BuildContext context, {
  required String mensaje,
}) async {
  final AuthCubit authCubit = context.read<AuthCubit>();
  final bool? confirmado = await ConfirmDialog.mostrar(
    context,
    titulo: '¿Cerrar sesión?',
    mensaje: mensaje,
    icono: LucideIcons.logOut,
    textoConfirmar: 'Cerrar sesión',
    esDestructivo: true,
  );
  if (confirmado == true) {
    await authCubit.cerrarSesion();
  }
}
