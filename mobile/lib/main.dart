import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/routing/app_routes.dart';
import 'core/supabase/supabase_init.dart';
import 'core/theme/app_theme.dart';
import 'features/autenticacion/data/datasources/auth_remote_data_source.dart';
import 'features/autenticacion/data/repositories/auth_repository_impl.dart';
import 'features/autenticacion/domain/repositories/auth_repository.dart';
import 'features/autenticacion/domain/usecases/cerrar_sesion_use_case.dart';
import 'features/autenticacion/domain/usecases/iniciar_sesion_use_case.dart';
import 'features/autenticacion/domain/usecases/observar_sesion_use_case.dart';
import 'features/autenticacion/domain/usecases/recuperar_password_use_case.dart';
import 'features/autenticacion/domain/usecases/registrarse_use_case.dart';
import 'features/autenticacion/presentation/bloc/auth_cubit.dart';
import 'features/autenticacion/presentation/widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    runApp(const _ConfigFaltanteApp());
    return;
  }

  final SupabaseClient client = await initSupabase();
  final AuthRepository authRepository = AuthRepositoryImpl(
    AuthRemoteDataSource(client),
  );

  runApp(OptiRutaApp(authRepository: authRepository));
}

/// Raiz de la app. Recibe el [AuthRepository] por constructor (DI): en produccion
/// lo arma `main`; en pruebas se inyecta un doble.
class OptiRutaApp extends StatelessWidget {
  const OptiRutaApp({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>(
      create: (_) => AuthCubit(
        iniciarSesion: IniciarSesionUseCase(authRepository),
        registrarse: RegistrarseUseCase(authRepository),
        cerrarSesion: CerrarSesionUseCase(authRepository),
        observarSesion: ObservarSesionUseCase(authRepository),
        recuperarPassword: RecuperarPasswordUseCase(authRepository),
      ),
      child: MaterialApp(
        title: 'OptiRuta',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
        routes: AppRoutes.map,
      ),
    );
  }
}

/// Pantalla mostrada cuando la app se compilo sin `SUPABASE_URL` /
/// `SUPABASE_ANON_KEY`.
class _ConfigFaltanteApp extends StatelessWidget {
  const _ConfigFaltanteApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OptiRuta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              SupabaseConfig.faltaConfigMensaje,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
