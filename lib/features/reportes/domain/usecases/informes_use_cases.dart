import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../calidad/domain/entities/calidad.dart';
import '../../../calidad/domain/repositories/calidad_repository.dart';
import '../../../dashboard/domain/entities/metricas.dart';
import '../../../dashboard/domain/repositories/metricas_repository.dart';
import '../../../esperas/domain/entities/espera_cliente.dart';
import '../../../esperas/domain/repositories/espera_repository.dart';
import '../../../satisfaccion/domain/entities/satisfaccion.dart';
import '../../../satisfaccion/domain/repositories/satisfaccion_repository.dart';
import '../../../vehiculos/domain/entities/documento_vehiculo.dart';
import '../../../vehiculos/domain/entities/hoja_vida.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../../vehiculos/domain/repositories/hoja_vida_repository.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../../viajes/domain/entities/categoria_costo.dart';
import '../../../viajes/domain/entities/rentabilidad_consolidada.dart';
import '../../../viajes/domain/repositories/rentabilidad_repository.dart';
import '../entities/informe.dart';
import '../entities/reporte.dart';
import '../repositories/reporte_repository.dart';

// Los informes solo leen y dan formato a lo que calculan las RPC: ningún
// umbral ni regla de negocio vive aquí (semáforos, margen mínimo, umbral de
// espera y cortes de calidad los fija el servidor).

/// Arma un informe con los filtros y la agrupación elegidos.
abstract interface class ConstructorInforme {
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension);
}

String _dinero(double v) => NumberFormatCop().formatear(v);

String _horas(double? h) => h == null ? '—' : formatearDecimal(h);

String _pct(double? v) => v == null ? '—' : formatearPorcentaje(v);

/// Variación porcentual contra el período anterior; `—` sin base de cálculo.
String _variacion(double actual, double anterior) {
  if (anterior == 0) return '—';
  return formatearPorcentaje((actual - anterior) / anterior.abs() * 100);
}

/// Exige que la agrupación sea de las que la RPC acepta.
void _validarDimension(TipoInforme tipo, DimensionMetrica dimension) {
  if (!tipo.dimensiones.contains(dimension)) {
    throw ArgumentError.value(
      dimension,
      'dimension',
      'Agrupación no válida para ${tipo.etiqueta}.',
    );
  }
}

class InformeViajes implements ConstructorInforme {
  const InformeViajes(this._reportes);

  final ReporteRepository _reportes;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    final List<FilaReporte> filas = await _reportes.viajes(filtro);
    final TotalesReporte t = TotalesReporte.de(filas);
    return Informe(
      titulo: 'Reporte de viajes cerrados',
      columnas: const <String>[
        'Remisión',
        'Cierre',
        'Ruta',
        'Cliente',
        'Conductor',
        'Km',
        'Flete',
        'Costos',
        'Rentab.',
        'A tiempo',
      ],
      numericas: const <int>{5, 6, 7, 8},
      filas: <List<String>>[
        for (final FilaReporte f in filas)
          <String>[
            f.remision,
            formatearFecha(f.fechaCierre),
            f.ruta,
            f.cliente,
            '${f.conductor} (${f.placa})',
            f.km.round().toString(),
            _dinero(f.valorFlete),
            _dinero(f.costos),
            _dinero(f.rentabilidad),
            f.aTiempo == null ? '—' : (f.aTiempo! ? 'Sí' : 'No'),
          ],
      ],
      resumen:
          'Totales: ${t.viajes} viajes · ${t.km.round()} km · '
          'Flete ${_dinero(t.valorFlete)} · Costos ${_dinero(t.costos)} · '
          'Rentabilidad ${_dinero(t.rentabilidad)}',
    );
  }
}

/// Consolidada del período y del período anterior de igual duración.
class InformeEstadoResultados implements ConstructorInforme {
  const InformeEstadoResultados(this._rentabilidad);

  final RentabilidadRepository _rentabilidad;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    final int dias = filtro.hasta.difference(filtro.desde).inDays + 1;
    final DateTime hastaAnterior = filtro.desde.subtract(
      const Duration(days: 1),
    );
    final DateTime desdeAnterior = hastaAnterior.subtract(
      Duration(days: dias - 1),
    );
    final List<RentabilidadConsolidada> r = await Future.wait(
      <Future<RentabilidadConsolidada>>[
        _consolidada(filtro.desde, filtro.hasta, filtro),
        _consolidada(desdeAnterior, hastaAnterior, filtro),
      ],
    );
    final RentabilidadConsolidada a = r[0];
    final RentabilidadConsolidada p = r[1];

