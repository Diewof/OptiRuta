import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/distancia_utils.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../mantenimiento/domain/mantenimiento.dart';
import '../../../mantenimiento/presentation/registrar_mantenimiento_sheet.dart';
import '../../domain/entities/documento_vehiculo.dart';
import '../../domain/entities/ficha_tecnica.dart';
import '../../domain/entities/hoja_vida.dart';
import '../../domain/entities/vehiculo.dart';
import '../../domain/repositories/hoja_vida_repository.dart';
import '../../domain/usecases/obtener_hoja_vida_use_case.dart';
import '../../domain/usecases/registrar_documento_vehiculo_use_case.dart';
import '../bloc/hoja_vida_cubit.dart';

/// Hoja de vida del vehículo (solo administrador): ficha técnica, SOAT y
/// tecnomecánica vigentes, plan de mantenimiento preventivo y la línea de
/// tiempo de viajes, mantenimientos y checklists.
class HojaVidaPage extends StatelessWidget {
  const HojaVidaPage({required this.vehiculo, super.key});

  final Vehiculo vehiculo;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HojaVidaCubit>(
      create: (BuildContext context) {
        final HojaVidaRepository repo = context.read<HojaVidaRepository>();
        final MantenimientoRepository mantenimientos = context
            .read<MantenimientoRepository>();
        return HojaVidaCubit(
          vehiculoId: vehiculo.id,
          obtener: ObtenerHojaVidaUseCase(repo),
          registrarDocumento: RegistrarDocumentoVehiculoUseCase(repo),
          registrarMantenimiento: RegistrarMantenimientoUseCase(mantenimientos),
          listarTipos: ListarTiposMantenimientoUseCase(mantenimientos),
        );
      },
      child: _RefrescarAlVolver(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Hoja de vida · ${vehiculo.placa}'),
            actions: <Widget>[
              Builder(
                builder: (BuildContext context) => IconButton(
                  tooltip: 'Actualizar',
                  icon: const Icon(LucideIcons.refreshCw),
                  onPressed: () =>
                      context.read<HojaVidaCubit>().cargar(silencioso: true),
                ),
              ),
            ],
          ),
          body: BlocBuilder<HojaVidaCubit, HojaVidaState>(
            builder: (BuildContext context, HojaVidaState state) {
              return switch (state) {
                HojaVidaCargando() => const Padding(
                  padding: EdgeInsets.all(AppSpacing.x4),
                  child: Column(
                    children: <Widget>[
                      SkeletonBlock(alto: 120, radio: 16),
                      SizedBox(height: AppSpacing.x3),
                      SkeletonBlock(alto: 120, radio: 16),
                    ],
                  ),
                ),
                HojaVidaError(:final mensaje) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  children: <Widget>[
                    ErrorState(
                      mensaje: mensaje,
                      destacado: true,
                      onReintentar: () =>
                          context.read<HojaVidaCubit>().cargar(),
                    ),
                  ],
                ),
                HojaVidaListo(:final hojaVida) => RefreshIndicator(
                  onRefresh: () => context.read<HojaVidaCubit>().cargar(),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      _Ficha(
                        vehiculo: vehiculo,
                        odometroKm: hojaVida.odometroKm,
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      _Documentos(hojaVida: hojaVida),
                      const SizedBox(height: AppSpacing.x3),
                      _RegistrarMantenimiento(placa: vehiculo.placa),
                      const SizedBox(height: AppSpacing.x3),
                      _Plan(plan: hojaVida.plan),
                      const SizedBox(height: AppSpacing.x3),
                      _Historial(eventos: hojaVida.eventos),
                    ],
                  ),
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}

/// Recarga la hoja de vida cuando la app vuelve a primer plano (o la pestaña
/// del navegador recupera el foco): mantenimientos, checklists o viajes pudieron
/// registrarse mientras estaba abierta.
class _RefrescarAlVolver extends StatefulWidget {
  const _RefrescarAlVolver({required this.child});

  final Widget child;

  @override
  State<_RefrescarAlVolver> createState() => _RefrescarAlVolverState();
}

class _RefrescarAlVolverState extends State<_RefrescarAlVolver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<HojaVidaCubit>().cargar(silencioso: true);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(texto, style: AppTypography.subtitle),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(etiqueta, style: AppTypography.caption),
          ),
          Expanded(
            flex: 3,
            child: Text(
              valor ?? 'Sin registrar',
              textAlign: TextAlign.end,
              style: AppTypography.body.copyWith(
                color: valor == null
                    ? AppColors.textDisabled
                    : AppColors.textPrimary,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.vehiculo, required this.odometroKm});

  final Vehiculo vehiculo;
  final double odometroKm;

  @override
  Widget build(BuildContext context) {
    final FichaTecnica f = vehiculo.ficha;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Titulo('Ficha técnica'),
          _Dato('Tipo', vehiculo.tipo.etiqueta),
          _Dato('Marca y línea', f.descripcion),
          _Dato('Modelo (año)', f.modeloAnio?.toString()),
          _Dato('VIN / chasis', f.vin),
          _Dato('Número de motor', f.numeroMotor),
          _Dato('Ejes · llantas', _ejesLlantas(f)),
          _Dato(
            'PBV',
            f.pbvKg == null
                ? null
                : '${formatearKm(f.pbvKg!).replaceAll(' km', '')} kg',
          ),
          const Divider(height: AppSpacing.x4),
          _Dato('Odómetro (aprox.)', formatearKm(odometroKm)),
          const Text(
            'Se calcula con los km del GPS de cada viaje; puede diferir un poco '
            'del tablero.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }

  static String? _ejesLlantas(FichaTecnica f) {
    if (f.numeroEjes == null && f.cantidadLlantas == null) return null;
    return '${f.numeroEjes ?? '—'} ejes · ${f.cantidadLlantas ?? '—'} llantas';
  }
}

class _Documentos extends StatelessWidget {
  const _Documentos({required this.hojaVida});

  final HojaVida hojaVida;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Titulo('Documentos'),
          for (final TipoDocumentoVehiculo tipo
              in TipoDocumentoVehiculo.values) ...<Widget>[
            _FilaDocumento(tipo: tipo, documento: hojaVida.documento(tipo)),
            if (tipo != TipoDocumentoVehiculo.values.last)
              const Divider(height: AppSpacing.x4),
          ],
          const SizedBox(height: AppSpacing.x2),
          const Text(
            'Con el SOAT o la tecnomecánica vencidos (o sin registrar) el '
            'conductor no puede comenzar un viaje.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

/// Acción para registrar un mantenimiento de este vehículo, justo debajo de
/// los documentos. El plan y el historial de más abajo se actualizan al guardar.
class _RegistrarMantenimiento extends StatelessWidget {
  const _RegistrarMantenimiento({required this.placa});

  final String placa;

  Future<void> _abrir(BuildContext context) async {
    final HojaVidaCubit cubit = context.read<HojaVidaCubit>();
    final bool? ok = await HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) => RegistrarMantenimientoSheet(
        placa: placa,
        cargarTipos: cubit.tipos,
        alGuardar: cubit.registrarMantenimiento,
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mantenimiento registrado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Titulo('Mantenimiento'),
          const Text(
            'Registra aquí lo que se le hizo al vehículo: reinicia el plan '
            'preventivo y queda en el historial.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x3),
          SecondaryButton(
            label: 'Registrar mantenimiento',
            leadingIcon: LucideIcons.wrench,
            onPressed: () => _abrir(context),
          ),
        ],
      ),
    );
  }
}

class _FilaDocumento extends StatelessWidget {
  const _FilaDocumento({required this.tipo, required this.documento});

  final TipoDocumentoVehiculo tipo;
  final DocumentoVehiculo? documento;

  StatusBadge get _badge {
    final DocumentoVehiculo? d = documento;
    if (d == null) {
      return const StatusBadge(label: 'Sin registrar', tone: StatusTone.error);
    }
    return switch (d.estado) {
      EstadoDocumento.vigente => const StatusBadge(
        label: 'Vigente',
        tone: StatusTone.success,
      ),
      EstadoDocumento.porVencer => StatusBadge(
        label: d.diasRestantes == 0
            ? 'Vence hoy'
            : 'Vence en ${d.diasRestantes} d',
        tone: StatusTone.warning,
      ),
      EstadoDocumento.vencido => const StatusBadge(
        label: 'Vencido',
        tone: StatusTone.error,
      ),
    };
  }

  Future<void> _registrar(BuildContext context) async {
    final HojaVidaCubit cubit = context.read<HojaVidaCubit>();
    final bool? ok = await HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) => _RegistrarDocumentoSheet(
        tipo: tipo,
        alGuardar: cubit.registrarDocumento,
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${tipo.etiqueta} registrado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final DocumentoVehiculo? d = documento;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                tipo.etiqueta,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _badge,
          ],
        ),
        if (d != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Vence el ${formatearFecha(d.fechaVencimiento)}'
            '${d.entidadEmisora == null ? '' : ' · ${d.entidadEmisora}'}'
            '${d.numero == null ? '' : ' · N.º ${d.numero}'}',
            style: AppTypography.caption,
          ),
        ],
        const SizedBox(height: AppSpacing.x2),
        SecondaryButton(
          label: d == null ? 'Registrar' : 'Renovar',
          leadingIcon: LucideIcons.filePlus,
          onPressed: () => _registrar(context),
        ),
      ],
    );
  }
}

