import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/checklist/domain/entities/checklist.dart';
import 'package:optiruta/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:optiruta/features/checklist/domain/usecases/checklist_use_cases.dart';
import 'package:optiruta/features/checklist/presentation/bloc/checklist_form_cubit.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';

class _MockRepo extends Mock implements ChecklistRepository {}

void main() {
  late _MockRepo repo;

  const ItemChecklist freno = ItemChecklist(
    id: 'i-1',
    codigo: 'FRENO_SERVICIO',
    grupo: 'Frenos',
    nombre: 'Freno de servicio',
    critico: true,
  );
  const ItemChecklist pito = ItemChecklist(
    id: 'i-2',
    codigo: 'PITO',
    grupo: 'Cabina',
    nombre: 'Pito funciona',
    critico: false,
  );

  final ChecklistViaje registrado = ChecklistViaje(
    id: 'k-1',
    viajeId: 'v-1',
    fechaHora: DateTime(2026, 10, 11),
    resultado: ResultadoChecklist.bloqueado,
  );

  setUpAll(() {
    registerFallbackValue(TipoVehiculo.dobleTroque);
  });

  setUp(() {
    repo = _MockRepo();
    when(() => repo.listarItems(any()))
        .thenAnswer((_) async => const <ItemChecklist>[freno, pito]);
  });

  Future<ChecklistFormCubit> crear() async {
    final ChecklistFormCubit cubit = ChecklistFormCubit(
      viajeId: 'v-1',
      tipoVehiculo: TipoVehiculo.dobleTroque,
      listarItems: ListarItemsChecklistUseCase(repo),
      registrar: RegistrarChecklistUseCase(repo),
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  test('carga los ítems del tipo de vehículo, todos en OK', () async {
    final ChecklistFormCubit cubit = await crear();

    expect(cubit.state.cargando, isFalse);
    expect(cubit.state.items, const <ItemChecklist>[freno, pito]);
    expect(cubit.state.fallas, isEmpty);
    verify(() => repo.listarItems(TipoVehiculo.dobleTroque)).called(1);
  });

  test('marcar una falla crítica lo avisa y desmarcarla lo quita', () async {
    final ChecklistFormCubit cubit = await crear();

    cubit.alternarFalla('i-2', falla: true);
    expect(cubit.state.hayFallaCritica, isFalse);

    cubit.alternarFalla('i-1', falla: true);
    expect(cubit.state.hayFallaCritica, isTrue);

    cubit.alternarFalla('i-1', falla: false);
    expect(cubit.state.hayFallaCritica, isFalse);
    expect(cubit.state.fallas.keys, <String>['i-2']);
  });

  test('una falla sin descripción no se envía', () async {
    final ChecklistFormCubit cubit = await crear();
    cubit.alternarFalla('i-1', falla: true);

    final ChecklistViaje? resultado = await cubit.enviar();

    expect(resultado, isNull);
    expect(cubit.state.error, 'Describe cada falla que marcaste.');
    expect(cubit.state.enviando, isFalse);
    verifyNever(
      () => repo.registrar(
        viajeId: any(named: 'viajeId'),
        items: any(named: 'items'),
        respuestas: any(named: 'respuestas'),
        observaciones: any(named: 'observaciones'),
      ),
    );
  });

  test('envía solo las fallas con su descripción', () async {
    when(
      () => repo.registrar(
        viajeId: any(named: 'viajeId'),
        items: any(named: 'items'),
        respuestas: any(named: 'respuestas'),
        observaciones: any(named: 'observaciones'),
      ),
    ).thenAnswer((_) async => registrado);
    final ChecklistFormCubit cubit = await crear();
    cubit.alternarFalla('i-1', falla: true);
    cubit.describirFalla('i-1', 'No frena bien');

    final ChecklistViaje? resultado = await cubit.enviar();

    expect(resultado, registrado);
    verify(
      () => repo.registrar(
        viajeId: 'v-1',
        items: const <ItemChecklist>[freno, pito],
        respuestas: const <RespuestaChecklist>[
          RespuestaChecklist(
            itemId: 'i-1',
            falla: true,
            observacion: 'No frena bien',
          ),
        ],
        observaciones: null,
      ),
    ).called(1);
  });

  test('si el servidor rechaza el checklist deja el mensaje', () async {
    when(
      () => repo.registrar(
        viajeId: any(named: 'viajeId'),
        items: any(named: 'items'),
        respuestas: any(named: 'respuestas'),
        observaciones: any(named: 'observaciones'),
      ),
    ).thenThrow(
      const CatalogoFailure(
        CatalogoErrorCodigo.desconocido,
        'El checklist se llena antes de comenzar un viaje asignado.',
      ),
    );
    final ChecklistFormCubit cubit = await crear();

    final ChecklistViaje? resultado = await cubit.enviar();

    expect(resultado, isNull);
    expect(
      cubit.state.error,
      'El checklist se llena antes de comenzar un viaje asignado.',
    );
  });
}
