import 'package:flutter/material.dart';

import '../../../viajes/presentation/pages/conductor_inicio_page.dart';
import '../../domain/entities/usuario.dart';

/// Punto de entrada del rol CONDUCTOR: Inicio (viaje activo) es la vista
/// inicial, igual que Analítica lo es para el Administrador ([HomeAdminPage]).
/// El resto de las secciones (Mis viajes, Manual, Perfil) se
/// alcanzan desde la barra de navegación inferior de [ConductorScaffold].
class HomeConductorPage extends StatelessWidget {
  const HomeConductorPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) => ConductorInicioPage(usuario: usuario);
}
