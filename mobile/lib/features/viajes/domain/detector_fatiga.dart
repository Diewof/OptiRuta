import 'entities/coordenada.dart';
import 'ruta_geometria.dart';

enum EventoFatiga {
  /// Llegó a las horas máximas al volante: hay que avisar al conductor.
  pausaActiva,

  /// Pasó la gracia tras el aviso y sigue conduciendo.
  pausaIgnorada,
}

/// Mide la conducción continua a partir de las posiciones del conductor.
/// Lógica pura (sin GPS ni red), como `DetectorRuta`: la posición nunca sale
/// del teléfono, solo el evento de «pausa ignorada».
///
/// Umbrales (decisión de producto, 2026-10-13): 4 h al volante; una parada de
/// 15 min (dentro de 100 m) reinicia la cuenta; 15 min de gracia tras el
/// aviso antes de considerarlo ignorado. Solo cuenta en «ignorada» si sigue
/// en movimiento (última evidencia de desplazamiento de menos de
/// [tiempoQuieto]); si está parado esperando la pausa, no se acusa.
class DetectorFatiga {
  DetectorFatiga({
    this.conduccionMaxima = const Duration(hours: 4),
    this.pausaMinima = const Duration(minutes: 15),
    this.gracia = const Duration(minutes: 15),
    this.tiempoQuieto = const Duration(minutes: 5),
    this.radioParadaM = 100,
  });

  final Duration conduccionMaxima;
  final Duration pausaMinima;
  final Duration gracia;
  final Duration tiempoQuieto;
  final double radioParadaM;

  Coordenada? _ancla;
  DateTime? _desdeAncla;
  DateTime? _inicioConduccion;
  DateTime? _avisoEn;
  bool _ignoradaEmitida = false;
  bool _prueba = false;

  /// El aviso en curso lo lanzó el administrador (modo prueba).
  bool get prueba => _prueba;

  /// Hay un aviso emitido que el conductor aún no resolvió con una pausa.
  bool get avisoVigente => _avisoEn != null;

  /// Tiempo de conducción continua hasta [ahora].
  Duration conduccion(DateTime ahora) {
    final DateTime? inicio = _inicioConduccion;
    return inicio == null ? Duration.zero : ahora.difference(inicio);
  }

  /// Tiempo transcurrido desde el aviso hasta [ahora].
  Duration tiempoIgnorado(DateTime ahora) {
    final DateTime? aviso = _avisoEn;
    return aviso == null ? Duration.zero : ahora.difference(aviso);
  }

  /// Dispara el aviso ya (prueba del administrador). Equivale a haber llegado
  /// a [conduccionMaxima] en este instante; la gracia corre desde ahora.
  void forzarAviso(DateTime ahora) {
    _inicioConduccion = ahora.subtract(conduccionMaxima);
    _avisoEn = ahora;
    _ignoradaEmitida = false;
    _prueba = true;
    // Si el teléfono está quieto, la pausa cuenta desde el aviso.
    _desdeAncla = ahora;
  }

  EventoFatiga? evaluar(Coordenada posicion, DateTime ahora) {
    final Coordenada? ancla = _ancla;
    if (ancla == null || distanciaMetros(ancla, posicion) > radioParadaM) {
      _ancla = posicion;
      _desdeAncla = ahora;
      _inicioConduccion ??= ahora;
    } else if (ahora.difference(_desdeAncla!) >= pausaMinima) {
      _reiniciar();
      return null;
    }

    final DateTime inicio = _inicioConduccion!;
    if (_avisoEn == null) {
      if (ahora.difference(inicio) >= conduccionMaxima) {
        _avisoEn = ahora;
        return EventoFatiga.pausaActiva;
      }
      return null;
    }

    final bool enMovimiento = ahora.difference(_desdeAncla!) < tiempoQuieto;
    if (!_ignoradaEmitida &&
        enMovimiento &&
        ahora.difference(_avisoEn!) >= gracia) {
      _ignoradaEmitida = true;
      return EventoFatiga.pausaIgnorada;
    }
    return null;
  }

  void _reiniciar() {
    _inicioConduccion = null;
    _avisoEn = null;
    _ignoradaEmitida = false;
    _prueba = false;
  }
}
