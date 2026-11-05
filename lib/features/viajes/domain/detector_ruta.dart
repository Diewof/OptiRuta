import 'entities/coordenada.dart';
import 'entities/tipo_alerta_viaje.dart';
import 'ruta_geometria.dart';

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Detecta, a partir de las posiciones del conductor, una parada prolongada o
/// un desvío de la ruta estimada. Es lógica pura (sin GPS ni red) y la usa el
/// teléfono: la posición nunca se guarda ni se envía, solo el evento.
///
/// Umbrales (decisión de producto): parada de 30 min dentro de un radio de
/// 100 m; desvío de más de 1 km de la ruta sostenido 2 min (para no alertar
/// por un salto de GPS o un tramo sin cobertura).
class DetectorRuta {
  DetectorRuta({
    required List<Coordenada> ruta,
    this.tiempoParada = const Duration(minutes: 30),
    this.radioParadaM = 100,
    this.distanciaDesvioM = 1000,
    this.tiempoDesvio = const Duration(minutes: 2),
  }) : _ruta = ruta;

  final List<Coordenada> _ruta;
  final Duration tiempoParada;
  final double radioParadaM;
  final double distanciaDesvioM;
  final Duration tiempoDesvio;

  Coordenada? _ancla;
  DateTime? _desdeAncla;
  DateTime? _fueraDesde;

  /// Procesa una posición y devuelve la alerta que corresponda, si la hay.
  /// Tras emitir una alerta el contador de ese tipo se reinicia, así que la
  /// misma situación solo vuelve a alertar pasado otro período completo.
  TipoAlertaViaje? evaluar(Coordenada posicion, DateTime ahora) {
    final TipoAlertaViaje? desvio = _evaluarDesvio(posicion, ahora);
    final TipoAlertaViaje? parada = _evaluarParada(posicion, ahora);
    return desvio ?? parada;
  }

  TipoAlertaViaje? _evaluarParada(Coordenada posicion, DateTime ahora) {
    final Coordenada? ancla = _ancla;
    if (ancla == null || distanciaMetros(ancla, posicion) > radioParadaM) {
      _ancla = posicion;
      _desdeAncla = ahora;
      return null;
    }
    if (ahora.difference(_desdeAncla!) >= tiempoParada) {
      _desdeAncla = ahora;
      return TipoAlertaViaje.paradaProlongada;
    }
    return null;
  }

  TipoAlertaViaje? _evaluarDesvio(Coordenada posicion, DateTime ahora) {
    // Sin trazado no hay contra qué comparar (viaje antiguo).
    if (_ruta.length < 2) return null;
    if (distanciaARuta(posicion, _ruta) <= distanciaDesvioM) {
      _fueraDesde = null;
      return null;
    }
    final DateTime desde = _fueraDesde ??= ahora;
    if (ahora.difference(desde) >= tiempoDesvio) {
      _fueraDesde = ahora;
      return TipoAlertaViaje.desvioRuta;
    }
    return null;
  }
}