    List<String> linea(String concepto, double actual, double anterior) =>
        <String>[
          concepto,
          _dinero(actual),
          _dinero(anterior),
          _variacion(actual, anterior),
        ];

    double? margen(RentabilidadConsolidada x) => x.totalFlete == 0
        ? null
        : x.rentabilidadConsolidada / x.totalFlete * 100;

    final bool atribuible = filtro.clienteId == null && filtro.ruta == null;
    return Informe(
      titulo: 'Estado de resultados',
      columnas: <String>[
        'Concepto',
        '${formatearFecha(filtro.desde)} a ${formatearFecha(filtro.hasta)}',
        '${formatearFecha(desdeAnterior)} a ${formatearFecha(hastaAnterior)}',
        'Variación',
      ],
      numericas: const <int>{1, 2, 3},
      filas: a.viajesIncluidos == 0 && p.viajesIncluidos == 0
          ? const <List<String>>[]
          : <List<String>>[
              linea('Fletes', a.totalFlete, p.totalFlete),
              linea(
                'Costos directos',
                a.totalCostosDirectos,
                p.totalCostosDirectos,
              ),
              linea(
                'Mantenimiento amortizado',
                a.mantenimientoAmortizado,
                p.mantenimientoAmortizado,
              ),
              linea(
                'Sueldo fijo prorrateado',
                a.sueldoFijoProrrateado,
                p.sueldoFijoProrrateado,
              ),
              linea('Costos totales', a.totalCostos, p.totalCostos),
              linea(
                'Rentabilidad consolidada',
                a.rentabilidadConsolidada,
                p.rentabilidadConsolidada,
              ),
              <String>[
                'Margen sobre el flete',
                _pct(margen(a)),
                _pct(margen(p)),
                '—',
              ],
              <String>[
                'Viajes incluidos',
                '${a.viajesIncluidos}',
                '${p.viajesIncluidos}',
                _variacion(
                  a.viajesIncluidos.toDouble(),
                  p.viajesIncluidos.toDouble(),
                ),
              ],
            ],
      notas: <String>[
        if (!atribuible)
          'Con filtro de cliente o ruta, el mantenimiento y el sueldo fijo no '
              'son atribuibles y valen 0.',
      ],
    );
  }

  Future<RentabilidadConsolidada> _consolidada(
    DateTime desde,
    DateTime hasta,
    FiltroReporte f,
  ) {
    return _rentabilidad.consolidada(
      desde: desde,
      hasta: hasta,
      clienteId: f.clienteId,
      conductorId: f.conductorId,
      vehiculoId: f.vehiculoId,
      ruta: f.ruta,
    );
  }
}

class InformeCostos implements ConstructorInforme {
  const InformeCostos(this._rentabilidad);

  final RentabilidadRepository _rentabilidad;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    final RentabilidadConsolidada r = await _rentabilidad.consolidada(
      desde: filtro.desde,
      hasta: filtro.hasta,
      clienteId: filtro.clienteId,
      conductorId: filtro.conductorId,
      vehiculoId: filtro.vehiculoId,
      ruta: filtro.ruta,
    );
    final double total = r.totalCostos;
    final List<MapEntry<String, double>> partidas =
        <MapEntry<String, double>>[
          for (final MapEntry<CategoriaCosto, double> e
              in r.costosPorCategoria.entries)
            MapEntry<String, double>(e.key.etiqueta, e.value),
          MapEntry<String, double>(
            'Mantenimiento amortizado',
            r.mantenimientoAmortizado,
          ),
          MapEntry<String, double>(
            'Sueldo fijo prorrateado',
            r.sueldoFijoProrrateado,
          ),
        ].where((MapEntry<String, double> e) => e.value > 0).toList()..sort(
          (MapEntry<String, double> x, MapEntry<String, double> y) =>
              y.value.compareTo(x.value),
        );

    return Informe(
      titulo: 'Desglose de costos',
      columnas: const <String>['Categoría', 'Monto', '% del total'],
      numericas: const <int>{1, 2},
      filas: <List<String>>[
        for (final MapEntry<String, double> e in partidas)
          <String>[
            e.key,
            _dinero(e.value),
            _pct(total == 0 ? null : e.value / total * 100),
          ],
      ],
      resumen:
          'Costos totales ${_dinero(total)} · ${r.viajesIncluidos} viajes · '
          'Flete ${_dinero(r.totalFlete)}',
    );
  }
}

