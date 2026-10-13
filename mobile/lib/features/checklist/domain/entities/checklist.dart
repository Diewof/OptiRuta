import 'package:equatable/equatable.dart';

/// Resultado del checklist; lo calcula el servidor: una falla en un ítem
/// crítico lo deja BLOQUEADO hasta que el administrador autorice la salida.
enum ResultadoChecklist {
  aprobado('APROBADO', 'Aprobado'),
  conObservaciones('CON_OBSERVACIONES', 'Con observaciones'),
  bloqueado('BLOQUEADO', 'Bloqueado');

  const ResultadoChecklist(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static ResultadoChecklist desdeCodigo(String valor) {
    return switch (valor) {
      'APROBADO' => ResultadoChecklist.aprobado,
      'CON_OBSERVACIONES' => ResultadoChecklist.conObservaciones,
      'BLOQUEADO' => ResultadoChecklist.bloqueado,
      _ => throw ArgumentError.value(valor, 'valor', 'Resultado no válido'),
    };
  }
}

/// Ítem del catálogo `public.checklist_item`.
class ItemChecklist extends Equatable {
  const ItemChecklist({
    required this.id,
    required this.codigo,
    required this.grupo,
    required this.nombre,
    required this.critico,
  });

  final String id;
  final String codigo;
  final String grupo;
  final String nombre;

  /// Una falla aquí impide salir sin autorización del administrador.
  final bool critico;

  @override
  List<Object?> get props => <Object?>[id, codigo, grupo, nombre, critico];
}

/// Respuesta del conductor a un ítem; solo viajan las fallas con su
/// descripción, el resto se envía como OK.
class RespuestaChecklist extends Equatable {
  const RespuestaChecklist({
    required this.itemId,
    required this.falla,
    this.observacion,
  });

  final String itemId;
  final bool falla;
  final String? observacion;

  @override
  List<Object?> get props => <Object?>[itemId, falla, observacion];
}

class FallaChecklist extends Equatable {
  const FallaChecklist({
    required this.nombre,
    required this.critico,
    this.observacion,
  });

  final String nombre;
  final bool critico;
  final String? observacion;

  @override
  List<Object?> get props => <Object?>[nombre, critico, observacion];
}

/// Checklist pre-viaje ya registrado (el más reciente de un viaje).
class ChecklistViaje extends Equatable {
  const ChecklistViaje({
    required this.id,
    required this.viajeId,
    required this.fechaHora,
    required this.resultado,
    this.observaciones,
    this.fallas = const <FallaChecklist>[],
    this.motivoAutorizacion,
  });

  /// Cuánto vale un checklist para comenzar el viaje. Espejo de la regla de
  /// `viaje_iniciar` (que es la que la hace cumplir): aquí solo evita
  /// ofrecer «Registrar salida» con un checklist vencido.
  static const Duration vigencia = Duration(hours: 12);

  final String id;
  final String viajeId;
  final DateTime fechaHora;
  final ResultadoChecklist resultado;
  final String? observaciones;
  final List<FallaChecklist> fallas;

  /// Motivo con el que el administrador autorizó salir pese a una falla crítica.
  final String? motivoAutorizacion;

  bool get autorizado => motivoAutorizacion != null;

  /// Falla crítica sin autorización: el conductor no puede comenzar.
  bool get bloqueaSalida =>
      resultado == ResultadoChecklist.bloqueado && !autorizado;

  bool estaVencido(DateTime ahora) => ahora.difference(fechaHora) > vigencia;

  @override
  List<Object?> get props => <Object?>[
    id,
    viajeId,
    fechaHora,
    resultado,
    observaciones,
    fallas,
    motivoAutorizacion,
  ];
}
