import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/figura_ruta.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/tipo_alerta_viaje.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../bloc/monitor_ruta_cubit.dart';
import '../bloc/monitor_ruta_registro.dart';
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

    // El cubit vive en el registro (no en este widget) para seguir activo si
    // el conductor cambia de pestaña o bloquea la pantalla.
    return BlocProvider<MonitorRutaCubit>.value(
      value: context.read<MonitorRutaRegistro>().obtener(viaje),
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
            if (activo != null && activo.consentimientoPendiente)
              const _PedirConsentimiento(),
            if (activo != null && activo.registrando) ...<Widget>[
              const SizedBox(height: AppSpacing.x2),
              const Text(
                'Tu ubicación se comparte con la empresa cada pocos minutos '
                'mientras el viaje esté en curso y la app abierta.',
                style: AppTypography.caption,
              ),
            ],
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

/// Consentimiento informado para registrar la ubicación (RF-23).
class _PedirConsentimiento extends StatelessWidget {
  const _PedirConsentimiento();

  @override
  Widget build(BuildContext context) {
    final MonitorRutaCubit cubit = context.read<MonitorRutaCubit>();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AppAlert(
            tono: AppAlertTono.advertencia,
            titulo: '¿Compartir tu ubicación con la empresa?',
            mensaje:
                'Mientras un viaje esté en curso y la app abierta, se guarda '
                'tu posición cada pocos minutos para que la empresa siga el '
                'viaje. Fuera de un viaje no se guarda nada. Puedes cambiarlo '
                'cuando quieras.',
          ),
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => cubit.responderConsentimiento(acepta: false),
                  child: const Text('Ahora no'),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: FilledButton(
                  onPressed: () => cubit.responderConsentimiento(acepta: true),
                  child: const Text('Acepto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