class InformeRentabilidad implements ConstructorInforme {
  const InformeRentabilidad(this._metricas);

  final MetricasRepository _metricas;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    _validarDimension(TipoInforme.rentabilidad, dimension);
    final List<MetricaDimension> filas = await _metricas.porDimension(
      desde: filtro.desde,
      hasta: filtro.hasta,
      dimension: dimension,
      clienteId: filtro.clienteId,
      conductorId: filtro.conductorId,
      vehiculoId: filtro.vehiculoId,
      ruta: filtro.ruta,
    );
    final double flete = filas.fold(0, (double a, m) => a + m.totalFlete);
    final double costos = filas.fold(0, (double a, m) => a + m.totalCostos);
    final double rentab = filas.fold(0, (double a, m) => a + m.rentabilidad);
    final int viajes = filas.fold(0, (int a, m) => a + m.viajes);
    return Informe(
      titulo: 'Rentabilidad por ${dimension.etiqueta.toLowerCase()}',
      columnas: <String>[
        dimension.etiqueta,
        'Viajes',
        'Flete',
        'Costos',
        'Rentab.',
        'Margen',
        'Km',
        'Alerta',
      ],
      numericas: const <int>{1, 2, 3, 4, 5, 6},
      filas: <List<String>>[
        for (final MetricaDimension m in filas)
          <String>[
            m.clave,
            '${m.viajes}',
            _dinero(m.totalFlete),
            _dinero(m.totalCostos),
            _dinero(m.rentabilidad),
            _pct(m.margenPct),
            m.kmTotal.round().toString(),
            m.bajoMargen ? 'Bajo margen' : '',
          ],
      ],
      resumen:
          'Totales: $viajes viajes · Flete ${_dinero(flete)} · '
          'Costos ${_dinero(costos)} · Rentabilidad ${_dinero(rentab)}',
    );
  }
}

class InformePuntualidad implements ConstructorInforme {
  const InformePuntualidad(this._metricas);

  final MetricasRepository _metricas;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    _validarDimension(TipoInforme.puntualidad, dimension);
    final List<MetricaDimension> filas = <MetricaDimension>[
      ...await _metricas.porDimension(
        desde: filtro.desde,
        hasta: filtro.hasta,
        dimension: dimension,
        clienteId: filtro.clienteId,
        conductorId: filtro.conductorId,
        vehiculoId: filtro.vehiculoId,
        ruta: filtro.ruta,
      ),
    ];
    // Los más impuntuales primero; sin medición al final.
    filas.sort((MetricaDimension a, MetricaDimension b) {
      final double? x = a.cumplimientoPct;
      final double? y = b.cumplimientoPct;
      if (x == null || y == null) {
        return x == y ? 0 : (x == null ? 1 : -1);
      }
      return x.compareTo(y);
    });
    final int medidos = filas.fold(0, (int a, m) => a + m.viajesMedidos);
    final int aTiempo = filas.fold(0, (int a, m) => a + m.viajesATiempo);
    return Informe(
      titulo: 'Puntualidad por ${dimension.etiqueta.toLowerCase()}',
      columnas: <String>[
        dimension.etiqueta,
        'Viajes',
        'Medidos',
        'A tiempo',
        'Tarde',
        '% a tiempo',
      ],
      numericas: const <int>{1, 2, 3, 4, 5},
      filas: <List<String>>[
        for (final MetricaDimension m in filas)
          <String>[
            m.clave,
            '${m.viajes}',
            '${m.viajesMedidos}',
            '${m.viajesATiempo}',
            '${m.viajesMedidos - m.viajesATiempo}',
            _pct(m.cumplimientoPct),
          ],
      ],
      resumen: medidos == 0
          ? 'Sin viajes medidos en el período.'
          : 'Cumplimiento global: ${_pct(aTiempo / medidos * 100)} '
                '($aTiempo de $medidos viajes medidos)',
      notas: const <String>[
        'Solo cuentan viajes con hito de salida y llegada y tiempo estimado.',
      ],
    );
  }
}

class InformeEsperas implements ConstructorInforme {
  const InformeEsperas(this._esperas);

