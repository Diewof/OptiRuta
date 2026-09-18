import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/accessibility/announce.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/validation/validation_rule.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/auth_alternatives.dart';
import '../../../../core/widgets/auth_link.dart';
import '../../../../core/widgets/auth_hero.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/auth_field_rules.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';

/// Pantalla de inicio de sesion. Valida el formato por UX y delega la
/// autenticacion real al [AuthCubit] (Supabase Auth). El enrutamiento por rol
/// tras entrar lo resuelve `AuthGate`.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();
  final FocusNode _correoFocus = FocusNode();
  final FocusNode _contrasenaFocus = FocusNode();

  bool _submitted = false;
  String? _contrasenaError;
  String? _errorAuth;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _correoFocus.dispose();
    _contrasenaFocus.dispose();
    super.dispose();
  }

  void _ingresar() {
    setState(() {
      _submitted = true;
      _contrasenaError = _contrasena.text.isEmpty
          ? 'La contraseña es obligatoria.'
          : null;
    });

    final bool correoOk = allSatisfied(AuthFieldRules.correo, _correo.text);
    if (correoOk && _contrasenaError == null) {
      FocusScope.of(context).unfocus();
      context.read<AuthCubit>().iniciarSesion(
        correo: _correo.text,
        contrasena: _contrasena.text,
      );
      return;
    }

    if (!correoOk) {
      _correoFocus.requestFocus();
      announceForAccessibility(
        context,
        firstUnsatisfied(AuthFieldRules.correo, _correo.text)!,
      );
    } else {
      _contrasenaFocus.requestFocus();
      announceForAccessibility(context, _contrasenaError!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (AuthState anterior, AuthState actual) =>
          actual is AuthError || actual is AuthAutenticando,
      listener: (BuildContext context, AuthState estado) {
        if (estado is AuthError) {
          setState(() => _errorAuth = estado.mensaje);
          announceForAccessibility(context, estado.mensaje);
        } else if (estado is AuthAutenticando) {
          setState(() => _errorAuth = null);
        }
      },
      builder: (BuildContext context, AuthState estado) {
        final bool cargando = estado is AuthAutenticando;

        return AuthScaffold(
          title: 'Iniciar sesión',
          subtitle: 'Ingresa tus credenciales para acceder al panel.',
          header: const AuthHero(),
          fullBleedHeader: true,
          children: <Widget>[
            if (_errorAuth != null) ...<Widget>[
              AppAlert(mensaje: _errorAuth!),
              const SizedBox(height: AppSpacing.x4),
            ],
            AppTextField(
              label: 'Correo electrónico',
              controller: _correo,
              focusNode: _correoFocus,
              prefixIcon: Icons.mail_outline,
              hint: 'ejemplo@empresa.com',
              rules: AuthFieldRules.correo,
              showRuleErrors: _submitted,
              validMessage: 'Correo válido',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.username],
              onSubmitted: (_) => _contrasenaFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.x4),
            AppTextField(
              label: 'Contraseña',
              controller: _contrasena,
              focusNode: _contrasenaFocus,
              prefixIcon: Icons.lock_outline,
              errorText: _contrasenaError,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              onSubmitted: (_) => _ingresar(),
            ),
            const SizedBox(height: AppSpacing.x3),
            Align(
              alignment: Alignment.centerRight,
              child: AuthLink(
                label: '¿Olvidaste tu contraseña?',
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamed(AppRoutes.recuperarPassword),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            PrimaryButton(
              label: 'Ingresar',
              onPressed: cargando ? null : _ingresar,
              loading: cargando,
              trailingIcon: Icons.arrow_forward,
            ),
            const SizedBox(height: AppSpacing.x6),
            const OrDivider(),
            const SizedBox(height: AppSpacing.x4),
            const GoogleButton(),
            const SizedBox(height: AppSpacing.x4),
            AuthFooterPrompt(
              question: '¿No tienes cuenta? ',
              actionLabel: 'Crear cuenta',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.registro),
            ),
          ],
        );
      },
    );
  }
}
