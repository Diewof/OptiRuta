import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/marca_icon.dart';

/// Una fila de la tabla estimado vs. real (valores en pesos).
class FilaEstimadoReal {
  const FilaEstimadoReal({
    required this.concepto,
    required this.estimado,
    this.real,
    this.fuente,
    this.pendiente = 'Pendiente',
  });

  final String concepto;

  /// Origen del dato como texto («Automático», «Manual»): no cambia la marca.
  final String? fuente;
  final double estimado;
  final double? real;
  final String pendiente;
}

/// Tabla «Estimado vs. real» del detalle (opción C del rediseño). Muestra el
/// flete como **valor pactado** (un solo monto, no un par) y el margen del
/// viaje al final. Columnas fluidas; con texto grande (≥ 115 %) cada fila se
/// apila: concepto arriba y los tres valores con su rótulo debajo.
class EstimadoRealTabla extends StatelessWidget {
  const EstimadoRealTabla({
    required this.flete,
    required this.filas,
    required this.margenEstimado,
    required this.margenActual,
    required this.margenConfirmado,
    super.key,
  });

  final double flete;
  final List<FilaEstimadoReal> filas;
  final double margenEstimado;
  final double margenActual;

  /// `true` si todos los costos ya tienen valor real.
  final bool margenConfirmado;

  static String miles(double v) {
    final String s = (v.abs() / 1000).round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (Match _) => '.',
    );
    return '${v < 0 ? '−' : ''}$s';
  }

  @override
  Widget build(BuildContext context) {
    final bool apilada = MediaQuery.textScalerOf(context).scale(14) > 14 * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!apilada) const _Encabezado(),
        _FilaFlete(flete: flete, apilada: apilada),
        for (final FilaEstimadoReal f in filas)
          _Fila(fila: f, apilada: apilada),
        _FilaMargen(
          estimado: margenEstimado,
          actual: margenActual,
          confirmado: margenConfirmado,
          apilada: apilada,
        ),
      ],
    );
  }
}

const TextStyle _celda = TextStyle(
  fontFamily: AppTypography.family,
  fontSize: 13,
  height: 18 / 13,
  color: AppColors.textBody,
  fontFeatures: AppTypography.tabular,
);

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final TextStyle e = AppTypography.caption.copyWith(
      fontWeight: FontWeight.w500,
    );
    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderCard)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(flex: 30, child: Text('Concepto', style: e)),
          Expanded(
            flex: 20,
            child: Text('Estimado', style: e, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 20,
            child: Text('Real', style: e, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 18,
            child: Text('Dif.', style: e, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _separador({bool grueso = false}) => BoxDecoration(
  border: Border(
    bottom: BorderSide(
      color: grueso ? AppColors.borderCard : AppColors.dividerTable,
      width: grueso ? 2 : 1,
    ),
  ),
);

class _Concepto extends StatelessWidget {
  const _Concepto(this.titulo, this.pie, {this.fuerte = false});

  final String titulo;
  final String? pie;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          titulo,
          style: _celda.copyWith(
            fontWeight: fuerte ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        if (pie != null) Text(pie!, style: AppTypography.caption),
      ],
    );
  }
}

class _Valor extends StatelessWidget {
  const _Valor({required this.rotulo, required this.hijo, required this.flex});

  final String rotulo;
  final Widget hijo;
  final int flex;

  /// Con la tabla apilada se muestra el rótulo encima del valor.
  static bool _conRotulo(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) > 14 * 1.15;

  @override
  Widget build(BuildContext context) {
    final bool apilada = _conRotulo(context);
    final Widget contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (apilada) Text(rotulo, style: AppTypography.caption),
        hijo,
      ],
    );
    return apilada
        ? Expanded(child: contenido)
        : Expanded(flex: flex, child: contenido);
  }
}

/// Las cifras se encogen en vez de desbordar si la columna es estrecha.
Widget _ajustar(Widget h) => FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.centerRight,
  child: h,
);

Widget _estimado(double v) => _ajustar(
  Text(
    '≈ ${EstimadoRealTabla.miles(v)}',
    style: _celda.copyWith(color: AppColors.textSecondary),
  ),
);

