import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/conductor.dart';
import '../../domain/repositories/conductor_repository.dart';
import '../../domain/usecases/inhabilitar_conductor_use_case.dart';
import '../../domain/usecases/listar_conductores_use_case.dart';
import '../bloc/conductor_list_cubit.dart';
import '../bloc/conductor_list_state.dart';
import 'conductor_form_page.dart';

/// Listado paginado de conductores (solo ADMINISTRADOR: la ruta que llega
/// aqui ya esta protegida por rol; RLS es la defensa real de escritura).
class ConductoresListPage extends StatelessWidget {
  const ConductoresListPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConductorListCubit>(
      create: (BuildContext context) => ConductorListCubit(
        listar: ListarConductoresUseCase(context.read<ConductorRepository>()),
        inhabilitar: InhabilitarConductorUseCase(
          context.read<ConductorRepository>(),
        ),
      ),
      child: _ConductoresListView(usuario: usuario),
    );
  }
}

class _ConductoresListView extends StatelessWidget {
  const _ConductoresListView({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Personas',
      seccionActual: AdminSection.conductores,
      usuario: usuario,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final bool? creado = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(builder: (_) => const ConductorFormPage()),
          );
          if (creado == true && context.mounted) {
            context.read<ConductorListCubit>().recargar();
          }
        },
        icon: const Icon(LucideIcons.plus),
        label: const Text('Agregar conductor'),
      ),
      body: BlocBuilder<ConductorListCubit, ConductorListState>(
        builder: (BuildContext context, ConductorListState state) {
          return switch (state) {
            ConductorListCargando() => const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: Column(
                children: <Widget>[
                  SkeletonBlock(alto: 88, radio: 16),
                  SizedBox(height: AppSpacing.x2),
                  SkeletonBlock(alto: 88, radio: 16),
                  SizedBox(height: AppSpacing.x2),
                  SkeletonBlock(alto: 88, radio: 16),
                ],
              ),
            ),
            ConductorListError(:final mensaje) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje: mensaje,
                  destacado: true,
                  onReintentar: () =>
                      context.read<ConductorListCubit>().recargar(),
                ),
              ],
            ),
            ConductorListListo(:final conductores) when conductores.isEmpty =>
              const _SinConductores(),
            ConductorListListo() => _ListaConductores(state: state),
          };
        },
      ),
    );
  }
}

class _SinConductores extends StatelessWidget {
  const _SinConductores();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icono: LucideIcons.idCard,
      titulo: 'Todavía no hay conductores',
      mensaje: 'Los conductores con perfil creado aparecerán aquí.',
    );
  }
}

class _ListaConductores extends StatefulWidget {
  const _ListaConductores({required this.state});

  final ConductorListListo state;

  @override
  State<_ListaConductores> createState() => _ListaConductoresState();
}

class _ListaConductoresState extends State<_ListaConductores> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
  }

  void _alDesplazar() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      context.read<ConductorListCubit>().cargarSiguientePagina();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_alDesplazar);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ConductorListListo state = widget.state;
    return RefreshIndicator(
      onRefresh: () => context.read<ConductorListCubit>().recargar(),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.all(AppSpacing.x4),
        itemCount: state.conductores.length + (state.hayMas ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x2),
        itemBuilder: (BuildContext context, int i) {
          if (i >= state.conductores.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.x4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _ConductorCard(conductor: state.conductores[i]);
        },
      ),
    );
  }
}

class _ConductorCard extends StatelessWidget {
  const _ConductorCard({required this.conductor});

  final Conductor conductor;

  Future<void> _editar(BuildContext context) async {
    final bool? actualizado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ConductorFormPage(conductor: conductor),
      ),
    );
    if (actualizado == true && context.mounted) {
      context.read<ConductorListCubit>().recargar();
    }
  }

  Future<void> _confirmarInhabilitar(BuildContext context) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Inhabilitar conductor'),
        content: Text(
          '¿Inhabilitar a ${conductor.nombre}? '
          'No se podrá asignar a nuevos viajes.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Inhabilitar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    final bool ok = await context.read<ConductorListCubit>().inhabilitar(
      conductor.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Conductor inhabilitado.'
              : 'No se pudo inhabilitar al conductor.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        conductor.nombre,
                        style: AppTypography.subtitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    StatusBadge.activo(conductor.activo),
                  ],
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  'Licencia ${conductor.licencia} · vence '
                  '${formatearFecha(conductor.fechaVencimientoLicencia)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  '${conductor.tipoPago.etiqueta} · '
                  '${conductor.porcentajeComision.toStringAsFixed(0)} % comisión',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.x1),
                _EstadoLicencia(
                  vencimiento: conductor.fechaVencimientoLicencia,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreVertical),
            onSelected: (String accion) {
              if (accion == 'editar') _editar(context);
              if (accion == 'inhabilitar') _confirmarInhabilitar(context);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'editar',
                child: Text('Editar'),
              ),
              if (conductor.activo)
                const PopupMenuItem<String>(
                  value: 'inhabilitar',
                  child: Text('Inhabilitar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Estado de vigencia de la licencia: vencida (rojo), por vencer en 30 días o
/// menos (ámbar), o vigente (verde). Siempre icono + texto, nunca solo color.
class _EstadoLicencia extends StatelessWidget {
  const _EstadoLicencia({required this.vencimiento});

  final DateTime vencimiento;

  @override
  Widget build(BuildContext context) {
    final int diasRestantes = vencimiento.difference(DateTime.now()).inDays;

    final (IconData icono, Color color, String texto) = switch (diasRestantes) {
      < 0 => (LucideIcons.circleAlert, AppColors.error, 'Licencia vencida'),
      <= 30 => (
        LucideIcons.triangleAlert,
        AppColors.warning,
        'Licencia vence en $diasRestantes días',
      ),
      _ => (LucideIcons.circleCheck, AppColors.success, 'Licencia vigente'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icono, size: 14, color: color),
        const SizedBox(width: AppSpacing.x1),
        Text(texto, style: AppTypography.caption.copyWith(color: color)),
      ],
    );
  }
}
