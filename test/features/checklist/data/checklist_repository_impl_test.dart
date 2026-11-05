import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/features/checklist/data/checklist_repository_impl.dart';
import 'package:optiruta/features/checklist/domain/entities/checklist.dart';

void main() {
  Map<String, dynamic> fila({Object? autorizacion}) => <String, dynamic>{
    'id': 'k-1',
    'viaje_id': 'v-1',
    'fecha_hora': '2026-10-11T13:00:00Z',
    'resultado': 'BLOQUEADO',
    'observaciones': null,
    'autorizacion': autorizacion,
    'respuestas': <Map<String, dynamic>>[
      <String, dynamic>{
        'estado': 'OK',
        'critico': true,
        'observacion': null,
        'item': <String, dynamic>{'nombre': 'Luces'},
      },
      <String, dynamic>{
        'estado': 'FALLA',
        'critico': true,
        'observacion': 'No frena bien',
        'item': <String, dynamic>{'nombre': 'Freno de servicio'},
      },
    ],
  };

  test('aEntidad conserva solo las fallas, con su descripción', () {
    final ChecklistViaje c = ChecklistRepositoryImpl.aEntidad(fila());

    expect(c.resultado, ResultadoChecklist.bloqueado);
    expect(c.fallas, hasLength(1));
    expect(c.fallas.single.nombre, 'Freno de servicio');
    expect(c.fallas.single.critico, isTrue);
    expect(c.fallas.single.observacion, 'No frena bien');
    expect(c.autorizado, isFalse);
    expect(c.bloqueaSalida, isTrue);
  });

  test('la autorización llega como objeto o como lista', () {
    final ChecklistViaje comoObjeto = ChecklistRepositoryImpl.aEntidad(
      fila(autorizacion: <String, dynamic>{'motivo': 'Revisado'}),
    );
    final ChecklistViaje comoLista = ChecklistRepositoryImpl.aEntidad(
      fila(
        autorizacion: <Map<String, dynamic>>[
          <String, dynamic>{'motivo': 'Revisado'},
        ],
      ),
    );

    expect(comoObjeto.motivoAutorizacion, 'Revisado');
    expect(comoLista.motivoAutorizacion, 'Revisado');
    expect(comoObjeto.bloqueaSalida, isFalse);
  });
}
