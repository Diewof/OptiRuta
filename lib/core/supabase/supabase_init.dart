import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Inicializa el cliente global de Supabase.
///
/// La persistencia de sesion y el refresco automatico del token (~1h) los
/// gestiona el SDK con su almacenamiento por defecto; no hay manejo propio de
/// tokens. Debe llamarse una sola vez, antes de `runApp`.
Future<SupabaseClient> initSupabase() async {
  if (!SupabaseConfig.isConfigured) {
    throw StateError(SupabaseConfig.faltaConfigMensaje);
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    // Clave publica del proyecto (SUPABASE_ANON_KEY en CLAUDE.md). Supabase la
    // llama ahora "publishable key"; el valor sirve igual con el nombre viejo
    // (anon, JWT) o el nuevo (sb_publishable_...).
    publishableKey: SupabaseConfig.anonKey,
  );

  return Supabase.instance.client;
}
