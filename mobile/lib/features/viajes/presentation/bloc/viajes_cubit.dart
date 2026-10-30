import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/usecases/listar_viajes_activos_use_case.dart';
import '../../domain/usecases/listar_viajes_por_rango_use_case.dart';

/// Vistas rápidas de la lista de viajes.
enum FiltroViajes {
  hoy('Hoy'),
  programados('Programados'),
  enCurso('En curso'),
  finalizados('Finalizados'),
  todos('Todos');

  const FiltroViajes(this.etiqueta);

  final String etiqueta;

  /// Lo próximo va primero; lo ya hecho, lo más reciente primero.
  bool get ascendente =>
      this == FiltroViajes.hoy ||
      this == FiltroViajes.programados ||
      this == FiltroViajes.enCurso;

  bool acepta(ViajeResumen v, DateTime hoy) => switch (this) {
    FiltroViajes.hoy =>
      _mismoDia(v.fechaSalidaProgramada, hoy) ||
          v.estado == EstadoViaje.enCurso,
    FiltroViajes.programados =>
      v.estado == EstadoViaje.planificado || v.estado == EstadoViaje.asignado,
    FiltroViajes.enCurso => v.estado == EstadoViaje.enCurso,
    FiltroViajes.finalizados =>
      v.estado == EstadoViaje.finalizado || v.estado == EstadoViaje.cerrado,
    FiltroViajes.todos => true,
  };
}

bool _mismoDia(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

sealed class ViajesState extends Equatable {
  const ViajesState();

  @override
  List<Object?> get props => <Object?>[];
}

class ViajesCargando extends ViajesState {
  const ViajesCargando();
}

class ViajesError extends ViajesState {
  const ViajesError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class ViajesListo extends ViajesState {
  const ViajesListo({
    required this.viajes,
    required this.hoy,
    this.filtro = FiltroViajes.hoy,
    this.busqueda = '',
    this.agenda = false,
  });

  final List<ViajeResumen> viajes;
  final DateTime hoy;
  final FiltroViajes filtro;
  final String busqueda;

  /// Agrupa por día de salida en vez de una lista plana.
  final bool agenda;

  /// Filtrados por chip y búsqueda, ya en el orden que corresponde.
  List<ViajeResumen> get visibles {
    final String q = _normalizar(busqueda.trim());
    final List<ViajeResumen> lista = viajes
        .where((ViajeResumen v) => filtro.acepta(v, hoy))
        .where((ViajeResumen v) => q.isEmpty || _coincide(v, q))
        .toList();
    lista.sort((ViajeResumen a, ViajeResumen b) {
      final DateTime fa = a.fechaSalidaProgramada ?? a.fechaCreacion;
      final DateTime fb = b.fechaSalidaProgramada ?? b.fechaCreacion;
      return filtro.ascendente ? fa.compareTo(fb) : fb.compareTo(fa);
    });
    return lista;
  }

  /// Cuántos viajes tiene cada chip (sin tener en cuenta la búsqueda).
  int cuantos(FiltroViajes f) =>
      viajes.where((ViajeResumen v) => f.acepta(v, hoy)).length;

  static bool _coincide(ViajeResumen v, String q) => <String>[
    v.remision,
    v.origen,
    v.destino,
    v.nombreCliente,
    v.placaVehiculo,
    v.nombreConductor,
  ].any((String campo) => _normalizar(campo).contains(q));

  static String _normalizar(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');

  ViajesListo copiarCon({
    List<ViajeResumen>? viajes,
    FiltroViajes? filtro,
    String? busqueda,
    bool? agenda,
  }) => ViajesListo(
    viajes: viajes ?? this.viajes,
    hoy: hoy,
    filtro: filtro ?? this.filtro,
    busqueda: busqueda ?? this.busqueda,
    agenda: agenda ?? this.agenda,
  );

  @override
  List<Object?> get props => <Object?>[viajes, hoy, filtro, busqueda, agenda];
}

/// Lista única de viajes: una ventana de fechas (30 días atrás, 90 adelante)
/// más los activos de cualquier fecha, filtrada en memoria por chip y
/// búsqueda. El histórico completo y la rentabilidad viven en Historial.
class ViajesCubit extends Cubit<ViajesState> {
  ViajesCubit({
    required this.listarPorRango,
    required this.listarActivos,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now,
       super(const ViajesCargando()) {
    cargar();
  }

  static const int _diasAtras = 30;
  static const int _diasAdelante = 90;

  final ListarViajesPorRangoUseCase listarPorRango;
  final ListarViajesActivosUseCase listarActivos;
  final DateTime Function() _ahora;

  /// [silencioso] conserva filtro y búsqueda y no vuelve al esqueleto.
  Future<void> cargar({bool silencioso = false}) async {
    final ViajesState previo = state;
    if (!silencioso || previo is! ViajesListo) emit(const ViajesCargando());
    try {
      final DateTime ahora = _ahora();
      final DateTime hoy = DateTime(ahora.year, ahora.month, ahora.day);
      final List<List<ViajeResumen>> resultados = await Future.wait(
        <Future<List<ViajeResumen>>>[
          listarPorRango(
            desde: hoy.subtract(const Duration(days: _diasAtras)),
            hasta: hoy.add(const Duration(days: _diasAdelante)),
          ),
          listarActivos(),
        ],
      );
      final Map<String, ViajeResumen> porId = <String, ViajeResumen>{
        for (final ViajeResumen v in resultados[0]) v.id: v,
        for (final ViajeResumen v in resultados[1]) v.id: v,
      };
      if (isClosed) return;
      final List<ViajeResumen> viajes = porId.values.toList();
      emit(
        previo is ViajesListo
            ? previo.copiarCon(viajes: viajes)
            : ViajesListo(viajes: viajes, hoy: hoy),
      );
    } on CatalogoFailure catch (falla) {
      if (!isClosed && previo is! ViajesListo) emit(ViajesError(falla.mensaje));
    }
  }

  void elegirFiltro(FiltroViajes filtro) {
    final ViajesState actual = state;
    if (actual is ViajesListo) emit(actual.copiarCon(filtro: filtro));
  }

  void buscar(String texto) {
    final ViajesState actual = state;
    if (actual is ViajesListo) emit(actual.copiarCon(busqueda: texto));
  }

  void alternarAgenda() {
    final ViajesState actual = state;
    if (actual is ViajesListo) emit(actual.copiarCon(agenda: !actual.agenda));
  }
}
