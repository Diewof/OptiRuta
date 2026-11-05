import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../domain/repositories/pausa_activa_repository.dart';
import '../../domain/usecases/pausa_activa_use_cases.dart';

/// Modo prueba (decisión del 2026-10-13): el administrador lanza el aviso de
/// pausa activa en el teléfono del conductor del viaje EN_CURSO. La app del
/// conductor lo recoge en unos segundos, con la app abierta.
class BotonProbarPausaActiva extends StatelessWidget {
  const BotonProbarPausaActiva({
    required this.viajeId,
    required this.conductor,
    super.key,
  });

  final String viajeId;
  final String conductor;

  Future<void> _probar(BuildContext context) async {
    final ScaffoldMessengerState mensajes = ScaffoldMessenger.of(context);
    final ProbarPausaActivaUseCase probar = ProbarPausaActivaUseCase(
      context.read<PausaActivaRepository>(),
    );
    String texto;
    try {
      await probar(viajeId: viajeId);
      texto =
          'Aviso enviado a $conductor. Le llegará en unos segundos si tiene '
          'la app abierta.';
    } on CatalogoFailure catch (falla) {
      texto = falla.mensaje;
    }
    mensajes.showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return SecondaryButton(
      label: 'Probar pausa activa',
      leadingIcon: LucideIcons.coffee,
      onPressed: () => _probar(context),
    );
  }
}
