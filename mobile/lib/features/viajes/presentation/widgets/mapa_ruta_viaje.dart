import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/figura_ruta.dart';
import '../../domain/detector_ruta.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/tipo_alerta_viaje.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../../domain/ruta_geometria.dart';
import '../../domain/servicios/servicio_ubicacion.dart';
import '../../domain/usecases/registrar_alerta_viaje_use_case.dart';
import '../bloc/monitor_ruta_cubit.dart';
import '../bloc/monitor_ruta_state.dart';
import 'mapa_ruta.dart';

/// Reemplaza a la figura estática de ruta: muestra el mapa del viaje cuando
/// tiene ubicaciones y, con [monitorear], sigue al conductor en vivo y avisa
/// de paradas o desvíos. Los viajes anteriores a los mapas (sin coordenadas)
/// conservan la figura.
class MapaRutaViaje extends StatelessWidget {
  const MapaRutaViaje({
    required this.viaje,
    this.monitorear = false,
    this.alerta,
    this.altura = 200,
    super.key,
  });

  final ViajeResumen viaje;

  /// Solo en la pantalla del conductor con el viaje EN_CURSO.
  final bool monitorear;

  /// Ubicación de una alerta de parada o desvío para marcar en el mapa.
  final Coordenada? alerta;
  final double altura;

  @override
  Widget build(BuildContext context) {
    if (!viaje.tieneMapa) return const FiguraRuta();

    final MapaRuta estatico = MapaRuta(
      origen: viaje.origenCoordenada!,
      destino: viaje.destinoCoordenada!,
      polilinea: viaje.rutaPolilinea ?? '',
      alerta: alerta,
      altura: altura,
    );
    if (!monitorear) return estatico;

    return BlocProvider<MonitorRutaCubit>(
      // La clave evita reutilizar el cubit si la pantalla pasa a otro viaje.
      key: ValueKey<String>(viaje.id),
      create: (BuildContext context) => MonitorRutaCubit(
        viajeId: viaje.id,
        ubicacion: context.read<ServicioUbicacion>(),
        detector: DetectorRuta(
          ruta: decodificarPolilinea(viaje.rutaPolilinea ?? ''),
        ),
        registrarAlerta: RegistrarAlertaViajeUseCase(
          context.read<ViajeRepository>(),
        ),
      )..iniciar(),
      child: _MapaEnVivo(viaje: viaje, altura: altura),
    );
  }
}

class _MapaEnVivo extends StatelessWidget {
  const _MapaEnVivo({required this.viaje, required this.altura});

  final ViajeResumen viaje;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MonitorRutaCubit, MonitorRutaState>(
      builder: (BuildContext context, MonitorRutaState state) {
        final MonitorRutaActivo? activo = state is MonitorRutaActivo
            ? state
            : null;
        final TipoAlertaViaje? alerta = activo?.alerta;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (alerta != null) ...<Widget>[
              GestureDetector(
                onTap: context.read<MonitorRutaCubit>().descartarAlerta,
                child: AppAlert(
                  tono: AppAlertTono.advertencia,
                  titulo: alerta.mensaje,
                  mensaje: 'Se avisó al administrador. Toca para ocultar.',
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
            ],
            MapaRuta(
              origen: viaje.origenCoordenada!,
              destino: viaje.destinoCoordenada!,
              polilinea: viaje.rutaPolilinea ?? '',
              posicion: activo?.posicion,
              altura: altura,
            ),
            if (state is MonitorRutaSinPermiso) ...<Widget>[
              const SizedBox(height: AppSpacing.x2),
              AppAlert(
                tono: AppAlertTono.advertencia,
                mensaje: state.bloqueado
                    ? 'Activa la ubicación del teléfono y su permiso para '
                          'esta app y ver tu posición en el mapa.'
                    : 'Sin permiso de ubicación no se muestra tu posición ni '
                          'se detectan paradas o desvíos.',
              ),
            ],
          ],
        );
      },
    );
  }
}
