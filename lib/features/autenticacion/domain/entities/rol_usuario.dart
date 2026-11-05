/// Roles del sistema. Fuente de verdad: `app_metadata.rol` del JWT emitido por
/// Supabase Auth (no un campo editable por el cliente).
enum RolUsuario {
  administrador('ADMINISTRADOR'),
  conductor('CONDUCTOR');

  const RolUsuario(this.codigo);

  /// Valor tal cual viaja en el JWT y se guarda en la columna `usuario.rol`.
  final String codigo;

  /// Convierte el valor del JWT/BD al enum. Lanza [ArgumentError] si el valor
  /// no corresponde a un rol conocido (denegar por defecto).
  static RolUsuario desdeCodigo(String? valor) {
    return switch (valor?.toUpperCase()) {
      'ADMINISTRADOR' => RolUsuario.administrador,
      'CONDUCTOR' => RolUsuario.conductor,
      _ => throw ArgumentError.value(
        valor,
        'valor',
        'Rol de usuario no valido',
      ),
    };
  }
}
