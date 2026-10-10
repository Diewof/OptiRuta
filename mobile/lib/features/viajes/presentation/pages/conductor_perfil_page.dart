import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/conductor_scaffold.dart';
import '../../../../core/widgets/conductor_section.dart';
import '../../../../core/widgets/module_link_card.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../../clientes/presentation/pages/clientes_list_page.dart';
import '../../../conductores/presentation/pages/mi_perfil_conductor_page.dart';

/// Último destino de la barra inferior del Conductor: su propia ficha (solo
/// lectura), el listado de clientes y el cierre de sesión.
class ConductorPerfilPage extends StatelessWidget {
  const ConductorPerfilPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return ConductorScaffold(
      titulo: 'Perfil',
      seccionActual: ConductorSection.perfil,
      usuario: usuario,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          ModuleLinkCard(
            icono: LucideIcons.idCard,
            titulo: 'Mi perfil de conductor',
            subtitulo: 'Licencia, tipo de pago y comisión',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MiPerfilConductorPage(usuarioId: usuario.id),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          ModuleLinkCard(
            icono: LucideIcons.users,
            titulo: 'Clientes',
            subtitulo: 'Datos de contacto de los clientes de la empresa',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ClientesListPage(esAdministrador: false),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          SecondaryButton(
            label: 'Cerrar sesión',
            leadingIcon: LucideIcons.logOut,
            onPressed: () => ConductorScaffold.cerrarSesion(context),
          ),
        ],
      ),
    );
  }
}
