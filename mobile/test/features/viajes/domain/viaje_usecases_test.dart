import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/domain/entities/lugar.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/hito.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_consolidada.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_marginal.dart';
import 'package:optiruta/features/viajes/domain/entities/ruta_estimada.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/hito_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/rentabilidad_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/ruta_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/cambiar_estado_viaje_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/cerrar_viaje_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/crear_viaje_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/estimar_acpm_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/estimar_ruta_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_hitos_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_historial_viajes_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_viajes_activos_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_viajes_por_rango_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/rentabilidad_consolidada_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/rentabilidad_marginal_use_case.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockHitoRepository extends Mock implements HitoRepository {}

class _MockRentabilidadRepository extends Mock
    implements RentabilidadRepository {}

class _MockRutaRepository extends Mock implements RutaRepository {}

const Lugar _bogota = Lugar(
  nombre: 'Bogotá',
  coordenada: Coordenada(4.711, -74.0721),
);
const Lugar _cali = Lugar(
  nombre: 'Cali',
  coordenada: Coordenada(3.4516, -76.532),
);

void main() {
  group('ViajeRepository usecases', () {
    late _MockViajeRepository repo;

    setUp(() {
      repo = _MockViajeRepository();
      registerFallbackValue(EstadoViaje.planificado);
    });

    test('CrearViajeUseCase: recorta texto y delega', () async {
      final DateTime fecha = DateTime(2026, 9, 30, 6);
      when(
        () => repo.crear(
          remision: 'REM-001',
          vehiculoId: 'veh-1',
          conductorId: 'con-1',
          clienteId: 'cli-1',
          origen: _bogota,
          destino: _cali,
          rutaPolilinea: 'abc',
          fechaSalidaProgramada: fecha,
          distanciaEstimada: 1012,
          tiempoEstimadoMin: 1080,
          pesoCarga: 28,
          valorFlete: 9200000,
        ),
      ).thenAnswer((_) async => _viajeConFecha(fecha));

      final caso = CrearViajeUseCase(repo);
      await caso(
        remision: '  REM-001  ',
        vehiculoId: 'veh-1',
        conductorId: 'con-1',
        clienteId: 'cli-1',
        origen: const Lugar(
          nombre: '  Bogotá  ',
          coordenada: Coordenada(4.711, -74.0721),
        ),
        destino: const Lugar(
          nombre: '  Cali  ',
          coordenada: Coordenada(3.4516, -76.532),
        ),
        rutaPolilinea: 'abc',
        fechaSalidaProgramada: fecha,
        distanciaEstimada: 1012,
        tiempoEstimadoMin: 1080,
        pesoCarga: 28,
        valorFlete: 9200000,
      );

      verify(
        () => repo.crear(
          remision: 'REM-001',
          vehiculoId: 'veh-1',
          conductorId: 'con-1',
          clienteId: 'cli-1',
          origen: _bogota,
          destino: _cali,
          rutaPolilinea: 'abc',
          fechaSalidaProgramada: fecha,
          distanciaEstimada: 1012,
          tiempoEstimadoMin: 1080,
          pesoCarga: 28,
          valorFlete: 9200000,
        ),
      ).called(1);
    });

    test('CambiarEstadoViajeUseCase: delega en el repositorio', () async {
      when(
        () => repo.cambiarEstado(
          viajeId: 'v-1',
          nuevoEstado: EstadoViaje.asignado,
        ),
      ).thenAnswer((_) async => _viajeConFecha(DateTime(2026)));

      final caso = CambiarEstadoViajeUseCase(repo);
      await caso(viajeId: 'v-1', nuevoEstado: EstadoViaje.asignado);

      verify(
        () => repo.cambiarEstado(
          viajeId: 'v-1',
          nuevoEstado: EstadoViaje.asignado,
        ),
      ).called(1);
    });

    test('CerrarViajeUseCase: delega en el repositorio', () async {
      when(() => repo.cerrar('v-1'))
          .thenAnswer((_) async => _viajeConFecha(DateTime(2026)));

      final caso = CerrarViajeUseCase(repo);
      await caso('v-1');

      verify(() => repo.cerrar('v-1')).called(1);
    });

    test('ListarViajesPorRangoUseCase: delega en el repositorio', () async {
      final DateTime desde = DateTime(2026, 9);
      final DateTime hasta = DateTime(2026, 10);
      when(() => repo.listarPorRango(desde: desde, hasta: hasta))
          .thenAnswer((_) async => const <ViajeResumen>[]);

      final caso = ListarViajesPorRangoUseCase(repo);
      await caso(desde: desde, hasta: hasta);

      verify(() => repo.listarPorRango(desde: desde, hasta: hasta)).called(1);
    });

    test('ListarViajesActivosUseCase: delega en el repositorio', () async {
      when(() => repo.listarActivos())
          .thenAnswer((_) async => const <ViajeResumen>[]);

      final caso = ListarViajesActivosUseCase(repo);
      await caso();

      verify(() => repo.listarActivos()).called(1);
    });

    test('ListarHistorialViajesUseCase: delega con el filtro dado', () async {
      when(
        () => repo.listarHistorial(
          pagina: 0,
          tamano: 20,
          filtroEstado: EstadoViaje.cerrado,
        ),
      ).thenAnswer(
        (_) async =>
            const PaginaViajes(viajes: <ViajeResumen>[], hayMas: false),
      );

      final caso = ListarHistorialViajesUseCase(repo);
      await caso(pagina: 0, filtroEstado: EstadoViaje.cerrado);

      verify(
        () => repo.listarHistorial(
          pagina: 0,
          tamano: 20,
          filtroEstado: EstadoViaje.cerrado,
        ),
      ).called(1);
    });

    test('EstimarAcpmUseCase: delega en el repositorio', () async {
      when(
        () => repo.estimarAcpm(
          vehiculoId: 'veh-1',
          distanciaKm: 1012,
          ciudad: 'Bogotá',
        ),
      ).thenAnswer((_) async => 1840000);

      final caso = EstimarAcpmUseCase(repo);
      await caso(vehiculoId: 'veh-1', distanciaKm: 1012, ciudad: 'Bogotá');

      verify(
        () => repo.estimarAcpm(
          vehiculoId: 'veh-1',
          distanciaKm: 1012,
          ciudad: 'Bogotá',
        ),
      ).called(1);
    });
  });

  test('EstimarRutaUseCase: recorta origen/destino y delega', () async {
    final _MockRutaRepository repo = _MockRutaRepository();
    when(
      () => repo.estimar(origen: _bogota.coordenada, destino: _cali.coordenada),
    ).thenAnswer(
      (_) async => const RutaEstimada(distanciaKm: 1012, duracionMin: 1080),
    );

    final caso = EstimarRutaUseCase(repo);
    await caso(origen: _bogota.coordenada, destino: _cali.coordenada);

    verify(
      () => repo.estimar(origen: _bogota.coordenada, destino: _cali.coordenada),
    ).called(1);
  });

  test('ListarHitosUseCase: delega en el repositorio', () async {
    final _MockHitoRepository repo = _MockHitoRepository();
    when(() => repo.listarPorViaje('v-1'))
        .thenAnswer((_) async => const <Hito>[]);

    final caso = ListarHitosUseCase(repo);
    await caso('v-1');

    verify(() => repo.listarPorViaje('v-1')).called(1);
  });

  test('RentabilidadMarginalUseCase: delega en el repositorio', () async {
    final _MockRentabilidadRepository repo = _MockRentabilidadRepository();
    when(() => repo.marginal('v-1')).thenAnswer(
      (_) async => const RentabilidadMarginal(
        valorFlete: 1000000,
        costosTotales: 400000,
        rentabilidad: 600000,
      ),
    );

    final caso = RentabilidadMarginalUseCase(repo);
    await caso('v-1');

    verify(() => repo.marginal('v-1')).called(1);
  });

  test('RentabilidadConsolidadaUseCase: delega en el repositorio', () async {
    final _MockRentabilidadRepository repo = _MockRentabilidadRepository();
    final DateTime desde = DateTime(2026, 9, 1);
    final DateTime hasta = DateTime(2026, 9, 30);
    when(() => repo.consolidada(desde: desde, hasta: hasta)).thenAnswer(
      (_) async => const RentabilidadConsolidada(
        totalFlete: 0,
        totalCostosDirectos: 0,
        mantenimientoAmortizado: 0,
        sueldoFijoProrrateado: 0,
        rentabilidadConsolidada: 0,
        viajesIncluidos: 0,
      ),
    );

    final caso = RentabilidadConsolidadaUseCase(repo);
    await caso(desde: desde, hasta: hasta);

    verify(() => repo.consolidada(desde: desde, hasta: hasta)).called(1);
  });
}

Viaje _viajeConFecha(DateTime fecha) {
  return Viaje(
    id: 'v-1',
    remision: 'REM-001',
    vehiculoId: 'veh-1',
    conductorId: 'con-1',
    clienteId: 'cli-1',
    origen: 'Bogotá',
    destino: 'Cali',
    estado: EstadoViaje.planificado,
    valorFlete: 1000000,
    valorAnticipo: 0,
    saldoPendiente: 1000000,
    fechaCreacion: fecha,
  );
}
