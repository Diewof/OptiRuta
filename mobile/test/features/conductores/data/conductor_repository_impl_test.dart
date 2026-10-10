import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/conductores/data/datasources/conductor_remote_data_source.dart';
import 'package:optiruta/features/conductores/data/repositories/conductor_repository_impl.dart';
import 'package:optiruta/features/conductores/domain/entities/conductor.dart';
import 'package:optiruta/features/conductores/domain/entities/tipo_pago.dart';
import 'package:optiruta/features/conductores/domain/entities/usuario_disponible.dart';
import 'package:optiruta/features/conductores/domain/repositories/conductor_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemote extends Mock implements ConductorRemoteDataSource {}

Map<String, dynamic> _fila({
  String usuarioId = 'u-1',
  bool activo = true,
}) => <String, dynamic>{
  'id': 'c-1',
  'usuario_id': usuarioId,
  'licencia': 'LIC-001',
  'fecha_vencimiento_licencia': '2030-01-01',
  'tipo_pago': 'COMISION',
  'porcentaje_comision': 10,
  'sueldo_base': 0,
  'activo': activo,
  'usuario': <String, dynamic>{'nombre': 'Conductor Uno', 'documento': 'CC-1'},
};

void main() {
  late _MockRemote remote;
  late ConductorRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = ConductorRepositoryImpl(remote);
  });

  test('listar: mapea el usuario embebido a nombre/documento', () async {
    when(() => remote.listar(pagina: 0, tamano: 2))
        .thenAnswer((_) async => <Map<String, dynamic>>[_fila()]);

    final PaginaConductores pagina = await repo.listar(pagina: 0, tamano: 2);

    expect(pagina.conductores, hasLength(1));
    expect(pagina.conductores.first.nombre, 'Conductor Uno');
    expect(pagina.conductores.first.tipoPago, TipoPago.comision);
    expect(pagina.hayMas, isFalse);
  });

  test(
    'obtenerPropio: null cuando el administrador no ha creado el perfil',
    () async {
      when(() => remote.obtenerPropio('u-2')).thenAnswer((_) async => null);

      final Conductor? conductor = await repo.obtenerPropio('u-2');

      expect(conductor, isNull);
    },
  );

  test('listarUsuariosDisponibles: mapea las filas de usuario', () async {
    when(() => remote.listarUsuariosDisponibles()).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'u-3',
          'nombre': 'Nuevo Conductor',
          'documento': null,
        },
      ],
    );

    final List<UsuarioDisponible> usuarios = await repo
        .listarUsuariosDisponibles();

    expect(usuarios, hasLength(1));
    expect(usuarios.first.nombre, 'Nuevo Conductor');
  });

  test(
    'crear: usuario ya tiene perfil (23505) se traduce a YA_EXISTE',
    () async {
      when(() => remote.crear(any())).thenThrow(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );

      await expectLater(
        repo.crear(
          usuarioId: 'u-1',
          licencia: 'LIC-002',
          fechaVencimientoLicencia: DateTime(2030),
          tipoPago: TipoPago.fijo,
          porcentajeComision: 0,
          sueldoBase: 1500000,
        ),
        throwsA(
          isA<CatalogoFailure>().having(
            (CatalogoFailure f) => f.codigo,
            'codigo',
            CatalogoErrorCodigo.yaExiste,
          ),
        ),
      );
    },
  );
}
