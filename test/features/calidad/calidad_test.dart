import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/calidad/domain/entities/calidad.dart';
import 'package:optiruta/features/calidad/domain/repositories/calidad_repository.dart';
import 'package:optiruta/features/calidad/domain/usecases/calidad_use_cases.dart';
import 'package:optiruta/features/calidad/presentation/widgets/calidad_conductor_indicador.dart';
import 'package:optiruta/features/calidad/presentation/widgets/calidad_viaje_card.dart';

class _MockCalidad extends Mock implements CalidadRepository {}

void main() {
  group('AlertaRecurrente.mensaje', () {
    test('incidencias de una placa piden revisar hábitos de conducción', () {
      const AlertaRecurrente a = AlertaRecurrente(
        entidad: 'VEHICULO',
        clave: 'ABC123',
        dimension: 'INCIDENCIAS',
        viajes: 3,
      );
      expect(a.mensaje, 'Revisar hábitos de conducción en placa ABC123');
    });

    test('sobrecostos de una ruta se nombran como tales', () {
      const AlertaRecurrente a = AlertaRecurrente(
        entidad: 'RUTA',
        clave: 'Medellín → Bogotá',
        dimension: 'RENTABILIDAD',
        viajes: 4,
      );
      expect(a.mensaje, 'Ruta Medellín → Bogotá con sobrecostos frecuentes');
    });

    test('retrasos de un conductor', () {
      const AlertaRecurrente a = AlertaRecurrente(
        entidad: 'CONDUCTOR',
        clave: 'Ana Pérez',
        dimension: 'PUNTUALIDAD',
        viajes: 3,
      );
      expect(a.mensaje, 'Conductor Ana Pérez con retrasos frecuentes');
    });
  });

  test('NivelCalidad.desdeCodigo traduce los códigos del servidor', () {
    expect(NivelCalidad.desdeCodigo('VERDE'), NivelCalidad.verde);
    expect(NivelCalidad.desdeCodigo('AMBAR'), NivelCalidad.ambar);
    expect(NivelCalidad.desdeCodigo('ROJO'), NivelCalidad.rojo);
    expect(NivelCalidad.desdeCodigo(null), isNull);
  });

  test('NivelCalidad.dePuntaje usa los cortes 75 y 40 del servidor', () {
    expect(NivelCalidad.dePuntaje(75), NivelCalidad.verde);
    expect(NivelCalidad.dePuntaje(74.9), NivelCalidad.ambar);
    expect(NivelCalidad.dePuntaje(40), NivelCalidad.ambar);
    expect(NivelCalidad.dePuntaje(39.9), NivelCalidad.rojo);
    expect(NivelCalidad.dePuntaje(null), isNull);
  });

  group('CalidadConductorIndicador', () {
    late _MockCalidad repo;

    setUp(() => repo = _MockCalidad());

    Future<void> montar(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CalidadConductorIndicador(
              conductorId: 'c-1',
              ahora: DateTime(2026, 10, 14),
              obtener: ObtenerCalidadDeConductorUseCase(repo),
            ),
          ),
        ),
      );
    }

    testWidgets('consulta el mes completo y muestra nivel y puntaje', (
      WidgetTester tester,
    ) async {
      when(() => repo.resumenDeConductor('c-1', any(), any())).thenAnswer(
        (_) async => const ResumenCalidad(
          viajesEvaluados: 4,
          verdes: 2,
          ambares: 1,
          rojos: 1,
          puntajePromedio: 62,
          puntualidadRojos: 1,
          rentabilidadRojos: 0,
          satisfaccionRojos: 0,
          incidenciasRojos: 0,
        ),
      );

      await montar(tester);
      await tester.pumpAndSettle();

      verify(
        () => repo.resumenDeConductor(
          'c-1',
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31),
        ),
      ).called(1);
      expect(find.text('Calidad del mes'), findsOneWidget);
      expect(find.text('Con mejoras'), findsOneWidget);
      expect(find.text('62/100 · 4 viajes'), findsOneWidget);
    });

    testWidgets('sin viajes evaluados en el mes no se muestra', (
      WidgetTester tester,
    ) async {
      when(() => repo.resumenDeConductor('c-1', any(), any())).thenAnswer(
        (_) async => const ResumenCalidad(
          viajesEvaluados: 0,
          verdes: 0,
          ambares: 0,
          rojos: 0,
          puntualidadRojos: 0,
          rentabilidadRojos: 0,
          satisfaccionRojos: 0,
          incidenciasRojos: 0,
        ),
      );

      await montar(tester);
      await tester.pumpAndSettle();

      expect(find.text('Calidad del mes'), findsNothing);
    });
  });

  group('CalidadViajeCard', () {
    late _MockCalidad repo;

    setUp(() => repo = _MockCalidad());

    Future<void> montar(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CalidadViajeCard(
              viajeId: 'v-1',
              obtener: ObtenerCalidadDeViajeUseCase(repo),
            ),
          ),
        ),
      );
    }

    testWidgets('muestra el nivel y el detalle de cada dimensión', (
      WidgetTester tester,
    ) async {
      when(() => repo.calidadDeViaje('v-1')).thenAnswer(
        (_) async => const CalidadViaje(
          puntualidad: NivelCalidad.rojo,
          minutosRetraso: 180,
          rentabilidad: NivelCalidad.ambar,
          desvioCostosPct: 20,
          categoriaMayorDesvio: 'ACPM',
          incidencias: NivelCalidad.verde,
          puntaje: 50,
          nivel: NivelCalidad.ambar,
        ),
      );

      await montar(tester);
      await tester.pumpAndSettle();

      expect(find.text('Calidad del viaje'), findsOneWidget);
      expect(find.text('Con mejoras'), findsOneWidget);
      expect(find.text('Puntaje 50 de 100'), findsOneWidget);
      expect(find.text('180 min más de lo estimado'), findsOneWidget);
      expect(
        find.text('Costos 20,0 % sobre lo estimado (mayor desvío: ACPM)'),
        findsOneWidget,
      );
      expect(
        find.text('El cliente aún no responde la encuesta'),
        findsOneWidget,
      );
      expect(find.text('Sin alertas en ruta'), findsOneWidget);
    });

    testWidgets('se oculta si el viaje aún no tiene calificación', (
      WidgetTester tester,
    ) async {
      when(() => repo.calidadDeViaje('v-1')).thenAnswer((_) async => null);

      await montar(tester);
      await tester.pumpAndSettle();

      expect(find.text('Calidad del viaje'), findsNothing);
    });

    testWidgets('se oculta si la consulta falla', (WidgetTester tester) async {
      when(() => repo.calidadDeViaje('v-1')).thenThrow(Exception('fallo'));

      await montar(tester);
      await tester.pumpAndSettle();

      expect(find.text('Calidad del viaje'), findsNothing);
    });
  });
}
