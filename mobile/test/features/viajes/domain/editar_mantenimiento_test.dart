import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/mantenimiento/data/mantenimiento_repository_impl.dart';
import 'package:optiruta/features/mantenimiento/domain/mantenimiento.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/actualizar_viaje_use_case.dart';

class _MockViajeRepo extends Mock implements ViajeRepository {}

class _MockMantenimientoRepo extends Mock implements MantenimientoRepository {}

void main() {
  group('ActualizarViajeUseCase (RF-04)', () {
    test('rechaza flete <= 0 y peso negativo sin llamar al servidor', () {
      final _MockViajeRepo repo = _MockViajeRepo();
      final ActualizarViajeUseCase uc = ActualizarViajeUseCase(repo);

      expect(
        () => uc(
          viajeId: 'v-1',
          fechaSalidaProgramada: DateTime(2026, 10, 20),
          pesoCarga: 20,
          valorFlete: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => uc(
          viajeId: 'v-1',
          fechaSalidaProgramada: DateTime(2026, 10, 20),
          pesoCarga: -1,
          valorFlete: 1000,
        ),
        throwsArgumentError,
      );
      verifyNever(
        () => repo.actualizar(
          viajeId: any(named: 'viajeId'),
          fechaSalidaProgramada: any(named: 'fechaSalidaProgramada'),
          pesoCarga: any(named: 'pesoCarga'),
          valorFlete: any(named: 'valorFlete'),
        ),
      );
    });
  });

  group('Mantenimiento (RF-17)', () {
    test('el caso de uso valida tipo, costo y kilometraje', () {
      final RegistrarMantenimientoUseCase uc = RegistrarMantenimientoUseCase(
        _MockMantenimientoRepo(),
      );
      final DateTime hoy = DateTime(2026, 10, 10);

      expect(
        () => uc(vehiculoId: 'v', tipo: ' ', costo: 100, fecha: hoy),
        throwsArgumentError,
      );
      expect(
        () => uc(vehiculoId: 'v', tipo: 'Llantas', costo: 0, fecha: hoy),
        throwsArgumentError,
      );
      expect(
        () => uc(
          vehiculoId: 'v',
          tipo: 'Llantas',
          costo: 100,
          fecha: hoy,
          kilometraje: -5,
        ),
        throwsArgumentError,
      );
    });

    test('registra con el tipo sin espacios sobrantes', () async {
      final _MockMantenimientoRepo repo = _MockMantenimientoRepo();
      final Mantenimiento esperado = Mantenimiento(
        id: 'm-1',
        vehiculoId: 'v',
        placa: 'ABC123',
        tipo: 'Llantas',
        costo: 2500000,
        fecha: DateTime(2026, 10, 10),
      );
      when(
        () => repo.registrar(
          vehiculoId: 'v',
          tipo: 'Llantas',
          costo: 2500000,
          fecha: DateTime(2026, 10, 10),
          kilometraje: null,
          tipoMantenimientoId: null,
          categoria: CategoriaMantenimiento.preventivo,
          taller: null,
          descripcion: null,
        ),
      ).thenAnswer((_) async => esperado);

      final Mantenimiento m = await RegistrarMantenimientoUseCase(repo)(
        vehiculoId: 'v',
        tipo: ' Llantas ',
        costo: 2500000,
        fecha: DateTime(2026, 10, 10),
      );

      expect(m.placa, 'ABC123');
    });

    test('aEntidad mapea la placa del vehículo embebido', () {
      final Mantenimiento m = MantenimientoRepositoryImpl.aEntidad(
        <String, dynamic>{
          'id': 'm-1',
          'vehiculo_id': 'v',
          'tipo': 'Frenos',
          'costo': 900000,
          'fecha': '2026-10-02',
          'kilometraje': 120500,
          'vehiculo': <String, dynamic>{'placa': 'XYZ789'},
        },
      );

      expect(m.placa, 'XYZ789');
      expect(m.kilometraje, 120500);
      expect(m.fecha, DateTime(2026, 10, 2));
    });
  });
}
