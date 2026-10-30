import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/calidad/domain/entities/calidad.dart';
import 'package:optiruta/features/calidad/domain/repositories/calidad_repository.dart';
import 'package:optiruta/features/dashboard/domain/entities/metricas.dart';
import 'package:optiruta/features/dashboard/domain/repositories/metricas_repository.dart';
import 'package:optiruta/features/reportes/data/repositories/reporte_repository_impl.dart';
import 'package:optiruta/features/reportes/data/servicios/exportador_reporte_pdf.dart';
import 'package:optiruta/features/reportes/domain/entities/informe.dart';
import 'package:optiruta/features/reportes/domain/entities/reporte.dart';
import 'package:optiruta/features/reportes/domain/repositories/reporte_repository.dart';
import 'package:optiruta/features/reportes/domain/usecases/informes_use_cases.dart';
import 'package:optiruta/features/reportes/domain/usecases/reporte_use_cases.dart';
import 'package:optiruta/features/reportes/presentation/bloc/reportes_cubit.dart';
import 'package:optiruta/features/satisfaccion/domain/entities/satisfaccion.dart';
import 'package:optiruta/features/satisfaccion/domain/repositories/satisfaccion_repository.dart';
import 'package:optiruta/features/viajes/domain/entities/categoria_costo.dart';
import 'package:optiruta/features/viajes/domain/entities/rentabilidad_consolidada.dart';
import 'package:optiruta/features/viajes/domain/repositories/rentabilidad_repository.dart';

class _MockReportes extends Mock implements ReporteRepository {}

class _MockExportador extends Mock implements ExportadorReporte {}

class _MockRentabilidad extends Mock implements RentabilidadRepository {}

class _MockMetricas extends Mock implements MetricasRepository {}

class _MockCalidad extends Mock implements CalidadRepository {}

class _MockSatisfaccion extends Mock implements SatisfaccionRepository {}

FilaReporte _fila(String rem, double flete, double costos) => FilaReporte(
  viajeId: 'v-$rem',
  remision: rem,
  fechaCierre: DateTime(2026, 10, 5),
  ruta: 'Medellín → Bogotá',
  cliente: 'Cliente A',
  conductor: 'Luis',
  placa: 'ABC123',
  km: 400,
  valorFlete: flete,
  costos: costos,
  rentabilidad: flete - costos,
  aTiempo: true,
);

RentabilidadConsolidada _consolidada({
  double flete = 10000000,
  double directos = 6000000,
  double mantenimiento = 500000,
  double sueldo = 500000,
  int viajes = 4,
}) => RentabilidadConsolidada(
  totalFlete: flete,
  totalCostosDirectos: directos,
  mantenimientoAmortizado: mantenimiento,
  sueldoFijoProrrateado: sueldo,
  rentabilidadConsolidada: flete - directos - mantenimiento - sueldo,
  viajesIncluidos: viajes,
  costosPorCategoria: <CategoriaCosto, double>{
    CategoriaCosto.acpm: directos * 0.7,
    CategoriaCosto.peaje: directos * 0.3,
  },
);

MetricaDimension _metrica(String clave, {int aTiempo = 1, int medidos = 2}) =>
    MetricaDimension(
      clave: clave,
      viajes: 3,
      totalFlete: 3000000,
      totalCostos: 2000000,
      rentabilidad: 1000000,
      kmTotal: 900,
      viajesATiempo: aTiempo,
      viajesMedidos: medidos,
      margenPct: 33.3,
    );

