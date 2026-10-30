/// Pausa activa por conducción continua (RPC `viaje_probar_pausa_activa`,
/// `viaje_consumir_pausa_prueba`, `viaje_registrar_pausa_ignorada`).
abstract interface class PausaActivaRepository {
  /// Administrador: pide a la app del conductor mostrar el aviso (prueba).
  Future<void> probar({required String viajeId});

  /// Conductor: `true` una sola vez si hay una prueba pendiente del viaje.
  Future<bool> consumirPrueba({required String viajeId});

  /// Conductor: siguió conduciendo tras el aviso. `true` si se notificó al
  /// administrador, `false` si ya había una alerta reciente.
  Future<bool> registrarIgnorada({
    required String viajeId,
    required int minutosConduccion,
    required int minutosIgnorada,
    required bool prueba,
  });
}
