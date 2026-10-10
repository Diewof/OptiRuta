import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../clientes/domain/entities/cliente.dart';
import '../../../clientes/domain/repositories/cliente_repository.dart';
import '../../../conductores/domain/entities/conductor.dart';
import '../../../conductores/domain/repositories/conductor_repository.dart';
import '../../../vehiculos/domain/entities/vehiculo.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../domain/entities/lugar.dart';
import '../../domain/repositories/ruta_repository.dart';
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
  DateTime _fecha = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _hora = const TimeOfDay(hour: 6, minute: 0);

  String? _errorFormulario;

  @override
  void dispose() {
    _remision.dispose();
    _carga.dispose();
    _flete.dispose();
    super.dispose();
  }

  DateTime get _fechaSalidaProgramada =>
      DateTime(_fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);

  Future<void> _elegirFecha() async {
    final DateTime? elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final TimeOfDay? elegida = await showTimePicker(
      context: context,
      initialTime: _hora,
    );
    if (elegida != null) setState(() => _hora = elegida);
  }

  Future<T?> _elegirDeLista<T>({
    required String titulo,
    required List<T> opciones,
    required String Function(T) etiqueta,
  }) {
    return showModalBottomSheet<T>(
      context: context,
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
                    return ListTile(
                      title: Text(etiqueta(opcion)),
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

  void _agendar(BuildContext context, AgendarViajeListo estado) {
    final double? carga = double.tryParse(_carga.text.trim());
    final double? flete = double.tryParse(_flete.text.trim());

    if (_remision.text.trim().isEmpty ||
        _origen == null ||
        _destino == null ||
        _cliente == null ||
        _vehiculo == null ||
        _conductor == null ||
        carga == null ||
        flete == null) {
      setState(
        () =>
            _errorFormulario = 'Completa todos los campos con valores válidos.',
      );
      return;
    }
    if (estado.ruta == null) {
      setState(
        () => _errorFormulario =
            'Calcula la distancia y el tiempo de ruta antes de agendar.',
      );
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
      fechaSalidaProgramada: _fechaSalidaProgramada,
      distanciaEstimada: estado.ruta!.distanciaKm,
      tiempoEstimadoMin: estado.ruta!.duracionMin,
      pesoCarga: carga,
      valorFlete: flete,
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

    return SingleChildScrollView(
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
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Datos del viaje', style: AppTypography.subtitle),
                const SizedBox(height: AppSpacing.x4),
                AppTextField(
                  label: 'Remisión',
                  controller: _remision,
                  textInputAction: TextInputAction.next,
                ),
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
                      child: AppSelectField(
                        label: 'Fecha de salida',
                        valor:
                            '${_fecha.day.toString().padLeft(2, '0')}/'
                            '${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
                        icono: LucideIcons.calendar,
                        onTap: _elegirFecha,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: AppSelectField(
                        label: 'Hora',
                        valor: _hora.format(context),
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
                      etiqueta: (Vehiculo v) =>
                          '${v.placa} · ${v.tipo.etiqueta}',
                    );
                    if (elegido != null) _alElegirVehiculo(cubit, elegido);
                  },
                ),
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
                    );
                    if (elegido != null) setState(() => _conductor = elegido);
                  },
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
                        keyboardType: const TextInputType.numberWithOptions(),
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
          const SizedBox(height: AppSpacing.x6),
          PrimaryActionButton(
            label: 'Agendar viaje',
            loading: estado.enviando,
            onPressed: estado.enviando ? null : () => _agendar(context, estado),
          ),
          const SizedBox(height: AppSpacing.x2),
          SecondaryButton(
            label: 'Cancelar',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
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
              valor: '${(estado.ruta!.duracionMin / 60).toStringAsFixed(0)} h',
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
