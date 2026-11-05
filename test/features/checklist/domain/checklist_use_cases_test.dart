import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/checklist/domain/entities/checklist.dart';
import 'package:optiruta/features/checklist/domain/repositories/checklist_repository.dart';
import 'package:optiruta/features/checklist/domain/usecases/checklist_use_cases.dart';

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

  setUp(() {
    repo = _MockRepo();
  });

  group('ChecklistViaje', () {
    ChecklistViaje checklist({
      ResultadoChecklist resultado = ResultadoChecklist.bloqueado,
      String? motivo,
      Duration hace = Duration.zero,
    }) => ChecklistViaje(
      id: 'k-1',
      viajeId: 'v-1',
      fechaHora: DateTime(2026, 10, 11, 8).subtract(hace),
      resultado: resultado,
      motivoAutorizacion: motivo,
    );

    test('bloquea la salida solo si es BLOQUEADO y no fue autorizado', () {
      expect(checklist().bloqueaSalida, isTrue);
      expect(checklist(motivo: 'Frenos revisados').bloqueaSalida, isFalse);
      expect(
        checklist(resultado: ResultadoChecklist.conObservaciones).bloqueaSalida,
        isFalse,
      );
    });

    test('vale 12 horas', () {
      final DateTime ahora = DateTime(2026, 10, 11, 8);
      expect(
        checklist(hace: const Duration(hours: 12)).estaVencido(ahora),
        isFalse,
      );
      expect(
        checklist(hace: const Duration(hours: 12, minutes: 1))
            .estaVencido(ahora),
        isTrue,
      );
    });
  });

  group('RegistrarChecklistUseCase', () {
    test('exige descripción en cada falla', () {
      final RegistrarChecklistUseCase caso = RegistrarChecklistUseCase(repo);

      expect(
        () => caso(
          viajeId: 'v-1',
          items: const <ItemChecklist>[freno],
          respuestas: const <RespuestaChecklist>[
            RespuestaChecklist(itemId: 'i-1', falla: true, observacion: '  '),
          ],
        ),
        throwsArgumentError,
      );
      verifyNever(
        () => repo.registrar(
          viajeId: any(named: 'viajeId'),
          items: any(named: 'items'),
          respuestas: any(named: 'respuestas'),
          observaciones: any(named: 'observaciones'),
        ),
      );
    });

    test(
      'envía las observaciones sin espacios o nulas si quedaron vacías',
      () async {
        when(
          () => repo.registrar(
            viajeId: any(named: 'viajeId'),
            items: any(named: 'items'),
            respuestas: any(named: 'respuestas'),
            observaciones: any(named: 'observaciones'),
          ),
        ).thenAnswer(
          (_) async => ChecklistViaje(
            id: 'k-1',
            viajeId: 'v-1',
            fechaHora: DateTime(2026, 10, 11),
            resultado: ResultadoChecklist.aprobado,
          ),
        );
        final RegistrarChecklistUseCase caso = RegistrarChecklistUseCase(repo);

        await caso(
          viajeId: 'v-1',
          items: const <ItemChecklist>[freno],
          respuestas: const <RespuestaChecklist>[],
          observaciones: '  todo bien  ',
        );
        await caso(
          viajeId: 'v-1',
          items: const <ItemChecklist>[freno],
          respuestas: const <RespuestaChecklist>[],
          observaciones: '   ',
        );

        verify(
          () => repo.registrar(
            viajeId: 'v-1',
            items: const <ItemChecklist>[freno],
            respuestas: const <RespuestaChecklist>[],
            observaciones: 'todo bien',
          ),
        ).called(1);
        verify(
          () => repo.registrar(
            viajeId: 'v-1',
            items: const <ItemChecklist>[freno],
            respuestas: const <RespuestaChecklist>[],
            observaciones: null,
          ),
        ).called(1);
      },
    );
  });

  group('AutorizarSalidaChecklistUseCase', () {
    test('exige motivo', () {
      expect(
        () =>
            AutorizarSalidaChecklistUseCase(repo)(viajeId: 'v-1', motivo: '  '),
        throwsArgumentError,
      );
    });

    test('envía el motivo sin espacios sobrantes', () async {
      when(
        () => repo.autorizarSalida(
          viajeId: any(named: 'viajeId'),
          motivo: any(named: 'motivo'),
        ),
      ).thenAnswer((_) async {});

      await AutorizarSalidaChecklistUseCase(repo)(
        viajeId: 'v-1',
        motivo: ' Frenos revisados ',
      );

      verify(
        () => repo.autorizarSalida(viajeId: 'v-1', motivo: 'Frenos revisados'),
      ).called(1);
    });
  });
}
