import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/dashboard/domain/entities/metricas.dart';
import 'package:optiruta/features/reportes/domain/entities/reporte.dart';
import 'package:optiruta/features/satisfaccion/domain/entities/satisfaccion.dart';
import 'package:optiruta/features/satisfaccion/domain/repositories/satisfaccion_repository.dart';
import 'package:optiruta/features/satisfaccion/domain/usecases/satisfaccion_use_cases.dart';
import 'package:optiruta/features/satisfaccion/presentation/bloc/satisfaccion_cubit.dart';
import 'package:optiruta/features/satisfaccion/presentation/bloc/satisfaccion_state.dart';

class _MockRepo extends Mock implements SatisfaccionRepository {}

ResumenSatisfaccion _resumen({
  int respondidas = 10,
  int total = 20,
  int medidos = 8,
  int aTiempo = 6,
  int percibida = 9,
}) => ResumenSatisfaccion(
  encuestasTotal: total,
  respondidas: respondidas,
  pendientes: 4,
  sinContacto: 1,
  vencidas: 5,
  promotores: 6,
  pasivos: 2,
  detractores: 2,
  viajesMedidos: medidos,
  viajesATiempo: aTiempo,
  puntualidadPercibida: percibida,
  csatGlobal: 4.3,
  nps: 40,
);

void main() {
  group('NivelSatisfaccion', () {
    test('CSAT: verde desde 4,2, ámbar desde 3,5, rojo por debajo', () {
      expect(NivelSatisfaccion.deCsat(4.2), NivelSatisfaccion.bueno);
      expect(NivelSatisfaccion.deCsat(4.19), NivelSatisfaccion.regular);
      expect(NivelSatisfaccion.deCsat(3.5), NivelSatisfaccion.regular);
      expect(NivelSatisfaccion.deCsat(3.49), NivelSatisfaccion.bajo);
      expect(NivelSatisfaccion.deCsat(null), NivelSatisfaccion.sinDatos);
    });

    test('NPS: verde desde 50, ámbar desde 0, rojo negativo', () {
      expect(NivelSatisfaccion.deNps(50), NivelSatisfaccion.bueno);
      expect(NivelSatisfaccion.deNps(49), NivelSatisfaccion.regular);
      expect(NivelSatisfaccion.deNps(0), NivelSatisfaccion.regular);
      expect(NivelSatisfaccion.deNps(-1), NivelSatisfaccion.bajo);
      expect(NivelSatisfaccion.deNps(null), NivelSatisfaccion.sinDatos);
    });
  });

  group('ResumenSatisfaccion', () {
    test('calcula tasa de respuesta y puntualidad real y percibida', () {
      final ResumenSatisfaccion r = _resumen();
      expect(r.tasaRespuestaPct, 50);
      expect(r.puntualidadRealPct, 75);
      expect(r.puntualidadPercibidaPct, 90);
    });

    test('sin base de cálculo no inventa porcentajes', () {
      final ResumenSatisfaccion r = _resumen(
        respondidas: 0,
        total: 0,
        medidos: 0,
        aTiempo: 0,
        percibida: 0,
      );
      expect(r.tasaRespuestaPct, isNull);
      expect(r.puntualidadRealPct, isNull);
      expect(r.puntualidadPercibidaPct, isNull);
    });

    test('exige un mínimo de respuestas para los promedios', () {
      expect(_resumen(respondidas: 4).hayDatosSuficientes, isFalse);
      expect(_resumen(respondidas: 5).hayDatosSuficientes, isTrue);
    });
  });

  group('EncuestaViaje.compartible', () {
    test('solo con enlace y sin respuesta ni vencimiento', () {
      const String enlace = 'https://forms.gle/x';
      expect(
        const EncuestaViaje(
          estado: EstadoEncuesta.enviada,
          enlace: enlace,
        ).compartible,
        isTrue,
      );
      expect(
        const EncuestaViaje(estado: EstadoEncuesta.enviada).compartible,
        isFalse,
      );
      expect(
        const EncuestaViaje(
          estado: EstadoEncuesta.respondida,
          enlace: enlace,
        ).compartible,
        isFalse,
      );
      expect(
        const EncuestaViaje(
          estado: EstadoEncuesta.vencida,
          enlace: enlace,
        ).compartible,
        isFalse,
      );
    });
  });

  group('SatisfaccionCubit', () {
    late _MockRepo repo;

    setUpAll(() {
      registerFallbackValue(
        FiltroReporte(desde: DateTime(2026), hasta: DateTime(2026)),
      );
      registerFallbackValue(DimensionMetrica.ruta);
    });

    setUp(() {
      repo = _MockRepo();
    });

    SatisfaccionCubit crear() => SatisfaccionCubit(
      resumen: ObtenerResumenSatisfaccionUseCase(repo),
      porDimension: ObtenerSatisfaccionPorDimensionUseCase(repo),
      comentarios: ListarComentariosSatisfaccionUseCase(repo),
      cargarOpciones: () async => const OpcionesReporte(),
    );

    blocTest<SatisfaccionCubit, SatisfaccionState>(
      'carga resumen, ranking y comentarios del mes',
      setUp: () {
        when(() => repo.resumen(any())).thenAnswer((_) async => _resumen());
        when(() => repo.comentarios(any(), limite: any(named: 'limite')))
            .thenAnswer((_) async => <ComentarioSatisfaccion>[]);
        when(() => repo.porDimension(any(), any())).thenAnswer(
          (_) async => const <SatisfaccionDimension>[
            SatisfaccionDimension(clave: 'Ana', respondidas: 3),
          ],
        );
      },
      build: crear,
      wait: const Duration(milliseconds: 50),
      expect: () => <Matcher>[
        isA<SatisfaccionListo>()
            .having((SatisfaccionListo s) => s.resumen.respondidas, 'resp', 10)
            .having(
              (SatisfaccionListo s) => s.porDimension.keys.toSet(),
              'dimensiones',
              DimensionMetrica.values.toSet(),
            ),
      ],
    );

    blocTest<SatisfaccionCubit, SatisfaccionState>(
      'una falla de dominio deja el estado de error con su mensaje',
      setUp: () {
        when(() => repo.resumen(any())).thenThrow(CatalogoFailure.sinPermiso());
        when(() => repo.comentarios(any(), limite: any(named: 'limite')))
            .thenAnswer((_) async => <ComentarioSatisfaccion>[]);
        when(() => repo.porDimension(any(), any()))
            .thenAnswer((_) async => <SatisfaccionDimension>[]);
      },
      build: crear,
      wait: const Duration(milliseconds: 50),
      expect: () => <Matcher>[
        isA<SatisfaccionError>().having(
          (SatisfaccionError s) => s.mensaje,
          'mensaje',
          CatalogoFailure.sinPermiso().mensaje,
        ),
      ],
    );
  });
}
