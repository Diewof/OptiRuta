import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/ruta_geometria.dart';

LatLng aLatLng(Coordenada c) => LatLng(c.lat, c.lng);

/// Rectángulo que contiene a Colombia (con sus islas). El selector de ubicación
/// se abre aquí y no se puede arrastrar fuera de él.
final LatLngBounds limitesColombia = LatLngBounds(
  const LatLng(-4.3, -79.1),
  const LatLng(13.5, -66.8),
);

/// Restricción de cámara del selector: dentro de Colombia y sin alejarse más de
/// lo que cabe el país en la pantalla. No se aplica al mapa pequeño de la ruta:
/// ahí obligaría a un zoom que deja fuera partes del trazado.
final CameraConstraint restriccionColombia = CameraConstraint.contain(
  bounds: limitesColombia,
);

/// Encuadre inicial que muestra Colombia completa.
final CameraFit encuadreColombia = CameraFit.bounds(
  bounds: limitesColombia,
  padding: const EdgeInsets.all(AppSpacing.x2),
);

/// Mapa base de OptiRuta (OpenStreetMap, sin API key). Los tiles públicos
/// exigen atribución y un user agent propio; no son para tráfico alto.
class MapaBase extends StatelessWidget {
  const MapaBase({
    required this.opciones,
    this.controller,
    this.capas = const <Widget>[],
    super.key,
  });

  final MapOptions opciones;
  final MapController? controller;
  final List<Widget> capas;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: opciones,
      children: <Widget>[
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.optiruta.optiruta',
        ),
        ...capas,
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: <SourceAttribution>[
            TextSourceAttribution('© colaboradores de OpenStreetMap'),
          ],
        ),
      ],
    );
  }
}

/// Mapa de la ruta de un viaje: origen, destino, trazado estimado y, si se
/// pasa [posicion], el marcador del conductor. Sin [posicion] es una vista
/// estática (se puede mover con el dedo, pero no sigue a nadie).
class MapaRuta extends StatefulWidget {
  const MapaRuta({
    required this.origen,
    required this.destino,
    this.polilinea = '',
    this.posicion,
    this.alerta,
    this.altura = 200,
    super.key,
  });

  final Coordenada origen;
  final Coordenada destino;
  final String polilinea;

  /// Posición viva del conductor; `null` si no se monitorea.
  final Coordenada? posicion;

  /// Punto donde se detectó una parada prolongada o un desvío.
  final Coordenada? alerta;
  final double altura;

  @override
  State<MapaRuta> createState() => _MapaRutaState();
}

class _MapaRutaState extends State<MapaRuta> {
  static const double _zoomSeguimiento = 14;

  final MapController _controller = MapController();
  late List<Coordenada> _trazado = _calcularTrazado();
  bool _siguiendo = true;

  List<Coordenada> _calcularTrazado() {
    final List<Coordenada> puntos = decodificarPolilinea(widget.polilinea);
    // Sin trazado (proveedor sin geometría) se une origen y destino en línea
    // recta, solo como referencia visual.
    return puntos.length >= 2
        ? puntos
        : <Coordenada>[widget.origen, widget.destino];
  }

  @override
  void didUpdateWidget(MapaRuta anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.polilinea != widget.polilinea ||
        anterior.origen != widget.origen ||
        anterior.destino != widget.destino) {
      _trazado = _calcularTrazado();
      // El mapa ya está construido: hay que reencuadrar a mano.
      WidgetsBinding.instance.addPostFrameCallback((_) => _encuadrarRuta());
    }
    final Coordenada? posicion = widget.posicion;
    if (posicion != null && posicion != anterior.posicion && _siguiendo) {
      _controller.move(aLatLng(posicion), _zoomSeguimiento);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CameraFit get _encuadre => CameraFit.coordinates(
    coordinates: _trazado.map(aLatLng).toList(),
    padding: const EdgeInsets.all(AppSpacing.x8),
  );

  void _encuadrarRuta() {
    if (!mounted) return;
    _controller.fitCamera(_encuadre);
  }

  void _centrarEnConductor() {
    final Coordenada? posicion = widget.posicion;
    if (posicion == null) return;
    setState(() => _siguiendo = true);
    _controller.move(aLatLng(posicion), _zoomSeguimiento);
  }

  @override
  Widget build(BuildContext context) {
    final Coordenada? posicion = widget.posicion;
    final Coordenada? alerta = widget.alerta;

    return Semantics(
      label: posicion == null
          ? 'Mapa de la ruta de origen a destino'
          : 'Mapa de la ruta con tu posición actual',
      child: ClipRRect(
        borderRadius: AppRadius.mdAll,
        child: SizedBox(
          height: widget.altura,
          child: Stack(
            children: <Widget>[
              MapaBase(
                controller: _controller,
                opciones: MapOptions(
                  initialCameraFit: _encuadre,
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                  ),
                  // Arrastrar el mapa con el dedo deja de seguir al conductor.
                  onPositionChanged: (MapCamera _, bool hayGesto) {
                    if (hayGesto && _siguiendo && posicion != null) {
                      setState(() => _siguiendo = false);
                    }
                  },
                ),
                capas: <Widget>[
                  PolylineLayer(
                    polylines: <Polyline>[
                      // Con el conductor en ruta, la línea azul empieza donde
                      // él está y lo ya recorrido queda atenuado.
                      if (posicion != null)
                        Polyline(
                          points: rutaRecorrida(
                            posicion,
                            _trazado,
                          ).map(aLatLng).toList(),
                          strokeWidth: 4,
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                        ),
                      Polyline(
                        points:
                            (posicion == null
                                    ? _trazado
                                    : rutaRestante(posicion, _trazado))
                                .map(aLatLng)
                                .toList(),
                        strokeWidth: 4,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      _marcador(
                        widget.origen,
                        LucideIcons.circleDot,
                        AppColors.primary,
                        'Origen',
                      ),
                      _marcador(
                        widget.destino,
                        LucideIcons.mapPin,
                        AppColors.brandRed,
                        'Destino',
                      ),
                      if (alerta != null)
                        _marcador(
                          alerta,
                          LucideIcons.triangleAlert,
                          AppColors.warning,
                          'Ubicación de la alerta',
                        ),
                      if (posicion != null)
                        _marcador(
                          posicion,
                          LucideIcons.navigation,
                          AppColors.success,
                          'Tu posición',
                        ),
                    ],
                  ),
                ],
              ),
              if (posicion != null && !_siguiendo)
                Positioned(
                  right: AppSpacing.x2,
                  top: AppSpacing.x2,
                  child: _BotonMapa(
                    icono: LucideIcons.locateFixed,
                    etiqueta: 'Centrar en mi posición',
                    onPressed: _centrarEnConductor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _marcador(
    Coordenada punto,
    IconData icono,
    Color color,
    String etiqueta,
  ) {
    return Marker(
      point: aLatLng(punto),
      width: 36,
      height: 36,
      child: Semantics(
        label: etiqueta,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icono, size: 18, color: color),
        ),
      ),
    );
  }
}

class _BotonMapa extends StatelessWidget {
  const _BotonMapa({
    required this.icono,
    required this.etiqueta,
    required this.onPressed,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(side: BorderSide(color: AppColors.borderCard)),
      child: IconButton(
        tooltip: etiqueta,
        icon: Icon(icono, size: 20, color: AppColors.primary),
        onPressed: onPressed,
      ),
    );
  }
}
