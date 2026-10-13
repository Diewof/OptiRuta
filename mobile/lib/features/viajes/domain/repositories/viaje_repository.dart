import 'package:equatable/equatable.dart';

import '../entities/coordenada.dart';
import '../entities/estado_viaje.dart';
import '../entities/lugar.dart';
import '../entities/tipo_alerta_viaje.dart';
import '../entities/viaje.dart';
import '../entities/viaje_resumen.dart';

class PaginaViajes extends Equatable {
  const PaginaViajes({required this.viajes, required this.hayMas});

  final List<ViajeResumen> viajes;
  final bool hayMas;

  @override
  List<Object?> get props => <Object?>[viajes, hayMas];
}

/// Contrato de acceso a `public.viaje` para la capa de dominio. Toda
/// escritura pasa por las RPC de dominio (`viaje_crear`,
/// `viaje_cambiar_estado`, `viaje_cerrar`); no hay INSERT/UPDATE directo
/// porque la tabla no tiene grant para eso (ver CLAUDE.md "Dominio: viajes").
abstract interface class ViajeRepository {
  Future<Viaje> crear({
    required String remision,
    required String vehiculoId,
    required String conductorId,
    required String clienteId,
    required Lugar origen,
    required Lugar destino,
    required String rutaPolilinea,
    required DateTime fechaSalidaProgramada,
    required double distanciaEstimada,
    required double tiempoEstimadoMin,
    required double pesoCarga,
    required double valorFlete,
  });

  /// Evento puntual de parada prolongada o desvío detectado en el teléfono
  /// (RPC `viaje_registrar_alerta`). Nunca se envía la posición continua.
  /// `true` si se notificó al administrador, `false` si ya había una alerta
  /// reciente del mismo tipo.
  Future<bool> registrarAlerta({
    required String viajeId,
    required TipoAlertaViaje tipo,
    required Coordenada ubicacion,
  });

  Future<Viaje> cambiarEstado({
    required String viajeId,
    required EstadoViaje nuevoEstado,
  });

  /// Comienza el viaje propio (RPC `viaje_iniciar`): registra el hito SALIDA y
  /// lo pasa a EN_CURSO. El servidor rechaza si [ubicacion] está a más de
  /// 500 m del origen. La posición se usa solo para esa validación.
  Future<Viaje> iniciar({
    required String viajeId,
    required Coordenada ubicacion,
    required DateTime fechaHora,
  });

  Future<Viaje> cerrar(String viajeId);

  /// Edita fecha de salida, peso y flete de un viaje abierto (RPC
  /// `viaje_actualizar`). El servidor recalcula la comisión estimada.
  Future<Viaje> actualizar({
    required String viajeId,
    required DateTime fechaSalidaProgramada,
    required double? pesoCarga,
    required double valorFlete,
  });

  /// Cancela un viaje no cerrado (RPC `viaje_cancelar`). El motivo es
  /// obligatorio. El viaje queda en el historial como CANCELADO.
  Future<Viaje> cancelar({required String viajeId, required String motivo});

  /// Elimina un viaje no cerrado (RPC `viaje_eliminar`). Queda una bitácora
  /// con el motivo; un viaje CERRADO no se puede eliminar.
  Future<void> eliminar({required String viajeId, required String motivo});

  /// Un viaje con sus datos de listado (placa, conductor, cliente, mapa), p. ej.
  /// para abrirlo desde una notificación.
  Future<ViajeResumen> obtenerResumen(String viajeId);

  /// Vista previa del ACPM estimado antes de crear el viaje (RPC
  /// `costo_acpm_estimado`, la misma que usa `viaje_crear` internamente).
  Future<double> estimarAcpm({
    required String vehiculoId,
    required double distanciaKm,
    required String ciudad,
  });

  /// Viajes cuya fecha de salida programada cae en `[desde, hasta)`. Para el
  /// grid mensual y el listado del día en Calendario (una sola consulta por
  /// mes; el día seleccionado se filtra en memoria).
  Future<List<ViajeResumen>> listarPorRango({
    required DateTime desde,
    required DateTime hasta,
  });

  /// Viajes ASIGNADO o EN_CURSO, para la pestaña "En curso" de Seguimiento.
  Future<List<ViajeResumen>> listarActivos();

  /// Historial paginado, más reciente primero, con filtro opcional de
  /// estado.
  Future<PaginaViajes> listarHistorial({
    required int pagina,
    required int tamano,
    EstadoViaje? filtroEstado,
  });
}
