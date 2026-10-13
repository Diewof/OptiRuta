import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/reportes/data/repositories/reporte_repository_impl.dart';
import 'package:optiruta/features/reportes/data/servicios/exportador_reporte_pdf.dart';
import 'package:optiruta/features/reportes/domain/entities/reporte.dart';
import 'package:optiruta/features/reportes/domain/repositories/reporte_repository.dart';
import 'package:optiruta/features/reportes/domain/usecases/reporte_use_cases.dart';
import 'package:optiruta/features/reportes/presentation/bloc/reportes_cubit.dart';

class _MockRepo extends Mock implements ReporteRepository {}

class _MockExportador extends Mock implements ExportadorReporte {}

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

void main() {
  setUpAll(() {
    registerFallbackValue(
      FiltroReporte(desde: DateTime(2026), hasta: DateTime(2026)),
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

  test('el caso de uso rechaza un rango invertido sin llamar al servidor', () {
    final _MockRepo repo = _MockRepo();
    final ObtenerReporteViajesUseCase uc = ObtenerReporteViajesUseCase(repo);

    expect(
      () => uc(
        FiltroReporte(
          desde: DateTime(2026, 10, 9),
          hasta: DateTime(2026, 10, 1),
        ),
      ),
      throwsArgumentError,
    );
    verifyNever(() => repo.viajes(any()));
  });

  test('exportar sin filas falla: no hay nada que exportar', () {
    final ExportarReportePdfUseCase uc = ExportarReportePdfUseCase(
      _MockExportador(),
    );

    expect(
      () => uc(
        filtro: FiltroReporte(desde: DateTime(2026), hasta: DateTime(2026)),
        descripcionFiltros: '',
        filas: const <FilaReporte>[],
      ),
      throwsStateError,
    );
  });

  test('el cubit consulta con el filtro y guarda las filas', () async {
    final _MockRepo repo = _MockRepo();
    when(() => repo.viajes(any()))
        .thenAnswer((_) async => <FilaReporte>[_fila('1', 1000, 400)]);
    final ReportesCubit cubit = ReportesCubit(
      obtener: ObtenerReporteViajesUseCase(repo),
      exportar: ExportarReportePdfUseCase(_MockExportador()),
      cargarOpciones: () async => const OpcionesReporte(
        clientes: <OpcionFiltro>[OpcionFiltro('c-1', 'Cliente A')],
      ),
      hoy: DateTime(2026, 10, 10),
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.estado, EstadoReporte.listo);
    expect(cubit.state.filas, hasLength(1));
    expect(cubit.state.filtro.desde, DateTime(2026, 10));

    await cubit.aplicarFiltro(
      cubit.state.filtro.copiarCon(clienteId: () => 'c-1'),
    );

    final FiltroReporte enviado =
        verify(() => repo.viajes(captureAny())).captured.last as FiltroReporte;
    expect(enviado.clienteId, 'c-1');
    expect(cubit.state.descripcionFiltros, contains('Cliente: Cliente A'));
  });

  test('exportarPdf pasa los filtros activos al exportador', () async {
    final _MockRepo repo = _MockRepo();
    final _MockExportador exportador = _MockExportador();
    when(() => repo.viajes(any()))
        .thenAnswer((_) async => <FilaReporte>[_fila('1', 1000, 400)]);
    when(
      () => exportador.exportarPdf(
        filtro: any(named: 'filtro'),
        descripcionFiltros: any(named: 'descripcionFiltros'),
        filas: any(named: 'filas'),
      ),
    ).thenAnswer((_) async {});
    final ReportesCubit cubit = ReportesCubit(
      obtener: ObtenerReporteViajesUseCase(repo),
      exportar: ExportarReportePdfUseCase(exportador),
      cargarOpciones: () async => const OpcionesReporte(),
      hoy: DateTime(2026, 10, 10),
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    await cubit.exportarPdf();

    verify(
      () => exportador.exportarPdf(
        filtro: any(named: 'filtro'),
        descripcionFiltros: any(named: 'descripcionFiltros'),
        filas: any(named: 'filas'),
      ),
    ).called(1);
    expect(cubit.state.exportando, isFalse);
    expect(cubit.state.mensaje, isNull);
  });

  test('el PDF se genera con las filas y los totales', () async {
    final bytes = await const ExportadorReportePdf().construir(
      filtro: FiltroReporte(
        desde: DateTime(2026, 10),
        hasta: DateTime(2026, 10, 10),
      ),
      descripcionFiltros: 'Cliente: Todos',
      filas: <FilaReporte>[_fila('1', 1000000, 400000)],
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
