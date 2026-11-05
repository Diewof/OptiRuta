import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/features/vehiculos/domain/entities/documento_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/estado_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/hoja_vida.dart';

DocumentoVehiculo _doc(TipoDocumentoVehiculo t, EstadoDocumento e, int dias) =>
    DocumentoVehiculo(
      id: t.codigo,
      vehiculoId: 'v',
      tipo: t,
      fechaVencimiento: DateTime(2027),
      diasRestantes: dias,
      estado: e,
    );

HojaVida _hoja(
  List<DocumentoVehiculo> docs, [
  List<ItemPlanMantenimiento> plan = const <ItemPlanMantenimiento>[],
]) => HojaVida(
  odometroKm: 0,
  documentos: docs,
  plan: plan,
  eventos: const <EventoHojaVida>[],
);

final DocumentoVehiculo _soatOk = _doc(
  TipoDocumentoVehiculo.soat,
  EstadoDocumento.vigente,
  200,
);
final DocumentoVehiculo _rtmOk = _doc(
  TipoDocumentoVehiculo.tecnomecanica,
  EstadoDocumento.vigente,
  200,
);

void main() {
  test('con todo vigente y al día no hay nada que atender', () {
    final EstadoVehiculo e = estadoDeVehiculo(
      _hoja(<DocumentoVehiculo>[_soatOk, _rtmOk]),
    );
    expect(e.nivel, NivelEstadoVehiculo.alDia);
    expect(e.motivos, isEmpty);
  });

  test('un documento por vencer es aviso con los días que quedan', () {
    final EstadoVehiculo e = estadoDeVehiculo(
      _hoja(<DocumentoVehiculo>[
        _doc(TipoDocumentoVehiculo.soat, EstadoDocumento.porVencer, 12),
        _rtmOk,
      ]),
    );
    expect(e.nivel, NivelEstadoVehiculo.aviso);
    expect(e.motivos, <String>['SOAT vence en 12 d']);
  });

  test('un documento vencido o ausente es crítico', () {
    expect(
      estadoDeVehiculo(
        _hoja(<DocumentoVehiculo>[
          _doc(TipoDocumentoVehiculo.soat, EstadoDocumento.vencido, -3),
          _rtmOk,
        ]),
      ).nivel,
      NivelEstadoVehiculo.critico,
    );
    final EstadoVehiculo sin = estadoDeVehiculo(
      _hoja(<DocumentoVehiculo>[_soatOk]),
    );
    expect(sin.nivel, NivelEstadoVehiculo.critico);
    expect(sin.motivos.single, startsWith('Sin '));
  });

  test('el mantenimiento vencido es crítico y el próximo es aviso', () {
    ItemPlanMantenimiento item(EstadoPlanMantenimiento e) =>
        ItemPlanMantenimiento(tipoNombre: 'Cambio de aceite', estado: e);
    final List<DocumentoVehiculo> docs = <DocumentoVehiculo>[_soatOk, _rtmOk];

    expect(
      estadoDeVehiculo(
        _hoja(docs, <ItemPlanMantenimiento>[
          item(EstadoPlanMantenimiento.vencido),
        ]),
      ).nivel,
      NivelEstadoVehiculo.critico,
    );
    expect(
      estadoDeVehiculo(
        _hoja(docs, <ItemPlanMantenimiento>[
          item(EstadoPlanMantenimiento.proximo),
        ]),
      ).nivel,
      NivelEstadoVehiculo.aviso,
    );
  });
}
