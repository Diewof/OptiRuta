import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/checklist.dart';
import '../../domain/repositories/checklist_repository.dart';
import '../../domain/usecases/checklist_use_cases.dart';
import '../bloc/checklist_viaje_cubit.dart';

/// Checklist pre-viaje en el detalle del viaje (administrador): resultado,
/// fallas y, si quedó bloqueado, la autorización de la salida con motivo.
/// Sin checklist no muestra nada, salvo en un viaje asignado, donde avisa que
/// está pendiente.
class ChecklistViajeCard extends StatelessWidget {
  const ChecklistViajeCard({
    required this.viajeId,
    required this.viajeAsignado,
    super.key,
  });

  final String viajeId;
  final bool viajeAsignado;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChecklistViajeCubit>(
      create: (BuildContext context) {
        final ChecklistRepository repo = context.read<ChecklistRepository>();
        return ChecklistViajeCubit(
          viajeId: viajeId,
          obtener: ObtenerChecklistViajeUseCase(repo),
          autorizar: AutorizarSalidaChecklistUseCase(repo),
        );
      },
      child: BlocBuilder<ChecklistViajeCubit, ChecklistViajeState>(
        builder: (BuildContext context, ChecklistViajeState state) {
          return switch (state) {
            ChecklistViajeCargando() ||
            ChecklistViajeError() => const SizedBox.shrink(),
            ChecklistViajeListo(:final checklist) when checklist == null =>
              viajeAsignado
                  ? const _Contenedor(
                      child: Text(
                        'El conductor todavía no hizo el checklist del '
                        'vehículo.',
                        style: AppTypography.caption,
                      ),
                    )
                  : const SizedBox.shrink(),
            ChecklistViajeListo(:final checklist) => _Contenedor(
              child: _Detalle(checklist: checklist!),
            ),
          };
        },
      ),
    );
  }
}

class _Contenedor extends StatelessWidget {
  const _Contenedor({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x3),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: const Text(
                'Checklist del vehículo',
                style: AppTypography.subtitle,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            child,
          ],
        ),
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.checklist});

  final ChecklistViaje checklist;

  StatusBadge get _badge => switch (checklist.resultado) {
    ResultadoChecklist.aprobado => const StatusBadge(
      label: 'Aprobado',
      tone: StatusTone.success,
    ),
    ResultadoChecklist.conObservaciones => const StatusBadge(
      label: 'Con observaciones',
      tone: StatusTone.warning,
    ),
    ResultadoChecklist.bloqueado => StatusBadge(
      label: checklist.autorizado ? 'Salida autorizada' : 'Bloqueado',
      tone: checklist.autorizado ? StatusTone.warning : StatusTone.error,
    ),
  };

  Future<void> _autorizar(BuildContext context) async {
    final ChecklistViajeCubit cubit = context.read<ChecklistViajeCubit>();
    final bool? ok = await HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) =>
          _AutorizarSheet(alAutorizar: cubit.autorizarSalida),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Salida autorizada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                formatearFechaHoraCorta(checklist.fechaHora),
                style: AppTypography.caption,
              ),
            ),
            _badge,
          ],
        ),
        if (checklist.fallas.isEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.x2),
          const Text('Sin fallas reportadas.', style: AppTypography.body),
        ],
        for (final FallaChecklist f in checklist.fallas)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  f.critico ? '${f.nombre} · crítico' : f.nombre,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: f.critico ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                if (f.observacion != null)
                  Text(f.observacion!, style: AppTypography.caption),
              ],
            ),
          ),
        if (checklist.observaciones != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Observaciones: ${checklist.observaciones}',
            style: AppTypography.caption,
          ),
        ],
        if (checklist.autorizado) ...<Widget>[
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Autorizada: ${checklist.motivoAutorizacion}',
            style: AppTypography.caption,
          ),
        ],
        if (checklist.bloqueaSalida) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          const AppAlert(
            tono: AppAlertTono.advertencia,
            mensaje:
                'El conductor no puede comenzar el viaje hasta que autorices '
                'la salida.',
          ),
          const SizedBox(height: AppSpacing.x3),
          PrimaryActionButton(
            label: 'Autorizar salida',
            onPressed: () => _autorizar(context),
          ),
        ],
      ],
    );
  }
}

class _AutorizarSheet extends StatefulWidget {
  const _AutorizarSheet({required this.alAutorizar});

  final Future<void> Function(String motivo) alAutorizar;

  @override
  State<_AutorizarSheet> createState() => _AutorizarSheetState();
}

class _AutorizarSheetState extends State<_AutorizarSheet> {
  final TextEditingController _motivo = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_motivo.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el motivo de la autorización.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.alAutorizar(_motivo.text);
      if (mounted) Navigator.of(context).pop(true);
    } on CatalogoFailure catch (falla) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = falla.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Autorizar salida', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'Queda registrado con tu usuario y el motivo.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.x4),
        TextField(
          controller: _motivo,
          maxLength: 300,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Motivo (p. ej. frenos revisados en taller)',
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(mensaje: _error!),
        ],
        const SizedBox(height: AppSpacing.x4),
        PrimaryActionButton(
          label: 'Autorizar',
          grande: true,
          loading: _guardando,
          onPressed: _guardar,
        ),
        const SizedBox(height: AppSpacing.x2),
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
