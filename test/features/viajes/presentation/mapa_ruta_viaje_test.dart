import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:optiruta/core/theme/app_theme.dart';

import 'package:optiruta/core/widgets/figura_ruta.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';
import 'package:optiruta/features/viajes/presentation/widgets/mapa_ruta.dart';
import 'package:optiruta/features/viajes/presentation/widgets/mapa_ruta_viaje.dart';

ViajeResumen _viaje({bool conMapa = false}) => ViajeResumen(
  id: 'v-1',
  remision: 'V-001',
  origen: 'Medellín',
  destino: 'Cartagena',
  estado: EstadoViaje.asignado,
  placaVehiculo: 'UFH664',
  nombreConductor: 'Camilo Rojas',
  nombreCliente: 'Distribuidora Andina',
  fechaCreacion: DateTime(2026, 10, 8),
  origenCoordenada: conMapa ? const Coordenada(6.2442, -75.5812) : null,
  destinoCoordenada: conMapa ? const Coordenada(10.391, -75.4794) : null,
  // Sin trazado: el mapa une origen y destino en línea recta.
  rutaPolilinea: null,
);

Future<void> _montar(
  WidgetTester tester,
  ViajeResumen viaje, {
  Coordenada? alerta,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MapaRutaViaje(viaje: viaje, alerta: alerta),
      ),
    ),
  );
}

void main() {
  testWidgets('un viaje anterior a los mapas conserva la figura estática', (
    WidgetTester tester,
  ) async {
    await _montar(tester, _viaje());

    expect(find.byType(FiguraRuta), findsOneWidget);
    expect(find.byType(MapaRuta), findsNothing);
  });

  testWidgets('un viaje con ubicaciones muestra el mapa de la ruta', (
    WidgetTester tester,
  ) async {
    await _montar(tester, _viaje(conMapa: true));

    expect(find.byType(MapaRuta), findsOneWidget);
    expect(find.byType(FiguraRuta), findsNothing);
  });

  testWidgets('el mapa dibuja origen, destino y el trazado de la ruta', (
    WidgetTester tester,
  ) async {
    await _montar(tester, _viaje(conMapa: true));
    await tester.pump();

    expect(find.byIcon(LucideIcons.circleDot), findsOneWidget);
    expect(find.byIcon(LucideIcons.mapPin), findsOneWidget);
    expect(find.byIcon(LucideIcons.navigation), findsNothing);
    expect(find.byType(PolylineLayer), findsOneWidget);
  });

  testWidgets('con una alerta marca el punto donde ocurrió', (
    WidgetTester tester,
  ) async {
    await _montar(
      tester,
      _viaje(conMapa: true),
      alerta: const Coordenada(8.0, -75.5),
    );
    await tester.pump();

    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
  });

  testWidgets('sin alerta no hay marcador de alerta', (
    WidgetTester tester,
  ) async {
    await _montar(tester, _viaje(conMapa: true));
    await tester.pump();

    expect(find.byIcon(LucideIcons.triangleAlert), findsNothing);
  });
}
