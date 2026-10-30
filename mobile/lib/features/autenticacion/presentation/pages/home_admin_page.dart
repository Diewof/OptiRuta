import 'package:flutter/material.dart';

import '../../../../core/routing/admin_shell.dart';
import '../../domain/entities/usuario.dart';

/// Punto de entrada del rol ADMINISTRADOR: el shell abre en Inicio (alertas y
/// viajes en curso) y desde su barra inferior se alcanza el resto.
class HomeAdminPage extends StatelessWidget {
  const HomeAdminPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) => AdminShell(usuario: usuario);
}
