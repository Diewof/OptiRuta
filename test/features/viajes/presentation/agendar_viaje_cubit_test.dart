import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:optiruta/features/viajes/domain/entities/lugar.dart';
import 'package:optiruta/features/viajes/domain/entities/coordenada.dart';
import 'package:optiruta/core/error/catalogo_failure.dart';
import 'package:optiruta/features/clientes/domain/entities/cliente.dart';
import 'package:optiruta/features/clientes/domain/repositories/cliente_repository.dart';
import 'package:optiruta/features/conductores/domain/entities/conductor.dart';
import 'package:optiruta/features/conductores/domain/entities/tipo_pago.dart';
import 'package:optiruta/features/conductores/domain/repositories/conductor_repository.dart';
import 'package:optiruta/features/vehiculos/domain/entities/tipo_vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/entities/vehiculo.dart';
import 'package:optiruta/features/vehiculos/domain/repositories/vehiculo_repository.dart';
import 'package:optiruta/features/viajes/domain/entities/estado_viaje.dart';
import 'package:optiruta/features/viajes/domain/entities/ruta_estimada.dart';
import 'package:optiruta/features/viajes/domain/entities/viaje.dart';
import 'package:optiruta/features/viajes/domain/repositories/ruta_repository.dart';
import 'package:optiruta/features/viajes/domain/repositories/viaje_repository.dart';
import 'package:optiruta/features/viajes/domain/usecases/crear_viaje_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/estimar_acpm_use_case.dart';
import 'package:optiruta/features/viajes/domain/usecases/estimar_ruta_use_case.dart';
import 'package:optiruta/features/viajes/presentation/bloc/agendar_viaje_cubit.dart';
import 'package:optiruta/features/viajes/presentation/bloc/agendar_viaje_state.dart';

class _MockClienteRepository extends Mock implements ClienteRepository {}

class _MockVehiculoRepository extends Mock implements VehiculoRepository {}

class _MockConductorRepository extends Mock implements ConductorRepository {}

class _MockViajeRepository extends Mock implements ViajeRepository {}

class _MockRutaRepository extends Mock implements RutaRepository {}

const Cliente _clienteActivo = Cliente(
  id: 'cli-1',
  nombre: 'Distribuidora Andina',
  documento: null,
  telefono: null,
  correo: null,
  direccion: null,
  activo: true,
);
const Cliente _clienteInactivo = Cliente(
  id: 'cli-2',
  nombre: 'Cliente Viejo',
  documento: null,
  telefono: null,
  correo: null,
  direccion: null,
  activo: false,
);

const Vehiculo _vehiculoActivo = Vehiculo(
  id: 'veh-1',
  placa: 'UFH664',
  tipo: TipoVehiculo.dobleTroque,
  capacidadCarga: 17,
  rendimientoKmGalon: 9,
  activo: true,
);

Conductor _conductorActivo() => Conductor(
  id: 'con-1',
  usuarioId: 'u-1',
  nombre: 'Camilo Rojas',
  documento: null,
  licencia: 'LIC-1',
  fechaVencimientoLicencia: DateTime(2030),
  tipoPago: TipoPago.comision,
  porcentajeComision: 10,
  sueldoBase: 0,
  activo: true,
);

Viaje _viajeCreado() => Viaje(
  id: 'v-1',
  remision: 'V-001',
  vehiculoId: 'veh-1',
  conductorId: 'con-1',
  clienteId: 'cli-1',
  origen: 'Bogotá',
  destino: 'Barranquilla',
  estado: EstadoViaje.planificado,
  valorFlete: 9200000,
  valorAnticipo: 0,
  saldoPendiente: 9200000,
  fechaCreacion: DateTime.now(),
);

const Lugar _bogota = Lugar(
  nombre: 'Bogotá',
  coordenada: Coordenada(4.711, -74.0721),
);
const Lugar _cali = Lugar(
  nombre: 'Cali',
  coordenada: Coordenada(3.4516, -76.532),
);

