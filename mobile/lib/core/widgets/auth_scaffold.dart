import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'brand_route_header.dart';

/// Estructura compartida de las pantallas de autenticación.
///
/// Cabecera de marca ([header]) y, debajo, un formulario compacto sobre el
/// fondo de la app: título, subtítulo y campos. El contenido se alinea arriba
/// (no se centra): el espacio sobrante queda al pie, como en cualquier
/// formulario. Desplazable para tolerar teclado y escalado de fuente. Si se
/// puede volver atrás, muestra una `AppBar` plana solo con la flecha.
///
/// `login` pasa `header: AuthHero()` con [fullBleedHeader] para incorporar la
/// ilustración a la pantalla; registro y recuperar usan la cabecera de ruta
/// compacta, porque ahí la checklist de validación en vivo ya alarga la vista.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    this.header = const BrandRouteHeader(),
    this.fullBleedHeader = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  /// Marca de la pantalla, encima del formulario.
  final Widget header;

  /// Si `true`, [header] ocupa todo el ancho y llega al borde superior (para
  /// ilustraciones). Si `false`, va centrado dentro del ancho del formulario.
  final bool fullBleedHeader;

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    final Widget headerBand = fullBleedHeader
        ? header
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x6,
              AppSpacing.x4,
              0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: header,
              ),
            ),
          );

    final Widget form = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4,
        fullBleedHeader ? AppSpacing.x6 : AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x6,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(title, style: AppTypography.display),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                subtitle,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x6),
              ...children,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: fullBleedHeader,
      appBar: canPop
          ? AppBar(
              backgroundColor: fullBleedHeader
                  ? Colors.transparent
                  : AppColors.canvas,
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver',
              ),
            )
          : null,
      body: SafeArea(
        top: !fullBleedHeader,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[headerBand, form],
          ),
        ),
      ),
    );
  }
}
