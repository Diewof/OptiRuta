import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/repositories/ubicacion_viaje_repository.dart';
import '../../domain/usecases/ubicacion_viaje_use_cases.dart';
import 'mapa_ruta.dart';
import 'mapa_ruta_viaje.dart';

/// Mapa del viaje para el administrador con la última ubicación que reportó
/// el conductor (RF-21). Si el conductor no aceptó el registro o aún no envió
/// puntos, muestra el mapa de la ruta tal cual.
class MapaRutaConUbicacion extends StatefulWidget {
  const MapaRutaConUbicacion({required this.viaje, this.alerta, super.key});

  final ViajeResumen viaje;
  final Coordenada? alerta;

  @override
  State<MapaRutaConUbicacion> createState() => _MapaRutaConUbicacionState();
}

class _MapaRutaConUbicacionState extends State<MapaRutaConUbicacion> {
  late final Future<List<PuntoUbicacion>> _puntos =
      ListarPuntosUbicacionUseCase(context.read<UbicacionViajeRepository>())(
        widget.viaje.id,
      ).catchError((Object _) => const <PuntoUbicacion>[]);

  @override
  Widget build(BuildContext context) {
    final ViajeResumen v = widget.viaje;
    if (!v.tieneMapa) return MapaRutaViaje(viaje: v, alerta: widget.alerta);

    return FutureBuilder<List<PuntoUbicacion>>(
      future: _puntos,
      builder: (BuildContext context, AsyncSnapshot<List<PuntoUbicacion>> s) {
        final List<PuntoUbicacion> puntos = s.data ?? const <PuntoUbicacion>[];
        if (puntos.isEmpty) {
          return MapaRutaViaje(viaje: v, alerta: widget.alerta);
        }
        final PuntoUbicacion ultimo = puntos.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MapaRuta(
              origen: v.origenCoordenada!,
              destino: v.destinoCoordenada!,
              polilinea: v.rutaPolilinea ?? '',
              alerta: widget.alerta,
              posicion: ultimo.posicion,
              altura: 200,
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Última ubicación del conductor: '
              '${formatearFechaHoraCorta(ultimo.fechaHora)} '
              '(${puntos.length} ${puntos.length == 1 ? 'punto' : 'puntos'} '
              'registrados)',
              style: AppTypography.caption,
            ),
          ],
        );
      },
    );
  }
}
