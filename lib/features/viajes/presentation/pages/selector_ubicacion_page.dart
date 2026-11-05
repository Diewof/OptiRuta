import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/lugar.dart';
import '../../domain/usecases/buscar_lugares_use_case.dart';
import '../../domain/usecases/lugar_en_coordenada_use_case.dart';
import '../bloc/selector_ubicacion_cubit.dart';
import '../bloc/selector_ubicacion_state.dart';
import '../widgets/mapa_ruta.dart';

/// Selector de ubicación (origen o destino): buscador con autocompletado +
/// mapa de Colombia con un pin fijo al centro. El administrador escribe y
/// elige una sugerencia, o arrastra el mapa, y confirma; devuelve un [Lugar]
/// (nombre + coordenada) con `Navigator.pop`.
class SelectorUbicacionPage extends StatelessWidget {
  const SelectorUbicacionPage({
    required this.titulo,
    required this.buscar,
    required this.lugarEn,
    this.inicial,
    super.key,
  });

  final String titulo;
  final BuscarLugaresUseCase buscar;
  final LugarEnCoordenadaUseCase lugarEn;
  final Lugar? inicial;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SelectorUbicacionCubit>(
      create: (_) => SelectorUbicacionCubit(
        buscar: buscar,
        lugarEn: lugarEn,
        inicial: inicial,
      ),
      child: _SelectorView(titulo: titulo, inicial: inicial),
    );
  }
}

class _SelectorView extends StatefulWidget {
  const _SelectorView({required this.titulo, this.inicial});

  final String titulo;
  final Lugar? inicial;

  @override
  State<_SelectorView> createState() => _SelectorViewState();
}

class _SelectorViewState extends State<_SelectorView> {
  static const double _zoomLugar = 13;
  static const Coordenada _centroColombia = Coordenada(4.6, -74.1);

  // El servicio público de búsqueda es de uso razonable: se espera a que deje
  // de teclear en lugar de consultar en cada tecla.
  static const Duration _esperaBusqueda = Duration(milliseconds: 400);

  final TextEditingController _busqueda = TextEditingController();
  final MapController _mapa = MapController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(_alEscribir);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busqueda.dispose();
    _mapa.dispose();
    super.dispose();
  }

  void _alEscribir() {
    _debounce?.cancel();
    _debounce = Timer(
      _esperaBusqueda,
      () => context.read<SelectorUbicacionCubit>().buscar(_busqueda.text),
    );
  }

  void _elegirResultado(Lugar lugar) {
    context.read<SelectorUbicacionCubit>().elegirResultado(lugar);
    FocusScope.of(context).unfocus();
    _mapa.move(aLatLng(lugar.coordenada), _zoomLugar);
  }

  @override
  Widget build(BuildContext context) {
    final Lugar? inicial = widget.inicial;

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: BlocBuilder<SelectorUbicacionCubit, SelectorUbicacionState>(
        builder: (BuildContext context, SelectorUbicacionState state) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: AppTextField(
                  label: 'Buscar lugar',
                  hint: 'Ciudad, dirección o sitio en Colombia',
                  controller: _busqueda,
                  prefixIcon: LucideIcons.search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (String texto) {
                    _debounce?.cancel();
                    context.read<SelectorUbicacionCubit>().buscar(texto);
                  },
                ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x4,
                    0,
                    AppSpacing.x4,
                    AppSpacing.x2,
                  ),
                  child: AppAlert(
                    tono: AppAlertTono.advertencia,
                    mensaje: state.error!,
                  ),
                ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    MapaBase(
                      controller: _mapa,
                      opciones: MapOptions(
                        // Sin ubicación previa el mapa abre mostrando
                        // Colombia completa; no se puede salir de ella.
                        initialCameraFit: inicial == null
                            ? encuadreColombia
                            : null,
                        initialCenter: aLatLng(
                          inicial?.coordenada ?? _centroColombia,
                        ),
                        initialZoom: _zoomLugar,
                        cameraConstraint: restriccionColombia,
                        interactionOptions: const InteractionOptions(
                          flags:
                              InteractiveFlag.drag |
                              InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom |
                              InteractiveFlag.flingAnimation,
                        ),
                        onMapEvent: (MapEvent evento) {
                          // Solo los gestos del usuario mueven el pin; los
                          // desplazamientos por código (elegir un resultado)
                          // ya traen su propio lugar.
                          if (evento is MapEventMoveEnd &&
                              evento.source != MapEventSource.mapController) {
                            context.read<SelectorUbicacionCubit>().moverPin(
                              Coordenada(
                                evento.camera.center.latitude,
                                evento.camera.center.longitude,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    // Pin fijo al centro: su punta marca la ubicación.
                    const IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 36),
                          child: Icon(
                            LucideIcons.mapPin,
                            size: 40,
                            color: AppColors.brandRed,
                            semanticLabel: 'Ubicación elegida',
                          ),
                        ),
                      ),
                    ),
                    if (state.resultados.isNotEmpty ||
                        state.buscando ||
                        state.busquedaSinResultados)
                      Positioned.fill(
                        child: _ListaResultados(
                          state: state,
                          alElegir: _elegirResultado,
                        ),
                      ),
                  ],
                ),
              ),
              _PieSeleccion(state: state),
            ],
          );
        },
      ),
    );
  }
}

class _ListaResultados extends StatelessWidget {
  const _ListaResultados({required this.state, required this.alElegir});

  final SelectorUbicacionState state;
  final ValueChanged<Lugar> alElegir;

  @override
  Widget build(BuildContext context) {
    // Material (no ColoredBox): ListTile pinta su fondo y su efecto táctil en
    // el Material más cercano.
    return Material(
      color: AppColors.card,
      child: state.buscando && state.resultados.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.busquedaSinResultados
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: Text(
                'No se encontró ese lugar en Colombia. Prueba con otro '
                'nombre o mueve el mapa para ubicarlo.',
              ),
            )
          : ListView.separated(
              itemCount: state.resultados.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int i) {
                final Lugar lugar = state.resultados[i];
                return ListTile(
                  leading: const Icon(
                    LucideIcons.mapPin,
                    color: AppColors.textSecondary,
                  ),
                  title: Text(
                    lugar.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => alElegir(lugar),
                );
              },
            ),
    );
  }
}

class _PieSeleccion extends StatelessWidget {
  const _PieSeleccion({required this.state});

  final SelectorUbicacionState state;

  @override
  Widget build(BuildContext context) {
    final Lugar? seleccion = state.seleccion;

    return Material(
      color: AppColors.card,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                state.resolviendo
                    ? 'Buscando el nombre del lugar...'
                    : seleccion?.nombre ??
                          'Busca un lugar o mueve el mapa para colocar el pin.',
                style: AppTypography.body.copyWith(
                  color: seleccion == null && !state.resolviendo
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.x3),
              PrimaryActionButton(
                label: 'Confirmar ubicación',
                onPressed: seleccion == null || state.resolviendo
                    ? null
                    : () => Navigator.of(context).pop(seleccion),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