class _RegistrarDocumentoSheet extends StatefulWidget {
  const _RegistrarDocumentoSheet({required this.tipo, required this.alGuardar});

  final TipoDocumentoVehiculo tipo;
  final Future<void> Function({
    required TipoDocumentoVehiculo tipo,
    required DateTime fechaVencimiento,
    String? numero,
    String? entidadEmisora,
    DateTime? fechaExpedicion,
  })
  alGuardar;

  @override
  State<_RegistrarDocumentoSheet> createState() =>
      _RegistrarDocumentoSheetState();
}

class _RegistrarDocumentoSheetState extends State<_RegistrarDocumentoSheet> {
  final TextEditingController _numero = TextEditingController();
  final TextEditingController _entidad = TextEditingController();
  DateTime? _expedicion;
  DateTime? _vencimiento;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _numero.dispose();
    _entidad.dispose();
    super.dispose();
  }

  Future<DateTime?> _elegir(DateTime? inicial, {required bool futuro}) {
    final DateTime hoy = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: inicial ?? hoy,
      firstDate: DateTime(hoy.year - 10),
      lastDate: DateTime(hoy.year + 10),
      helpText: futuro ? 'Fecha de vencimiento' : 'Fecha de expedición',
    );
  }

  Future<void> _guardar() async {
    final DateTime? vence = _vencimiento;
    if (vence == null) {
      setState(() => _error = 'Elige la fecha de vencimiento.');
      return;
    }
    if (_expedicion != null && _expedicion!.isAfter(vence)) {
      setState(
        () => _error = 'La expedición no puede ser posterior al vencimiento.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.alGuardar(
        tipo: widget.tipo,
        fechaVencimiento: vence,
        numero: _numero.text,
        entidadEmisora: _entidad.text,
        fechaExpedicion: _expedicion,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on CatalogoFailure catch (falla) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = falla.codigo == CatalogoErrorCodigo.yaExiste
            ? 'Ya registraste un documento con ese vencimiento.'
            : falla.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esSoat = widget.tipo == TipoDocumentoVehiculo.soat;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Registrar ${widget.tipo.etiqueta}',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'El documento anterior queda en el historial.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.x4),
        AppSelectField(
          label: 'Vencimiento',
          valor: _vencimiento == null ? null : formatearFecha(_vencimiento!),
          marcador: 'Elegir fecha',
          onTap: () async {
            final DateTime? f = await _elegir(_vencimiento, futuro: true);
            if (f != null) setState(() => _vencimiento = f);
          },
        ),
        const SizedBox(height: AppSpacing.x3),
        AppSelectField(
          label: 'Expedición (opcional)',
          valor: _expedicion == null ? null : formatearFecha(_expedicion!),
          marcador: 'Elegir fecha',
          onTap: () async {
            final DateTime? f = await _elegir(_expedicion, futuro: false);
            if (f != null) setState(() => _expedicion = f);
          },
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _numero,
          decoration: InputDecoration(
            labelText: esSoat
                ? 'Número de póliza (opcional)'
                : 'Número de certificado (opcional)',
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _entidad,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: esSoat ? 'Aseguradora (opcional)' : 'CDA (opcional)',
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(mensaje: _error!),
        ],
        const SizedBox(height: AppSpacing.x4),
        PrimaryActionButton(
          label: 'Guardar',
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

class _Plan extends StatelessWidget {
  const _Plan({required this.plan});

  final List<ItemPlanMantenimiento> plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Titulo('Mantenimiento preventivo'),
          if (plan.isEmpty)
            const Text(
              'Este vehículo no tiene plan de mantenimiento.',
              style: AppTypography.caption,
            )
          else
            for (final ItemPlanMantenimiento item in plan)
              _FilaPlan(item: item),
          const SizedBox(height: AppSpacing.x2),
          const Text(
            'Cuenta desde el último mantenimiento de ese tipo (o desde el alta '
            'del vehículo). Registra el último mantenimiento conocido en '
            'Mantenimiento para que los avisos partan de un punto real.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _FilaPlan extends StatelessWidget {
  const _FilaPlan({required this.item});

  final ItemPlanMantenimiento item;

  StatusBadge get _badge => switch (item.estado) {
    EstadoPlanMantenimiento.alDia => const StatusBadge(
      label: 'Al día',
      tone: StatusTone.success,
    ),
    EstadoPlanMantenimiento.proximo => const StatusBadge(
      label: 'Próximo',
      tone: StatusTone.warning,
    ),
    EstadoPlanMantenimiento.vencido => const StatusBadge(
      label: 'Vencido',
      tone: StatusTone.error,
    ),
  };

  String get _detalle {
    final List<String> partes = <String>[
      if (item.kmRestantes != null)
        item.kmRestantes! <= 0
            ? 'excedido ${formatearKm(item.kmRestantes!.abs())}'
            : 'faltan ${formatearKm(item.kmRestantes!)}',
      if (item.diasRestantes != null)
        item.diasRestantes! <= 0
            ? 'excedido ${item.diasRestantes!.abs()} d'
            : 'faltan ${item.diasRestantes} d',
    ];
    final String ultimo = item.ultimoFecha == null
        ? 'Sin mantenimiento registrado'
        : 'Último: ${formatearFecha(item.ultimoFecha!)}';
    return partes.isEmpty ? ultimo : '${partes.join(' · ')} · $ultimo';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.tipoNombre,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(_detalle, style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          _badge,
        ],
      ),
    );
  }
}

class _Historial extends StatelessWidget {
  const _Historial({required this.eventos});

  final List<EventoHojaVida> eventos;

  static IconData _icono(TipoEventoHojaVida tipo) => switch (tipo) {
    TipoEventoHojaVida.viaje => LucideIcons.route,
    TipoEventoHojaVida.mantenimiento => LucideIcons.wrench,
    TipoEventoHojaVida.checklist => LucideIcons.clipboardCheck,
    TipoEventoHojaVida.documento => LucideIcons.fileText,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Titulo('Historial'),
          if (eventos.isEmpty)
            const Text(
              'Aún no hay viajes, mantenimientos ni checklists de este vehículo.',
              style: AppTypography.caption,
            )
          else
            for (final EventoHojaVida e in eventos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _icono(e.tipo),
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            e.titulo,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (e.detalle != null)
                            Text(e.detalle!, style: AppTypography.caption),
                          Text(
                            formatearFecha(e.fecha),
                            style: AppTypography.caption.copyWith(
                              fontFeatures: AppTypography.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
