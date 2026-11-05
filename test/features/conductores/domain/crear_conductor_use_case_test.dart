import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/conductores/domain/entities/conductor.dart';
import 'package:optiruta/features/conductores/domain/entities/tipo_pago.dart';
import 'package:optiruta/features/conductores/domain/repositories/conductor_repository.dart';
import 'package:optiruta/features/conductores/domain/usecases/crear_conductor_use_case.dart';

class _MockRepo extends Mock implements ConductorRepository {}

void main() {
  late _MockRepo repo;
  late CrearConductorUseCase caso;

  final Conductor conductorCreado = Conductor(
    id: 'c-1',
    usuarioId: 'u-1',
    nombre: 'Conductor Uno',
    documento: 'CC-1',
    licencia: 'LIC-001',
    fechaVencimientoLicencia: DateTime(2030),
    tipoPago: TipoPago.comision,
    porcentajeComision: 10,
    sueldoBase: 0,
    activo: true,
  );

  setUpAll(() {
    registerFallbackValue(TipoPago.comision);
  });

  setUp(() {
    repo = _MockRepo();
    caso = CrearConductorUseCase(repo);
    when(
      () => repo.crear(
        usuarioId: any(named: 'usuarioId'),
        licencia: any(named: 'licencia'),
        fechaVencimientoLicencia: any(named: 'fechaVencimientoLicencia'),
        tipoPago: any(named: 'tipoPago'),
        porcentajeComision: any(named: 'porcentajeComision'),
        sueldoBase: any(named: 'sueldoBase'),
      ),
    ).thenAnswer((_) async => conductorCreado);
  });

  test('recorta espacios de la licencia antes de enviarla', () async {
    await caso(
      usuarioId: 'u-1',
      licencia: '  LIC-001  ',
      fechaVencimientoLicencia: DateTime(2030),
      tipoPago: TipoPago.comision,
      porcentajeComision: 10,
      sueldoBase: 0,
    );

    verify(
      () => repo.crear(
        usuarioId: 'u-1',
        licencia: 'LIC-001',
        fechaVencimientoLicencia: DateTime(2030),
        tipoPago: TipoPago.comision,
        porcentajeComision: 10,
        sueldoBase: 0,
      ),
    ).called(1);
  });
}
