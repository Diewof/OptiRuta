import '../../../../core/utils/busqueda_utils.dart';
import '../../../../core/widgets/campo_busqueda.dart';

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
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/cliente.dart';
import '../../domain/repositories/cliente_repository.dart';
import '../../domain/usecases/inhabilitar_cliente_use_case.dart';
import '../../domain/usecases/listar_clientes_use_case.dart';
import '../bloc/cliente_list_cubit.dart';
import '../bloc/cliente_list_state.dart';
import 'cliente_form_page.dart';

/// Listado paginado de clientes. Lectura para ADMINISTRADOR y CONDUCTOR
/// (RLS); las acciones de escritura (agregar/editar/inhabilitar) solo se
/// muestran cuando [esAdministrador] es `true` — RLS las bloquearia igual,
/// esto es solo para no ofrecer una accion que el servidor va a rechazar.
class ClientesListPage extends StatelessWidget {
  const ClientesListPage({
    required this.esAdministrador,
    this.usuario,
    super.key,
  });

  final bool esAdministrador;

  /// Si viene, la pantalla se monta dentro del armazón del panel de admin.
  final Usuario? usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ClienteListCubit>(
      create: (BuildContext context) => ClienteListCubit(
        listar: ListarClientesUseCase(context.read<ClienteRepository>()),
        inhabilitar: InhabilitarClienteUseCase(
          context.read<ClienteRepository>(),
        ),
      ),
      child: _ClientesListView(
        esAdministrador: esAdministrador,
        usuario: usuario,
      ),
    );
  }
}

class _ClientesListView extends StatelessWidget {
  const _ClientesListView({required this.esAdministrador, this.usuario});

  final bool esAdministrador;
  final Usuario? usuario;

  @override
  Widget build(BuildContext context) {
    final Widget? fab = !esAdministrador
        ? null
        : FloatingActionButton.extended(
            onPressed: () async {
              final bool? creado = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => const ClienteFormPage(),
                ),
              );
              if (creado == true && context.mounted) {
                context.read<ClienteListCubit>().recargar();
              }
            },
            icon: const Icon(LucideIcons.plus),
            label: const Text('Agregar cliente'),
          );

    final Widget cuerpo = BlocBuilder<ClienteListCubit, ClienteListState>(
      builder: (BuildContext context, ClienteListState state) {
        return switch (state) {
          ClienteListCargando() => const Padding(
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
          ClienteListError(:final mensaje) => ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: <Widget>[
              ErrorState(
                mensaje: mensaje,
                destacado: true,
                onReintentar: () => context.read<ClienteListCubit>().recargar(),
              ),
            ],
          ),
          ClienteListListo(:final clientes) when clientes.isEmpty =>
            const _SinClientes(),
          ClienteListListo() => _ListaClientes(
            state: state,
            esAdministrador: esAdministrador,
          ),
        };
      },
    );

    final Usuario? admin = usuario;
    if (admin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Clientes')),
        floatingActionButton: fab,
        body: cuerpo,
      );
    }
    return AdminScaffold(
      titulo: 'Personas',
      seccionActual: AdminSection.clientes,
      usuario: admin,
      floatingActionButton: fab,
      body: cuerpo,
    );
  }
}

class _SinClientes extends StatelessWidget {
  const _SinClientes();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icono: LucideIcons.users,
      titulo: 'Todavía no hay clientes',
      mensaje: 'Los clientes que registres aparecerán aquí.',
    );
  }
}

class _ListaClientes extends StatefulWidget {
  const _ListaClientes({required this.state, required this.esAdministrador});

  final ClienteListListo state;
  final bool esAdministrador;

  @override
  State<_ListaClientes> createState() => _ListaClientesState();
}

class _ListaClientesState extends State<_ListaClientes> {
  final ScrollController _scroll = ScrollController();
  String _consulta = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
  }

  void _alDesplazar() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      context.read<ClienteListCubit>().cargarSiguientePagina();
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
    final ClienteListListo state = widget.state;
    final List<Cliente> items = filtrarPorTexto<Cliente>(
      state.clientes,
      _consulta,
      (Cliente c) => <String?>[c.nombre, c.documento, c.correo, c.telefono],
    );
    final Widget lista = RefreshIndicator(
      onRefresh: () => context.read<ClienteListCubit>().recargar(),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x4,
          AppSpacing.x4,
          96,
        ),
        itemCount: items.length + (state.hayMas ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x2),
        itemBuilder: (BuildContext context, int i) {
          if (i >= items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.x4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _ClienteCard(
            cliente: items[i],
            esAdministrador: widget.esAdministrador,
          );
        },
      ),
    );
    return Column(
      children: <Widget>[
        CampoBusqueda(
          etiqueta: 'Buscar cliente',
          alCambiar: (String t) => setState(() => _consulta = t),
        ),
        Expanded(child: lista),
      ],
    );
  }
}

class _ClienteCard extends StatelessWidget {
  const _ClienteCard({required this.cliente, required this.esAdministrador});

  final Cliente cliente;
  final bool esAdministrador;

  Future<void> _editar(BuildContext context) async {
    final bool? actualizado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ClienteFormPage(cliente: cliente),
      ),
    );
    if (actualizado == true && context.mounted) {
      context.read<ClienteListCubit>().recargar();
    }
  }

  Future<void> _confirmarInhabilitar(BuildContext context) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Inhabilitar cliente'),
        content: Text(
          '¿Inhabilitar a ${cliente.nombre}? '
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

    final bool ok = await context.read<ClienteListCubit>().inhabilitar(
      cliente.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Cliente inhabilitado.' : 'No se pudo inhabilitar el cliente.',
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
                        cliente.nombre,
                        style: AppTypography.subtitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    StatusBadge.activo(cliente.activo),
                  ],
                ),
                if (cliente.documento != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'Doc. ${cliente.documento}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (cliente.telefono != null ||
                    cliente.direccion != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    <String>[
                      if (cliente.telefono != null) cliente.telefono!,
                      if (cliente.direccion != null) cliente.direccion!,
                    ].join(' · '),
                    style: AppTypography.caption,
                  ),
                ],
              ],
            ),
          ),
          if (esAdministrador)
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
                if (cliente.activo)
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
