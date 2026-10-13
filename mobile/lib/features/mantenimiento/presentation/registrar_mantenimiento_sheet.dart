import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/error/catalogo_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/distancia_utils.dart';
import '../../../core/utils/fecha_utils.dart';
import '../../../core/widgets/app_alert.dart';
import '../../../core/widgets/app_select_field.dart';
import '../../../core/widgets/miles_formatter.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../domain/mantenimiento.dart';

/// Hoja para registrar un mantenimiento del vehículo cuya hoja de vida está
/// abierta (por eso no pide la placa). Un tipo del catálogo reinicia su
/// contador en el plan; «Otro» es un trabajo libre, preventivo o correctivo.
class RegistrarMantenimientoSheet extends StatefulWidget {
  const RegistrarMantenimientoSheet({
    required this.placa,
    required this.cargarTipos,
    required this.alGuardar,
    super.key,
  });

  final String placa;
  final Future<List<TipoMantenimiento>> Function() cargarTipos;
  final Future<void> Function({
    required String tipo,
    required double costo,
    required DateTime fecha,
    double? kilometraje,
    String? tipoMantenimientoId,
    CategoriaMantenimiento categoria,
    String? taller,
    String? descripcion,
  })
  alGuardar;

  @override
  State<RegistrarMantenimientoSheet> createState() =>
      _RegistrarMantenimientoSheetState();
}

class _RegistrarMantenimientoSheetState
    extends State<RegistrarMantenimientoSheet> {
  final TextEditingController _tipo = TextEditingController();
  final TextEditingController _costo = TextEditingController();
  final TextEditingController _km = TextEditingController();
  final TextEditingController _taller = TextEditingController();
  final TextEditingController _descripcion = TextEditingController();
  List<TipoMantenimiento> _tipos = const <TipoMantenimiento>[];

  /// Nulo con [_eligioOtro] = trabajo libre escrito a mano.
  TipoMantenimiento? _tipoCatalogo;
  bool _eligioOtro = false;
  CategoriaMantenimiento _categoria = CategoriaMantenimiento.correctivo;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget
        .cargarTipos()
        .then((List<TipoMantenimiento> t) {
          if (mounted) setState(() => _tipos = t);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _tipo.dispose();
    _costo.dispose();
    _km.dispose();
    _taller.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _elegirTipo() async {
    // Un par (catálogo, otro) distingue «Otro» de cerrar la hoja sin elegir.
    final (TipoMantenimiento?, bool)? elegido =
        await showModalBottomSheet<(TipoMantenimiento?, bool)>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final TipoMantenimiento t in _tipos)
                  ListTile(
                    title: Text(t.nombre),
                    subtitle: Text(_intervalo(t)),
                    onTap: () => Navigator.of(ctx).pop((t, false)),
                  ),
                ListTile(
                  title: const Text('Otro (reparación u otro trabajo)'),
                  onTap: () => Navigator.of(ctx).pop((null, true)),
                ),
              ],
            ),
          ),
        );
    if (elegido == null) return;
    setState(() {
      _tipoCatalogo = elegido.$1;
      _eligioOtro = elegido.$2;
      _categoria = elegido.$2
          ? CategoriaMantenimiento.correctivo
          : CategoriaMantenimiento.preventivo;
    });
  }

  static String _intervalo(TipoMantenimiento t) {
    final List<String> partes = <String>[
      if (t.intervaloKm != null) 'cada ${formatearKm(t.intervaloKm!)}',
      if (t.intervaloDias != null) 'cada ${t.intervaloDias} días',
    ];
    return partes.join(' o ');
  }

  Future<void> _elegirFecha() async {
    final DateTime? f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (f != null) setState(() => _fecha = f);
  }

  Future<void> _guardar() async {
    final double? costo = double.tryParse(
      _costo.text.replaceAll(RegExp(r'\D'), ''),
    );
    final double? km = double.tryParse(_km.text.replaceAll(RegExp(r'\D'), ''));
    final bool sinTipo =
        _tipoCatalogo == null && (!_eligioOtro || _tipo.text.trim().isEmpty);
    if (sinTipo || costo == null || costo <= 0) {
      setState(() => _error = 'Elige el tipo y escribe el costo pagado.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.alGuardar(
        tipo: _tipoCatalogo == null ? _tipo.text : '',
        costo: costo,
        fecha: _fecha,
        kilometraje: km,
        tipoMantenimientoId: _tipoCatalogo?.id,
        categoria: _categoria,
        taller: _taller.text,
        descripcion: _descripcion.text,
      );
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
        const Text('Registrar mantenimiento', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.x1),
        Text('Vehículo ${widget.placa}', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.x4),
        AppSelectField(
          label: 'Tipo de mantenimiento',
          valor: _tipoCatalogo?.nombre ?? (_eligioOtro ? 'Otro' : null),
          onTap: _elegirTipo,
        ),
        if (_tipoCatalogo != null)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.x1),
            child: Text(
              'Reinicia el contador de este mantenimiento en el plan del '
              'vehículo.',
              style: AppTypography.caption,
            ),
          ),
        if (_eligioOtro) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          TextField(
            controller: _tipo,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Trabajo realizado (p. ej. cambio de embrague)',
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          SegmentedButton<CategoriaMantenimiento>(
            segments: <ButtonSegment<CategoriaMantenimiento>>[
              for (final CategoriaMantenimiento c
                  in CategoriaMantenimiento.values)
                ButtonSegment<CategoriaMantenimiento>(
                  value: c,
                  label: Text(c.etiqueta),
                ),
            ],
            selected: <CategoriaMantenimiento>{_categoria},
            onSelectionChanged: (Set<CategoriaMantenimiento> s) =>
                setState(() => _categoria = s.first),
          ),
        ],
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _costo,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[MilesFormatter()],
          decoration: const InputDecoration(
            labelText: 'Costo',
            prefixText: r'$ ',
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _km,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[MilesFormatter()],
          decoration: const InputDecoration(
            labelText: 'Kilometraje (opcional)',
            helperText: 'Si es de hoy y lo dejas vacío, se usa el odómetro del vehículo.',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _taller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Taller (opcional)'),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _descripcion,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Observaciones (opcional)',
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        OutlinedButton.icon(
          onPressed: _elegirFecha,
          icon: const Icon(LucideIcons.calendar, size: 18),
          label: Text('Fecha ${formatearFecha(_fecha)}'),
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
