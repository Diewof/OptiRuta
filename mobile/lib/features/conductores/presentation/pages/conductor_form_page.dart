import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/conductor.dart';
import '../../domain/entities/tipo_pago.dart';
import '../../domain/entities/usuario_disponible.dart';
import '../../domain/repositories/conductor_repository.dart';
import '../../domain/usecases/actualizar_conductor_use_case.dart';
import '../../domain/usecases/crear_conductor_use_case.dart';
import '../../domain/usecases/listar_usuarios_disponibles_use_case.dart';
import '../bloc/conductor_form_cubit.dart';
import '../bloc/conductor_form_state.dart';

/// Alta/edicion de un conductor. Sin [conductor] => crear (requiere elegir
/// un usuario con rol CONDUCTOR que aun no tenga perfil).
class ConductorFormPage extends StatelessWidget {
  const ConductorFormPage({this.conductor, super.key});

  final Conductor? conductor;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConductorFormCubit>(
      create: (BuildContext context) => ConductorFormCubit(
        crear: CrearConductorUseCase(context.read<ConductorRepository>()),
        actualizar: ActualizarConductorUseCase(
          context.read<ConductorRepository>(),
        ),
        listarUsuariosDisponibles: ListarUsuariosDisponiblesUseCase(
          context.read<ConductorRepository>(),
        ),
        esEdicion: conductor != null,
      ),
      child: _ConductorFormView(conductor: conductor),
    );
  }
}

class _ConductorFormView extends StatefulWidget {
  const _ConductorFormView({this.conductor});

  final Conductor? conductor;

  @override
  State<_ConductorFormView> createState() => _ConductorFormViewState();
}

class _ConductorFormViewState extends State<_ConductorFormView> {
  late final TextEditingController _licencia = TextEditingController(
    text: widget.conductor?.licencia,
  );
  late final TextEditingController _porcentajeComision = TextEditingController(
    text: (widget.conductor?.porcentajeComision ?? 10).toString(),
  );
  late final TextEditingController _sueldoBase = TextEditingController(
    text: (widget.conductor?.sueldoBase ?? 0).toString(),
  );
  late DateTime _fechaVencimiento =
      widget.conductor?.fechaVencimientoLicencia ??
      DateTime.now().add(const Duration(days: 365));
  late TipoPago _tipoPago = widget.conductor?.tipoPago ?? TipoPago.comision;
  UsuarioDisponible? _usuarioSeleccionado;

  bool get _esEdicion => widget.conductor != null;

  @override
  void dispose() {
    _licencia.dispose();
    _porcentajeComision.dispose();
    _sueldoBase.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha(BuildContext context) async {
    final DateTime? elegida = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _fechaVencimiento = elegida);
  }

  void _guardar(BuildContext context) {
    final double? porcentaje = double.tryParse(_porcentajeComision.text.trim());
    final double? sueldo = double.tryParse(_sueldoBase.text.trim());
    if (_licencia.text.trim().isEmpty || porcentaje == null || sueldo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos con valores válidos.'),
        ),
      );
      return;
    }

    final ConductorFormCubit cubit = context.read<ConductorFormCubit>();
    if (_esEdicion) {
      cubit.actualizar(
        id: widget.conductor!.id,
        licencia: _licencia.text,
        fechaVencimientoLicencia: _fechaVencimiento,
        tipoPago: _tipoPago,
        porcentajeComision: porcentaje,
        sueldoBase: sueldo,
      );
      return;
    }

    if (_usuarioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el usuario del conductor.')),
      );
      return;
    }
    cubit.crear(
      usuarioId: _usuarioSeleccionado!.id,
      licencia: _licencia.text,
      fechaVencimientoLicencia: _fechaVencimiento,
      tipoPago: _tipoPago,
      porcentajeComision: porcentaje,
      sueldoBase: sueldo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConductorFormCubit, ConductorFormState>(
      listener: (BuildContext context, ConductorFormState state) {
        if (state is ConductorFormExito) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_esEdicion ? 'Editar conductor' : 'Agregar conductor'),
        ),
        body: BlocBuilder<ConductorFormCubit, ConductorFormState>(
          builder: (BuildContext context, ConductorFormState state) {
            if (state is ConductorFormCargandoUsuarios) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (state is ConductorFormError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                      child: AppAlert(mensaje: state.mensaje),
                    ),
                  if (!_esEdicion)
                    _SelectorUsuario(
                      usuarios: state is ConductorFormListo
                          ? state.usuariosDisponibles
                          : const <UsuarioDisponible>[],
                      seleccionado: _usuarioSeleccionado,
                      onChanged: (UsuarioDisponible? usuario) =>
                          setState(() => _usuarioSeleccionado = usuario),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                      child: Text(
                        widget.conductor!.nombre,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.x4),
                  AppTextField(
                    label: 'Número de licencia',
                    controller: _licencia,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  InkWell(
                    onTap: () => _elegirFecha(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Vencimiento de la licencia',
                      ),
                      child: Text(formatearFecha(_fechaVencimiento)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  DropdownButtonFormField<TipoPago>(
                    initialValue: _tipoPago,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de pago',
                    ),
                    items: TipoPago.values
                        .map(
                          (TipoPago tipo) => DropdownMenuItem<TipoPago>(
                            value: tipo,
                            child: Text(tipo.etiqueta),
                          ),
                        )
                        .toList(),
                    onChanged: (TipoPago? nuevo) {
                      if (nuevo != null) setState(() => _tipoPago = nuevo);
                    },
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  AppTextField(
                    label: 'Comisión (%)',
                    controller: _porcentajeComision,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  AppTextField(
                    label: 'Sueldo base',
                    controller: _sueldoBase,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  FilledButton(
                    onPressed: state is ConductorFormEnviando
                        ? null
                        : () => _guardar(context),
                    child: state is ConductorFormEnviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _esEdicion ? 'Guardar cambios' : 'Crear conductor',
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SelectorUsuario extends StatelessWidget {
  const _SelectorUsuario({
    required this.usuarios,
    required this.seleccionado,
    required this.onChanged,
  });

  final List<UsuarioDisponible> usuarios;
  final UsuarioDisponible? seleccionado;
  final ValueChanged<UsuarioDisponible?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (usuarios.isEmpty) {
      return const AppAlert(
        tono: AppAlertTono.advertencia,
        mensaje:
            'No hay usuarios con rol CONDUCTOR pendientes de perfil. '
            'La persona debe registrarse primero en la app.',
      );
    }
    return DropdownButtonFormField<UsuarioDisponible>(
      initialValue: seleccionado,
      decoration: const InputDecoration(
        labelText: 'Usuario (conductor registrado)',
      ),
      items: usuarios
          .map(
            (UsuarioDisponible usuario) => DropdownMenuItem<UsuarioDisponible>(
              value: usuario,
              child: Text(usuario.nombre),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
