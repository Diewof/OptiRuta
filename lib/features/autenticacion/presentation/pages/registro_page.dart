import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';

/// Pantalla de registro. Valida el formato por UX y delega el alta al
/// [AuthCubit] (Supabase Auth). El servidor asigna siempre rol CONDUCTOR.
class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();
  final TextEditingController _confirmar = TextEditingController();

  final FocusNode _nombreFocus = FocusNode();
  final FocusNode _correoFocus = FocusNode();
  final FocusNode _contrasenaFocus = FocusNode();
  final FocusNode _confirmarFocus = FocusNode();

  bool _submitted = false;
  String? _errorAuth;

  late final List<ValidationRule> _confirmarRules =
      AuthFieldRules.confirmarContrasena(() => _contrasena.text);

  @override
  void initState() {
    super.initState();
    // Reevaluar la checklist de "Confirmar contraseña" cuando cambia la
    // contraseña original.
    _contrasena.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _contrasena.removeListener(_refresh);
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    _confirmar.dispose();
    _nombreFocus.dispose();
    _correoFocus.dispose();
    _contrasenaFocus.dispose();
    _confirmarFocus.dispose();
    super.dispose();
  }

  void _crearCuenta() {
    setState(() => _submitted = true);

    final List<(FocusNode, List<ValidationRule>, String)> campos =
        <(FocusNode, List<ValidationRule>, String)>[
          (_nombreFocus, AuthFieldRules.nombre, _nombre.text),
          (_correoFocus, AuthFieldRules.correo, _correo.text),
          (_contrasenaFocus, AuthFieldRules.contrasena, _contrasena.text),
          (_confirmarFocus, _confirmarRules, _confirmar.text),
        ];

    for (final (FocusNode foco, List<ValidationRule> reglas, String valor)
        in campos) {
      final String? pendiente = firstUnsatisfied(reglas, valor);
      if (pendiente != null) {
        foco.requestFocus();
        announceForAccessibility(context, pendiente);
        return;
      }
    }

    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().registrarse(
      nombre: _nombre.text,
      correo: _correo.text,
      contrasena: _contrasena.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (AuthState anterior, AuthState actual) =>
          actual is AuthError ||
          actual is AuthAutenticando ||
          actual is AuthAutenticado,
      listener: (BuildContext context, AuthState estado) {
        if (estado is AuthAutenticado) {
          // El alta entro directo: volver a la raiz para que AuthGate muestre
          // la vista por rol.
          Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        } else if (estado is AuthError) {
          setState(() => _errorAuth = estado.mensaje);
          announceForAccessibility(context, estado.mensaje);
        } else if (estado is AuthAutenticando) {
          setState(() => _errorAuth = null);
        }
      },
      builder: (BuildContext context, AuthState estado) {
        final bool cargando = estado is AuthAutenticando;

        return AuthScaffold(
          title: 'Crear cuenta',
          subtitle: 'Registra tus datos para acceder a OptiRuta.',
          header: const AuthHero(compact: true),
          fullBleedHeader: true,
          children: <Widget>[
            if (_errorAuth != null) ...<Widget>[
              AppAlert(mensaje: _errorAuth!),
              const SizedBox(height: AppSpacing.x4),
            ],
            AppTextField(
              label: 'Nombre completo',
              controller: _nombre,
              focusNode: _nombreFocus,
              prefixIcon: LucideIcons.user,
              rules: AuthFieldRules.nombre,
              showRuleErrors: _submitted,
              validMessage: 'Nombre válido',
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              onSubmitted: (_) => _correoFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.x4),
            AppTextField(
              label: 'Correo electrónico',
              controller: _correo,
              focusNode: _correoFocus,
              prefixIcon: LucideIcons.mail,
              rules: AuthFieldRules.correo,
              showRuleErrors: _submitted,
              validMessage: 'Correo válido',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              onSubmitted: (_) => _contrasenaFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.x4),
            AppTextField(
              label: 'Contraseña',
              controller: _contrasena,
              focusNode: _contrasenaFocus,
              prefixIcon: LucideIcons.lock,
              rules: AuthFieldRules.contrasena,
              showRuleErrors: _submitted,
              validMessage: 'Contraseña válida',
              isPassword: true,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onSubmitted: (_) => _confirmarFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.x4),
            AppTextField(
              label: 'Confirmar contraseña',
              controller: _confirmar,
              focusNode: _confirmarFocus,
              prefixIcon: LucideIcons.lock,
              rules: _confirmarRules,
              showRuleErrors: _submitted,
              validMessage: 'Las contraseñas coinciden',
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              onSubmitted: (_) => _crearCuenta(),
            ),
            const SizedBox(height: AppSpacing.x6),
            PrimaryButton(
              label: 'Crear cuenta',
              onPressed: cargando ? null : _crearCuenta,
              loading: cargando,
            ),
            const SizedBox(height: AppSpacing.x4),
            AuthFooterPrompt(
              question: '¿Ya tienes cuenta? ',
              actionLabel: 'Iniciar sesión',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
