import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/satisfaccion.dart';
import '../../domain/usecases/satisfaccion_use_cases.dart';

/// Estado de la encuesta del viaje, en su detalle (solo Administrador). Si
/// todavía no se respondió, permite copiar el mensaje con el enlace para
/// mandarlo por WhatsApp u otro canal. No se muestra si el viaje aún no generó
/// encuesta ni si falla la consulta: es informativa, no bloquea el detalle.
class EncuestaViajeCard extends StatefulWidget {
  const EncuestaViajeCard({
    required this.viajeId,
    required this.obtener,
    required this.remision,
    super.key,
  });

  final String viajeId;
  final String remision;
  final ObtenerEncuestaDeViajeUseCase obtener;

  @override
  State<EncuestaViajeCard> createState() => _EncuestaViajeCardState();
}

class _EncuestaViajeCardState extends State<EncuestaViajeCard> {
  late final Future<EncuestaViaje?> _encuesta = _cargar();

  Future<EncuestaViaje?> _cargar() async {
    try {
      return await widget.obtener(widget.viajeId);
    } on Object {
      return null;
    }
  }

  Future<void> _copiar(EncuestaViaje e) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            'Hola, gracias por confiar en nosotros. ¿Nos regala un minuto para '
            'calificar su servicio (remisión ${widget.remision})? ${e.enlace}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensaje copiado. Pégalo en WhatsApp o donde prefieras.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EncuestaViaje?>(
      future: _encuesta,
      builder: (BuildContext context, AsyncSnapshot<EncuestaViaje?> snap) {
        final EncuestaViaje? e = snap.data;
        if (e == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x3),
          child: AppCard(
            stripe: AppCardStripe.left,
            stripeColor: e.estado == EstadoEncuesta.respondida
                ? AppColors.success
                : AppColors.navy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      LucideIcons.messageSquareText,
                      size: 18,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    const Expanded(
                      child: Text(
                        'Encuesta de satisfacción',
                        style: AppTypography.subtitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(e.estado.etiqueta, style: AppTypography.body),
                if (e.estado == EstadoEncuesta.respondida &&
                    e.csatGlobal != null)
                  Text(
                    'Calificación ${e.csatGlobal!.toStringAsFixed(1).replaceAll('.', ',')} de 5'
                    '${e.nps == null ? '' : ' · recomendación ${e.nps}/10'}',
                    style: AppTypography.caption,
                  ),
                if (e.estado == EstadoEncuesta.sinContacto)
                  const Text(
                    'Agrega el correo del cliente para que se envíe sola, o '
                    'comparte el enlace a mano.',
                    style: AppTypography.caption,
                  ),
                if (e.compartible) ...<Widget>[
                  const SizedBox(height: AppSpacing.x2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _copiar(e),
                      icon: const Icon(LucideIcons.copy, size: 18),
                      label: const Text('Copiar mensaje con el enlace'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
