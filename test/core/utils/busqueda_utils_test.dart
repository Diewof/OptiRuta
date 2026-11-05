import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/utils/busqueda_utils.dart';

void main() {
  final List<String> nombres = <String>['José Peña', 'Camilo Rojas', 'Ñandú'];

  List<String> buscar(String q) =>
      filtrarPorTexto<String>(nombres, q, (String n) => <String?>[n]);

  test('ignora mayúsculas y tildes', () {
    expect(buscar('JOSE'), <String>['José Peña']);
    expect(buscar('pena'), <String>['José Peña']);
    expect(buscar('nandu'), <String>['Ñandú']);
  });

  test('con la consulta vacía o de espacios devuelve todo', () {
    expect(buscar(''), nombres);
    expect(buscar('   '), nombres);
  });

  test('ignora campos nulos y devuelve vacío si nada coincide', () {
    expect(
      filtrarPorTexto<String>(nombres, 'zzz', (String n) => <String?>[null, n]),
      isEmpty,
    );
  });
}
