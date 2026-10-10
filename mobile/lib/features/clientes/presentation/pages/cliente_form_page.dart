import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/cliente.dart';
import '../../domain/repositories/cliente_repository.dart';
import '../../domain/usecases/actualizar_cliente_use_case.dart';
import '../../domain/usecases/crear_cliente_use_case.dart';
import '../bloc/cliente_form_cubit.dart';
import '../bloc/cliente_form_state.dart';

/// Alta/edicion de un cliente. Sin [cliente] => crear.
class ClienteFormPage extends StatelessWidget {
  const ClienteFormPage({this.cliente, super.key});

  final Cliente? cliente;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ClienteFormCubit>(
      create: (BuildContext context) => ClienteFormCubit(
        crear: CrearClienteUseCase(context.read<ClienteRepository>()),
        actualizar: ActualizarClienteUseCase(context.read<ClienteRepository>()),
      ),
      child: _ClienteFormView(cliente: cliente),
    );
  }
}

class _ClienteFormView extends StatefulWidget {
  const _ClienteFormView({this.cliente});

  final Cliente? cliente;

  @override
  State<_ClienteFormView> createState() => _ClienteFormViewState();
}

class _ClienteFormViewState extends State<_ClienteFormView> {
  late final TextEditingController _nombre = TextEditingController(
    text: widget.cliente?.nombre,
  );
  late final TextEditingController _documento = TextEditingController(
    text: widget.cliente?.documento,
  );
  late final TextEditingController _telefono = TextEditingController(
    text: widget.cliente?.telefono,
  );
  late final TextEditingController _correo = TextEditingController(
    text: widget.cliente?.correo,
  );
  late final TextEditingController _direccion = TextEditingController(
    text: widget.cliente?.direccion,
  );

  bool get _esEdicion => widget.cliente != null;

  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    _telefono.dispose();
    _correo.dispose();
    _direccion.dispose();
    super.dispose();
  }

  void _guardar(BuildContext context) {
    if (_nombre.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio.')),
      );
      return;
    }

    context.read<ClienteFormCubit>().guardar(
      idExistente: widget.cliente?.id,
      nombre: _nombre.text,
      documento: _documento.text,
      telefono: _telefono.text,
      correo: _correo.text,
      direccion: _direccion.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClienteFormCubit, ClienteFormState>(
      listener: (BuildContext context, ClienteFormState state) {
        if (state is ClienteFormExito) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_esEdicion ? 'Editar cliente' : 'Agregar cliente'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BlocBuilder<ClienteFormCubit, ClienteFormState>(
                builder: (BuildContext context, ClienteFormState state) {
                  if (state is! ClienteFormError) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                    child: AppAlert(mensaje: state.mensaje),
                  );
                },
              ),
              AppTextField(
                label: 'Nombre',
                controller: _nombre,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.x4),
              AppTextField(
                label: 'NIT o documento',
                controller: _documento,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.x4),
              AppTextField(
                label: 'Teléfono',
                controller: _telefono,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.x4),
              AppTextField(
                label: 'Correo',
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.x4),
              AppTextField(
                label: 'Dirección',
                controller: _direccion,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.x6),
              BlocBuilder<ClienteFormCubit, ClienteFormState>(
                builder: (BuildContext context, ClienteFormState state) {
                  final bool enviando = state is ClienteFormEnviando;
                  return FilledButton(
                    onPressed: enviando ? null : () => _guardar(context),
                    child: enviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _esEdicion ? 'Guardar cambios' : 'Crear cliente',
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