Widget _real(double v, {bool confirmado = true}) => _ajustar(
  Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      MarcaIcon(
        confirmado ? MarcaIconos.check : MarcaIconos.datoParcial,
        size: 14,
        color: confirmado ? AppColors.success : AppColors.textSecondary,
      ),
      const SizedBox(width: 2),
      Text(
        EstimadoRealTabla.miles(v),
        style: _celda.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  ),
);

/// Diferencia real − estimado. En costos, subir es desfavorable; en el margen,
/// bajar lo es. Flecha + signo: no depende solo del color.
Widget _dif(double d, {required bool ingreso}) {
  if (d.round() == 0) {
    return Text('0', style: _celda.copyWith(color: AppColors.textSecondary));
  }
  final bool malo = ingreso ? d < 0 : d > 0;
  final Color c = malo ? AppColors.error : AppColors.success;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      MarcaIcon(
        d > 0 ? MarcaIconos.subir : MarcaIconos.bajar,
        size: 12,
        color: c,
      ),
      Text(
        '${d > 0 ? '+' : '−'}${EstimadoRealTabla.miles(d.abs())}',
        style: _celda.copyWith(fontWeight: FontWeight.w600, color: c),
      ),
    ],
  );
}

class _FilaFlete extends StatelessWidget {
  const _FilaFlete({required this.flete, required this.apilada});

  final double flete;
  final bool apilada;

  @override
  Widget build(BuildContext context) {
    final Widget valor = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.x1,
      children: <Widget>[
        Text(
          EstimadoRealTabla.miles(flete),
          style: _celda.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: Border.all(color: AppColors.borderInput),
          ),
          child: const Text('Pactado', style: AppTypography.caption),
        ),
      ],
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      decoration: _separador(grueso: true),
      child: apilada
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _Concepto('Flete (ingreso)', 'Pactado con el cliente'),
                Align(alignment: Alignment.centerRight, child: valor),
              ],
            )
          : Row(
              children: <Widget>[
                const Expanded(
                  flex: 30,
                  child: _Concepto('Flete (ingreso)', 'Pactado con el cliente'),
                ),
                Expanded(
                  flex: 58,
                  child: Align(alignment: Alignment.centerRight, child: valor),
                ),
              ],
            ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.fila, required this.apilada});

  final FilaEstimadoReal fila;
  final bool apilada;

  @override
  Widget build(BuildContext context) {
    final double? r = fila.real;
    final Widget est = _Valor(
      rotulo: 'Estimado',
      flex: 20,
      hijo: _estimado(fila.estimado),
    );
    final Widget real = _Valor(
      rotulo: 'Real',
      flex: 20,
      hijo: r != null
          ? _real(r)
          : Text(
              fila.pendiente,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
    );
    final Widget dif = _Valor(
      rotulo: 'Dif.',
      flex: 18,
      hijo: r == null
          ? Text('—', style: _celda.copyWith(color: AppColors.textSecondary))
          : _dif(r - fila.estimado, ingreso: false),
    );
    final Widget concepto = _Concepto(fila.concepto, fila.fuente);

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      decoration: _separador(),
      child: apilada
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                concepto,
                Row(children: <Widget>[est, real, dif]),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(flex: 30, child: concepto),
                est,
                real,
                dif,
              ],
            ),
    );
  }
}

class _FilaMargen extends StatelessWidget {
  const _FilaMargen({
    required this.estimado,
    required this.actual,
    required this.confirmado,
    required this.apilada,
  });

  final double estimado;
  final double actual;
  final bool confirmado;
  final bool apilada;

  @override
  Widget build(BuildContext context) {
    final Widget concepto = _Concepto(
      'Margen',
      confirmado
          ? 'Con todos los costos reales'
          : 'Usa el estimado donde falta el real',
      fuerte: true,
    );
    final Widget est = _Valor(
      rotulo: 'Estimado',
      flex: 20,
      hijo: _estimado(estimado),
    );
    final Widget real = _Valor(
      rotulo: 'Real',
      flex: 20,
      hijo: _real(actual, confirmado: confirmado),
    );
    final Widget dif = _Valor(
      rotulo: 'Dif.',
      flex: 18,
      hijo: _dif(actual - estimado, ingreso: true),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(top: AppSpacing.x2),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderCard, width: 2)),
      ),
      child: apilada
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                concepto,
                Row(children: <Widget>[est, real, dif]),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(flex: 30, child: concepto),
                est,
                real,
                dif,
              ],
            ),
    );
  }
}
