import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/lugar.dart';
import 'package:optiruta/features/viajes/domain/repositories/ruta_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/buscar_lugares_use_case.dart';

class _MockRutaRepository extends Mock implements RutaRepository {}

void main() {
  test('BuscarLugaresUseCase: recorta y delega', () async {
    final repo = _MockRutaRepository();
    const Lugar lugar = Lugar(
      nombre: 'Cali, Valle del Cauca',
      coordenada: Coordenada(3.4516, -76.532),
    );
    when(() => repo.buscarLugares('Cali'))
        .thenAnswer((_) async => <Lugar>[lugar]);

    final List<Lugar> resultado = await BuscarLugaresUseCase(repo)('  Cali  ');

    expect(resultado, <Lugar>[lugar]);
  });

  test('BuscarLugaresUseCase: con menos de 3 letras no consulta', () async {
    final repo = _MockRutaRepository();

    final List<Lugar> resultado = await BuscarLugaresUseCase(repo)(' ca ');

    expect(resultado, isEmpty);
    verifyNever(() => repo.buscarLugares(any()));
  });
}
