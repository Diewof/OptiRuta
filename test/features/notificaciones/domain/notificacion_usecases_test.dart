import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/notificaciones/domain/entities/notificacion.dart';
import 'package:optiruta/features/notificaciones/domain/repositories/notificacion_repository.dart';
import 'package:optiruta/features/notificaciones/domain/usecases/listar_notificaciones_use_case.dart';
import 'package:optiruta/features/notificaciones/domain/usecases/marcar_notificacion_leida_use_case.dart';
import 'package:optiruta/features/notificaciones/domain/usecases/marcar_todas_notificaciones_leidas_use_case.dart';

class _MockRepo extends Mock implements NotificacionRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  test('ListarNotificacionesUseCase: delega en el repositorio', () async {
    when(() => repo.listar(pagina: 0, tamano: 20)).thenAnswer(
      (_) async => const PaginaNotificaciones(
        notificaciones: <Notificacion>[],
        hayMas: false,
      ),
    );

    final caso = ListarNotificacionesUseCase(repo);
    await caso(pagina: 0);

    verify(() => repo.listar(pagina: 0, tamano: 20)).called(1);
  });

  test('MarcarNotificacionLeidaUseCase: delega en el repositorio', () async {
    when(() => repo.marcarLeida('n-1')).thenAnswer((_) async {});

    final caso = MarcarNotificacionLeidaUseCase(repo);
    await caso('n-1');

    verify(() => repo.marcarLeida('n-1')).called(1);
  });

  test(
    'MarcarTodasNotificacionesLeidasUseCase: delega en el repositorio',
    () async {
      when(() => repo.marcarTodasLeidas()).thenAnswer((_) async {});

      final caso = MarcarTodasNotificacionesLeidasUseCase(repo);
      await caso();

      verify(() => repo.marcarTodasLeidas()).called(1);
    },
  );
}
