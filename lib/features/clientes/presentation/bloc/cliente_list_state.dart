import 'package:equatable/equatable.dart';

import '../../domain/entities/cliente.dart';

sealed class ClienteListState extends Equatable {
  const ClienteListState();

  @override
  List<Object?> get props => <Object?>[];
}

class ClienteListCargando extends ClienteListState {
  const ClienteListCargando();
}

class ClienteListListo extends ClienteListState {
  const ClienteListListo({
    required this.clientes,
    required this.pagina,
    required this.hayMas,
    this.cargandoMas = false,
  });

  final List<Cliente> clientes;
  final int pagina;
  final bool hayMas;
  final bool cargandoMas;

  ClienteListListo copiarCon({
    List<Cliente>? clientes,
    int? pagina,
    bool? hayMas,
    bool? cargandoMas,
  }) {
    return ClienteListListo(
      clientes: clientes ?? this.clientes,
      pagina: pagina ?? this.pagina,
      hayMas: hayMas ?? this.hayMas,
      cargandoMas: cargandoMas ?? this.cargandoMas,
    );
  }

  @override
  List<Object?> get props => <Object?>[clientes, pagina, hayMas, cargandoMas];
}

class ClienteListError extends ClienteListState {
  const ClienteListError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}
