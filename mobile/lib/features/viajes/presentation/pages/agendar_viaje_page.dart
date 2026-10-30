import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/miles_formatter.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../clientes/domain/entities/cliente.dart';
import '../../../clientes/domain/repositories/cliente_repository.dart';
import '../../../conductores/domain/entities/conductor.dart';
import '../../../conductores/domain/repositories/conductor_repository.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../../vehiculos/domain/repositories/hoja_vida_repository.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/lugar.dart';
import '../../domain/repositories/ruta_repository.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../../domain/usecases/buscar_lugares_use_case.dart';
import '../../domain/usecases/crear_viaje_use_case.dart';
import '../../domain/usecases/estimar_acpm_use_case.dart';
import '../../domain/usecases/estimar_ruta_use_case.dart';
import '../../domain/usecases/lugar_en_coordenada_use_case.dart';
import '../bloc/agendar_viaje_cubit.dart';
import '../bloc/agendar_viaje_state.dart';
import '../widgets/mapa_ruta.dart';
import 'selector_ubicacion_page.dart';

/// Formulario de Agendar viaje: datos del viaje + estimados automáticos
/// (distancia/tiempo vía Edge Function `rutas`, ACPM vía
/// `costo_acpm_estimado`). Sub-flujo del Calendario: AppBar con flecha de
/// volver, no hamburguesa (no forma parte del shell de secciones).
class AgendarViajePage extends StatelessWidget {
  const AgendarViajePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgendarViajeCubit>(
      create: (BuildContext context) => AgendarViajeCubit(
        clienteRepository: context.read<ClienteRepository>(),
        vehiculoRepository: context.read<VehiculoRepository>(),
        conductorRepository: context.read<ConductorRepository>(),
        crear: CrearViajeUseCase(context.read()),
        estimarRuta: EstimarRutaUseCase(context.read()),
        estimarAcpm: EstimarAcpmUseCase(context.read()),
        hojaVidaRepository: context.read<HojaVidaRepository>(),
        viajeRepository: context.read<ViajeRepository>(),
      ),
      child: const _AgendarViajeView(),
    );
  }
}

String _generarRemision() {
  final DateTime ahora = DateTime.now();
  final String fecha =
      '${ahora.year}${ahora.month.toString().padLeft(2, '0')}'
      '${ahora.day.toString().padLeft(2, '0')}';
  final int sufijo = Random().nextInt(9000) + 1000;
  return 'V-$fecha-$sufijo';
}

class _AgendarViajeView extends StatefulWidget {
  const _AgendarViajeView();

  @override
  State<_AgendarViajeView> createState() => _AgendarViajeViewState();
}

class _AgendarViajeViewState extends State<_AgendarViajeView> {
  late final TextEditingController _remision = TextEditingController(
    text: _generarRemision(),
  );
  final TextEditingController _carga = TextEditingController();
  final TextEditingController _flete = TextEditingController();

  Lugar? _origen;
  Lugar? _destino;
  Cliente? _cliente;
  Vehiculo? _vehiculo;
  Conductor? _conductor;
  // Sin valor por defecto: una fecha u hora silenciosa se confirma sin querer.
  DateTime? _fecha;
  TimeOfDay? _hora;
  int _paso = 0;

  String? _errorFormulario;

  @override
  void dispose() {
    _remision.dispose();
    _carga.dispose();
    _flete.dispose();
    super.dispose();
  }

  DateTime? get _fechaSalidaProgramada => _fecha == null || _hora == null
      ? null
      : DateTime(
          _fecha!.year,
          _fecha!.month,
          _fecha!.day,
          _hora!.hour,
          _hora!.minute,
        );

  double? get _fleteValor =>
      double.tryParse(_flete.text.replaceAll(RegExp(r'\D'), ''));

