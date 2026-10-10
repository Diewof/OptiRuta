import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Iconos propios de dominio (cuadrícula 24, trazo 1,75, nodo de ruta como
/// rasgo de marca). Los genéricos de interfaz (flechas, cerrar, campana...)
/// siguen siendo `LucideIcons`. Archivos: `assets/icons/<nombre>.svg`.
enum MarcaIconos {
  inicio,
  resumen,
  ruta,
  dobleTroque,
  mula,
  personas,
  perfil,
  origen,
  destino,
  carga,
  cliente,
  conductor,
  acpm,
  peaje,
  mantenimiento,
  documento,
  vencimiento,
  retraso,
  rentabilidad,
  hitoSalida,
  hitoCargue,
  hitoConCarga,
  hitoDestino,
  syncOk,
  syncPendiente,
  syncSinSenal,
  syncGirando,
  datoEstimado,
  datoReal,
  datoParcial,
  datoAjustado,
  check,
  lock,
  calendario,
  asignado,
  camara,
  alerta,
  info,
  subir,
  bajar;

  /// Nombre del archivo SVG (snake_case).
  String get archivo => name.replaceAllMapped(
    RegExp('[A-Z]'),
    (Match m) => '_${m[0]!.toLowerCase()}',
  );

  /// Solo estos tienen variante rellena (destino activo de navegación).
  bool get tieneRelleno => const <MarcaIconos>{
    inicio,
    resumen,
    ruta,
    dobleTroque,
    mula,
    personas,
    perfil,
    hitoDestino,
    destino,
    carga,
    conductor,
    cliente,
  }.contains(this);
}

/// Dibuja un [MarcaIconos] con el color del `IconTheme` (o [color]).
class MarcaIcon extends StatelessWidget {
  const MarcaIcon(
    this.icono, {
    this.size = 24,
    this.color,
    this.relleno = false,
    this.semanticLabel,
    super.key,
  });

  final MarcaIconos icono;
  final double size;
  final Color? color;

  /// Variante rellena (solo si [MarcaIconos.tieneRelleno]).
  final bool relleno;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? IconTheme.of(context).color ?? AppColors.slate;
    final bool conRelleno = relleno && icono.tieneRelleno;
    return SvgPicture.asset(
      'assets/icons/${icono.archivo}${conRelleno ? '_fill' : ''}.svg',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: c),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
