import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/hito.dart';
import 'package:optiruta/features/viajes/domain/entities/tipo_hito.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/hito_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_hitos_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_viajes_activos_use_case.dart';
import 'package:optiruta/features/viajes/presentation/bloc/seguimiento_en_curso_cubit.dart';
import 'package:optiruta/features/viajes/presentation/bloc/seguimiento_en_curso_state.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockHitoRepository extends Mock implements HitoRepository {}

ViajeResumen _viaje({double? tiempoEstimadoMin}) => ViajeResumen(
  id: 'v-1',
  remision: 'REM-1',
  origen: 'Bogotá',
  destino: 'Barranquilla',
  estado: EstadoViaje.enCurso,
  placaVehiculo: 'TKM218',
  nombreConductor: 'Luis Herrera',
  nombreCliente: 'Distribuidora Andina',
  fechaCreacion: DateTime.now(),
  tiempoEstimadoMin: tiempoEstimadoMin,
);

void main() {
  group('ViajeActivo.calcularRetraso', () {
    test('false sin hito de salida', () {
      final bool r = ViajeActivo.calcularRetraso(
        _viaje(tiempoEstimadoMin: 60),
        const <Hito>[],
      );
      expect(r, isFalse);
    });

    test('true si ya pasó la hora estimada de llegada', () {
      final DateTime salida = DateTime.now().subtract(const Duration(hours: 3));
      final bool r = ViajeActivo.calcularRetraso(
        _viaje(tiempoEstimadoMin: 60),
        <Hito>[
          Hito(
            id: 'h-1',
            viajeId: 'v-1',
            tipo: TipoHito.salida,
            fechaHora: salida,
          ),
        ],
      );
      expect(r, isTrue);
    });

    test('false si ya llegó a destino', () {
      final DateTime salida = DateTime.now().subtract(const Duration(hours: 3));
      final bool r = ViajeActivo.calcularRetraso(
        _viaje(tiempoEstimadoMin: 60),
        <Hito>[
          Hito(
            id: 'h-1',
            viajeId: 'v-1',
            tipo: TipoHito.salida,
            fechaHora: salida,
          ),
          Hito(
            id: 'h-2',
            viajeId: 'v-1',
            tipo: TipoHito.llegadaDestino,
            fechaHora: DateTime.now(),
          ),
        ],
      );
      expect(r, isFalse);
    });
  });

  group('SeguimientoEnCursoCubit', () {
    late _MockViajeRepository viajeRepo;
    late _MockHitoRepository hitoRepo;

    setUp(() {
      viajeRepo = _MockViajeRepository();
      hitoRepo = _MockHitoRepository();
    });

    test('combina viajes activos con sus hitos', () async {
      when(
        () => viajeRepo.listarActivos(),
      ).thenAnswer((_) async => <ViajeResumen>[_viaje(tiempoEstimadoMin: 60)]);
      when(() => hitoRepo.listarPorViaje('v-1'))
          .thenAnswer((_) async => const <Hito>[]);

      final cubit = SeguimientoEnCursoCubit(
        listarActivos: ListarViajesActivosUseCase(viajeRepo),
        listarHitos: ListarHitosUseCase(hitoRepo),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      final SeguimientoEnCursoListo estado =
          cubit.state as SeguimientoEnCursoListo;
      expect(estado.viajes, hasLength(1));
      expect(estado.viajes.first.hitos, isEmpty);
    });

    test('SeguimientoEnCursoError cuando falla la carga', () async {
      when(() => viajeRepo.listarActivos())
          .thenThrow(CatalogoFailure.desconocido());

      final cubit = SeguimientoEnCursoCubit(
        listarActivos: ListarViajesActivosUseCase(viajeRepo),
        listarHitos: ListarHitosUseCase(hitoRepo),
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<SeguimientoEnCursoError>());
    });
  });
}
