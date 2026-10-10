import 'package:flutter/material.dart';

import '../../../dashboard/presentation/pages/analitica_page.dart';
import '../../domain/entities/usuario.dart';

/// Punto de entrada del rol ADMINISTRADOR: Analítica es la vista inicial
/// (ver LEEME-CLAUDE-CODE.md, "Dashboard · Analítica es la vista inicial del
/// admin"). El resto de las secciones (Calendario, Seguimiento, Conductores,
/// Notificaciones, Perfil, Cerrar sesión) se alcanzan desde su menú lateral.
class HomeAdminPage extends StatelessWidget {
  const HomeAdminPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) => AnaliticaPage(usuario: usuario);
}