void main() {
  late _MockClienteRepository clienteRepo;
  late _MockVehiculoRepository vehiculoRepo;
  late _MockConductorRepository conductorRepo;
  late _MockViajeRepository viajeRepo;
  late _MockRutaRepository rutaRepo;

  AgendarViajeCubit crear() => AgendarViajeCubit(
    clienteRepository: clienteRepo,
    vehiculoRepository: vehiculoRepo,
    conductorRepository: conductorRepo,
    crear: CrearViajeUseCase(viajeRepo),
    estimarRuta: EstimarRutaUseCase(rutaRepo),
    estimarAcpm: EstimarAcpmUseCase(viajeRepo),
  );

  setUpAll(() => registerFallbackValue(_bogota));

  setUp(() {
    clienteRepo = _MockClienteRepository();
    vehiculoRepo = _MockVehiculoRepository();
    conductorRepo = _MockConductorRepository();
    viajeRepo = _MockViajeRepository();
    rutaRepo = _MockRutaRepository();

    when(() => clienteRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaClientes(
        clientes: <Cliente>[_clienteActivo, _clienteInactivo],
        hayMas: false,
      ),
    );
    when(() => vehiculoRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => const PaginaVehiculos(
        vehiculos: <Vehiculo>[_vehiculoActivo],
        hayMas: false,
      ),
    );
    when(() => conductorRepo.listar(pagina: 0, tamano: 100)).thenAnswer(
      (_) async => PaginaConductores(
        conductores: <Conductor>[_conductorActivo()],
        hayMas: false,
      ),
    );
  });

  test('carga catálogos y filtra solo los activos', () async {
    final AgendarViajeCubit cubit = crear();
    addTearDown(cubit.close);

    await Future<void>.delayed(Duration.zero);

    final AgendarViajeState estado = cubit.state;
    expect(estado, isA<AgendarViajeListo>());
    final AgendarViajeListo listo = estado as AgendarViajeListo;
    expect(listo.clientes, <Cliente>[_clienteActivo]);
    expect(listo.vehiculos, <Vehiculo>[_vehiculoActivo]);
  });

  test('errorCatalogos cuando falla la carga inicial', () async {
    clienteRepo = _MockClienteRepository();
    when(() => clienteRepo.listar(pagina: 0, tamano: 100))
        .thenThrow(CatalogoFailure.desconocido());

    final AgendarViajeCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<AgendarViajeErrorCatalogos>());
  });

  test('estimarRuta: éxito guarda la ruta calculada', () async {
    when(
      () => rutaRepo.estimar(
        origen: _bogota.coordenada,
        destino: _cali.coordenada,
      ),
    ).thenAnswer(
      (_) async => const RutaEstimada(distanciaKm: 1012, duracionMin: 1080),
    );

    final AgendarViajeCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.estimarRuta(
      origen: _bogota.coordenada,
      destino: _cali.coordenada,
    );

    final AgendarViajeListo estado = cubit.state as AgendarViajeListo;
    expect(estado.ruta?.distanciaKm, 1012);
    expect(estado.estimandoRuta, isFalse);
  });

  test('estimarRuta: falla guarda el mensaje de error', () async {
    when(
      () => rutaRepo.estimar(
        origen: _bogota.coordenada,
        destino: _cali.coordenada,
      ),
    ).thenThrow(
      const CatalogoFailure(
        CatalogoErrorCodigo.desconocido,
        'No se encontró la ubicación "X".',
      ),
    );

    final AgendarViajeCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.estimarRuta(
      origen: _bogota.coordenada,
      destino: _cali.coordenada,
    );

    final AgendarViajeListo estado = cubit.state as AgendarViajeListo;
    expect(estado.ruta, isNull);
    expect(estado.errorRuta, 'No se encontró la ubicación "X".');
  });

  test('crear: éxito emite AgendarViajeExito', () async {
    when(
      () => viajeRepo.crear(
        remision: any(named: 'remision'),
        vehiculoId: any(named: 'vehiculoId'),
        conductorId: any(named: 'conductorId'),
        clienteId: any(named: 'clienteId'),
        origen: any(named: 'origen'),
        destino: any(named: 'destino'),
        rutaPolilinea: any(named: 'rutaPolilinea'),
        fechaSalidaProgramada: any(named: 'fechaSalidaProgramada'),
        distanciaEstimada: any(named: 'distanciaEstimada'),
        tiempoEstimadoMin: any(named: 'tiempoEstimadoMin'),
        pesoCarga: any(named: 'pesoCarga'),
        valorFlete: any(named: 'valorFlete'),
      ),
    ).thenAnswer((_) async => _viajeCreado());

    final AgendarViajeCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.crear(
      remision: 'V-001',
      vehiculoId: 'veh-1',
      conductorId: 'con-1',
      clienteId: 'cli-1',
      origen: _bogota,
      destino: _cali,
      rutaPolilinea: 'abc',
      fechaSalidaProgramada: DateTime.now(),
      distanciaEstimada: 1012,
      tiempoEstimadoMin: 1080,
      pesoCarga: 28,
      valorFlete: 9200000,
    );

    expect(cubit.state, isA<AgendarViajeExito>());
  });

  test('crear: falla conserva el formulario con errorEnvio', () async {
    when(
      () => viajeRepo.crear(
        remision: any(named: 'remision'),
        vehiculoId: any(named: 'vehiculoId'),
        conductorId: any(named: 'conductorId'),
        clienteId: any(named: 'clienteId'),
        origen: any(named: 'origen'),
        destino: any(named: 'destino'),
        rutaPolilinea: any(named: 'rutaPolilinea'),
        fechaSalidaProgramada: any(named: 'fechaSalidaProgramada'),
        distanciaEstimada: any(named: 'distanciaEstimada'),
        tiempoEstimadoMin: any(named: 'tiempoEstimadoMin'),
        pesoCarga: any(named: 'pesoCarga'),
        valorFlete: any(named: 'valorFlete'),
      ),
    ).thenThrow(
      const CatalogoFailure(
        CatalogoErrorCodigo.desconocido,
        'El vehículo ya tiene un viaje asignado o en curso.',
      ),
    );

    final AgendarViajeCubit cubit = crear();
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.crear(
      remision: 'V-001',
      vehiculoId: 'veh-1',
      conductorId: 'con-1',
      clienteId: 'cli-1',
      origen: _bogota,
      destino: _cali,
      rutaPolilinea: 'abc',
      fechaSalidaProgramada: DateTime.now(),
      distanciaEstimada: 1012,
      tiempoEstimadoMin: 1080,
      pesoCarga: 28,
      valorFlete: 9200000,
    );

    final AgendarViajeListo estado = cubit.state as AgendarViajeListo;
    expect(estado.enviando, isFalse);
    expect(
      estado.errorEnvio,
      'El vehículo ya tiene un viaje asignado o en curso.',
    );
  });
}
