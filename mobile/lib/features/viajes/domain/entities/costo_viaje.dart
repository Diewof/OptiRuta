import 'package:equatable/equatable.dart';

import 'categoria_costo.dart';
import 'fuente_costo.dart';

/// Línea de costo de un viaje (par `valor_estimado`/`valor_real`, como
/// manda CLAUDE.md "Dominio: viajes"). Las categorías ACPM y PEAJE las crea
/// el flujo automático (RPC `viaje_crear`, Edge Function `peajes-correo`);
/// el resto las crea el administrador al planear el viaje. El conductor solo
/// confirma `valor_real` de sus propios costos, nunca crea categorías nuevas.
class CostoViaje extends Equatable {
  const CostoViaje({
    required this.id,
    required this.viajeId,
    required this.categoria,
    required this.valorEstimado,
    required this.fuente,
    this.valorReal,
  });

  final String id;
  final String viajeId;
  final CategoriaCosto categoria;
  final double valorEstimado;
  final double? valorReal;
  final FuenteCosto fuente;

  @override
  List<Object?> get props => <Object?>[
    id,
    viajeId,
    categoria,
    valorEstimado,
    valorReal,
    fuente,
  ];
}