  Future<void> _elegirFecha(AgendarViajeCubit cubit) async {
    final DateTime? elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida == null) return;
    setState(() => _fecha = elegida);
    // Documentos vencidos y cruces dependen del día de salida.
    cubit.cargarDisponibilidad(elegida);
  }

  Future<void> _elegirHora() async {
    final TimeOfDay? elegida = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 6, minute: 0),
    );
    if (elegida != null) setState(() => _hora = elegida);
  }

  Future<T?> _elegirDeLista<T>({
    required String titulo,
    required List<T> opciones,
    required String Function(T) etiqueta,
    AvisoDisponibilidad Function(T)? aviso,
    String? nota,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Text(titulo, style: AppTypography.subtitle),
              ),
              if (nota != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x4,
                    0,
                    AppSpacing.x4,
                    AppSpacing.x2,
                  ),
                  child: Text(nota, style: AppTypography.caption),
                ),
              if (opciones.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.x4),
                  child: Text('No hay opciones activas disponibles.'),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: opciones.length,
                  itemBuilder: (BuildContext context, int i) {
                    final T opcion = opciones[i];
                    final AvisoDisponibilidad? a = aviso?.call(opcion);
                    final bool hayAviso =
                        a != null && a.nivel != NivelAviso.ninguno;
                    return ListTile(
                      title: Text(etiqueta(opcion)),
                      subtitle: hayAviso
                          ? Text(
                              a.mensaje ?? '',
                              style: AppTypography.caption.copyWith(
                                color: _colorAviso(a.nivel),
                              ),
                            )
                          : null,
                      trailing: hayAviso
                          ? Icon(
                              a.nivel == NivelAviso.critico
                                  ? LucideIcons.circleAlert
                                  : LucideIcons.triangleAlert,
                              color: _colorAviso(a.nivel),
                              size: 20,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(opcion),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _elegirUbicacion(
    AgendarViajeCubit cubit, {
    required bool esOrigen,
  }) async {
    final Lugar? actual = esOrigen ? _origen : _destino;
    final Lugar? elegido = await Navigator.of(context).push<Lugar>(
      MaterialPageRoute<Lugar>(
        builder: (BuildContext _) => SelectorUbicacionPage(
          titulo: esOrigen ? 'Origen' : 'Destino',
          inicial: actual,
          buscar: BuscarLugaresUseCase(context.read<RutaRepository>()),
          lugarEn: LugarEnCoordenadaUseCase(context.read<RutaRepository>()),
        ),
      ),
    );
    if (elegido == null || !mounted) return;

    setState(() {
      if (esOrigen) {
        _origen = elegido;
      } else {
        _destino = elegido;
      }
      _errorFormulario = null;
    });
    // La ruta depende de ambos puntos: se recalcula sola al tener los dos.
    if (_origen != null && _destino != null) await _calcularRuta(cubit);
  }

  Future<void> _calcularRuta(AgendarViajeCubit cubit) async {
    final Lugar? origen = _origen;
    final Lugar? destino = _destino;
    if (origen == null || destino == null) {
      setState(
        () => _errorFormulario =
            'Elige origen y destino en el mapa para calcular la ruta.',
      );
      return;
    }
    setState(() => _errorFormulario = null);
    await cubit.estimarRuta(
      origen: origen.coordenada,
      destino: destino.coordenada,
    );

    final AgendarViajeState estado = cubit.state;
    if (estado is AgendarViajeListo &&
        estado.ruta != null &&
        _vehiculo != null) {
      await cubit.estimarAcpm(
        vehiculoId: _vehiculo!.id,
        distanciaKm: estado.ruta!.distanciaKm,
        ciudad: origen.nombre,
      );
    }
  }

  void _alElegirVehiculo(AgendarViajeCubit cubit, Vehiculo vehiculo) {
    setState(() => _vehiculo = vehiculo);
    final AgendarViajeState estado = cubit.state;
    if (estado is AgendarViajeListo && estado.ruta != null) {
      cubit.estimarAcpm(
        vehiculoId: vehiculo.id,
        distanciaKm: estado.ruta!.distanciaKm,
        ciudad: _origen!.nombre,
      );
    }
  }

  /// Qué falta en el paso [paso] para poder continuar; `null` si está listo.
  String? _faltaEnPaso(int paso, AgendarViajeListo estado) {
    switch (paso) {
      case 0:
        if (_cliente == null ||
            _origen == null ||
            _destino == null ||
            double.tryParse(_carga.text.trim()) == null ||
            _fleteValor == null) {
          return 'Completa cliente, origen, destino, carga y flete.';
        }
        if (estado.ruta == null) {
          return 'Calcula la distancia y el tiempo de ruta antes de continuar.';
        }
      case 1:
        if (_fecha == null || _hora == null) {
          return 'Elige la fecha y la hora de salida.';
        }
        if (_vehiculo == null || _conductor == null) {
          return 'Elige el vehículo y el conductor.';
        }
    }
    return null;
  }

  void _siguiente(AgendarViajeListo estado) {
    final String? falta = _faltaEnPaso(_paso, estado);
    setState(() {
      _errorFormulario = falta;
      if (falta == null) _paso++;
    });
  }

  void _agendar(BuildContext context, AgendarViajeListo estado) {
    final String? falta =
        _faltaEnPaso(0, estado) ??
        _faltaEnPaso(1, estado) ??
        (_remision.text.trim().isEmpty
            ? 'La remisión no puede estar vacía.'
            : null);
    if (falta != null) {
      setState(() => _errorFormulario = falta);
      return;
    }

    setState(() => _errorFormulario = null);
    context.read<AgendarViajeCubit>().crear(
      remision: _remision.text,
      vehiculoId: _vehiculo!.id,
      conductorId: _conductor!.id,
      clienteId: _cliente!.id,
      origen: _origen!,
      destino: _destino!,
      rutaPolilinea: estado.ruta!.polilinea,
      fechaSalidaProgramada: _fechaSalidaProgramada!,
      distanciaEstimada: estado.ruta!.distanciaKm,
      tiempoEstimadoMin: estado.ruta!.duracionMin,
      pesoCarga: double.parse(_carga.text.trim()),
      valorFlete: _fleteValor!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AgendarViajeCubit, AgendarViajeState>(
      listener: (BuildContext context, AgendarViajeState state) {
        if (state is AgendarViajeExito) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (BuildContext context, AgendarViajeState state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Agendar viaje')),
          body: switch (state) {
            AgendarViajeCargando() => const LoadingState(),
            AgendarViajeErrorCatalogos(:final mensaje) => Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: AppAlert(mensaje: mensaje),
            ),
            AgendarViajeListo() => _formulario(context, state),
            AgendarViajeExito() => const LoadingState(),
          },
        );
      },
    );
  }

  Widget _formulario(BuildContext context, AgendarViajeListo estado) {
    final AgendarViajeCubit cubit = context.read<AgendarViajeCubit>();
    final bool ultimo = _paso == _etiquetasPasos.length - 1;

    return Column(
      children: <Widget>[
        _Pasos(actual: _paso),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_errorFormulario != null) ...<Widget>[
                  AppAlert(mensaje: _errorFormulario!),
                  const SizedBox(height: AppSpacing.x4),
                ],
                if (estado.errorEnvio != null) ...<Widget>[
                  AppAlert(mensaje: estado.errorEnvio!),
                  const SizedBox(height: AppSpacing.x4),
                ],
                ...switch (_paso) {
                  0 => _pasoRuta(estado, cubit),
                  1 => _pasoCuando(estado, cubit),
                  _ => _pasoRevisar(estado),
                },
              ],
            ),
          ),
        ),
        _BarraPaso(
          resumenMargen: _resumenMargen(estado),
          puedeVolver: _paso > 0 && !estado.enviando,
          alVolver: () => setState(() {
            _errorFormulario = null;
            _paso--;
          }),
          etiquetaAvance: ultimo ? 'Agendar viaje' : 'Siguiente',
          enviando: estado.enviando,
          alAvanzar: ultimo
              ? () => _agendar(context, estado)
              : () => _siguiente(estado),
        ),
      ],
    );
  }

  static const List<String> _etiquetasPasos = <String>[
    'Ruta y carga',
    'Cuándo y con qué',
    'Revisar',
  ];

  /// Margen con lo único que se conoce al agendar. Los peajes y los demás
  /// costos llegan con el viaje, por eso se dice «antes de».
  String? _resumenMargen(AgendarViajeListo estado) {
    final double? flete = _fleteValor;
    final double? acpm = estado.acpmEstimado;
    if (flete == null || flete <= 0 || acpm == null) return null;
    final NumberFormatCop m = NumberFormatCop();
    final double margen = flete - acpm;
    return 'Flete ${m.formatear(flete)} − ACPM ${m.formatear(acpm)} = '
        '${m.formatear(margen)} (${formatearPorcentaje(margen / flete * 100)}) '
        'antes de peajes y otros costos';
  }

  List<Widget> _pasoRuta(AgendarViajeListo estado, AgendarViajeCubit cubit) {
    return <Widget>[
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Carga y ruta', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.x4),
            AppSelectField(
              label: 'Cliente',
              valor: _cliente?.nombre,
              marcador: 'Seleccionar cliente',
              onTap: () async {
                final Cliente? elegido = await _elegirDeLista<Cliente>(
                  titulo: 'Cliente',
                  opciones: estado.clientes,
                  etiqueta: (Cliente c) => c.nombre,
                );
                if (elegido != null) setState(() => _cliente = elegido);
              },
            ),
            const SizedBox(height: AppSpacing.x4),
            AppSelectField(
              label: 'Origen',
              valor: _origen?.nombre,
              marcador: 'Buscar o elegir en el mapa',
              icono: LucideIcons.mapPin,
              onTap: () => _elegirUbicacion(cubit, esOrigen: true),
            ),
            const SizedBox(height: AppSpacing.x4),
            AppSelectField(
              label: 'Destino',
              valor: _destino?.nombre,
              marcador: 'Buscar o elegir en el mapa',
              icono: LucideIcons.mapPin,
              onTap: () => _elegirUbicacion(cubit, esOrigen: false),
            ),
            const SizedBox(height: AppSpacing.x4),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    label: 'Carga (toneladas)',
                    controller: _carga,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: AppTextField(
                    label: 'Flete (COP)',
                    controller: _flete,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[MilesFormatter()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.x4),
      _EstimadosCard(
        estado: estado,
        origen: _origen,
        destino: _destino,
        vehiculo: _vehiculo,
        onCalcular: () => _calcularRuta(cubit),
      ),
    ];
  }

  List<Widget> _pasoCuando(AgendarViajeListo estado, AgendarViajeCubit cubit) {
    final AvisoDisponibilidad? avisoVeh = _vehiculo == null
        ? null
        : estado.avisosVehiculos[_vehiculo!.id];
    final AvisoDisponibilidad? avisoCon = _conductor == null
        ? null
        : estado.avisosConductores[_conductor!.id];
    const String nota =
        'Elige primero la fecha: así se ven los documentos vencidos y los '
        'cruces de agenda de cada opción.';

    return <Widget>[
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Cuándo y con qué', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.x4),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppSelectField(
                    label: 'Fecha de salida',
                    valor: _fecha == null ? null : formatearFecha(_fecha!),
                    marcador: 'Elegir fecha',
                    icono: LucideIcons.calendar,
                    onTap: () => _elegirFecha(cubit),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: AppSelectField(
                    label: 'Hora',
                    valor: _hora?.format(context),
                    marcador: 'Elegir hora',
                    icono: LucideIcons.clock,
                    onTap: _elegirHora,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
            AppSelectField(
              label: 'Vehículo',
              valor: _vehiculo == null
                  ? null
                  : '${_vehiculo!.placa} · ${_vehiculo!.tipo.etiqueta}',
              marcador: 'Seleccionar vehículo',
              onTap: () async {
                final Vehiculo? elegido = await _elegirDeLista<Vehiculo>(
                  titulo: 'Vehículo',
                  opciones: estado.vehiculos,
                  etiqueta: (Vehiculo v) => '${v.placa} · ${v.tipo.etiqueta}',
                  aviso: (Vehiculo v) =>
                      estado.avisosVehiculos[v.id] ?? AvisoDisponibilidad.libre,
                  nota: _fecha == null ? nota : null,
                );
                if (elegido != null) _alElegirVehiculo(cubit, elegido);
              },
            ),
            if (avisoVeh != null) _AvisoInline(aviso: avisoVeh),
            const SizedBox(height: AppSpacing.x4),
            AppSelectField(
              label: 'Conductor',
              valor: _conductor?.nombre,
              marcador: 'Seleccionar conductor',
              onTap: () async {
                final Conductor? elegido = await _elegirDeLista<Conductor>(
                  titulo: 'Conductor',
                  opciones: estado.conductores,
                  etiqueta: (Conductor c) => c.nombre,
                  aviso: (Conductor c) =>
                      estado.avisosConductores[c.id] ??
                      AvisoDisponibilidad.libre,
                  nota: _fecha == null ? nota : null,
                );
                if (elegido != null) setState(() => _conductor = elegido);
              },
            ),
            if (avisoCon != null) _AvisoInline(aviso: avisoCon),
          ],
        ),
      ),
    ];
  }

  List<Widget> _pasoRevisar(AgendarViajeListo estado) {
    final NumberFormatCop m = NumberFormatCop();
    final AvisoDisponibilidad? avisoVeh = _vehiculo == null
        ? null
        : estado.avisosVehiculos[_vehiculo!.id];
    final AvisoDisponibilidad? avisoCon = _conductor == null
        ? null
        : estado.avisosConductores[_conductor!.id];
    final DateTime salida = _fechaSalidaProgramada!;
    final bool critico =
        avisoVeh?.nivel == NivelAviso.critico ||
        avisoCon?.nivel == NivelAviso.critico;

    return <Widget>[
      if (critico) ...<Widget>[
        const AppAlert(
          tono: AppAlertTono.advertencia,
          titulo: 'Hay un impedimento para esta salida',
          mensaje:
              'Puedes agendar igual, pero el conductor no podrá comenzar el '
              'viaje hasta regularizarlo. Revisa los avisos del paso anterior.',
        ),
        const SizedBox(height: AppSpacing.x4),
      ],
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Revisar y agendar', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.x3),
            _FilaEstimado(etiqueta: 'Cliente', valor: _cliente!.nombre),
            _FilaEstimado(
              etiqueta: 'Ruta',
              valor: '${_origen!.nombre} → ${_destino!.nombre}',
            ),
            _FilaEstimado(
              etiqueta: 'Salida',
              valor: '${formatearFecha(salida)} · ${_hora!.format(context)}',
            ),
            _FilaEstimado(
              etiqueta: 'Vehículo',
              valor: '${_vehiculo!.placa} · ${_vehiculo!.tipo.etiqueta}',
            ),
            _FilaEstimado(etiqueta: 'Conductor', valor: _conductor!.nombre),
            _FilaEstimado(etiqueta: 'Carga', valor: '${_carga.text.trim()} t'),
            _FilaEstimado(etiqueta: 'Flete', valor: m.formatear(_fleteValor!)),
            _FilaEstimado(
              etiqueta: 'Distancia',
              valor: '${estado.ruta!.distanciaKm.toStringAsFixed(0)} km',
            ),
            _FilaEstimado(
              etiqueta: 'Tiempo de ruta',
              valor: formatearDuracion(estado.ruta!.duracionMin),
            ),
            if (estado.acpmEstimado != null)
              _FilaEstimado(
                etiqueta: 'ACPM estimado',
                valor: m.formatear(estado.acpmEstimado!),
              ),
            const SizedBox(height: AppSpacing.x2),
            AppTextField(
              label: 'Remisión',
              hint: 'Se genera sola; puedes cambiarla',
              controller: _remision,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    ];
  }
}

