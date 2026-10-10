import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Codigos de error de dominio compartidos por los catalogos simples
/// (vehiculo, conductor, cliente): CRUD sobre PostgREST + RLS sin logica de
/// autenticacion. Se centraliza aqui para no repetir la misma traduccion de
/// errores de Postgres en cada repositorio.
enum CatalogoErrorCodigo {
  sinPermiso('SIN_PERMISO'),
  yaExiste('YA_EXISTE'),
  noEncontrado('NO_ENCONTRADO'),
  sinConexion('SIN_CONEXION'),
  desconocido('DESCONOCIDO');

  const CatalogoErrorCodigo(this.codigo);

  final String codigo;
}

/// Falla de dominio de un catalogo: un codigo estable y un mensaje ya
/// traducido para mostrar al usuario. Nunca se expone el error crudo del
/// proveedor (`PostgrestException`, `SQLSTATE`, nombres de tabla/columna).
class CatalogoFailure extends Equatable implements Exception {
  const CatalogoFailure(this.codigo, this.mensaje);

  factory CatalogoFailure.sinPermiso() => const CatalogoFailure(
    CatalogoErrorCodigo.sinPermiso,
    'No tienes permiso para realizar esta acción.',
  );

  factory CatalogoFailure.yaExiste([
    String mensaje = 'Ya existe un registro con ese valor.',
  ]) => CatalogoFailure(CatalogoErrorCodigo.yaExiste, mensaje);

  factory CatalogoFailure.noEncontrado() => const CatalogoFailure(
    CatalogoErrorCodigo.noEncontrado,
    'El registro no existe o ya fue modificado.',
  );

  factory CatalogoFailure.sinConexion() => const CatalogoFailure(
    CatalogoErrorCodigo.sinConexion,
    'Sin conexión. Revisa tu internet e intenta de nuevo.',
  );

  factory CatalogoFailure.desconocido() => const CatalogoFailure(
    CatalogoErrorCodigo.desconocido,
    'No se pudo completar la operación. Intenta más tarde.',
  );

  final CatalogoErrorCodigo codigo;
  final String mensaje;

  @override
  List<Object?> get props => <Object?>[codigo, mensaje];

  @override
  String toString() => 'CatalogoFailure(${codigo.codigo}): $mensaje';
}

/// Patrón de los errcode de dominio propios (p. ej. `OR105`, `OR111`), que
/// las RPC lanzan con `RAISE EXCEPTION ... USING ERRCODE = 'ORxxx'` y un
/// mensaje ya redactado en español (CLAUDE.md "Seguridad": las RPC mapean su
/// propio ERRCODE a un mensaje de dominio). Ese mensaje se puede mostrar tal
/// cual; no hace falta traducirlo a mano aquí.
final RegExp _erroCodigoDominio = RegExp(r'^OR\d{3}$');

/// Traduce un `PostgrestException` crudo a [CatalogoFailure]. `23505` es
/// violacion de unicidad (placa/usuario ya usados); `42501`, RLS/permiso;
/// `ORxxx`, una regla de dominio de una RPC (el mensaje ya viene en español).
CatalogoFailure traducirPostgrestException(PostgrestException e) {
  switch (e.code) {
    case '23505':
      return CatalogoFailure.yaExiste();
    case '42501':
      return CatalogoFailure.sinPermiso();
    case 'PGRST116':
      return CatalogoFailure.noEncontrado();
    default:
      if (e.code != null && _erroCodigoDominio.hasMatch(e.code!)) {
        return CatalogoFailure(CatalogoErrorCodigo.desconocido, e.message);
      }
      return CatalogoFailure.desconocido();
  }
}

/// Ejecuta [operacion] traduciendo cualquier error de Supabase/red a
/// [CatalogoFailure]. Comparte la misma politica de traduccion entre los
/// repositorios de catalogo para no duplicar el try/catch en cada metodo.
Future<T> ejecutarCatalogo<T>(Future<T> Function() operacion) async {
  try {
    return await operacion();
  } on PostgrestException catch (e) {
    throw traducirPostgrestException(e);
  } on SocketException {
    throw CatalogoFailure.sinConexion();
  }
}
