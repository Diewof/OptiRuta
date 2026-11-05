import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../vehiculos/domain/entities/tipo_vehiculo.dart';
import '../../domain/entities/checklist.dart';
import '../../domain/usecases/checklist_use_cases.dart';

class ChecklistFormState extends Equatable {
  const ChecklistFormState({
    this.cargando = true,
    this.enviando = false,
    this.items = const <ItemChecklist>[],
    this.fallas = const <String, String>{},
    this.notas = '',
    this.error,
  });

  final bool cargando;
  final bool enviando;
  final List<ItemChecklist> items;

  /// Ítems en falla: id del ítem → descripción escrita (vacía mientras no
  /// la escriba). Un ítem ausente está OK.
  final Map<String, String> fallas;
  final String notas;
  final String? error;

  bool get hayFallaCritica =>
      items.any((ItemChecklist i) => i.critico && fallas.containsKey(i.id));

  ChecklistFormState copiarCon({
    bool? cargando,
    bool? enviando,
    List<ItemChecklist>? items,
    Map<String, String>? fallas,
    String? notas,
    String? error,
    bool limpiarError = false,
  }) {
    return ChecklistFormState(
      cargando: cargando ?? this.cargando,
      enviando: enviando ?? this.enviando,
      items: items ?? this.items,
      fallas: fallas ?? this.fallas,
      notas: notas ?? this.notas,
      error: limpiarError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    cargando,
    enviando,
    items,
    fallas,
    notas,
    error,
  ];
}

// Los parametros con nombre no pueden empezar por "_", asi que los campos
// privados se asignan en la lista de inicializacion (no como initializing formal).
// ignore_for_file: prefer_initializing_formals

/// Llena el checklist pre-viaje del conductor: cada ítem nace OK y solo se
/// marcan las fallas, cada una con su descripción.
class ChecklistFormCubit extends Cubit<ChecklistFormState> {
  ChecklistFormCubit({
    required String viajeId,
    required TipoVehiculo tipoVehiculo,
    required ListarItemsChecklistUseCase listarItems,
    required RegistrarChecklistUseCase registrar,
  }) : _viajeId = viajeId,
       _tipoVehiculo = tipoVehiculo,
       _listarItems = listarItems,
       _registrar = registrar,
       super(const ChecklistFormState()) {
    cargar();
  }

  final String _viajeId;
  final TipoVehiculo _tipoVehiculo;
  final ListarItemsChecklistUseCase _listarItems;
  final RegistrarChecklistUseCase _registrar;

  Future<void> cargar() async {
    emit(state.copiarCon(cargando: true, limpiarError: true));
    try {
      emit(
        state.copiarCon(
          cargando: false,
          items: await _listarItems(_tipoVehiculo),
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(state.copiarCon(cargando: false, error: falla.mensaje));
    }
  }

  void alternarFalla(String itemId, {required bool falla}) {
    final Map<String, String> nuevas = Map<String, String>.of(state.fallas);
    if (falla) {
      nuevas.putIfAbsent(itemId, () => '');
    } else {
      nuevas.remove(itemId);
    }
    emit(state.copiarCon(fallas: nuevas, limpiarError: true));
  }

  void describirFalla(String itemId, String texto) {
    if (!state.fallas.containsKey(itemId)) return;
    emit(
      state.copiarCon(
        fallas: <String, String>{...state.fallas, itemId: texto},
        limpiarError: true,
      ),
    );
  }

  void escribirNotas(String texto) => emit(state.copiarCon(notas: texto));

  /// Envía el checklist; devuelve el registrado o `null` si falló (el motivo
  /// queda en [ChecklistFormState.error]).
  Future<ChecklistViaje?> enviar() async {
    if (state.enviando || state.cargando) return null;
    emit(state.copiarCon(enviando: true, limpiarError: true));
    try {
      final ChecklistViaje checklist = await _registrar(
        viajeId: _viajeId,
        items: state.items,
        respuestas: <RespuestaChecklist>[
          for (final MapEntry<String, String> f in state.fallas.entries)
            RespuestaChecklist(
              itemId: f.key,
              falla: true,
              observacion: f.value,
            ),
        ],
        observaciones: state.notas,
      );
      emit(state.copiarCon(enviando: false));
      return checklist;
    } on ArgumentError {
      emit(
        state.copiarCon(
          enviando: false,
          error: 'Describe cada falla que marcaste.',
        ),
      );
    } on CatalogoFailure catch (falla) {
      emit(state.copiarCon(enviando: false, error: falla.mensaje));
    }
    return null;
  }
}
