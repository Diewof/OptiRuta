import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/vehiculo_thumb.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/vehiculo.dart';
import '../../domain/repositories/vehiculo_repository.dart';
import '../../domain/usecases/inhabilitar_vehiculo_use_case.dart';
import '../../domain/usecases/listar_vehiculos_use_case.dart';
import '../bloc/vehiculo_list_cubit.dart';
import '../bloc/vehiculo_list_state.dart';
import 'vehiculo_form_page.dart';

/// Listado paginado de vehiculos (solo ADMINISTRADOR: la ruta que llega aqui
/// ya esta protegida por rol; RLS es la defensa real de escritura).
class VehiculosListPage extends StatelessWidget {
  const VehiculosListPage({this.usuario, super.key});

  /// Administrador autenticado: monta la pantalla dentro del armazón del panel.
  final Usuario? usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VehiculoListCubit>(
      create: (BuildContext context) => VehiculoListCubit(
        listar: ListarVehiculosUseCase(context.read<VehiculoRepository>()),
        inhabilitar: InhabilitarVehiculoUseCase(
          context.read<VehiculoRepository>(),
        ),
      ),
      child: _VehiculosListView(usuario: usuario),
    );
  }
}

class _VehiculosListView extends StatelessWidget {
  const _VehiculosListView({this.usuario});

  final Usuario? usuario;

  @override
  Widget build(BuildContext context) {
    final FloatingActionButton fab = FloatingActionButton.extended(
      onPressed: () async {
        final bool? creado = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(builder: (_) => const VehiculoFormPage()),
        );
        if (creado == true && context.mounted) {
          context.read<VehiculoListCubit>().recargar();
        }
      },
      icon: const Icon(LucideIcons.plus),
      label: const Text('Agregar vehículo'),
    );

    final Widget cuerpo = BlocBuilder<VehiculoListCubit, VehiculoListState>(
      builder: (BuildContext context, VehiculoListState state) {
        return switch (state) {
          VehiculoListCargando() => const _EsqueletoLista(),
          VehiculoListError(:final mensaje) => ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: <Widget>[
              ErrorState(
                mensaje: mensaje,
                destacado: true,
                onReintentar: () =>
                    context.read<VehiculoListCubit>().recargar(),
              ),
            ],
          ),
          VehiculoListListo(:final vehiculos) when vehiculos.isEmpty =>
            const _SinVehiculos(),
          VehiculoListListo() => _ListaVehiculos(state: state),
        };
      },
    );

    final Usuario? admin = usuario;
    if (admin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehículos')),
        floatingActionButton: fab,
        body: cuerpo,
      );
    }
    return AdminScaffold(
      titulo: 'Flota',
      seccionActual: AdminSection.flota,
      usuario: admin,
      floatingActionButton: fab,
      body: cuerpo,
    );
  }
}

class _EsqueletoLista extends StatelessWidget {
  const _EsqueletoLista();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.x4),
      child: Column(
        children: <Widget>[
          SkeletonBlock(alto: 96, radio: 16),
          SizedBox(height: AppSpacing.x2),
          SkeletonBlock(alto: 96, radio: 16),
          SizedBox(height: AppSpacing.x2),
          SkeletonBlock(alto: 96, radio: 16),
        ],
      ),
    );
  }
}

class _SinVehiculos extends StatelessWidget {
  const _SinVehiculos();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icono: LucideIcons.truck,
      titulo: 'Todavía no hay vehículos',
      mensaje: 'Agrega el primero para poder asignarlo a un viaje.',
    );
  }
}

class _ListaVehiculos extends StatefulWidget {
  const _ListaVehiculos({required this.state});

  final VehiculoListListo state;

  @override
  State<_ListaVehiculos> createState() => _ListaVehiculosState();
}

class _ListaVehiculosState extends State<_ListaVehiculos> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
  }

  void _alDesplazar() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      context.read<VehiculoListCubit>().cargarSiguientePagina();
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
    final VehiculoListListo state = widget.state;
    return RefreshIndicator(
      onRefresh: () => context.read<VehiculoListCubit>().recargar(),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x4,
          AppSpacing.x4,
          96,
        ),
        itemCount: state.vehiculos.length + (state.hayMas ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x2),
        itemBuilder: (BuildContext context, int i) {
          if (i >= state.vehiculos.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.x4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _VehiculoCard(vehiculo: state.vehiculos[i]);
        },
      ),
    );
  }
}

class _VehiculoCard extends StatelessWidget {
  const _VehiculoCard({required this.vehiculo});

  final Vehiculo vehiculo;

  Future<void> _editar(BuildContext context) async {
    final bool? actualizado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VehiculoFormPage(vehiculo: vehiculo),
      ),
    );
    if (actualizado == true && context.mounted) {
      context.read<VehiculoListCubit>().recargar();
    }
  }

  Future<void> _confirmarInhabilitar(BuildContext context) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Inhabilitar vehículo'),
        content: Text(
          '¿Inhabilitar el vehículo ${vehiculo.placa}? '
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

    final bool ok = await context.read<VehiculoListCubit>().inhabilitar(
      vehiculo.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Vehículo inhabilitado.' : 'No se pudo inhabilitar el vehículo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          VehiculoThumb(tipo: vehiculo.tipo, ancho: 80),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x1,
                  children: <Widget>[
                    Text(vehiculo.placa, style: AppTypography.subtitle),
                    StatusBadge.activo(vehiculo.activo),
                  ],
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  vehiculo.tipo.etiqueta,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${vehiculo.capacidadCarga.toStringAsFixed(0)} ton · '
                  '${vehiculo.rendimientoKmGalon.toStringAsFixed(1)} km/gal',
                  style: AppTypography.caption.copyWith(
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más acciones',
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
              if (vehiculo.activo)
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
