import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('23505 se traduce a YA_EXISTE', () {
    final falla = traducirPostgrestException(
      const PostgrestException(message: 'duplicate', code: '23505'),
    );
    expect(falla.codigo, CatalogoErrorCodigo.yaExiste);
  });

  test('42501 se traduce a SIN_PERMISO', () {
    final falla = traducirPostgrestException(
      const PostgrestException(message: 'rls', code: '42501'),
    );
    expect(falla.codigo, CatalogoErrorCodigo.sinPermiso);
  });

  test('PGRST116 se traduce a NO_ENCONTRADO', () {
    final falla = traducirPostgrestException(
      const PostgrestException(message: 'not found', code: 'PGRST116'),
    );
    expect(falla.codigo, CatalogoErrorCodigo.noEncontrado);
  });

  test('un errcode de dominio ORxxx conserva el mensaje ya en español', () {
    final falla = traducirPostgrestException(
      const PostgrestException(
        message: 'El vehiculo ya tiene un viaje asignado o en curso.',
        code: 'OR114',
      ),
    );
    expect(falla.mensaje, 'El vehiculo ya tiene un viaje asignado o en curso.');
  });

  test('un codigo desconocido se traduce a un mensaje genérico', () {
    final falla = traducirPostgrestException(
      const PostgrestException(message: 'boom', code: '99999'),
    );
    expect(falla.codigo, CatalogoErrorCodigo.desconocido);
    expect(falla.mensaje, isNot('boom'));
  });
}
