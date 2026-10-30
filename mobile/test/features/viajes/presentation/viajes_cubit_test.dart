import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_viajes_activos_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/listar_viajes_por_rango_use_case.dart';
import 'package:optiruta/features/viajes/presentation/bloc/viajes_cubit.dart';

class _MockViajeRepository extends Mock implements ViajeRepository {}

final DateTime _ahora = DateTime(2026, 10, 29, 9);

ViajeResumen _v(
  String id,
  EstadoViaje estado, {
  DateTime? salida,
  String cliente = 'Distribuidora Andina',
  String placa = 'UFH664',
  String destino = 'Cali',
}) => ViajeResumen(
  id: id,
  remision: 'REM-$id',
  origen: 'Bogotá',
  destino: destino,
  estado: estado,
  placaVehiculo: placa,
  nombreConductor: 'Camilo Rojas',
  nombreCliente: cliente,
  fechaSalidaProgramada: salida,
  fechaCreacion: DateTime(2026, 10, 1),
);

void main() {
  late _MockViajeRepository repo;

  setUp(() {
    repo = _MockViajeRepository();
    registerFallbackValue(DateTime(2026));
  });

  Future<ViajesCubit> crear({
    required List<ViajeResumen> rango,
    List<ViajeResumen> activos = const <ViajeResumen>[],
  }) async {
    when(
      () => repo.listarPorRango(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
      ),
    ).thenAnswer((_) async => rango);
    when(() => repo.listarActivos()).thenAnswer((_) async => activos);
    final ViajesCubit cubit = ViajesCubit(
      listarPorRango: ListarViajesPorRangoUseCase(repo),
      listarActivos: ListarViajesActivosUseCase(repo),
      ahora: () => _ahora,
    );
    await cubit.stream.firstWhere((ViajesState s) => s is! ViajesCargando);
    return cubit;
  }

  test('Hoy trae lo que sale hoy y todo lo que está en curso', () async {
    final ViajesCubit cubit = await crear(
      rango: <ViajeResumen>[
        _v('1', EstadoViaje.asignado, salida: DateTime(2026, 10, 29, 14)),
        _v('2', EstadoViaje.asignado, salida: DateTime(2026, 10, 30, 6)),
        _v('3', EstadoViaje.enCurso, salida: DateTime(2026, 10, 27, 6)),
      ],
    );

    final ViajesListo s = cubit.state as ViajesListo;
    expect(s.filtro, FiltroViajes.hoy);
    expect(s.visibles.map((ViajeResumen v) => v.id), <String>['3', '1']);
    expect(s.cuantos(FiltroViajes.programados), 2);
    expect(s.cuantos(FiltroViajes.enCurso), 1);
  });

  test(
    'los viajes activos fuera de la ventana se suman sin duplicarse',
    () async {
      final ViajeResumen fuera = _v(
        '9',
        EstadoViaje.enCurso,
        salida: DateTime(2026, 6, 1),
      );
      final ViajesCubit cubit = await crear(
        rango: <ViajeResumen>[fuera],
        activos: <ViajeResumen>[fuera],
      );

      expect((cubit.state as ViajesListo).viajes, hasLength(1));
    },
  );

  test('Finalizados va del más reciente al más antiguo', () async {
    final ViajesCubit cubit = await crear(
      rango: <ViajeResumen>[
        _v('1', EstadoViaje.finalizado, salida: DateTime(2026, 10, 10)),
        _v('2', EstadoViaje.cerrado, salida: DateTime(2026, 10, 20)),
        _v('3', EstadoViaje.cancelado, salida: DateTime(2026, 10, 25)),
      ],
    );

    cubit.elegirFiltro(FiltroViajes.finalizados);

    final ViajesListo s = cubit.state as ViajesListo;
    expect(s.visibles.map((ViajeResumen v) => v.id), <String>['2', '1']);
  });

  test(
    'la búsqueda ignora tildes y mayúsculas y recorre varios campos',
    () async {
      final ViajesCubit cubit = await crear(
        rango: <ViajeResumen>[
          _v('1', EstadoViaje.asignado, salida: DateTime(2026, 10, 29, 8)),
          _v(
            '2',
            EstadoViaje.asignado,
            salida: DateTime(2026, 10, 29, 9),
            cliente: 'Cementos Río',
            placa: 'TPK320',
            destino: 'Medellín',
          ),
        ],
      );

      cubit.buscar('medellin');
      expect(
        (cubit.state as ViajesListo).visibles.map((ViajeResumen v) => v.id),
        <String>['2'],
      );
      cubit.buscar('RIO');
      expect(
        (cubit.state as ViajesListo).visibles.map((ViajeResumen v) => v.id),
        <String>['2'],
      );
      cubit.buscar('tpk');
      expect((cubit.state as ViajesListo).visibles, hasLength(1));
    },
  );

  test('recargar en silencio conserva filtro y búsqueda', () async {
    final ViajesCubit cubit = await crear(
      rango: <ViajeResumen>[
        _v('1', EstadoViaje.asignado, salida: DateTime(2026, 10, 29, 8)),
      ],
    );
    cubit
      ..elegirFiltro(FiltroViajes.programados)
      ..buscar('cali');

    await cubit.cargar(silencioso: true);

    final ViajesListo s = cubit.state as ViajesListo;
    expect(s.filtro, FiltroViajes.programados);
    expect(s.busqueda, 'cali');
  });
}
