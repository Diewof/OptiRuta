import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../vehiculos/domain/entities/tipo_vehiculo.dart';
import '../../domain/entities/checklist.dart';
import '../../domain/repositories/checklist_repository.dart';
import '../../domain/usecases/checklist_use_cases.dart';
import '../bloc/checklist_form_cubit.dart';

/// Checklist pre-viaje del conductor. Cada ítem nace en OK; solo se marcan las
/// fallas y cada una se describe. Al enviar vuelve con el [ChecklistViaje]
/// registrado (o `null` si el conductor salió sin enviarlo).
class ChecklistPage extends StatelessWidget {
  const ChecklistPage({
    required this.viajeId,
    required this.tipoVehiculo,
    required this.placa,
    super.key,
  });

  final String viajeId;
  final TipoVehiculo tipoVehiculo;
  final String placa;

  static Future<ChecklistViaje?> abrir(
    BuildContext context, {
    required String viajeId,
    required TipoVehiculo tipoVehiculo,
    required String placa,
  }) {
    return Navigator.of(context).push<ChecklistViaje>(
      MaterialPageRoute<ChecklistViaje>(
        builder: (_) => ChecklistPage(
          viajeId: viajeId,
          tipoVehiculo: tipoVehiculo,
          placa: placa,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChecklistFormCubit>(
      create: (BuildContext context) {
        final ChecklistRepository repo = context.read<ChecklistRepository>();
        return ChecklistFormCubit(
          viajeId: viajeId,
          tipoVehiculo: tipoVehiculo,
          listarItems: ListarItemsChecklistUseCase(repo),
          registrar: RegistrarChecklistUseCase(repo),
        );
      },
      child: _Vista(placa: placa),
    );
  }
}

class _Vista extends StatelessWidget {
  const _Vista({required this.placa});

  final String placa;

  Future<void> _enviar(BuildContext context) async {
    final ChecklistViaje? checklist = await context
        .read<ChecklistFormCubit>()
        .enviar();
    if (checklist != null && context.mounted) {
      Navigator.of(context).pop(checklist);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Checklist · $placa')),
      body: BlocBuilder<ChecklistFormCubit, ChecklistFormState>(
        builder: (BuildContext context, ChecklistFormState state) {
          if (state.cargando) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: SkeletonBlock(alto: 200, radio: 16),
            );
          }
          if (state.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje:
                      state.error ??
                      'No se pudo cargar el checklist del vehículo.',
                  destacado: true,
                  onReintentar: () =>
                      context.read<ChecklistFormCubit>().cargar(),
                ),
              ],
            );
          }
          return Column(
            children: <Widget>[
              Expanded(child: _Lista(state: state)),
              _Pie(state: state, alEnviar: () => _enviar(context)),
            ],
          );
        },
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.state});

  final ChecklistFormState state;

  @override
  Widget build(BuildContext context) {
    final List<String> grupos = <String>[];
    for (final ItemChecklist i in state.items) {
      if (!grupos.contains(i.grupo)) grupos.add(i.grupo);
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      children: <Widget>[
        const Text(
          'Revisa el vehículo antes de salir. Todo está en «Bien»; marca solo '
          'lo que falle y descríbelo.',
          style: AppTypography.body,
        ),
        const SizedBox(height: AppSpacing.x3),
        for (final String grupo in grupos) ...<Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(grupo, style: AppTypography.subtitle),
                ),
                const SizedBox(height: AppSpacing.x2),
                for (final ItemChecklist item in state.items.where(
                  (ItemChecklist i) => i.grupo == grupo,
                ))
                  _FilaItem(
                    key: ValueKey<String>(item.id),
                    item: item,
                    falla: state.fallas.containsKey(item.id),
                    descripcion: state.fallas[item.id] ?? '',
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        TextFormField(
          initialValue: state.notas,
          onChanged: context.read<ChecklistFormCubit>().escribirNotas,
          maxLines: 2,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Observaciones generales (opcional)',
          ),
        ),
      ],
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({
    required this.item,
    required this.falla,
    required this.descripcion,
    super.key,
  });

  final ItemChecklist item;
  final bool falla;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    final ChecklistFormCubit cubit = context.read<ChecklistFormCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.nombre,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (item.critico)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.x2),
                  child: Text(
                    'Crítico',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          _SelectorEstado(
            falla: falla,
            alCambiar: (bool v) => cubit.alternarFalla(item.id, falla: v),
          ),
          if (falla) ...<Widget>[
            const SizedBox(height: AppSpacing.x2),
            TextFormField(
              initialValue: descripcion,
              onChanged: (String t) => cubit.describirFalla(item.id, t),
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Describe la falla'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interruptor Bien / Falla: una "píldora" con un indicador deslizante que
/// pasa a verde (Bien) o rojo (Falla). Siempre icono + texto, no solo color.
class _SelectorEstado extends StatelessWidget {
  const _SelectorEstado({required this.falla, required this.alCambiar});

  final bool falla;
  final ValueChanged<bool> alCambiar;

  static const Duration _duracion = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final Color color = falla ? AppColors.error : AppColors.success;
    final Color fondo = falla ? AppColors.errorTint : AppColors.successTint;
    return Semantics(
      container: true,
      label: 'Estado del ítem',
      value: falla ? 'Falla' : 'Bien',
      child: AnimatedContainer(
        duration: _duracion,
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Stack(
          children: <Widget>[
            AnimatedAlign(
              duration: _duracion,
              curve: Curves.easeOutCubic,
              alignment: falla ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                _Opcion(
                  icono: LucideIcons.check,
                  texto: 'Bien',
                  activo: !falla,
                  colorInactivo: AppColors.success,
                  alTocar: () => alCambiar(false),
                ),
                _Opcion(
                  icono: LucideIcons.x,
                  texto: 'Falla',
                  activo: falla,
                  colorInactivo: AppColors.error,
                  alTocar: () => alCambiar(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.texto,
    required this.activo,
    required this.colorInactivo,
    required this.alTocar,
  });

  final IconData icono;
  final String texto;
  final bool activo;
  final Color colorInactivo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final Color color = activo ? Colors.white : colorInactivo;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alTocar,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icono, size: 18, color: color),
              const SizedBox(width: AppSpacing.x2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTypography.body.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                child: Text(texto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({required this.state, required this.alEnviar});

  final ChecklistFormState state;
  final VoidCallback alEnviar;

  @override
  Widget build(BuildContext context) {
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
              if (state.error != null) ...<Widget>[
                AppAlert(mensaje: state.error!),
                const SizedBox(height: AppSpacing.x3),
              ] else if (state.hayFallaCritica) ...<Widget>[
                const AppAlert(
                  tono: AppAlertTono.advertencia,
                  titulo: 'Falla crítica',
                  mensaje:
                      'No podrás comenzar el viaje hasta que el administrador '
                      'la autorice.',
                ),
                const SizedBox(height: AppSpacing.x3),
              ],
              PrimaryActionButton(
                label: 'Enviar checklist',
                grande: true,
                loading: state.enviando,
                onPressed: alEnviar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
