import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/lugar.dart';
import 'package:optiruta/features/viajes/domain/repositories/ruta_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/buscar_lugares_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/lugar_en_coordenada_use_case.dart';
import 'package:optiruta/features/viajes/presentation/bloc/selector_ubicacion_cubit.dart';

class _MockRutaRepository extends Mock implements RutaRepository {}

const Lugar _medellin = Lugar(
  nombre: 'Medellín, Antioquia',
  coordenada: Coordenada(6.2442, -75.5812),
);

void main() {
  late _MockRutaRepository repo;

  setUp(() {
    repo = _MockRutaRepository();
    registerFallbackValue(const Coordenada(0, 0));
  });

  SelectorUbicacionCubit crear({Lugar? inicial}) => SelectorUbicacionCubit(
    buscar: BuscarLugaresUseCase(repo),
    lugarEn: LugarEnCoordenadaUseCase(repo),
    inicial: inicial,
  );

  test('arranca con el lugar inicial como selección', () {
    final cubit = crear(inicial: _medellin);
    addTearDown(cubit.close);

    expect(cubit.state.seleccion, _medellin);
  });

  test('buscar con menos de 3 letras no consulta al proveedor', () async {
    final cubit = crear();
    addTearDown(cubit.close);

    await cubit.buscar('Me');

    verifyNever(() => repo.buscarLugares(any()));
    expect(cubit.state.resultados, isEmpty);
  });

  test('buscar guarda las sugerencias', () async {
    when(() => repo.buscarLugares('Medel'))
        .thenAnswer((_) async => <Lugar>[_medellin]);
    final cubit = crear();
    addTearDown(cubit.close);

    await cubit.buscar('Medel');

    expect(cubit.state.resultados, <Lugar>[_medellin]);
    expect(cubit.state.buscando, isFalse);
    expect(cubit.state.busquedaSinResultados, isFalse);
  });

  test('buscar sin coincidencias lo indica', () async {
    when(() => repo.buscarLugares(any())).thenAnswer((_) async => <Lugar>[]);
    final cubit = crear();
    addTearDown(cubit.close);

    await cubit.buscar('Zzzzz');

    expect(cubit.state.busquedaSinResultados, isTrue);
  });

  test('buscar con falla guarda el mensaje', () async {
    when(() => repo.buscarLugares(any()))
        .thenThrow(CatalogoFailure.sinConexion());
    final cubit = crear();
    addTearDown(cubit.close);

    await cubit.buscar('Medellín');

    expect(cubit.state.error, CatalogoFailure.sinConexion().mensaje);
    expect(cubit.state.buscando, isFalse);
  });

  test('una respuesta tardía de una búsqueda vieja se descarta', () async {
    final Completer<List<Lugar>> lenta = Completer<List<Lugar>>();
    when(() => repo.buscarLugares('Bogotá')).thenAnswer((_) => lenta.future);
    when(() => repo.buscarLugares('Medellín'))
        .thenAnswer((_) async => <Lugar>[_medellin]);
    final cubit = crear();
    addTearDown(cubit.close);

    final Future<void> primera = cubit.buscar('Bogotá');
    await cubit.buscar('Medellín');
    lenta.complete(<Lugar>[]);
    await primera;

    expect(cubit.state.resultados, <Lugar>[_medellin]);
  });

  test('elegirResultado fija la selección y limpia la lista', () async {
    when(() => repo.buscarLugares(any()))
        .thenAnswer((_) async => <Lugar>[_medellin]);
    final cubit = crear();
    addTearDown(cubit.close);
    await cubit.buscar('Medel');

    cubit.elegirResultado(_medellin);

    expect(cubit.state.seleccion, _medellin);
    expect(cubit.state.resultados, isEmpty);
    expect(cubit.state.resolviendo, isFalse);
  });

  test('moverPin resuelve el nombre del punto', () async {
    when(() => repo.lugarEn(any())).thenAnswer((_) async => _medellin);
    final cubit = crear();
    addTearDown(cubit.close);

    await cubit.moverPin(_medellin.coordenada);

    expect(cubit.state.seleccion, _medellin);
    expect(cubit.state.resolviendo, isFalse);
  });

  test('moverPin sin nombre conserva la coordenada elegida', () async {
    when(() => repo.lugarEn(any())).thenThrow(CatalogoFailure.sinConexion());
    final cubit = crear();
    addTearDown(cubit.close);

    await cubit.moverPin(const Coordenada(6.2442, -75.5812));

    expect(
      cubit.state.seleccion?.coordenada,
      const Coordenada(6.2442, -75.5812),
    );
    expect(cubit.state.seleccion?.nombre, '6.2442, -75.5812');
    expect(cubit.state.error, isNotNull);
  });
}