void main() {
  final FiltroReporte filtro = FiltroReporte(
    desde: DateTime(2026, 10),
    hasta: DateTime(2026, 10, 10),
  );

  setUpAll(() {
    registerFallbackValue(filtro);
    registerFallbackValue(DimensionMetrica.ruta);
    registerFallbackValue(DimensionCalidad.ruta);
    registerFallbackValue(
      const Informe(titulo: 't', columnas: <String>[], filas: <List<String>>[]),
    );
  });

  test('aEntidad mapea la fila de la RPC (a_tiempo puede ser nulo)', () {
    final FilaReporte f = ReporteRepositoryImpl.aEntidad(<String, dynamic>{
      'viaje_id': 'v-1',
      'remision': 'R-1',
      'fecha_cierre': '2026-10-05',
      'ruta': 'A → B',
      'cliente': 'C',
      'conductor': 'D',
      'placa': 'XYZ789',
      'km': 120,
      'valor_flete': 1000000,
      'costos': 400000,
      'rentabilidad': 600000,
      'a_tiempo': null,
    });

    expect(f.rentabilidad, 600000);
    expect(f.aTiempo, isNull);
    expect(f.fechaCierre, DateTime(2026, 10, 5));
  });

  test('TotalesReporte suma viajes, km, flete, costos y rentabilidad', () {
    final TotalesReporte t = TotalesReporte.de(<FilaReporte>[
      _fila('1', 1000, 400),
      _fila('2', 2000, 500),
    ]);

    expect(t.viajes, 2);
    expect(t.km, 800);
    expect(t.valorFlete, 3000);
    expect(t.rentabilidad, 2100);
  });

  group('informes', () {
    test('viajes: una fila por viaje y línea de totales', () async {
      final _MockReportes repo = _MockReportes();
      when(() => repo.viajes(any()))
          .thenAnswer((_) async => <FilaReporte>[_fila('1', 1000000, 400000)]);

      final Informe i = await InformeViajes(repo)(
        filtro,
        DimensionMetrica.ruta,
      );

      expect(i.filas, hasLength(1));
      expect(i.filas.first.length, i.columnas.length);
      expect(i.filas.first[8], r'$600.000');
      expect(i.resumen, contains('1 viajes'));
    });

    test('estado de resultados compara con el período anterior de igual '
        'duración', () async {
      final _MockRentabilidad repo = _MockRentabilidad();
      when(
        () => repo.consolidada(
          desde: any(named: 'desde'),
          hasta: any(named: 'hasta'),
          clienteId: any(named: 'clienteId'),
          conductorId: any(named: 'conductorId'),
          vehiculoId: any(named: 'vehiculoId'),
          ruta: any(named: 'ruta'),
        ),
      ).thenAnswer((_) async => _consolidada());

      final Informe i = await InformeEstadoResultados(repo)(
        filtro,
        DimensionMetrica.ruta,
      );

      // 1–10 de octubre (10 días) → anterior 21–30 de septiembre.
      final List<DateTime> desdes = verify(
        () => repo.consolidada(
          desde: captureAny(named: 'desde'),
          hasta: any(named: 'hasta'),
          clienteId: any(named: 'clienteId'),
          conductorId: any(named: 'conductorId'),
          vehiculoId: any(named: 'vehiculoId'),
          ruta: any(named: 'ruta'),
        ),
      ).captured.cast<DateTime>();
      expect(desdes, contains(DateTime(2026, 9, 21)));
      expect(i.filas.first, <String>[
        'Fletes',
        r'$10.000.000',
        r'$10.000.000',
        '0,0 %',
      ]);
      expect(i.notas, isEmpty);
    });

    test('estado de resultados avisa que con cliente o ruta no se atribuyen '
        'mantenimiento ni sueldo', () async {
      final _MockRentabilidad repo = _MockRentabilidad();
      when(
        () => repo.consolidada(
          desde: any(named: 'desde'),
          hasta: any(named: 'hasta'),
          clienteId: any(named: 'clienteId'),
          conductorId: any(named: 'conductorId'),
          vehiculoId: any(named: 'vehiculoId'),
          ruta: any(named: 'ruta'),
        ),
      ).thenAnswer((_) async => _consolidada());

      final Informe i = await InformeEstadoResultados(repo)(
        filtro.copiarCon(clienteId: () => 'c-1'),
        DimensionMetrica.ruta,
      );

      expect(i.notas, hasLength(1));
    });

    test(
      'estado de resultados sin viajes en ambos períodos queda vacío',
      () async {
        final _MockRentabilidad repo = _MockRentabilidad();
        when(
          () => repo.consolidada(
            desde: any(named: 'desde'),
            hasta: any(named: 'hasta'),
            clienteId: any(named: 'clienteId'),
            conductorId: any(named: 'conductorId'),
            vehiculoId: any(named: 'vehiculoId'),
            ruta: any(named: 'ruta'),
          ),
        ).thenAnswer(
          (_) async => _consolidada(
            flete: 0,
            directos: 0,
            mantenimiento: 0,
            sueldo: 0,
            viajes: 0,
          ),
        );

        final Informe i = await InformeEstadoResultados(repo)(
          filtro,
          DimensionMetrica.ruta,
        );

        expect(i.filas, isEmpty);
      },
    );

    test('costos: ordena de mayor a menor con el % sobre el total', () async {
      final _MockRentabilidad repo = _MockRentabilidad();
      when(
        () => repo.consolidada(
          desde: any(named: 'desde'),
          hasta: any(named: 'hasta'),
          clienteId: any(named: 'clienteId'),
          conductorId: any(named: 'conductorId'),
          vehiculoId: any(named: 'vehiculoId'),
          ruta: any(named: 'ruta'),
        ),
      ).thenAnswer((_) async => _consolidada());

      final Informe i = await InformeCostos(repo)(
        filtro,
        DimensionMetrica.ruta,
      );

      expect(i.filas.first[0], 'ACPM');
      // 4,2 M de 7,0 M de costos totales.
      expect(i.filas.first[2], '60,0 %');
      expect(
        i.filas.map((List<String> f) => f[0]),
        contains('Sueldo fijo prorrateado'),
      );
    });

    test(
      'puntualidad: los menos puntuales primero y los sin medir al final',
      () async {
        final _MockMetricas repo = _MockMetricas();
        when(
          () => repo.porDimension(
            desde: any(named: 'desde'),
            hasta: any(named: 'hasta'),
            dimension: any(named: 'dimension'),
            clienteId: any(named: 'clienteId'),
            conductorId: any(named: 'conductorId'),
            vehiculoId: any(named: 'vehiculoId'),
            ruta: any(named: 'ruta'),
          ),
        ).thenAnswer(
          (_) async => <MetricaDimension>[
            _metrica('Sin medir', aTiempo: 0, medidos: 0),
            _metrica('Puntual', aTiempo: 2, medidos: 2),
            _metrica('Tarde', aTiempo: 0, medidos: 2),
          ],
        );

        final Informe i = await InformePuntualidad(repo)(
          filtro,
          DimensionMetrica.conductor,
        );

        expect(i.filas.map((List<String> f) => f[0]), <String>[
          'Tarde',
          'Puntual',
          'Sin medir',
        ]);
        expect(i.filas.first[5], '0,0 %');
        expect(i.resumen, contains('50,0 %'));
      },
    );

    test('calidad rechaza una agrupación que su RPC no acepta', () {
      expect(
        () => InformeCalidad(_MockCalidad())(filtro, DimensionMetrica.cliente),
        throwsArgumentError,
      );
    });

    test('desempeño por conductor une las tres fuentes por nombre y oculta '
        'CSAT con pocas respuestas', () async {
      final _MockMetricas metricas = _MockMetricas();
      final _MockCalidad calidad = _MockCalidad();
      final _MockSatisfaccion satisfaccion = _MockSatisfaccion();
      when(
        () => metricas.porDimension(
          desde: any(named: 'desde'),
          hasta: any(named: 'hasta'),
          dimension: any(named: 'dimension'),
          clienteId: any(named: 'clienteId'),
          conductorId: any(named: 'conductorId'),
          vehiculoId: any(named: 'vehiculoId'),
          ruta: any(named: 'ruta'),
        ),
      ).thenAnswer(
        (_) async => <MetricaDimension>[_metrica('Luis'), _metrica('Ana')],
      );
      when(() => calidad.porDimension(any(), any())).thenAnswer(
        (_) async => const <CalidadDimension>[
          CalidadDimension(
            clave: 'Luis',
            viajes: 3,
            rojos: 0,
            puntualidadRojos: 0,
            rentabilidadRojos: 0,
            satisfaccionRojos: 0,
            incidenciasRojos: 0,
            puntajePromedio: 90,
          ),
        ],
      );
      when(() => satisfaccion.porDimension(any(), any())).thenAnswer(
        (_) async => const <SatisfaccionDimension>[
          SatisfaccionDimension(
            clave: 'Luis',
            respondidas: 6,
            csatGlobal: 4.5,
            nps: 60,
          ),
          SatisfaccionDimension(
            clave: 'Ana',
            respondidas: 2,
            csatGlobal: 5,
            nps: 100,
          ),
        ],
      );

      final Informe i = await InformeConductores(
        metricas,
        calidad,
        satisfaccion,
      )(filtro, DimensionMetrica.conductor);

      final List<String> luis = i.filas.firstWhere((f) => f[0] == 'Luis');
      final List<String> ana = i.filas.firstWhere((f) => f[0] == 'Ana');
      expect(luis[6], '90 · Conforme');
      expect(luis[7], '4,5');
      expect(luis[8], '60');
      expect(ana[6], '—');
      expect(ana[7], '—');
      expect(ana[8], '—');
    });

    test(
      'el caso de uso rechaza un rango invertido sin llamar al servidor',
      () {
        final _MockReportes repo = _MockReportes();
        final ObtenerInformeUseCase uc = ObtenerInformeUseCase(
          <TipoInforme, ConstructorInforme>{
            TipoInforme.viajes: InformeViajes(repo),
          },
        );

        expect(
          () => uc(
            TipoInforme.viajes,
            FiltroReporte(
              desde: DateTime(2026, 10, 9),
              hasta: DateTime(2026, 10, 1),
            ),
            DimensionMetrica.ruta,
          ),
          throwsArgumentError,
        );
        verifyNever(() => repo.viajes(any()));
      },
    );
  });

  test('exportar sin filas falla: no hay nada que exportar', () {
    final ExportarReportePdfUseCase uc = ExportarReportePdfUseCase(
      _MockExportador(),
    );

    expect(
      () => uc(
        informe: const Informe(
          titulo: 't',
          columnas: <String>['a'],
          filas: <List<String>>[],
        ),
        descripcionFiltros: '',
        nombreArchivo: 'x.pdf',
      ),
      throwsStateError,
    );
  });

  group('cubit', () {
    ReportesCubit crear(_MockReportes repo, ExportadorReporte exportador) {
      return ReportesCubit(
        obtener: ObtenerInformeUseCase(<TipoInforme, ConstructorInforme>{
          TipoInforme.viajes: InformeViajes(repo),
          TipoInforme.satisfaccion: _InformeFijo(),
          TipoInforme.rentabilidad: _InformeFijo(),
        }),
        exportar: ExportarReportePdfUseCase(exportador),
        cargarOpciones: () async => const OpcionesReporte(
          clientes: <OpcionFiltro>[OpcionFiltro('c-1', 'Cliente A')],
        ),
        hoy: DateTime(2026, 10, 10),
      );
    }

    Future<void> asentar() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('consulta con el filtro y guarda el informe', () async {
      final _MockReportes repo = _MockReportes();
      when(() => repo.viajes(any()))
          .thenAnswer((_) async => <FilaReporte>[_fila('1', 1000, 400)]);
      final ReportesCubit cubit = crear(repo, _MockExportador());
      addTearDown(cubit.close);
      await asentar();

      expect(cubit.state.estado, EstadoReporte.listo);
      expect(cubit.state.informe!.filas, hasLength(1));
      expect(cubit.state.filtro.desde, DateTime(2026, 10));

      await cubit.aplicarFiltro(
        cubit.state.filtro.copiarCon(clienteId: () => 'c-1'),
      );

      final FiltroReporte enviado =
          verify(() => repo.viajes(captureAny())).captured.last
              as FiltroReporte;
      expect(enviado.clienteId, 'c-1');
      expect(cubit.state.descripcionFiltros, contains('Cliente: Cliente A'));
    });

    test(
      'cambiar de informe ajusta la agrupación y el encabezado del PDF',
      () async {
        final _MockReportes repo = _MockReportes();
        when(() => repo.viajes(any())).thenAnswer((_) async => <FilaReporte>[]);
        final ReportesCubit cubit = crear(repo, _MockExportador());
        addTearDown(cubit.close);
        await asentar();

        await cubit.cambiarTipo(TipoInforme.satisfaccion);

        expect(cubit.state.tipo, TipoInforme.satisfaccion);
        // «Ruta» sí es válida en satisfacción, así que se conserva.
        expect(cubit.state.dimension, DimensionMetrica.ruta);
        expect(cubit.state.descripcionFiltros, contains('Agrupado por: Ruta'));

        await cubit.cambiarDimension(DimensionMetrica.cliente);
        expect(cubit.state.dimension, DimensionMetrica.cliente);
        expect(cubit.state.nombreArchivo, startsWith('informe-satisfaccion-'));
      },
    );

    test(
      'exportarPdf pasa el informe y los filtros activos al exportador',
      () async {
        final _MockReportes repo = _MockReportes();
        final _MockExportador exportador = _MockExportador();
        when(() => repo.viajes(any()))
            .thenAnswer((_) async => <FilaReporte>[_fila('1', 1000, 400)]);
        when(
          () => exportador.exportarPdf(
            informe: any(named: 'informe'),
            descripcionFiltros: any(named: 'descripcionFiltros'),
            nombreArchivo: any(named: 'nombreArchivo'),
          ),
        ).thenAnswer((_) async {});
        final ReportesCubit cubit = crear(repo, exportador);
        addTearDown(cubit.close);
        await asentar();

        await cubit.exportarPdf();

        verify(
          () => exportador.exportarPdf(
            informe: any(named: 'informe'),
            descripcionFiltros: any(named: 'descripcionFiltros'),
            nombreArchivo: any(named: 'nombreArchivo'),
          ),
        ).called(1);
        expect(cubit.state.exportando, isFalse);
        expect(cubit.state.mensaje, isNull);
      },
    );
  });

  test('el PDF se genera con las filas, el resumen y las notas', () async {
    final bytes = await const ExportadorReportePdf().construir(
      informe: const Informe(
        titulo: 'Prueba',
        columnas: <String>['Concepto', 'Monto'],
        numericas: <int>{1},
        filas: <List<String>>[
          <String>['Fletes', r'$1.000.000'],
        ],
        resumen: 'Total',
        notas: <String>['Una nota'],
      ),
      descripcionFiltros: 'Cliente: Todos',
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}

/// Informe fijo para probar el cubit sin depender de repositorios.
class _InformeFijo implements ConstructorInforme {
  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    return const Informe(
      titulo: 'Fijo',
      columnas: <String>['a'],
      filas: <List<String>>[
        <String>['1'],
      ],
    );
  }
}
