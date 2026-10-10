import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/lugar.dart';
import '../../domain/entities/ruta_estimada.dart';
import '../../domain/repositories/ruta_repository.dart';
import '../datasources/ruta_remote_data_source.dart';
import '../models/ruta_estimada_model.dart';

class RutaRepositoryImpl implements RutaRepository {
  RutaRepositoryImpl(this._remote);

  final RutaRemoteDataSource _remote;

  @override
  Future<RutaEstimada> estimar({
    required Coordenada origen,
    required Coordenada destino,
  }) {
    return _ejecutar(() async {
      final Map<String, dynamic> fila = await _remote.estimar(
        origen: _mapa(origen),
        destino: _mapa(destino),
      );
      return RutaEstimadaModel.aEntidad(fila);
    });
  }

  @override
  Future<List<Lugar>> buscarLugares(String consulta) {
    return _ejecutar(() async {
      final Map<String, dynamic> fila = await _remote.buscar(consulta);
      final List<dynamic> lugares = fila['lugares'] as List<dynamic>;
      return lugares
          .map((dynamic l) => LugarModel.aEntidad(l as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Lugar> lugarEn(Coordenada coordenada) {
    return _ejecutar(() async {
      final Map<String, dynamic> fila = await _remote.lugarEn(
        lat: coordenada.lat,
        lng: coordenada.lng,
      );
      return LugarModel.aEntidad(fila);
    });
  }

  static Map<String, double> _mapa(Coordenada c) => <String, double>{
    'lat': c.lat,
    'lng': c.lng,
  };

  Future<T> _ejecutar<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on FunctionException catch (e) {
      throw _traducirFunctionException(e);
    } on SocketException {
      throw CatalogoFailure.sinConexion();
    }
  }
}

/// La Edge Function `rutas` responde en JSON `{ error, message, ... }` en
/// caso de fallo (CLAUDE.md "Cuerpo de error consistente"); ese `message` ya
/// está redactado en español y es seguro mostrarlo tal cual.
CatalogoFailure _traducirFunctionException(FunctionException e) {
  final dynamic detalles = e.details;
  if (detalles is Map && detalles['message'] is String) {
    return CatalogoFailure(
      CatalogoErrorCodigo.desconocido,
      detalles['message'] as String,
    );
  }
  return CatalogoFailure.desconocido();
}