  final EsperaRepository _esperas;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    final List<EsperaCliente> filas = await _esperas.porCliente(
      desde: filtro.desde,
      hasta: filtro.hasta,
    );
    final int sobreUmbral = filas.fold(
      0,
      (int a, e) => a + e.viajesSobreUmbral,
    );
    return Informe(
      titulo: 'Tiempos de espera por cliente',
      columnas: const <String>[
        'Cliente',
        'Viajes',
        'Cargues medidos',
        'Espera cargue (h)',
        'Descargues medidos',
        'Espera descargue (h)',
        'Máxima (h)',
        'Viajes sobre el umbral',
      ],
      numericas: const <int>{1, 2, 3, 4, 5, 6, 7},
      filas: <List<String>>[
        for (final EsperaCliente e in filas)
          <String>[
            e.cliente,
            '${e.viajes}',
            '${e.carguesMedidos}',
            _horas(e.esperaCargueH),
            '${e.descarguesMedidos}',
            _horas(e.esperaDescargueH),
            _horas(e.esperaMaximaH),
            '${e.viajesSobreUmbral}',
          ],
      ],
      resumen: 'Viajes con espera sobre el umbral: $sobreUmbral',
      notas: const <String>[
        'Esperas promedio en horas. Solo cuentan esperas completas registradas '
            'por el conductor. El sistema informa; no calcula ni cobra standby.',
      ],
    );
  }
}

/// Foto de hoy: no usa fechas ni filtros.
class InformeFlota implements ConstructorInforme {
  const InformeFlota(this._vehiculos, this._hojasVida);

  final VehiculoRepository _vehiculos;
  final HojaVidaRepository _hojasVida;

  static const int _tamano = 100;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    final PaginaVehiculos pagina = await _vehiculos.listar(
      pagina: 0,
      tamano: _tamano,
    );
    final List<Vehiculo> vehiculos =
        pagina.vehiculos.where((Vehiculo v) => v.activo).toList()
          ..sort((Vehiculo a, Vehiculo b) => a.placa.compareTo(b.placa));
    final List<HojaVida> hojas = await Future.wait(
      vehiculos.map((Vehiculo v) => _hojasVida.obtener(v.id)),
    );

    int conDocumentoCritico = 0;
    int conMantenimientoVencido = 0;
    final List<List<String>> filas = <List<String>>[];
    for (int i = 0; i < vehiculos.length; i++) {
      final HojaVida h = hojas[i];
      final DocumentoVehiculo? soat = h.documento(TipoDocumentoVehiculo.soat);
      final DocumentoVehiculo? rtm = h.documento(
        TipoDocumentoVehiculo.tecnomecanica,
      );
      final List<ItemPlanMantenimiento> pendientes = h.plan
          .where(
            (ItemPlanMantenimiento p) =>
                p.estado != EstadoPlanMantenimiento.alDia,
          )
          .toList();
      final int vencidos = pendientes
          .where((p) => p.estado == EstadoPlanMantenimiento.vencido)
          .length;
      final bool docCritico = <DocumentoVehiculo?>[soat, rtm].any(
        (DocumentoVehiculo? d) =>
            d == null || d.estado != EstadoDocumento.vigente,
      );
      if (docCritico) conDocumentoCritico++;
      if (vencidos > 0) conMantenimientoVencido++;
      filas.add(<String>[
        vehiculos[i].placa,
        h.odometroKm.round().toString(),
        _documento(soat),
        _documento(rtm),
        '$vencidos',
        '${pendientes.length - vencidos}',
        pendientes
            .map(
              (ItemPlanMantenimiento p) =>
                  '${p.tipoNombre} (${p.estado.etiqueta})',
            )
            .join(', '),
      ]);
    }

    return Informe(
      titulo: 'Estado de flota y mantenimiento',
      columnas: const <String>[
        'Placa',
        'Odómetro (km)',
        'SOAT',
        'Técnico-mecánica',
        'Mant. vencidos',
        'Mant. próximos',
        'Pendientes',
      ],
      numericas: const <int>{1, 4, 5},
      filas: filas,
      resumen:
          '${vehiculos.length} vehículos activos · '
          '$conDocumentoCritico con documento sin registrar, por vencer o '
          'vencido · $conMantenimientoVencido con mantenimiento vencido',
      notas: const <String>[
        'El odómetro es aproximado (kilometraje GPS acumulado).',
      ],
    );
  }

  static String _documento(DocumentoVehiculo? d) {
    if (d == null) return 'Sin registrar';
    return '${d.estado.etiqueta} · ${formatearFecha(d.fechaVencimiento)}';
  }
}

