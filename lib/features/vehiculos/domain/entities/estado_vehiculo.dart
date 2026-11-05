import 'package:equatable/equatable.dart';

import 'documento_vehiculo.dart';
import 'hoja_vida.dart';

enum NivelEstadoVehiculo { alDia, aviso, critico }

/// Resumen de un vistazo para la lista de Flota: documentos que bloquean y
/// plan de mantenimiento. El estado de cada pieza lo calcula el servidor; aquí
/// solo se junta y se toma el peor.
class EstadoVehiculo extends Equatable {
  const EstadoVehiculo(this.nivel, this.motivos);

  final NivelEstadoVehiculo nivel;
  final List<String> motivos;

  @override
  List<Object?> get props => <Object?>[nivel, motivos];
}

EstadoVehiculo estadoDeVehiculo(HojaVida hoja) {
  final List<String> criticos = <String>[];
  final List<String> avisos = <String>[];

  for (final TipoDocumentoVehiculo tipo in TipoDocumentoVehiculo.values) {
    final DocumentoVehiculo? d = hoja.documento(tipo);
    if (d == null) {
      criticos.add('Sin ${tipo.etiqueta}');
    } else if (d.estado == EstadoDocumento.vencido) {
      criticos.add('${tipo.etiqueta} vencido');
    } else if (d.estado == EstadoDocumento.porVencer) {
      avisos.add('${tipo.etiqueta} vence en ${d.diasRestantes} d');
    }
  }
  for (final ItemPlanMantenimiento i in hoja.plan) {
    if (i.estado == EstadoPlanMantenimiento.vencido) {
      criticos.add('${i.tipoNombre} vencido');
    } else if (i.estado == EstadoPlanMantenimiento.proximo) {
      avisos.add('${i.tipoNombre} próximo');
    }
  }

  if (criticos.isNotEmpty) {
    return EstadoVehiculo(NivelEstadoVehiculo.critico, <String>[
      ...criticos,
      ...avisos,
    ]);
  }
  if (avisos.isNotEmpty) {
    return EstadoVehiculo(NivelEstadoVehiculo.aviso, avisos);
  }
  return const EstadoVehiculo(NivelEstadoVehiculo.alDia, <String>[]);
}
