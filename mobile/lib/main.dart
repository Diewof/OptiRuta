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
import 'features/autenticacion/domain/usecases/iniciar_con_google_use_case.dart';
import 'features/autenticacion/domain/usecases/iniciar_sesion_use_case.dart';
import 'features/autenticacion/domain/usecases/observar_sesion_use_case.dart';
import 'features/autenticacion/domain/usecases/recuperar_password_use_case.dart';
import 'features/autenticacion/domain/usecases/registrarse_use_case.dart';
import 'features/autenticacion/presentation/bloc/auth_cubit.dart';
import 'features/autenticacion/presentation/widgets/auth_gate.dart';
import 'features/clientes/data/datasources/cliente_remote_data_source.dart';
import 'features/clientes/data/repositories/cliente_repository_impl.dart';
import 'features/clientes/domain/repositories/cliente_repository.dart';
import 'features/conductores/data/datasources/conductor_remote_data_source.dart';
import 'features/conductores/data/repositories/conductor_repository_impl.dart';
import 'features/conductores/domain/repositories/conductor_repository.dart';
import 'features/notificaciones/data/datasources/notificacion_remote_data_source.dart';
import 'features/notificaciones/data/repositories/notificacion_repository_impl.dart';
import 'features/notificaciones/domain/repositories/notificacion_repository.dart';
import 'features/vehiculos/data/datasources/vehiculo_remote_data_source.dart';
import 'features/vehiculos/data/repositories/vehiculo_repository_impl.dart';
import 'features/vehiculos/domain/repositories/vehiculo_repository.dart';
import 'features/viajes/data/datasources/ajuste_viaje_remote_data_source.dart';
import 'features/viajes/data/datasources/costo_viaje_remote_data_source.dart';
import 'features/viajes/data/datasources/hito_remote_data_source.dart';
import 'features/viajes/data/datasources/rentabilidad_remote_data_source.dart';
import 'features/viajes/data/datasources/ruta_remote_data_source.dart';
import 'features/viajes/data/datasources/viaje_remote_data_source.dart';
import 'features/viajes/data/repositories/ajuste_viaje_repository_impl.dart';
import 'features/viajes/data/repositories/costo_viaje_repository_impl.dart';
import 'features/viajes/data/repositories/hito_repository_impl.dart';
import 'features/viajes/data/repositories/rentabilidad_repository_impl.dart';
import 'features/viajes/data/repositories/ruta_repository_impl.dart';
import 'features/viajes/data/servicios/servicio_ubicacion_impl.dart';
import 'features/viajes/data/repositories/viaje_repository_impl.dart';
import 'features/viajes/domain/repositories/ajuste_viaje_repository.dart';
import 'features/viajes/domain/repositories/costo_viaje_repository.dart';
import 'features/viajes/domain/repositories/hito_repository.dart';
import 'features/viajes/domain/repositories/rentabilidad_repository.dart';
import 'features/viajes/domain/repositories/ruta_repository.dart';
import 'features/viajes/domain/servicios/servicio_ubicacion.dart';
import 'features/viajes/domain/repositories/viaje_repository.dart';

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

  runApp(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<VehiculoRepository>(
          create: (_) =>
              VehiculoRepositoryImpl(VehiculoRemoteDataSource(client)),
        ),
        RepositoryProvider<ConductorRepository>(
          create: (_) =>
              ConductorRepositoryImpl(ConductorRemoteDataSource(client)),
        ),
        RepositoryProvider<ClienteRepository>(
          create: (_) => ClienteRepositoryImpl(ClienteRemoteDataSource(client)),
        ),
        RepositoryProvider<NotificacionRepository>(
          create: (_) =>
              NotificacionRepositoryImpl(NotificacionRemoteDataSource(client)),
        ),
        RepositoryProvider<ViajeRepository>(
          create: (_) => ViajeRepositoryImpl(ViajeRemoteDataSource(client)),
        ),
        RepositoryProvider<HitoRepository>(
          create: (_) => HitoRepositoryImpl(HitoRemoteDataSource(client)),
        ),
        RepositoryProvider<AjusteViajeRepository>(
          create: (_) =>
              AjusteViajeRepositoryImpl(AjusteViajeRemoteDataSource(client)),
        ),
        RepositoryProvider<CostoViajeRepository>(
          create: (_) =>
              CostoViajeRepositoryImpl(CostoViajeRemoteDataSource(client)),
        ),
        RepositoryProvider<RentabilidadRepository>(
          create: (_) =>
              RentabilidadRepositoryImpl(RentabilidadRemoteDataSource(client)),
        ),
        RepositoryProvider<ServicioUbicacion>(
          create: (_) => const ServicioUbicacionImpl(),
        ),
        RepositoryProvider<RutaRepository>(
          create: (_) => RutaRepositoryImpl(RutaRemoteDataSource(client)),
        ),
      ],
      child: OptiRutaApp(authRepository: authRepository),
    ),
  );
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
        iniciarConGoogle: IniciarConGoogleUseCase(authRepository),
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
