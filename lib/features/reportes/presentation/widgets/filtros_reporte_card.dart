import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../domain/entities/informe.dart';
import '../../domain/entities/reporte.dart';

/// Panel de filtros compartido por Reportes y por el Resumen: fechas,
/// cliente, conductor, vehículo y ruta (RF-27). No consulta nada: avisa cada
/// cambio con [alCambiar] y quien lo usa decide cuándo recargar.
class FiltrosReporteCard extends StatefulWidget {
  const FiltrosReporteCard({
    required this.filtro,
    required this.opciones,
    required this.alCambiar,
    this.titulo = 'Filtros',
    this.conCard = true,
    this.conFechas = true,
    this.campos = CampoFiltro.values,
    super.key,
  });

  final FiltroReporte filtro;
  final OpcionesReporte opciones;
  final void Function(FiltroReporte filtro) alCambiar;
  final String titulo;

  /// `false` cuando el panel ya va dentro de otra tarjeta o desplegable.
  final bool conCard;

  /// Qué controles se muestran; el resto no aplica al informe en curso.
  final bool conFechas;
  final Iterable<CampoFiltro> campos;

  @override
  State<FiltrosReporteCard> createState() => _FiltrosReporteCardState();
}

class _FiltrosReporteCardState extends State<FiltrosReporteCard> {
  late final TextEditingController _ruta = TextEditingController(
    text: widget.filtro.ruta,
  );

  @override
  void dispose() {
    _ruta.dispose();
    super.dispose();
  }

  void _aplicarRuta(String v) => widget.alCambiar(
    widget.filtro.copiarCon(ruta: () => v.trim().isEmpty ? null : v.trim()),
  );

  /// Elige una sola fecha (desde o hasta). Si queda invertido el rango, la
  /// otra fecha se mueve a la elegida para no dejar un rango inválido.
  Future<void> _elegirFecha({required bool esDesde}) async {
    final FiltroReporte f = widget.filtro;
    final DateTime manana = DateTime.now().add(const Duration(days: 1));
    final DateTime inicial = esDesde ? f.desde : f.hasta;
    // El Resumen arranca con el mes completo: su fin puede pasar de «mañana»
    // y showDatePicker exige initialDate dentro de [firstDate, lastDate].
    final DateTime ultimo = inicial.isAfter(manana) ? inicial : manana;
    final DateTime? d = await showDatePicker(
      context: context,
      helpText: esDesde ? 'Fecha desde' : 'Fecha hasta',
      firstDate: DateTime(2020),
      lastDate: ultimo,
      initialDate: inicial,
    );
    if (d == null) return;
    final DateTime dia = DateTime(d.year, d.month, d.day);
    widget.alCambiar(
      esDesde
          ? f.copiarCon(desde: dia, hasta: dia.isAfter(f.hasta) ? dia : null)
          : f.copiarCon(hasta: dia, desde: dia.isBefore(f.desde) ? dia : null),
    );
  }

  Future<void> _elegir(
    String titulo,
    List<OpcionFiltro> opciones,
    void Function(String? id) alElegir,
  ) async {
    final String? id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Text(titulo, style: AppTypography.subtitle),
            ),
            ListTile(
              title: const Text('Todos'),
              onTap: () => Navigator.of(ctx).pop(''),
            ),
            for (final OpcionFiltro o in opciones)
              ListTile(
                title: Text(o.nombre),
                onTap: () => Navigator.of(ctx).pop(o.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) alElegir(id.isEmpty ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final FiltroReporte f = widget.filtro;
    final OpcionesReporte o = widget.opciones;
    String? nombre(List<OpcionFiltro> l, String? id) => l
        .where((OpcionFiltro x) => x.id == id)
        .map((OpcionFiltro x) => x.nombre)
        .firstOrNull;

    final Set<CampoFiltro> usa = widget.campos.toSet();
    final List<Widget> controles = <Widget>[
      if (widget.conFechas)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AppSelectField(
                label: 'Cierre desde',
                icono: LucideIcons.calendar,
                valor: formatearFecha(f.desde),
                onTap: () => _elegirFecha(esDesde: true),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: AppSelectField(
                label: 'Cierre hasta',
                icono: LucideIcons.calendar,
                valor: formatearFecha(f.hasta),
                onTap: () => _elegirFecha(esDesde: false),
              ),
            ),
          ],
        ),
      if (usa.contains(CampoFiltro.cliente))
        AppSelectField(
          label: 'Cliente',
          marcador: 'Todos',
          valor: nombre(o.clientes, f.clienteId),
          onTap: () => _elegir(
            'Cliente',
            o.clientes,
            (String? id) => widget.alCambiar(f.copiarCon(clienteId: () => id)),
          ),
        ),
      if (usa.contains(CampoFiltro.conductor))
        AppSelectField(
          label: 'Conductor',
          marcador: 'Todos',
          valor: nombre(o.conductores, f.conductorId),
          onTap: () => _elegir(
            'Conductor',
            o.conductores,
            (String? id) =>
                widget.alCambiar(f.copiarCon(conductorId: () => id)),
          ),
        ),
      if (usa.contains(CampoFiltro.vehiculo))
        AppSelectField(
          label: 'Vehículo',
          marcador: 'Todos',
          valor: nombre(o.vehiculos, f.vehiculoId),
          onTap: () => _elegir(
            'Vehículo',
            o.vehiculos,
            (String? id) => widget.alCambiar(f.copiarCon(vehiculoId: () => id)),
          ),
        ),
      if (usa.contains(CampoFiltro.ruta))
        TextField(
          controller: _ruta,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Ruta (origen o destino)',
            hintText: 'Ej. Medellín',
            suffixIcon: IconButton(
              tooltip: 'Buscar ruta',
              icon: const Icon(LucideIcons.search),
              onPressed: () => _aplicarRuta(_ruta.text),
            ),
          ),
          onSubmitted: _aplicarRuta,
        ),
    ];

    final Widget contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < controles.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.x3),
          controles[i],
        ],
      ],
    );

    if (!widget.conCard) return contenido;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.titulo, style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x3),
          contenido,
        ],
      ),
    );
  }
}
