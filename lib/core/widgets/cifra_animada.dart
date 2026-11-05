import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';

/// Cifra que «se acomoda» al valor: cuenta desde 0 la primera vez y desde el
/// valor anterior cuando cambia (p. ej. al cambiar de mes). Dura 600 ms; con
/// «reducir movimiento» muestra el valor de inmediato.
class CifraAnimada extends StatefulWidget {
  const CifraAnimada({
    required this.valor,
    required this.formato,
    required this.estilo,
    super.key,
  });

  final double valor;
  final String Function(double) formato;
  final TextStyle estilo;

  @override
  State<CifraAnimada> createState() => _CifraAnimadaState();
}

class _CifraAnimadaState extends State<CifraAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.count,
  );
  double _desde = 0;
  bool _inicial = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicial) {
      _inicial = false;
      _animar();
    }
  }

  @override
  void didUpdateWidget(CifraAnimada old) {
    super.didUpdateWidget(old);
    if (old.valor != widget.valor) {
      _desde = _actual(old.valor);
      _animar();
    }
  }

  double _actual(double destinoAnterior) {
    final double t = AppMotion.easeOut.transform(_c.value);
    return _desde + (destinoAnterior - _desde) * t;
  }

  void _animar() {
    if (AppMotion.reducir(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? _) {
        final double t = AppMotion.easeOut.transform(_c.value);
        final double v = _desde + (widget.valor - _desde) * t;
        return Text(widget.formato(v), style: widget.estilo);
      },
    );
  }
}
