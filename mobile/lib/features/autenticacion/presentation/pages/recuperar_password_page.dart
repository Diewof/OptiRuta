import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/accessibility/announce.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/validation/validation_rule.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/auth_hero.dart';
import '../../../../core/widgets/auth_link.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/auth_field_rules.dart';
import '../../domain/errores/auth_failure.dart';
import '../bloc/auth_cubit.dart';

/// Pantalla de recuperación de contraseña. Envía el correo de restablecimiento
/// vía Supabase Auth y muestra una confirmación neutra (no revela si el correo
/// existe).
///
/// El paso de *fijar la nueva contraseña dentro de la app* requiere manejar el
/// deep link de recuperación (evento `passwordRecovery`) y queda como trabajo
/// posterior; por ahora el enlace del correo abre el flujo web de Supabase.
class RecuperarPasswordPage extends StatefulWidget {
  const RecuperarPasswordPage({super.key});

  @override
  State<RecuperarPasswordPage> createState() => _RecuperarPasswordPageState();
}

class _RecuperarPasswordPageState extends State<RecuperarPasswordPage> {
  final TextEditingController _correo = TextEditingController();
  final FocusNode _correoFocus = FocusNode();

  bool _submitted = false;
  bool _cargando = false;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _correoFocus.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _submitted = true);

    final String? pendiente = firstUnsatisfied(
      AuthFieldRules.correo,
      _correo.text,
    );
    if (pendiente != null) {
      _correoFocus.requestFocus();
      announceForAccessibility(context, pendiente);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await context.read<AuthCubit>().recuperarPassword(correo: _correo.text);
      if (!mounted) return;
      setState(() => _enviado = true);
      announceForAccessibility(
        context,
        'Si el correo está registrado, te enviamos instrucciones.',
      );
    } on AuthFailure catch (falla) {
      if (!mounted) return;
      setState(() => _error = falla.mensaje);
      announceForAccessibility(context, falla.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Recuperar contraseña',
      subtitle:
          'Ingresa tu correo electrónico y te enviaremos instrucciones para '
          'restablecer tu contraseña.',
      header: const AuthHero(),
      fullBleedHeader: true,
      children: <Widget>[
        if (_error != null) ...<Widget>[
          AppAlert(mensaje: _error!),
          const SizedBox(height: AppSpacing.x4),
        ],
        if (_enviado) ...<Widget>[
          const AppAlert(
            tono: AppAlertTono.exito,
            mensaje:
                'Si el correo está registrado, te enviamos instrucciones para '
                'restablecer tu contraseña. Revisa tu bandeja de entrada.',
          ),
          const SizedBox(height: AppSpacing.x4),
        ],
        AppTextField(
          label: 'Correo electrónico',
          controller: _correo,
          focusNode: _correoFocus,
          prefixIcon: Icons.mail_outline,
          rules: AuthFieldRules.correo,
          showRuleErrors: _submitted,
          validMessage: 'Correo válido',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.email],
          onSubmitted: (_) => _enviar(),
        ),
        const SizedBox(height: AppSpacing.x6),
        PrimaryButton(
          label: 'Enviar instrucciones',
          onPressed: _cargando ? null : _enviar,
          loading: _cargando,
        ),
        const SizedBox(height: AppSpacing.x4),
        AuthFooterPrompt(
          question: '¿Ya la recordaste? ',
          actionLabel: 'Volver a iniciar sesión',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
