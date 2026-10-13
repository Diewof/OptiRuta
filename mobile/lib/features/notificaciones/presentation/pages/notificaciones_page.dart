import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/error/catalogo_failure.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../../viajes/domain/entities/viaje_resumen.dart';
import '../../../viajes/domain/repositories/viaje_repository.dart';
import '../../../viajes/domain/usecases/obtener_viaje_resumen_use_case.dart';
import '../../../viajes/presentation/pages/viaje_detalle_page.dart';
import '../../domain/entities/notificacion.dart';
import '../../domain/entities/tipo_notificacion.dart';
import '../widgets/tipo_notificacion_visual.dart';
import '../../domain/repositories/notificacion_repository.dart';
import '../../domain/usecases/listar_notificaciones_use_case.dart';
import '../../domain/usecases/marcar_notificacion_leida_use_case.dart';
import '../../domain/usecases/marcar_todas_notificaciones_leidas_use_case.dart';
import '../bloc/notificacion_list_cubit.dart';
import '../bloc/notificacion_list_state.dart';

/// Notificaciones del Administrador: agrupadas por Hoy/Ayer/fecha, generadas
/// automáticamente en Postgres (`notificacion_generar`).
class NotificacionesPage extends StatelessWidget {
  const NotificacionesPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificacionListCubit>(
      create: (BuildContext context) {
        final NotificacionRepository repositorio = context
            .read<NotificacionRepository>();
        return NotificacionListCubit(
          listar: ListarNotificacionesUseCase(repositorio),
          marcarLeida: MarcarNotificacionLeidaUseCase(repositorio),
          marcarTodasLeidas: MarcarTodasNotificacionesLeidasUseCase(
            repositorio,
          ),
        );
      },
      child: _NotificacionesView(usuario: usuario),
    );
  }
}

class _NotificacionesView extends StatelessWidget {
  const _NotificacionesView({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Notificaciones',
      seccionActual: AdminSection.notificaciones,
      usuario: usuario,
      mostrarCampana: false,
      body: BlocBuilder<NotificacionListCubit, NotificacionListState>(
        builder: (BuildContext context, NotificacionListState state) {
          return switch (state) {
            NotificacionListCargando() => const LoadingState(),
            NotificacionListError(:final mensaje) => Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: ErrorState(
                mensaje: mensaje,
                destacado: true,
                onReintentar: () =>
                    context.read<NotificacionListCubit>().recargar(),
              ),
            ),
            NotificacionListListo(:final notificaciones)
                when notificaciones.isEmpty =>
              const Padding(
                padding: EdgeInsets.all(AppSpacing.x4),
                child: EmptyState(
                  icono: LucideIcons.bell,
                  titulo: 'Sin notificaciones',
                  mensaje: 'No hay alertas generadas todavía.',
                ),
              ),
            NotificacionListListo() => _ListaNotificaciones(state: state),
          };
        },
      ),
    );
  }
}

class _ListaNotificaciones extends StatefulWidget {
  const _ListaNotificaciones({required this.state});

  final NotificacionListListo state;

  @override
  State<_ListaNotificaciones> createState() => _ListaNotificacionesState();
}

