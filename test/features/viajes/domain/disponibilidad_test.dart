import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/features/conductores/domain/entities/conductor.dart';
import 'package:optiruta/features/conductores/domain/entities/tipo_pago.dart';
import 'package:optiruta/features/vehiculos/domain/entities/documento_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/hoja_vida.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/vehiculo.dart';
import 'package:optiruta/features/viajes/domain/entities/disponibilidad.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje_resumen.dart';

final DateTime _salida = DateTime(2026, 11, 10, 6);

const Vehiculo _veh = Vehiculo(
  id: 'v-1',
  placa: 'UFH664',
  tipo: TipoVehiculo.dobleTroque,
  capacidadCarga: 17,
  rendimientoKmGalon: 9,
  activo: true,
);

DocumentoVehiculo _doc(TipoDocumentoVehiculo tipo, DateTime vence) =>
    DocumentoVehiculo(
      id: 'd-${tipo.codigo}',
      vehiculoId: 'v-1',
      tipo: tipo,
      fechaVencimiento: vence,
      diasRestantes: 0,
      estado: EstadoDocumento.vigente,
    );

HojaVida _hoja(DateTime soat, DateTime rtm) => HojaVida(
  odometroKm: 0,
  documentos: <DocumentoVehiculo>[
    _doc(TipoDocumentoVehiculo.soat, soat),
    _doc(TipoDocumentoVehiculo.tecnomecanica, rtm),
  ],
  plan: const <ItemPlanMantenimiento>[],
  eventos: const <EventoHojaVida>[],
);

ViajeResumen _viaje({
  String placa = 'UFH664',
  String conductor = 'Camilo Rojas',
  EstadoViaje estado = EstadoViaje.asignado,
  DateTime? salida,
  double? minutos,
}) => ViajeResumen(
  id: 'x',
  remision: 'R',
  origen: 'Bogotá',
  destino: 'Cali',
  estado: estado,
  placaVehiculo: placa,
  nombreConductor: conductor,
  nombreCliente: 'C',
  fechaSalidaProgramada: salida,
  tiempoEstimadoMin: minutos,
  fechaCreacion: DateTime(2026, 10, 1),
);

Conductor _cond(DateTime licencia) => Conductor(
  id: 'c-1',
  usuarioId: 'u',
  nombre: 'Camilo Rojas',
  documento: null,
  licencia: 'L',
  fechaVencimientoLicencia: licencia,
  tipoPago: TipoPago.comision,
  porcentajeComision: 10,
  sueldoBase: 0,
  activo: true,
);

void main() {
  group('avisoVehiculo', () {
    test('con documentos vigentes y agenda libre no hay aviso', () {
      final AvisoDisponibilidad a = avisoVehiculo(
        vehiculo: _veh,
        hoja: _hoja(DateTime(2027, 6), DateTime(2027, 6)),
        viajes: const <ViajeResumen>[],
        salida: _salida,
      );
      expect(a.nivel, NivelAviso.ninguno);
    });

    test('un SOAT vencido a la fecha de salida es crítico', () {
      final AvisoDisponibilidad a = avisoVehiculo(
        vehiculo: _veh,
        hoja: _hoja(DateTime(2026, 11, 9), DateTime(2027, 6)),
        viajes: const <ViajeResumen>[],
        salida: _salida,
      );
      expect(a.nivel, NivelAviso.critico);
      expect(a.mensaje, contains('SOAT'));
      expect(a.mensaje, contains('no podrá salir'));
    });

    test('vencer el mismo día de la salida sigue siendo vigente', () {
      final AvisoDisponibilidad a = avisoVehiculo(
        vehiculo: _veh,
        hoja: _hoja(DateTime(2026, 11, 10), DateTime(2027, 6)),
        viajes: const <ViajeResumen>[],
        salida: _salida,
      );
      expect(a.nivel, NivelAviso.aviso); // vence hoy: por vencer, no vencido
    });

    test('sin documento registrado es crítico', () {
      final AvisoDisponibilidad a = avisoVehiculo(
        vehiculo: _veh,
        hoja: const HojaVida(
          odometroKm: 0,
          documentos: <DocumentoVehiculo>[],
          plan: <ItemPlanMantenimiento>[],
          eventos: <EventoHojaVida>[],
        ),
        viajes: const <ViajeResumen>[],
        salida: _salida,
      );
      expect(a.nivel, NivelAviso.critico);
    });

    test('un cruce de agenda avisa, no bloquea', () {
      final AvisoDisponibilidad a = avisoVehiculo(
        vehiculo: _veh,
        hoja: _hoja(DateTime(2027, 6), DateTime(2027, 6)),
        viajes: <ViajeResumen>[
          _viaje(salida: DateTime(2026, 11, 10, 18), minutos: 300),
        ],
        salida: _salida,
      );
      expect(a.nivel, NivelAviso.aviso);
      expect(a.mensaje, startsWith('Ocupado'));
    });

    test('un viaje largo que viene de días antes cuenta como cruce', () {
      final AvisoDisponibilidad a = avisoVehiculo(
        vehiculo: _veh,
        hoja: null,
        viajes: <ViajeResumen>[
          _viaje(
            estado: EstadoViaje.enCurso,
            salida: DateTime(2026, 11, 9, 20),
            minutos: 24 * 60,
          ),
        ],
        salida: _salida,
      );
      expect(a.nivel, NivelAviso.aviso);
    });

    test('viajes terminados, de otro vehículo o de otro día no cruzan', () {
      final AvisoDisponibilidad a = avisoVehiculo(
        vehiculo: _veh,
        hoja: null,
        viajes: <ViajeResumen>[
          _viaje(estado: EstadoViaje.finalizado, salida: _salida),
          _viaje(placa: 'TPK320', salida: _salida),
          _viaje(salida: DateTime(2026, 11, 12, 6), minutos: 60),
        ],
        salida: _salida,
      );
      expect(a.nivel, NivelAviso.ninguno);
    });

    test('gana el aviso más grave', () {
      final AvisoDisponibilidad a = avisoVehiculo(
        vehiculo: _veh,
        hoja: _hoja(DateTime(2026, 1), DateTime(2027, 6)),
        viajes: <ViajeResumen>[_viaje(salida: _salida, minutos: 60)],
        salida: _salida,
      );
      expect(a.nivel, NivelAviso.critico);
    });
  });

  group('avisoConductor', () {
    test('licencia vencida es crítica y ocupado es aviso', () {
      expect(
        avisoConductor(
          conductor: _cond(DateTime(2026, 11, 1)),
          viajes: const <ViajeResumen>[],
          salida: _salida,
        ).nivel,
        NivelAviso.critico,
      );
      expect(
        avisoConductor(
          conductor: _cond(DateTime(2030)),
          viajes: <ViajeResumen>[_viaje(salida: _salida, minutos: 60)],
          salida: _salida,
        ).nivel,
        NivelAviso.aviso,
      );
      expect(
        avisoConductor(
          conductor: _cond(DateTime(2030)),
          viajes: const <ViajeResumen>[],
          salida: _salida,
        ).nivel,
        NivelAviso.ninguno,
      );
    });
  });
}
