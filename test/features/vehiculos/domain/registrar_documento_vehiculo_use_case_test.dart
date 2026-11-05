import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/vehiculos/domain/entities/documento_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/hoja_vida_repository.dart';
import 'package:optiruta/features/vehiculos/domain/usecases/registrar_documento_vehiculo_use_case.dart';

class _MockRepo extends Mock implements HojaVidaRepository {}

void main() {
  late _MockRepo repo;
  late RegistrarDocumentoVehiculoUseCase caso;

  setUpAll(() {
    registerFallbackValue(TipoDocumentoVehiculo.soat);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repo = _MockRepo();
    caso = RegistrarDocumentoVehiculoUseCase(repo);
    when(
      () => repo.registrarDocumento(
        vehiculoId: any(named: 'vehiculoId'),
        tipo: any(named: 'tipo'),
        fechaVencimiento: any(named: 'fechaVencimiento'),
        numero: any(named: 'numero'),
        entidadEmisora: any(named: 'entidadEmisora'),
        fechaExpedicion: any(named: 'fechaExpedicion'),
      ),
    ).thenAnswer((_) async {});
  });

  test('rechaza una expedición posterior al vencimiento', () {
    expect(
      () => caso(
        vehiculoId: 'v-1',
        tipo: TipoDocumentoVehiculo.soat,
        fechaVencimiento: DateTime(2027, 1, 1),
        fechaExpedicion: DateTime(2027, 1, 2),
      ),
      throwsArgumentError,
    );
  });

  test('limpia los textos y deja nulos los vacíos', () async {
    await caso(
      vehiculoId: 'v-1',
      tipo: TipoDocumentoVehiculo.tecnomecanica,
      fechaVencimiento: DateTime(2027, 1, 1),
      numero: '  ',
      entidadEmisora: ' CDA Norte ',
    );

    verify(
      () => repo.registrarDocumento(
        vehiculoId: 'v-1',
        tipo: TipoDocumentoVehiculo.tecnomecanica,
        fechaVencimiento: DateTime(2027, 1, 1),
        numero: null,
        entidadEmisora: 'CDA Norte',
        fechaExpedicion: null,
      ),
    ).called(1);
  });
}
