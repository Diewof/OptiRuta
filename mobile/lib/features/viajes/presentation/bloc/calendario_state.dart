import 'package:equatable/equatable.dart';

import '../../domain/entities/viaje_resumen.dart';

sealed class CalendarioState extends Equatable {
  const CalendarioState();

  @override
  List<Object?> get props => <Object?>[];
}

class CalendarioCargando extends CalendarioState {
  const CalendarioCargando();
}

class CalendarioError extends CalendarioState {
  const CalendarioError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class CalendarioListo extends CalendarioState {
  const CalendarioListo({
    required this.mesMostrado,
    required this.diaSeleccionado,
    required this.viajesDelMes,
  });

  final DateTime mesMostrado;
  final DateTime diaSeleccionado;
  final List<ViajeResumen> viajesDelMes;

  List<ViajeResumen> get viajesDelDia => viajesDelMes
      .where(
        (ViajeResumen v) => _mismoDia(v.fechaSalidaProgramada, diaSeleccionado),
      )
      .toList();

  static bool _mismoDia(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  CalendarioListo copiarCon({
    DateTime? mesMostrado,
    DateTime? diaSeleccionado,
    List<ViajeResumen>? viajesDelMes,
  }) {
    return CalendarioListo(
      mesMostrado: mesMostrado ?? this.mesMostrado,
      diaSeleccionado: diaSeleccionado ?? this.diaSeleccionado,
      viajesDelMes: viajesDelMes ?? this.viajesDelMes,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    mesMostrado,
    diaSeleccionado,
    viajesDelMes,
  ];
}