/// Une, por nombre de conductor, rentabilidad, puntualidad, calidad y
/// satisfacción: las tres RPC agrupan por el mismo nombre.
class InformeConductores implements ConstructorInforme {
  const InformeConductores(this._metricas, this._calidad, this._satisfaccion);

  final MetricasRepository _metricas;
  final CalidadRepository _calidad;
  final SatisfaccionRepository _satisfaccion;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    final List<Object> r = await Future.wait(<Future<Object>>[
      _metricas.porDimension(
        desde: filtro.desde,
        hasta: filtro.hasta,
        dimension: DimensionMetrica.conductor,
        clienteId: filtro.clienteId,
        conductorId: filtro.conductorId,
        vehiculoId: filtro.vehiculoId,
        ruta: filtro.ruta,
      ),
      _calidad.porDimension(filtro, DimensionCalidad.conductor),
      _satisfaccion.porDimension(filtro, DimensionMetrica.conductor),
    ]);
    final List<MetricaDimension> metricas = r[0] as List<MetricaDimension>;
    final Map<String, CalidadDimension> calidad = <String, CalidadDimension>{
      for (final CalidadDimension c in r[1] as List<CalidadDimension>)
        c.clave: c,
    };
    final Map<String, SatisfaccionDimension> satisfaccion =
        <String, SatisfaccionDimension>{
          for (final SatisfaccionDimension s
              in r[2] as List<SatisfaccionDimension>)
            s.clave: s,
        };

    return Informe(
      titulo: 'Desempeño por conductor',
      columnas: const <String>[
        'Conductor',
        'Viajes',
        'Km',
        'Rentab.',
        'Margen',
        '% a tiempo',
        'Calidad',
        'CSAT',
        'NPS',
      ],
      numericas: const <int>{1, 2, 3, 4, 5, 7, 8},
      filas: <List<String>>[
        for (final MetricaDimension m in metricas)
          <String>[
            m.clave,
            '${m.viajes}',
            m.kmTotal.round().toString(),
            _dinero(m.rentabilidad),
            _pct(m.margenPct),
            _pct(m.cumplimientoPct),
            _calidadTexto(calidad[m.clave]),
            _csat(satisfaccion[m.clave]),
            _nps(satisfaccion[m.clave]),
          ],
      ],
      notas: const <String>[
        'Calidad: puntaje de 0 a 100 de los viajes del período. CSAT y NPS '
            'solo se muestran con 5 o más encuestas respondidas.',
      ],
    );
  }

  static String _calidadTexto(CalidadDimension? c) {
    final double? p = c?.puntajePromedio;
    if (p == null) return '—';
    return '${p.round()} · ${NivelCalidad.dePuntaje(p)!.etiqueta}';
  }

  static bool _suficiente(SatisfaccionDimension? s) =>
      s != null && s.respondidas >= ResumenSatisfaccion.minimoRespuestas;

  static String _csat(SatisfaccionDimension? s) =>
      !_suficiente(s) || s!.csatGlobal == null
      ? '—'
      : formatearDecimal(s.csatGlobal!);

  static String _nps(SatisfaccionDimension? s) =>
      !_suficiente(s) || s!.nps == null ? '—' : s.nps!.round().toString();
}

class InformeSatisfaccion implements ConstructorInforme {
  const InformeSatisfaccion(this._satisfaccion);

  final SatisfaccionRepository _satisfaccion;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    _validarDimension(TipoInforme.satisfaccion, dimension);
    final List<Object> r = await Future.wait(<Future<Object>>[
      _satisfaccion.resumen(filtro),
      _satisfaccion.porDimension(filtro, dimension),
    ]);
    final ResumenSatisfaccion s = r[0] as ResumenSatisfaccion;
    final List<SatisfaccionDimension> filas =
        r[1] as List<SatisfaccionDimension>;

