import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/tipo_vehiculo.dart';
import '../../domain/entities/vehiculo.dart';
import '../../domain/repositories/vehiculo_repository.dart';
import '../../domain/usecases/actualizar_vehiculo_use_case.dart';
import '../../domain/usecases/crear_vehiculo_use_case.dart';
import '../bloc/vehiculo_form_cubit.dart';
import '../bloc/vehiculo_form_state.dart';

/// Alta/edicion de un vehiculo. Sin [vehiculo] => crear.
class VehiculoFormPage extends StatelessWidget {
  const VehiculoFormPage({this.vehiculo, super.key});

  final Vehiculo? vehiculo;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VehiculoFormCubit>(
      create: (BuildContext context) => VehiculoFormCubit(
        crear: CrearVehiculoUseCase(context.read<VehiculoRepository>()),
        actualizar: ActualizarVehiculoUseCase(
          context.read<VehiculoRepository>(),
        ),
      ),
      child: _VehiculoFormView(vehiculo: vehiculo),
    );
  }
}

class _VehiculoFormView extends StatefulWidget {
  const _VehiculoFormView({this.vehiculo});

  final Vehiculo? vehiculo;

  @override
  State<_VehiculoFormView> createState() => _VehiculoFormViewState();
}

class _VehiculoFormViewState extends State<_VehiculoFormView> {
  late final TextEditingController _placa = TextEditingController(
    text: widget.vehiculo?.placa,
  );
  late final TextEditingController _capacidad = TextEditingController(
    text: widget.vehiculo?.capacidadCarga.toString(),
  );
  late final TextEditingController _rendimiento = TextEditingController(
    text: widget.vehiculo?.rendimientoKmGalon.toString(),
  );
  late TipoVehiculo _tipo = widget.vehiculo?.tipo ?? TipoVehiculo.dobleTroque;

  bool get _esEdicion => widget.vehiculo != null;

  @override
  void dispose() {
    _placa.dispose();
    _capacidad.dispose();
    _rendimiento.dispose();
    super.dispose();
  }

  void _guardar(BuildContext context) {
    final double? capacidad = double.tryParse(_capacidad.text.trim());
    final double? rendimiento = double.tryParse(_rendimiento.text.trim());
    if (_placa.text.trim().isEmpty ||
        capacidad == null ||
        rendimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos con valores válidos.'),
        ),
      );
      return;
    }

    context.read<VehiculoFormCubit>().guardar(
      idExistente: widget.vehiculo?.id,
      placa: _placa.text,
      tipo: _tipo,
      capacidadCarga: capacidad,
      rendimientoKmGalon: rendimiento,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VehiculoFormCubit, VehiculoFormState>(
      listener: (BuildContext context, VehiculoFormState state) {
        if (state is VehiculoFormExito) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_esEdicion ? 'Editar vehículo' : 'Agregar vehículo'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BlocBuilder<VehiculoFormCubit, VehiculoFormState>(
                builder: (BuildContext context, VehiculoFormState state) {
                  if (state is! VehiculoFormError) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                    child: AppAlert(mensaje: state.mensaje),
                  );
                },
              ),
              AppTextField(
                label: 'Placa',
                controller: _placa,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.x4),
              DropdownButtonFormField<TipoVehiculo>(
                initialValue: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de vehículo',
                ),
                items: TipoVehiculo.values
                    .map(
                      (TipoVehiculo tipo) => DropdownMenuItem<TipoVehiculo>(
                        value: tipo,
                        child: Text(tipo.etiqueta),
                      ),
                    )
                    .toList(),
                onChanged: (TipoVehiculo? nuevo) {
                  if (nuevo != null) setState(() => _tipo = nuevo);
                },
              ),
              const SizedBox(height: AppSpacing.x4),
              AppTextField(
                label: 'Capacidad de carga (toneladas)',
                controller: _capacidad,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.x4),
              AppTextField(
                label: 'Rendimiento (km por galón)',
                controller: _rendimiento,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.x6),
              BlocBuilder<VehiculoFormCubit, VehiculoFormState>(
                builder: (BuildContext context, VehiculoFormState state) {
                  final bool enviando = state is VehiculoFormEnviando;
                  return FilledButton(
                    onPressed: enviando ? null : () => _guardar(context),
                    child: enviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _esEdicion ? 'Guardar cambios' : 'Crear vehículo',
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