class _ListaNotificacionesState extends State<_ListaNotificaciones> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
  }

  void _alDesplazar() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      context.read<NotificacionListCubit>().cargarSiguientePagina();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_alDesplazar);
    _scroll.dispose();
    super.dispose();
  }

  bool get _hayNoLeidas =>
      widget.state.notificaciones.any((Notificacion n) => !n.leida);

  @override
  Widget build(BuildContext context) {
    final List<_Grupo> grupos = _agrupar(widget.state.notificaciones);

    return RefreshIndicator(
      onRefresh: () => context.read<NotificacionListCubit>().recargar(),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          if (_hayNoLeidas)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    context.read<NotificacionListCubit>().marcarTodasLeidas(),
                child: const Text('Marcar todas como leídas'),
              ),
            ),
          for (final _Grupo grupo in grupos) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
              child: Text(
                grupo.etiqueta,
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (final Notificacion n in grupo.notificaciones) ...<Widget>[
              _NotificacionCard(notificacion: n),
              const SizedBox(height: AppSpacing.x2),
            ],
          ],
          if (widget.state.hayMas)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.x4),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  List<_Grupo> _agrupar(List<Notificacion> notificaciones) {
    final DateTime hoy = DateTime.now();
    final DateTime ayer = hoy.subtract(const Duration(days: 1));
    final Map<String, List<Notificacion>> porEtiqueta =
        <String, List<Notificacion>>{};

    for (final Notificacion n in notificaciones) {
      final DateTime f = n.fechaCreacion;
      final String etiqueta;
      if (_mismoDia(f, hoy)) {
        etiqueta = 'Hoy';
      } else if (_mismoDia(f, ayer)) {
        etiqueta = 'Ayer';
      } else {
        etiqueta =
            '${f.day.toString().padLeft(2, '0')}/'
            '${f.month.toString().padLeft(2, '0')}/${f.year}';
      }
      porEtiqueta.putIfAbsent(etiqueta, () => <Notificacion>[]).add(n);
    }

    return porEtiqueta.entries
        .map(
          (MapEntry<String, List<Notificacion>> e) =>
              _Grupo(etiqueta: e.key, notificaciones: e.value),
        )
        .toList();
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Grupo {
  const _Grupo({required this.etiqueta, required this.notificaciones});

  final String etiqueta;
  final List<Notificacion> notificaciones;
}

class _NotificacionCard extends StatelessWidget {
  const _NotificacionCard({required this.notificacion});

  final Notificacion notificacion;

  (IconData, Color) get _iconoYColor =>
      (notificacion.tipo.icono, notificacion.tipo.color);

  bool get _puedeAbrirViaje =>
      (notificacion.tipo.esAlertaDeRuta ||
          notificacion.tipo == TipoNotificacion.checklistFalla) &&
      notificacion.viajeId != null;

  Future<void> _alTocar(BuildContext context) async {
    final NotificacionListCubit cubit = context.read<NotificacionListCubit>();
    final ViajeRepository viajes = context.read<ViajeRepository>();
    final NavigatorState navegador = Navigator.of(context);
    final ScaffoldMessengerState mensajes = ScaffoldMessenger.of(context);

    if (!notificacion.leida) cubit.marcarLeida(notificacion.id);
    if (!_puedeAbrirViaje) return;

    try {
      final ViajeResumen viaje = await ObtenerViajeResumenUseCase(viajes)(
        notificacion.viajeId!,
      );
      await navegador.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => ViajeDetallePage(
            viaje: viaje,
            puedeCerrar: true,
            alerta: notificacion.ubicacion,
          ),
        ),
      );
    } on CatalogoFailure catch (falla) {
      mensajes.showSnackBar(SnackBar(content: Text(falla.mensaje)));
    }
  }

  String _tiempoRelativo() {
    final Duration transcurrido = DateTime.now().difference(
      notificacion.fechaCreacion,
    );
    if (transcurrido.inMinutes < 60) return '${transcurrido.inMinutes} min';
    if (transcurrido.inHours < 24) return '${transcurrido.inHours} h';
    return '${transcurrido.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icono, Color color) = _iconoYColor;

    return AppCard(
      stripe: AppCardStripe.left,
      stripeColor: color,
      child: InkWell(
        onTap: _puedeAbrirViaje || !notificacion.leida
            ? () => _alTocar(context)
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                borderRadius: AppRadius.mdAll,
              ),
              alignment: Alignment.center,
              child: Icon(icono, size: 20, color: color),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          notificacion.titulo,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Text(_tiempoRelativo(), style: AppTypography.caption),
                      if (!notificacion.leida) ...<Widget>[
                        const SizedBox(width: AppSpacing.x1),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.navy,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(notificacion.mensaje, style: AppTypography.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
