/// Configuracion de conexion a Supabase.
///
/// Los valores llegan por `--dart-define` en tiempo de compilacion
/// (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). La `anon key` es publica por diseno;
/// la seguridad la dan las politicas RLS. La `service_role key` NUNCA se
/// incluye en la app.
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// `true` cuando ambos valores fueron inyectados en el build.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Mensaje de ayuda para el arranque cuando falta configuracion.
  static const String faltaConfigMensaje =
      'Faltan SUPABASE_URL y/o SUPABASE_ANON_KEY. Ejecuta la app con '
      '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... '
      '(ver mobile/.env.example).';
}