Color _colorAviso(NivelAviso n) => n == NivelAviso.critico
    ? AppColors.error
    : n == NivelAviso.aviso
    ? AppColors.warning
    : AppColors.textSecondary;

class _AvisoInline extends StatelessWidget {
  const _AvisoInline({required this.aviso});

  final AvisoDisponibilidad aviso;

  @override
  Widget build(BuildContext context) {
    if (aviso.nivel == NivelAviso.ninguno) return const SizedBox.shrink();
    final Color color = _colorAviso(aviso.nivel);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            aviso.nivel == NivelAviso.critico
                ? LucideIcons.circleAlert
                : LucideIcons.triangleAlert,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              aviso.mensaje ?? '',
              style: AppTypography.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador de pasos: número, nombre y progreso.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.actual});

  final int actual;

  @override
  Widget build(BuildContext context) {
    const List<String> etiquetas = _AgendarViajeViewState._etiquetasPasos;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        0,
      ),
      child: Semantics(
        label:
            'Paso ${actual + 1} de ${etiquetas.length}: ${etiquetas[actual]}',
        excludeSemantics: true,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < etiquetas.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == etiquetas.length - 1 ? 0 : AppSpacing.x2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= actual
                              ? AppColors.primary
                              : AppColors.borderInput,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        '${i + 1}. ${etiquetas[i]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: i == actual
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: i == actual
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pie fijo: el margen que se va armando y los botones del paso.
class _BarraPaso extends StatelessWidget {
  const _BarraPaso({
    required this.resumenMargen,
    required this.puedeVolver,
    required this.alVolver,
    required this.etiquetaAvance,
    required this.enviando,
    required this.alAvanzar,
  });

  final String? resumenMargen;
  final bool puedeVolver;
  final VoidCallback alVolver;
  final String etiquetaAvance;
  final bool enviando;
  final VoidCallback alAvanzar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.dividerTable)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (resumenMargen != null) ...<Widget>[
                Text(
                  resumenMargen!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
              ],
              Row(
                children: <Widget>[
                  if (puedeVolver) ...<Widget>[
                    Expanded(
                      child: SecondaryButton(
                        label: 'Atrás',
                        onPressed: alVolver,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                  ],
                  Expanded(
                    flex: 2,
                    child: PrimaryActionButton(
                      label: etiquetaAvance,
                      loading: enviando,
                      onPressed: enviando ? null : alAvanzar,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstimadosCard extends StatelessWidget {
  const _EstimadosCard({
    required this.estado,
    required this.origen,
    required this.destino,
    required this.vehiculo,
    required this.onCalcular,
  });

  final AgendarViajeListo estado;
  final Lugar? origen;
  final Lugar? destino;
  final Vehiculo? vehiculo;
  final VoidCallback onCalcular;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      stripe: AppCardStripe.top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Estimados del viaje',
                  style: AppTypography.subtitle,
                ),
              ),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                decoration: const BoxDecoration(
                  color: AppColors.navyTint,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Automático',
                  style: AppTypography.label.copyWith(color: AppColors.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          if (estado.errorRuta != null) ...<Widget>[
            AppAlert(mensaje: estado.errorRuta!),
            const SizedBox(height: AppSpacing.x3),
          ],
          if (estado.ruta == null)
            SecondaryButton(
              label: estado.estimandoRuta
                  ? 'Calculando...'
                  : 'Calcular distancia y tiempo',
              onPressed: estado.estimandoRuta ? null : onCalcular,
            )
          else ...<Widget>[
            if (origen != null && destino != null) ...<Widget>[
              MapaRuta(
                origen: origen!.coordenada,
                destino: destino!.coordenada,
                polilinea: estado.ruta!.polilinea,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],
            _FilaEstimado(
              etiqueta: 'Distancia',
              valor: '${estado.ruta!.distanciaKm.toStringAsFixed(0)} km',
            ),
            _FilaEstimado(
              etiqueta: 'Tiempo de ruta',
              valor: formatearDuracion(estado.ruta!.duracionMin),
            ),
            if (vehiculo != null)
              _FilaEstimado(
                etiqueta: 'ACPM estimado',
                valor:
                    '${(estado.ruta!.distanciaKm / vehiculo!.rendimientoKmGalon).toStringAsFixed(0)} gal',
              ),
            if (estado.estimandoAcpm)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.x2),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (estado.errorAcpm != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.x2),
                child: AppAlert(
                  tono: AppAlertTono.advertencia,
                  mensaje: estado.errorAcpm!,
                ),
              )
            else if (estado.acpmEstimado != null)
              _FilaEstimado(
                etiqueta: 'Costo ACPM estimado',
                valor:
                    r'$'
                    '${estado.acpmEstimado!.toStringAsFixed(0)}',
              ),
          ],
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Los valores reales (ACPM, peajes vía GoPass, tiempos) se '
            'confirman al ejecutar el viaje.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _FilaEstimado extends StatelessWidget {
  const _FilaEstimado({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: AppSpacing.x2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            etiqueta,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            valor,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}
