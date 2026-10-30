import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/widgets/admin_section.dart';
import 'package:optiruta/features/notificaciones/domain/entities/notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/entities/tipo_notificacion.dart';
import 'package:optiruta/features/notificaciones/presentation/widgets/destino_notificacion.dart';

Notificacion _n(TipoNotificacion tipo, {String? viajeId, bool leida = false}) =>
    Notificacion(
      id: 'n',
      tipo: tipo,
      titulo: tipo.etiqueta,
      mensaje: 'm',
      leida: leida,
      fechaCreacion: DateTime(2026, 10, 1),
      viajeId: viajeId,
    );

void main() {
  group('DestinoNotificacion', () {
    test('cada tipo con acción lleva a donde se resuelve', () {
      expect(
        DestinoNotificacion.de(_n(TipoNotificacion.mantenimientoVencido))
            ?.seccion,
        AdminSection.flota,
      );
      expect(
        DestinoNotificacion.de(_n(TipoNotificacion.calidadRecurrente))?.seccion,
        AdminSection.calidad,
      );
      expect(
        DestinoNotificacion.de(_n(TipoNotificacion.rendimientoBajo))?.seccion,
        AdminSection.combustible,
      );
      expect(
        DestinoNotificacion.de(_n(TipoNotificacion.esperaExcesiva))?.seccion,
        AdminSection.esperas,
      );
      expect(
        DestinoNotificacion.de(_n(TipoNotificacion.satisfaccionBaja))?.seccion,
        AdminSection.satisfaccion,
      );
    });

    test('si trae el viaje, abre el viaje en vez de la sección', () {
      final DestinoNotificacion? d = DestinoNotificacion.de(
        _n(TipoNotificacion.esperaExcesiva, viajeId: 'v-1'),
      );
      expect(d?.abreViaje, isTrue);
      expect(d?.verbo, 'Ver viaje');
    });

    test('un aviso de flota nunca abre un viaje', () {
      final DestinoNotificacion? d = DestinoNotificacion.de(
        _n(TipoNotificacion.documentoVencido, viajeId: 'v-1'),
      );
      expect(d?.abreViaje, isFalse);
      expect(d?.seccion, AdminSection.flota);
    });

    test('lo meramente informativo no tiene destino sin viaje', () {
      expect(
        DestinoNotificacion.de(_n(TipoNotificacion.viajeCompletado)),
        isNull,
      );
      expect(
        DestinoNotificacion.de(_n(TipoNotificacion.peajeRegistrado)),
        isNull,
      );
    });
  });

  group('FiltroNotificacion', () {
    final Notificacion desvio = _n(TipoNotificacion.desvioRuta);
    final Notificacion doc = _n(TipoNotificacion.documentoVencido, leida: true);
    final Notificacion csat = _n(TipoNotificacion.satisfaccionBaja);
    final Notificacion info = _n(TipoNotificacion.viajeCompletado);
    final List<Notificacion> todas = <Notificacion>[desvio, doc, csat, info];

    List<Notificacion> con(FiltroNotificacion f) =>
        todas.where(f.acepta).toList();

    test('sin leer, acción y categorías', () {
      expect(con(FiltroNotificacion.todas), todas);
      expect(con(FiltroNotificacion.sinLeer), <Notificacion>[
        desvio,
        csat,
        info,
      ]);
      expect(con(FiltroNotificacion.requierenAccion), <Notificacion>[
        desvio,
        doc,
        csat,
      ]);
      expect(con(FiltroNotificacion.ruta), <Notificacion>[desvio, info]);
      expect(con(FiltroNotificacion.flota), <Notificacion>[doc]);
      expect(con(FiltroNotificacion.clientes), <Notificacion>[csat]);
    });
  });
}
