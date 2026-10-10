import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/conductor.dart';
import '../../domain/repositories/conductor_repository.dart';
import '../../domain/usecases/obtener_mi_conductor_use_case.dart';
import '../bloc/mi_conductor_cubit.dart';
import '../bloc/mi_conductor_state.dart';

/// Vista de solo lectura de la propia ficha de conductor. Sin edicion: solo
/// el administrador crea/edita el perfil operativo (RLS: el conductor solo
/// tiene SELECT sobre su propia fila).
class MiPerfilConductorPage extends StatelessWidget {
  const MiPerfilConductorPage({required this.usuarioId, super.key});

  final String usuarioId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MiConductorCubit>(
      create: (BuildContext context) => MiConductorCubit(
        obtenerMiConductor: ObtenerMiConductorUseCase(
          context.read<ConductorRepository>(),
        ),
        usuarioId: usuarioId,
      ),
      child: const _MiPerfilConductorView(),
    );
  }
}

class _MiPerfilConductorView extends StatelessWidget {
  const _MiPerfilConductorView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil de conductor')),
      body: BlocBuilder<MiConductorCubit, MiConductorState>(
        builder: (BuildContext context, MiConductorState state) {
          return switch (state) {
            MiConductorCargando() => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            MiConductorError(:final mensaje) => Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: AppAlert(mensaje: mensaje),
            ),
            MiConductorListo(conductor: null) => const _SinPerfil(),
            MiConductorListo(:final conductor) => _Ficha(conductor: conductor!),
          };
        },
      ),
    );
  }
}

class _SinPerfil extends StatelessWidget {
  const _SinPerfil();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: AppAlert(
        tono: AppAlertTono.advertencia,
        titulo: 'Perfil pendiente',
        mensaje:
            'El administrador todavía no te ha creado el perfil de '
            'conductor. Contáctalo para que lo complete.',
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.conductor});

  final Conductor conductor;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(conductor.nombre, style: AppTypography.title),
                  ),
                  StatusBadge.activo(conductor.activo),
                ],
              ),
              if (conductor.documento != null) ...<Widget>[
                const SizedBox(height: AppSpacing.x1),
                Text(
                  'Documento: ${conductor.documento}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const Divider(height: AppSpacing.x6),
              _Dato(etiqueta: 'Licencia', valor: conductor.licencia),
              _Dato(
                etiqueta: 'Vencimiento de licencia',
                valor: formatearFecha(conductor.fechaVencimientoLicencia),
              ),
              _Dato(
                etiqueta: 'Tipo de pago',
                valor: conductor.tipoPago.etiqueta,
              ),
              _Dato(
                etiqueta: 'Comisión',
                valor: '${conductor.porcentajeComision.toStringAsFixed(0)} %',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              etiqueta,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(valor, style: AppTypography.body),
        ],
      ),
    );
  }
}
