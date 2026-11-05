import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vibration/vibration.dart';

import '../../../../core/accessibility/announce.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../bloc/monitor_ruta_cubit.dart';
import '../bloc/monitor_ruta_registro.dart';
import '../bloc/monitor_ruta_state.dart';

/// Vibración y sonido leve del aviso. Se inyecta en [AvisoPausaActiva] para
/// probar sin plataforma.
typedef EmitirAvisoPausa = Future<void> Function();

/// Vibración con patrón (paquete `vibration`) y sonido propio suave
/// (`assets/sounds/pausa_activa.wav`, paquete `audioplayers`). Ambos paquetes
/// resuelven las diferencias entre fabricantes de Android que `HapticFeedback`
/// y `SystemSound` de Flutter no cubren. Cada parte falla por separado: sin
/// vibrador o sin audio la card igual se muestra.
Future<void> emitirAvisoPausaDelSistema() async {
  await Future.wait(<Future<void>>[_vibrar(), _sonar()]);
}

Future<void> _vibrar() async {
  try {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(
        pattern: <int>[0, 500, 250, 500, 250, 500],
        intensities: <int>[0, 255, 0, 255, 0, 255],
      );
      return;
    }
    await HapticFeedback.vibrate();
  } on Object {
    // Intencional: ver comentario de la función pública.
  }
}

Future<void> _sonar() async {
  final AudioPlayer reproductor = AudioPlayer();
  try {
    // Como una notificación: sigue su volumen y no corta la música.
    await reproductor.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.notification,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
    await reproductor.play(AssetSource('sounds/pausa_activa.wav'));
    await reproductor.onPlayerComplete.first.timeout(
      const Duration(seconds: 5),
    );
  } on Object {
    // Intencional: ver comentario de la función pública.
  } finally {
    await reproductor.dispose();
  }
}

/// Card «Toma una pausa activa» del conductor. Escucha al monitor del viaje
/// EN_CURSO: cuando se cumplen las horas máximas al volante (o el
/// administrador lanza la prueba) aparece la card, el teléfono vibra y suena
/// una sola vez. «Entendido» la oculta; solo una pausa real reinicia la
/// cuenta (ver `DetectorFatiga`).
class AvisoPausaActiva extends StatelessWidget {
  const AvisoPausaActiva({
    required this.viaje,
    this.emitir = emitirAvisoPausaDelSistema,
    super.key,
  });

  final ViajeResumen viaje;
  final EmitirAvisoPausa emitir;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MonitorRutaCubit>.value(
      value: context.read<MonitorRutaRegistro>().obtener(viaje),
      child: BlocConsumer<MonitorRutaCubit, MonitorRutaState>(
        listenWhen: (MonitorRutaState antes, MonitorRutaState ahora) =>
            _activa(ahora) && !_activa(antes),
        listener: (BuildContext context, MonitorRutaState _) {
          announceForAccessibility(
            context,
            'Llevas más de 4 horas al volante. Toma una pausa activa.',
          );
          unawaited(emitir());
        },
        builder: (BuildContext context, MonitorRutaState state) {
          if (!_activa(state)) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: _CardPausa(
              alEntender: context.read<MonitorRutaCubit>().descartarPausaActiva,
            ),
          );
        },
      ),
    );
  }

  static bool _activa(MonitorRutaState s) =>
      s is MonitorRutaActivo && s.pausaActiva;
}

class _CardPausa extends StatelessWidget {
  const _CardPausa({required this.alEntender});

  final VoidCallback alEntender;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: AppCard(
        stripe: AppCardStripe.left,
        stripeColor: AppColors.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  LucideIcons.coffee,
                  size: 22,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Toma una pausa activa',
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        'Llevas más de 4 horas al volante. Detente en un '
                        'lugar seguro, baja del vehículo, estira y descansa al '
                        'menos 15 minutos antes de seguir.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            SecondaryButton(label: 'Entendido', onPressed: alEntender),
          ],
        ),
      ),
    );
  }
}
