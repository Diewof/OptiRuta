import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/miles_formatter.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/tarifa_combustible.dart';
import '../../domain/repositories/tarifa_combustible_repository.dart';
import '../../domain/usecases/tarifa_use_cases.dart';
import '../bloc/tarifa_list_cubit.dart';

/// Tarifas de ACPM por ciudad y fecha de vigencia (RF-12). El administrador
/// registra el precio vigente y lo corrige; el scraper mensual agrega filas
/// automáticas para la ciudad de referencia.
class TarifasPage extends StatelessWidget {
  const TarifasPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TarifaListCubit>(
      create: (BuildContext context) {
        final TarifaCombustibleRepository repo = context
            .read<TarifaCombustibleRepository>();
        return TarifaListCubit(
          listar: ListarTarifasUseCase(repo),
          registrar: RegistrarTarifaUseCase(repo),
          actualizarPrecio: ActualizarPrecioTarifaUseCase(repo),
        );
      },
      child: _TarifasView(usuario: usuario),
    );
  }
}

class _TarifasView extends StatelessWidget {
  const _TarifasView({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Tarifas de ACPM',
      seccionActual: AdminSection.tarifas,
      usuario: usuario,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Agregar tarifa'),
      ),
      body: BlocBuilder<TarifaListCubit, TarifaListState>(
        builder: (BuildContext context, TarifaListState state) {
          return switch (state) {
            TarifaListCargando() => const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: Column(
                children: <Widget>[
                  SkeletonBlock(alto: 80, radio: 16),
                  SizedBox(height: AppSpacing.x2),
                  SkeletonBlock(alto: 80, radio: 16),
                ],
              ),
            ),
            TarifaListError(:final mensaje) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje: mensaje,
                  destacado: true,
                  onReintentar: () => context.read<TarifaListCubit>().cargar(),
                ),
              ],
            ),
            TarifaListListo(:final tarifas) when tarifas.isEmpty =>
              const EmptyState(
                icono: LucideIcons.fuel,
                titulo: 'Todavía no hay tarifas',
                mensaje:
                    'Sin una tarifa para la ciudad de origen, el ACPM estimado '
                    'de los viajes queda en \$0.',
              ),
            TarifaListListo() => _Lista(state: state),
          };
        },
      ),
    );
  }
}

Future<void> _abrirFormulario(
  BuildContext context, {
  TarifaCombustible? editar,
}) async {
  final TarifaListCubit cubit = context.read<TarifaListCubit>();
  final bool? ok = await HojaInferior.mostrar<bool>(
    context,
    builder: (BuildContext _) => _TarifaSheet(
      editar: editar,
      alGuardar: (String ciudad, double precio, DateTime fecha) {
        return editar == null
            ? cubit.registrar(
                ciudad: ciudad,
                precioGalon: precio,
                fechaVigenciaDesde: fecha,
              )
            : cubit.actualizarPrecio(id: editar.id, precioGalon: precio);
      },
    ),
  );
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Tarifa guardada')));
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.state});

  final TarifaListListo state;

  @override
  Widget build(BuildContext context) {
    final DateTime hoy = DateTime.now();
    final Set<String> vigentes = state
        .vigentes(hoy)
        .map((TarifaCombustible t) => t.id)
        .toSet();
    final NumberFormatCop moneda = NumberFormatCop();

    return RefreshIndicator(
      onRefresh: () => context.read<TarifaListCubit>().cargar(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x4,
          AppSpacing.x4,
          96,
        ),
        itemCount: state.tarifas.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x2),
        itemBuilder: (BuildContext context, int i) {
          final TarifaCombustible t = state.tarifas[i];
          final bool vigente = vigentes.contains(t.id);
          return AppCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        t.ciudad,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${moneda.formatear(t.precioGalon)} por galón',
                        style: AppTypography.subtitle.copyWith(
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Desde ${formatearFecha(t.fechaVigenciaDesde)} · '
                        '${t.automatica ? 'Automática' : 'Manual'}'
                        '${vigente ? ' · Vigente' : ''}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar precio de ${t.ciudad}',
                  onPressed: () => _abrirFormulario(context, editar: t),
                  icon: const Icon(LucideIcons.pencil),
                  color: AppColors.primary,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TarifaSheet extends StatefulWidget {
  const _TarifaSheet({required this.alGuardar, this.editar});

  final TarifaCombustible? editar;
  final Future<void> Function(String ciudad, double precio, DateTime fecha)
  alGuardar;

  @override
  State<_TarifaSheet> createState() => _TarifaSheetState();
}

class _TarifaSheetState extends State<_TarifaSheet> {
  late final TextEditingController _ciudad = TextEditingController(
    text: widget.editar?.ciudad,
  );
  late final TextEditingController _precio = TextEditingController(
    text: widget.editar == null
        ? ''
        : MilesFormatter.conMiles(
            widget.editar!.precioGalon.round().toString(),
          ),
  );
  late DateTime _fecha = widget.editar?.fechaVigenciaDesde ?? _hoy();
  bool _guardando = false;
  String? _errorCiudad;
  String? _errorPrecio;
  String? _errorGuardado;

  static DateTime _hoy() {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _editando => widget.editar != null;

  @override
  void dispose() {
    _ciudad.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final DateTime? f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (f != null) setState(() => _fecha = f);
  }

  Future<void> _guardar() async {
    final String ciudad = _ciudad.text.trim();
    final double? precio = double.tryParse(
      _precio.text.replaceAll(RegExp(r'\D'), ''),
    );
    setState(() {
      _errorCiudad = ciudad.isEmpty ? 'Escribe la ciudad.' : null;
      _errorPrecio = precio == null || precio <= 0
          ? 'Escribe el precio por galón.'
          : null;
      _errorGuardado = null;
    });
    if (_errorCiudad != null || _errorPrecio != null) return;

    setState(() => _guardando = true);
    try {
      await widget.alGuardar(ciudad, precio!, _fecha);
      if (mounted) Navigator.of(context).pop(true);
    } on CatalogoFailure catch (falla) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = falla.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _editando ? 'Editar precio' : 'Agregar tarifa de ACPM',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'La ciudad debe aparecer en el origen del viaje (p. ej. «Medellín»).',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.x4),
        TextField(
          controller: _ciudad,
          enabled: !_editando,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Ciudad',
            errorText: _errorCiudad,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _precio,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[MilesFormatter()],
          decoration: InputDecoration(
            labelText: 'Precio por galón',
            prefixText: r'$ ',
            errorText: _errorPrecio,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        OutlinedButton.icon(
          onPressed: _editando ? null : _elegirFecha,
          icon: const Icon(LucideIcons.calendar, size: 18),
          label: Text('Vigente desde ${formatearFecha(_fecha)}'),
        ),
        if (_errorGuardado != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(mensaje: _errorGuardado!),
        ],
        const SizedBox(height: AppSpacing.x4),
        PrimaryActionButton(
          label: 'Guardar tarifa',
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
