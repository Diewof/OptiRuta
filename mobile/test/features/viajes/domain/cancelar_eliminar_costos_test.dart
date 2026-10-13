import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/domain/entities/categoria_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/costo_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/fuente_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje.dart';
import 'package:optiruta/features/viajes/domain/repositories/costo_viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/actualizar_estimado_costo_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/agregar_costo_viaje_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/cancelar_eliminar_viaje_use_cases.dart';

class _MockViajeRepo extends Mock implements ViajeRepository {}

class _MockCostoRepo extends Mock implements CostoViajeRepository {}

Viaje _viaje(EstadoViaje e) => Viaje(
  id: 'v-1',
  remision: 'R-1',
  vehiculoId: 'x',
  conductorId: 'y',
  clienteId: 'z',
  origen: 'A',
  destino: 'B',
  estado: e,
  valorFlete: 1000,
  valorAnticipo: 0,
  saldoPendiente: 1000,
  fechaCreacion: DateTime(2026, 10, 1),
);

void main() {
  group('cancelar / eliminar viaje', () {
    late _MockViajeRepo repo;

    setUp(() => repo = _MockViajeRepo());

    test('cancelar exige motivo de al menos 5 letras', () {
      final CancelarViajeUseCase uc = CancelarViajeUseCase(repo);

      expect(() => uc(viajeId: 'v-1', motivo: ' ab '), throwsArgumentError);
      verifyNever(
        () => repo.cancelar(
          viajeId: any(named: 'viajeId'),
          motivo: any(named: 'motivo'),
        ),
      );
    });

    test('cancelar envía el motivo sin espacios sobrantes', () async {
      when(() => repo.cancelar(viajeId: 'v-1', motivo: 'Cliente desistió'))
          .thenAnswer((_) async => _viaje(EstadoViaje.cancelado));

      final Viaje v = await CancelarViajeUseCase(repo)(
        viajeId: 'v-1',
        motivo: '  Cliente desistió ',
      );

      expect(v.estado, EstadoViaje.cancelado);
    });

    test('eliminar exige motivo y lo envía limpio', () async {
      when(() => repo.eliminar(viajeId: 'v-1', motivo: 'Cargado por error'))
          .thenAnswer((_) async {});
      final EliminarViajeUseCase uc = EliminarViajeUseCase(repo);

      expect(() => uc(viajeId: 'v-1', motivo: ''), throwsArgumentError);
      await uc(viajeId: 'v-1', motivo: ' Cargado por error ');

      verify(() => repo.eliminar(viajeId: 'v-1', motivo: 'Cargado por error'))
          .called(1);
    });

    test('EstadoViaje reconoce CANCELADO', () {
      expect(EstadoViaje.desdeCodigo('CANCELADO'), EstadoViaje.cancelado);
    });
  });

  group('costos del administrador (RF-14)', () {
    late _MockCostoRepo repo;

    setUp(() => repo = _MockCostoRepo());

    test('agregar costo con estimado sin valor real', () async {
      when(
        () => repo.agregarOtro(
          viajeId: 'v-1',
          descripcion: 'Escolta',
          valorEstimado: 400000,
          valorReal: null,
        ),
      ).thenAnswer(
        (_) async => const CostoViaje(
          id: 'c-1',
          viajeId: 'v-1',
          categoria: CategoriaCosto.otro,
          valorEstimado: 400000,
          fuente: FuenteCosto.manual,
          descripcion: 'Escolta',
        ),
      );

      final CostoViaje c = await AgregarCostoViajeUseCase(repo)(
        viajeId: 'v-1',
        descripcion: ' Escolta ',
        valorEstimado: 400000,
      );

      expect(c.etiqueta, 'Escolta');
      expect(c.valorReal, isNull);
    });

    test('sin ningún valor positivo no llega al repositorio', () {
      final AgregarCostoViajeUseCase uc = AgregarCostoViajeUseCase(repo);

      expect(
        () => uc(viajeId: 'v-1', descripcion: 'Escolta'),
        throwsArgumentError,
      );
      expect(
        () => uc(viajeId: 'v-1', descripcion: 'Escolta', valorEstimado: -1),
        throwsArgumentError,
      );
    });

    test('corregir estimado rechaza negativos', () async {
      final ActualizarEstimadoCostoUseCase uc = ActualizarEstimadoCostoUseCase(
        repo,
      );

      expect(() => uc(costoId: 'c-1', valorEstimado: -5), throwsArgumentError);
      verifyNever(
        () => repo.actualizarEstimado(
          costoId: any(named: 'costoId'),
          valorEstimado: any(named: 'valorEstimado'),
        ),
      );
    });
  });
}
