import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/vehiculo_repository.dart';
import 'package:optiruta/features/vehiculos/domain/usecases/crear_vehiculo_use_case.dart';

class _MockRepo extends Mock implements VehiculoRepository {}

void main() {
  late _MockRepo repo;
  late CrearVehiculoUseCase caso;

  const Vehiculo vehiculoCreado = Vehiculo(
    id: 'v-1',
    placa: 'ABC123',
    tipo: TipoVehiculo.dobleTroque,
    capacidadCarga: 17,
    rendimientoKmGalon: 9,
    activo: true,
  );

  setUpAll(() {
    registerFallbackValue(TipoVehiculo.dobleTroque);
  });

  setUp(() {
    repo = _MockRepo();
    caso = CrearVehiculoUseCase(repo);
    when(
      () => repo.crear(
        placa: any(named: 'placa'),
        tipo: any(named: 'tipo'),
        capacidadCarga: any(named: 'capacidadCarga'),
        rendimientoKmGalon: any(named: 'rendimientoKmGalon'),
      ),
    ).thenAnswer((_) async => vehiculoCreado);
  });

  test('normaliza la placa: recorta espacios y pone en mayusculas', () async {
    await caso(
      placa: '  abc123  ',
      tipo: TipoVehiculo.dobleTroque,
      capacidadCarga: 17,
      rendimientoKmGalon: 9,
    );

    verify(
      () => repo.crear(
        placa: 'ABC123',
        tipo: TipoVehiculo.dobleTroque,
        capacidadCarga: 17,
        rendimientoKmGalon: 9,
      ),
    ).called(1);
  });
}