    return Informe(
      titulo: 'Satisfacción por ${dimension.etiqueta.toLowerCase()}',
      columnas: <String>[
        dimension.etiqueta,
        'Respondidas',
        'CSAT',
        'NPS',
        'Nivel',
      ],
      numericas: const <int>{1, 2, 3},
      filas: s.encuestasTotal == 0
          ? const <List<String>>[]
          : <List<String>>[
              for (final SatisfaccionDimension f in filas)
                <String>[
                  f.clave,
                  '${f.respondidas}',
                  f.csatGlobal == null ? '—' : formatearDecimal(f.csatGlobal!),
                  f.nps == null ? '—' : f.nps!.round().toString(),
                  f.respondidas < ResumenSatisfaccion.minimoRespuestas
                      ? NivelSatisfaccion.sinDatos.etiqueta
                      : NivelSatisfaccion.deCsat(f.csatGlobal).etiqueta,
                ],
            ],
      resumen:
          'Encuestas ${s.encuestasTotal} · respondidas ${s.respondidas} '
          '(${_pct(s.tasaRespuestaPct)}) · pendientes ${s.pendientes} · '
          'CSAT ${s.csatGlobal == null ? '—' : formatearDecimal(s.csatGlobal!)} · '
          'NPS ${s.nps == null ? '—' : s.nps!.round().toString()}',
      notas: <String>[
        if (!s.hayDatosSuficientes)
          'Menos de ${ResumenSatisfaccion.minimoRespuestas} respuestas: '
              'los promedios no son representativos.',
      ],
    );
  }
}

class InformeCalidad implements ConstructorInforme {
  const InformeCalidad(this._calidad);

  final CalidadRepository _calidad;

  @override
  Future<Informe> call(FiltroReporte filtro, DimensionMetrica dimension) async {
    _validarDimension(TipoInforme.calidad, dimension);
    final DimensionCalidad eje = switch (dimension) {
      DimensionMetrica.ruta => DimensionCalidad.ruta,
      DimensionMetrica.conductor => DimensionCalidad.conductor,
      _ => DimensionCalidad.vehiculo,
    };
    final List<Object> r = await Future.wait(<Future<Object>>[
      _calidad.resumen(filtro),
      _calidad.porDimension(filtro, eje),
      _calidad.recurrentes(filtro),
    ]);
    final ResumenCalidad s = r[0] as ResumenCalidad;
    final List<CalidadDimension> filas = r[1] as List<CalidadDimension>;
    final List<AlertaRecurrente> alertas = r[2] as List<AlertaRecurrente>;

    return Informe(
      titulo: 'Calidad por ${dimension.etiqueta.toLowerCase()}',
      columnas: <String>[
        dimension.etiqueta,
        'Viajes',
        'Puntaje',
        'Nivel',
        'En rojo',
        'Puntualidad',
        'Rentabilidad',
        'Cliente',
        'Incidencias',
      ],
      numericas: const <int>{1, 2, 4, 5, 6, 7, 8},
      filas: s.viajesEvaluados == 0
          ? const <List<String>>[]
          : <List<String>>[
              for (final CalidadDimension c in filas)
                <String>[
                  c.clave,
                  '${c.viajes}',
                  c.puntajePromedio == null
                      ? '—'
                      : c.puntajePromedio!.round().toString(),
                  NivelCalidad.dePuntaje(c.puntajePromedio)?.etiqueta ?? '—',
                  '${c.rojos}',
                  '${c.puntualidadRojos}',
                  '${c.rentabilidadRojos}',
                  '${c.satisfaccionRojos}',
                  '${c.incidenciasRojos}',
                ],
            ],
      resumen:
          '${s.viajesEvaluados} viajes evaluados · ${s.verdes} conformes · '
          '${s.ambares} con mejoras · ${s.rojos} con observación · '
          'Puntaje promedio '
          '${s.puntajePromedio == null ? '—' : s.puntajePromedio!.round()}',
      notas: <String>[
        'Las columnas por dimensión cuentan los viajes en rojo.',
        for (final AlertaRecurrente a in alertas)
          'Alerta: ${a.mensaje} (${a.viajes} viajes).',
      ],
    );
  }
}

/// Punto de entrada de la pantalla: valida y delega en el informe elegido.
class ObtenerInformeUseCase {
  const ObtenerInformeUseCase(this._constructores);

  final Map<TipoInforme, ConstructorInforme> _constructores;

  Future<Informe> call(
    TipoInforme tipo,
    FiltroReporte filtro,
    DimensionMetrica dimension,
  ) {
    if (tipo.usaFechas && filtro.desde.isAfter(filtro.hasta)) {
      throw ArgumentError.value(
        filtro.desde,
        'desde',
        'La fecha inicial no puede ser posterior a la final.',
      );
    }
    final ConstructorInforme? constructor = _constructores[tipo];
    if (constructor == null) {
      throw StateError('Informe sin implementar: ${tipo.name}');
    }
    return constructor(filtro, dimension);
  }
}
