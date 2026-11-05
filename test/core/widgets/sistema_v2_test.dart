import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/core/widgets/dato_marca.dart';
import 'package:optiruta/core/widgets/estado_viaje_badge.dart';
import 'package:optiruta/core/widgets/figura_ruta.dart';
import 'package:optiruta/core/widgets/ilustracion_estado.dart';
import 'package:optiruta/core/widgets/marca_icon.dart';
import 'package:optiruta/core/widgets/semaforo_badge.dart';
import 'package:optiruta/core/widgets/skeleton.dart';
import 'package:optiruta/core/widgets/vehiculo_thumb.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('cada MarcaIconos carga su SVG (contorno y relleno)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Wrap(
          children: <Widget>[
            for (final MarcaIconos i in MarcaIconos.values) ...<Widget>[
              MarcaIcon(i),
              if (i.tieneRelleno) MarcaIcon(i, relleno: true),
            ],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('semáforo: cada estado dice su etiqueta (no solo color)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: <Widget>[
            for (final SemaforoRentabilidad s in SemaforoRentabilidad.values)
              SemaforoBadge(estado: s),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rentable'), findsOneWidget);
    expect(find.text('Margen bajo'), findsOneWidget);
    expect(find.text('Pérdida'), findsOneWidget);
    expect(find.text('Sin datos suficientes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('semáforo acepta etiqueta configurable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SemaforoBadge(
          estado: SemaforoRentabilidad.perdida,
          etiqueta: 'Margen crítico',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Margen crítico'), findsOneWidget);
    expect(find.text('Pérdida'), findsNothing);
  });

  testWidgets('badge de estado del viaje cubre el ciclo completo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: <Widget>[
            for (final EstadoViaje e in EstadoViaje.values)
              EstadoViajeBadge(estado: e),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final EstadoViaje e in EstadoViaje.values) {
      expect(find.text(e.etiqueta), findsOneWidget);
    }
  });

  testWidgets('DatoMarca distingue estimado, real y ajustado por texto', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: <Widget>[
            DatoMarca.estimado(r'$3.050.000'),
            DatoMarca.real(r'$3.210.000'),
            DatoMarca.ajustado(r'$3.300.000'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'≈ $3.050.000'), findsOneWidget);
    expect(find.text('Est.'), findsOneWidget);
    expect(find.text(r'$3.210.000'), findsOneWidget);
    expect(find.text('Real'), findsOneWidget);
    expect(find.text('Ajustado'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Estimado: ')), findsOneWidget);
  });

  testWidgets('base de cálculo, figura de ruta, vehículos e ilustraciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: <Widget>[
            for (final BaseCalculo b in BaseCalculo.values)
              BaseCalculoChip(base: b),
            const FiguraRuta(),
            for (final TipoVehiculo t in TipoVehiculo.values)
              VehiculoThumb(tipo: t),
            for (final IlustracionEstado i in IlustracionEstado.values)
              IlustracionEstadoView(i),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Proyectada'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('esqueleto no anima con reducir movimiento', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: SkeletonBlock()),
        ),
      ),
    );
    // Sin animación en marcha, pumpAndSettle termina de inmediato.
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonBlock), findsOneWidget);
  });
}
