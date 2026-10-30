import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/theme/app_theme.dart';
import 'package:optiruta/features/calidad/domain/repositories/calidad_repository.dart';
import 'package:optiruta/features/autenticacion/domain/entities/rol_usuario.dart';
import 'package:optiruta/features/autenticacion/domain/entities/usuario.dart';
import 'package:optiruta/features/conductores/domain/entities/conductor.dart';
import 'package:optiruta/features/conductores/domain/entities/tipo_pago.dart';
import 'package:optiruta/features/conductores/domain/repositories/conductor_repository.dart';
import 'package:optiruta/features/conductores/presentation/pages/conductores_list_page.dart';

class _MockConductorRepository extends Mock implements ConductorRepository {}

class _MockCalidad extends Mock implements CalidadRepository {}

const Usuario _admin = Usuario(
  id: 'u-1',
  nombre: 'Ana Admin',
  rol: RolUsuario.administrador,
  activo: true,
);

Conductor _conductor({
  required String id,
  required String nombre,
  required DateTime vencimiento,
}) {
  return Conductor(
    id: id,
    usuarioId: 'usuario-$id',
    nombre: nombre,
    documento: null,
    licencia: 'LIC-$id',
    fechaVencimientoLicencia: vencimiento,
    tipoPago: TipoPago.comision,
    porcentajeComision: 10,
    sueldoBase: 0,
    activo: true,
  );
}

void main() {
  late _MockConductorRepository repo;
  late _MockCalidad calidad;

  setUp(() {
    repo = _MockConductorRepository();
    calidad = _MockCalidad();
    // Sin calificación disponible el indicador no se muestra.
    when(() => calidad.resumenDeConductor(any(), any(), any()))
        .thenThrow(Exception('sin calificación'));
  });

  Future<void> montar(WidgetTester tester, List<Conductor> conductores) {
    when(
      () => repo.listar(
        pagina: any(named: 'pagina'),
        tamano: any(named: 'tamano'),
      ),
    ).thenAnswer(
      (_) async => PaginaConductores(conductores: conductores, hayMas: false),
    );

    return tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<Object?>>[
          RepositoryProvider<ConductorRepository>.value(value: repo),
          RepositoryProvider<CalidadRepository>.value(value: calidad),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ConductoresListPage(usuario: _admin),
        ),
      ),
    );
  }

  testWidgets('muestra el título "Conductores" y el boton de agregar', (
    WidgetTester tester,
  ) async {
    await montar(tester, <Conductor>[]);
    await tester.pumpAndSettle();

    expect(find.text('Conductores'), findsOneWidget);
    expect(find.text('Agregar conductor'), findsOneWidget);
  });

  testWidgets('marca licencia vencida, por vencer y vigente', (
    WidgetTester tester,
  ) async {
    final DateTime ahora = DateTime.now();
    await montar(tester, <Conductor>[
      _conductor(
        id: '1',
        nombre: 'Vencido',
        vencimiento: ahora.subtract(const Duration(days: 5)),
      ),
      _conductor(
        id: '2',
        nombre: 'Por vencer',
        vencimiento: ahora.add(const Duration(days: 10)),
      ),
      _conductor(
        id: '3',
        nombre: 'Vigente',
        vencimiento: ahora.add(const Duration(days: 200)),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Licencia vencida'), findsOneWidget);
    expect(find.textContaining('Licencia vence en'), findsOneWidget);
    expect(find.text('Licencia vigente'), findsOneWidget);
  });

  testWidgets('buscar filtra por nombre sin importar tildes ni mayúsculas', (
    WidgetTester tester,
  ) async {
    final DateTime lejos = DateTime.now().add(const Duration(days: 400));
    await montar(tester, <Conductor>[
      _conductor(id: '1', nombre: 'José Peña', vencimiento: lejos),
      _conductor(id: '2', nombre: 'Camilo Rojas', vencimiento: lejos),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('José Peña'), findsOneWidget);
    expect(find.text('Camilo Rojas'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'JOSE pena');
    await tester.pumpAndSettle();

    expect(find.text('José Peña'), findsOneWidget);
    expect(find.text('Camilo Rojas'), findsNothing);
  });
}
