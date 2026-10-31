import 'dart:convert';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/guide_remote_datasource.dart';
import 'package:app_novik/data/models/guide_model.dart';
import 'package:app_novik/domain/entities/client_form_entity.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart';
import 'package:app_novik/domain/entities/guide_form_entity.dart';
import 'package:app_novik/domain/entities/other_document_entity.dart';
import 'package:app_novik/domain/entities/sale_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/client_repository.dart';
import 'package:app_novik/domain/repositories/guide_repository.dart';
import 'package:app_novik/domain/usecases/client_usecases.dart';
import 'package:app_novik/domain/usecases/guide_usecases.dart';
import 'package:app_novik/presentation/providers/clients_provider.dart';
import 'package:app_novik/presentation/providers/guide_provider.dart';
import 'package:app_novik/presentation/widgets/guide_form.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------- datos de ejemplo

/// Forma de `GET /ventas/{id}` (solo lo que usa la guía).
Map<String, dynamic> _sale({bool guia = false, bool guiaEnBoleta = false, bool conDireccion = true}) => {
      'id': 30,
      'guia': guia ? {'id': 1, 'sale_id': 30} : null,
      'boleta': {
        'id': 8,
        'tipo': 'b',
        'guia': guiaEnBoleta ? {'id': 2, 'boleta_id': 8} : null,
      },
      'client': {
        'id': 7,
        'razon_social': 'ACME SAC',
        'department_id': '15',
        'province_id': '1501',
        'district_id': '150101',
        'direccion': 'AV. PRINCIPAL 100',
        'adresses': conDireccion
            ? [
                {
                  'predeterminado': false,
                  'department_id': '04',
                  'province_id': '0401',
                  'district_id': '040101',
                  'direccion': 'OTRA 1',
                },
                {
                  'predeterminado': true,
                  'department_id': '04',
                  'province_id': '0401',
                  'district_id': '040102',
                  'direccion': 'CALLE SOL 45',
                },
              ]
            : [],
      },
    };

GuideFormEntity _form({
  GuideKind tipo = GuideKind.privada,
  int? boletaId = 8,
  int? saleId,
  double? peso = 12.5,
}) =>
    GuideFormEntity(
      boletaId: boletaId,
      saleId: saleId,
      tipo: tipo,
      codTraslado: '01',
      fechaEmision: DateTime(2026, 10, 30),
      fechaTraslado: DateTime(2026, 10, 31),
      pesoTotal: peso,
      docTransportista: '20123456789',
      razonSocialTransportista: 'TRANSPORTES SAC',
      matricula: tipo == GuideKind.publica ? 'mtc-123' : null,
      dniChofer: tipo == GuideKind.privada ? '12-345678' : null,
      placaChofer: tipo == GuideKind.privada ? 'abc-123' : null,
      nombreChofer: tipo == GuideKind.privada ? 'JUAN' : null,
      apellidoChofer: tipo == GuideKind.privada ? 'PÉREZ' : null,
      licenciaChofer: tipo == GuideKind.privada ? 'q-12345' : null,
      ubigeoSalida: '150101',
      direccionSalida: 'AV. LIMA 123',
      ubigeoLlegada: '040102',
      direccionLlegada: 'CALLE SOL 45',
      observaciones: ' Frágil ',
    );

// ---------------------------------------------------------------- repositorios falsos

class _FakeGuideRepo implements GuideRepository {
  GuideDefaultsEntity defaults = const GuideDefaultsEntity(
    departmentId: '15',
    provinceId: '1501',
    districtId: '150101',
    direccion: 'JR. LOS ALAMOS 456',
  );
  Either<Failure, GuideDefaultsEntity>? defaultsResult;
  final List<int> defaultsCalls = [];
  final List<String> driverCalls = [];
  final List<GuideFormEntity> created = [];
  Either<Failure, OtherDocumentEntity>? createResult;

  @override
  Future<Either<Failure, GuideDefaultsEntity>> getDefaults(int saleId) async {
    defaultsCalls.add(saleId);
    return defaultsResult ?? Either.right(defaults);
  }

  @override
  Future<Either<Failure, DriverEntity?>> findDriver(String dni) async {
    driverCalls.add(dni);
    return Either.right(const DriverEntity(name: 'JUAN', lastName: 'PÉREZ', license: 'Q12345'));
  }

  @override
  Future<Either<Failure, OtherDocumentEntity>> createGuide(GuideFormEntity form) async {
    created.add(form);
    return createResult ??
        Either.right(const OtherDocumentEntity(kind: OtherDocumentKind.guia, id: 5, numero: 'TG01-0003'));
  }
}

class _FakeClientRepo implements ClientRepository {
  final List<String> calls = [];

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDepartments() async => Either.right(const [
        UbigeoItemEntity(id: '04', name: 'AREQUIPA'),
        UbigeoItemEntity(id: '15', name: 'LIMA'),
      ]);

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getProvinces(String departmentId) async =>
      Either.right([UbigeoItemEntity(id: '${departmentId}01', name: 'PROVINCIA $departmentId')]);

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDistricts(String provinceId) async =>
      Either.right([UbigeoItemEntity(id: '${provinceId}01', name: 'DISTRITO $provinceId')]);

  @override
  Future<Either<Failure, DocumentLookupEntity>> lookupDocument({
    required String tipo,
    required String number,
  }) async {
    calls.add('lookup:$tipo:$number');
    if (tipo == 'e') {
      return Either.right(const DocumentLookupEntity(
        tipo: 'e',
        razonSocial: 'TRANSPORTES DEL SUR SAC',
        direccion: 'AV. UNO 123',
        ubigeo: '150101',
      ));
    }
    return Either.right(const DocumentLookupEntity(tipo: 'p', name: 'JUAN', lastName: 'PEREZ'));
  }

  @override
  Future<Either<Failure, ClientEntity>> createClient({
    required int companyId,
    int? executiveId,
    required NewClientFormEntity form,
  }) async =>
      throw UnimplementedError();
}

SessionContextEntity _session() => SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: const CompanyEntity(id: 7, razonSocial: 'ACME', ruc: '20999999999'),
      modules: const [],
      permissions: const {},
      roles: const [],
      warehouses: const [],
    );

GuideProvider _provider(_FakeGuideRepo repo) => GuideProvider(
      getDefaultsUseCase: GetGuideDefaultsUseCase(repository: repo),
      findDriverUseCase: FindDriverUseCase(repository: repo),
      createGuideUseCase: CreateGuideUseCase(repository: repo),
    )..syncSession(_session());

const _doc = DocumentEntity(
  id: 30,
  kind: DocumentKind.venta,
  numero: 'B001-00077',
  comprobante: 'Boleta',
  boleta: DocumentBoletaEntity(id: 8, tipo: 'b'),
);

const _localDoc = DocumentEntity(
  id: 31,
  kind: DocumentKind.venta,
  numero: 'V001-0005',
  comprobante: 'Nota de venta',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('guideDefaultsFromJson', () {
    test('usa la dirección predeterminada del cliente', () {
      final d = guideDefaultsFromJson(_sale());

      expect(d.departmentId, '04');
      expect(d.provinceId, '0401');
      expect(d.districtId, '040102');
      expect(d.direccion, 'CALLE SOL 45');
      expect(d.tieneUbigeo, isTrue);
      expect(d.tieneGuia, isFalse);
    });

    test('sin dirección predeterminada usa la principal del cliente', () {
      final d = guideDefaultsFromJson(_sale(conDireccion: false));

      expect(d.districtId, '150101');
      expect(d.direccion, 'AV. PRINCIPAL 100');
    });

    test('los códigos numéricos recuperan sus ceros', () {
      final d = guideDefaultsFromJson({
        'client': {'department_id': 4, 'province_id': 401, 'district_id': 40101, 'direccion': 'X'},
      });

      expect((d.departmentId, d.provinceId, d.districtId), ('04', '0401', '040101'));
    });

    test('detecta que la venta o su boleta ya tienen guía', () {
      expect(guideDefaultsFromJson(_sale(guia: true)).tieneGuia, isTrue);
      expect(guideDefaultsFromJson(_sale(guiaEnBoleta: true)).tieneGuia, isTrue);
      expect(guideDefaultsFromJson(_sale()).tieneGuia, isFalse);
    });

    test('sin cliente no hay ubigeo', () {
      final d = guideDefaultsFromJson({'id': 1});

      expect(d.tieneUbigeo, isFalse);
      expect(d.direccion, isNull);
    });

    test('lee el chofer', () {
      final d = driverFromJson({'name': 'JUAN', 'last_name': 'PÉREZ', 'license': 'Q12345'});

      expect((d.name, d.lastName, d.license), ('JUAN', 'PÉREZ', 'Q12345'));
    });
  });

  group('guideToJson', () {
    test('una guía privada lleva chofer y placa, sin registro MTC; todo normalizado como la web', () {
      final body = guideToJson(_form());

      expect(body['boleta_id'], 8);
      expect(body.containsKey('sale_id'), isFalse);
      expect(body['tipo_guia'], '02');
      expect(body['cod_traslado'], '01');
      expect(body['fecha_emision'], '2026-10-30');
      expect(body['fecha_traslado'], '2026-10-31');
      expect(body['peso_total'], 12.5);
      expect(body['doc_transportista'], '20123456789');
      expect(body['rzn_social_transportista'], 'TRANSPORTES SAC');
      expect(body['dni_chofer'], '12345678'); // sin guiones
      expect(body['placa_chofer'], 'ABC123'); // sin guiones y en mayúsculas
      expect(body['licencia_chofer'], 'Q12345');
      expect(body['nombre_chofer'], 'JUAN');
      expect(body['apellido_chofer'], 'PÉREZ');
      expect(body.containsKey('matricula_transportista'), isFalse);
      expect(body['ubigeo_salida'], '150101');
      expect(body['direccion_salida'], 'AV. LIMA 123');
      expect(body['ubigeo_llegada'], '040102');
      expect(body['direccion_llegada'], 'CALLE SOL 45');
      expect(body['observaciones'], 'Frágil');
    });

    test('una guía pública lleva el registro MTC y no los datos del chofer', () {
      final body = guideToJson(_form(tipo: GuideKind.publica));

      expect(body['tipo_guia'], '01');
      expect(body['matricula_transportista'], 'MTC123');
      for (final key in ['dni_chofer', 'placa_chofer', 'nombre_chofer', 'apellido_chofer', 'licencia_chofer']) {
        expect(body.containsKey(key), isFalse, reason: key);
      }
    });

    test('una venta sin comprobante electrónico va por sale_id', () {
      final body = guideToJson(_form(boletaId: null, saleId: 31));

      expect(body['sale_id'], 31);
      expect(body.containsKey('boleta_id'), isFalse);
    });

    test('sin observaciones no se envían', () {
      final body = guideToJson(GuideFormEntity(
        boletaId: 8,
        pesoTotal: 1,
        docTransportista: '1',
        razonSocialTransportista: 'X',
        observaciones: '   ',
      ));

      expect(body.containsKey('observaciones'), isFalse);
    });
  });

  group('CreateGuideUseCase.validate', () {
    test('una guía completa es válida', () {
      expect(CreateGuideUseCase.validate(_form()), isNull);
      expect(CreateGuideUseCase.validate(_form(tipo: GuideKind.publica)), isNull);
    });

    test('pide una boleta o una venta', () {
      expect(
        CreateGuideUseCase.validate(_form(boletaId: null)),
        'Debe seleccionar una boleta o una venta',
      );
    });

    test('el peso debe ser mayor a 0', () {
      expect(CreateGuideUseCase.validate(_form(peso: null)), 'El peso total debe ser mayor a 0');
      expect(CreateGuideUseCase.validate(_form(peso: 0)), 'El peso total debe ser mayor a 0');
    });

    test('pide el transportista', () {
      expect(
        CreateGuideUseCase.validate(const GuideFormEntity(boletaId: 1, pesoTotal: 1)),
        'Escribe el DNI o RUC del transportista',
      );
      expect(
        CreateGuideUseCase.validate(
          const GuideFormEntity(boletaId: 1, pesoTotal: 1, docTransportista: '2012'),
        ),
        'Escribe la razón social del transportista',
      );
    });

    test('la guía pública exige el registro MTC', () {
      final f = GuideFormEntity(
        boletaId: 1,
        tipo: GuideKind.publica,
        pesoTotal: 1,
        docTransportista: '1',
        razonSocialTransportista: 'X',
        ubigeoSalida: '150101',
        direccionSalida: 'A',
        ubigeoLlegada: '150101',
        direccionLlegada: 'B',
      );

      expect(CreateGuideUseCase.validate(f), 'Escribe el registro MTC del transportista');
    });

    test('la guía privada exige chofer, placa y licencia', () {
      GuideFormEntity privada({String? dni = '1', String? placa = 'A', String? nombre = 'J', String? apellido = 'P', String? licencia = 'L'}) =>
          GuideFormEntity(
            boletaId: 1,
            pesoTotal: 1,
            docTransportista: '1',
            razonSocialTransportista: 'X',
            dniChofer: dni,
            placaChofer: placa,
            nombreChofer: nombre,
            apellidoChofer: apellido,
            licenciaChofer: licencia,
            ubigeoSalida: '150101',
            direccionSalida: 'A',
            ubigeoLlegada: '150101',
            direccionLlegada: 'B',
          );

      expect(CreateGuideUseCase.validate(privada(dni: '')), 'Escribe el DNI del chofer');
      expect(CreateGuideUseCase.validate(privada(placa: null)), 'Escribe la placa del vehículo');
      expect(CreateGuideUseCase.validate(privada(nombre: ' ')), 'Escribe el nombre del chofer');
      expect(CreateGuideUseCase.validate(privada(apellido: '')), 'Escribe el apellido del chofer');
      expect(CreateGuideUseCase.validate(privada(licencia: '')), 'Escribe la licencia de conducir');
      expect(CreateGuideUseCase.validate(privada()), isNull);
    });

    test('exige el ubigeo y la dirección de salida y de llegada', () {
      GuideFormEntity f({String us = '150101', String ds = 'A', String ul = '150101', String dl = 'B'}) =>
          GuideFormEntity(
            boletaId: 1,
            pesoTotal: 1,
            docTransportista: '1',
            razonSocialTransportista: 'X',
            dniChofer: '1',
            placaChofer: 'A',
            nombreChofer: 'J',
            apellidoChofer: 'P',
            licenciaChofer: 'L',
            ubigeoSalida: us,
            direccionSalida: ds,
            ubigeoLlegada: ul,
            direccionLlegada: dl,
          );

      expect(CreateGuideUseCase.validate(f(us: '')), contains('salida'));
      expect(CreateGuideUseCase.validate(f(ds: ' ')), 'Escribe la dirección de salida');
      expect(CreateGuideUseCase.validate(f(ul: '')), contains('llegada'));
      expect(CreateGuideUseCase.validate(f(dl: '')), 'Escribe la dirección de llegada');
    });

    test('las observaciones admiten hasta 500 caracteres', () {
      final long = GuideFormEntity(
        boletaId: 8,
        pesoTotal: 1,
        docTransportista: '1',
        razonSocialTransportista: 'X',
        dniChofer: '1',
        placaChofer: 'A',
        nombreChofer: 'J',
        apellidoChofer: 'P',
        licenciaChofer: 'L',
        ubigeoSalida: '150101',
        direccionSalida: 'A',
        ubigeoLlegada: '150101',
        direccionLlegada: 'B',
        observaciones: 'x' * 501,
      );

      expect(CreateGuideUseCase.validate(long), 'Las observaciones admiten hasta 500 caracteres');
    });

    test('una guía incompleta no llega a la API', () async {
      final repo = _FakeGuideRepo();

      final result = await CreateGuideUseCase(repository: repo)(const GuideFormEntity(boletaId: 1));

      expect(result.left, isA<ValidationFailure>());
      expect(repo.created, isEmpty);
    });
  });

  group('FindDriverUseCase', () {
    test('solo consulta con un DNI de 8 dígitos (sin guiones)', () async {
      final repo = _FakeGuideRepo();
      final useCase = FindDriverUseCase(repository: repo);

      expect((await useCase('1234567')).right, isNull);
      expect(repo.driverCalls, isEmpty);

      final found = await useCase('1234-5678');
      expect(found.right!.name, 'JUAN');
      expect(repo.driverCalls, ['12345678']);
    });
  });

  group('datos', () {
    late List<http.BaseRequest> requests;
    String body = '{}';
    int status = 200;
    late GuideRemoteDataSourceImpl dataSource;

    setUp(() {
      requests = [];
      body = '{}';
      status = 200;
      dataSource = GuideRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(body, status, headers: {'content-type': 'application/json'});
        }),
      );
    });

    test('las condiciones de la venta salen de GET /ventas/{id}', () async {
      body = jsonEncode(_sale());

      final d = await dataSource.getDefaults('tok', 30);

      expect(requests.last.method, 'GET');
      expect(requests.last.url.path, endsWith('/ventas/30'));
      expect(requests.last.headers['Authorization'], 'Bearer tok');
      expect(d.direccion, 'CALLE SOL 45');
    });

    test('la venta puede venir dentro de data', () async {
      body = jsonEncode({'success': true, 'data': _sale(guia: true)});

      expect((await dataSource.getDefaults('tok', 30)).tieneGuia, isTrue);
    });

    test('un chofer registrado trae sus datos', () async {
      body = jsonEncode({'name': 'JUAN', 'last_name': 'PÉREZ', 'license': 'Q1'});

      final d = await dataSource.findDriver('tok', '12345678');

      expect(requests.last.url.path, endsWith('/conductores/12345678'));
      expect(d!.license, 'Q1');
    });

    test('un chofer que no existe no es un error', () async {
      status = 404;
      body = jsonEncode({'message': 'No encontrado'});

      expect(await dataSource.findDriver('tok', '12345678'), isNull);
    });

    test('crear la guía hace POST /guia-remision con el cuerpo de la web', () async {
      body = jsonEncode({'id': 5, 'serie': 1, 'numero': 3, 'created_at': '2026-10-31T10:00:00.000000Z'});

      final created = await dataSource.createGuide('tok', _form());

      expect(requests.last.method, 'POST');
      expect(requests.last.url.path, endsWith('/guia-remision'));
      final sent = jsonDecode((requests.last as http.Request).body) as Map<String, dynamic>;
      expect(sent['boleta_id'], 8);
      expect(sent['tipo_guia'], '02');
      expect(sent['placa_chofer'], 'ABC123');
      expect(created.numero, 'TG01-0003');
      expect(created.kind, OtherDocumentKind.guia);
    });

    test('el rechazo del servidor llega con su mensaje', () async {
      status = 422;
      body = jsonEncode({
        'error': {
          'ubigeo_salida': ['The selected ubigeo salida is invalid.'],
        },
      });

      expect(
        () => dataSource.createGuide('tok', _form()),
        throwsA(predicate((e) => '$e'.contains('ubigeo salida is invalid'))),
      );
    });
  });

  group('GuideProvider', () {
    test('conoce el RUC de la empresa y crea la guía', () async {
      final repo = _FakeGuideRepo();
      final p = _provider(repo);

      final result = await p.create(_form());

      expect(p.companyRuc, '20999999999');
      expect(result.right.numero, 'TG01-0003');
      expect(repo.created.single.boletaId, 8);
      expect(p.creating, isFalse);
    });

    test('un error del servidor se devuelve y no deja la creación trabada', () async {
      final repo = _FakeGuideRepo()..createResult = Either.left(const ServerFailure('Error del servidor'));
      final p = _provider(repo);

      final result = await p.create(_form());

      expect(result.left.message, 'Error del servidor');
      expect(p.creating, isFalse);
    });
  });

  group('Formulario de la guía', () {
    Future<(_FakeGuideRepo, _FakeClientRepo, ValueNotifier<OtherDocumentEntity?>)> pump(
      WidgetTester tester, {
      DocumentEntity document = _doc,
      _FakeGuideRepo? guideRepo,
    }) async {
      // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real). La pantalla es
      // alta para que todo el formulario esté dibujado.
      tester.view.physicalSize = const Size(360 * 3, 3200 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = guideRepo ?? _FakeGuideRepo();
      final clientRepo = _FakeClientRepo();
      final guide = _provider(repo);
      final clients = ClientsProvider(
        getDepartmentsUseCase: GetDepartmentsUseCase(repository: clientRepo),
        getProvincesUseCase: GetProvincesUseCase(repository: clientRepo),
        getDistrictsUseCase: GetDistrictsUseCase(repository: clientRepo),
        lookupDocumentUseCase: LookupDocumentUseCase(repository: clientRepo),
        createClientUseCase: CreateClientUseCase(repository: clientRepo),
      )..syncSession(_session());
      final created = ValueNotifier<OtherDocumentEntity?>(null);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GuideProvider>.value(value: guide),
            ChangeNotifierProvider<ClientsProvider>.value(value: clients),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    created.value = await showGuideForm(
                      context,
                      document: document,
                      now: () => DateTime(2026, 10, 31, 9),
                    );
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return (repo, clientRepo, created);
    }

    Finder inForm(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);
    Finder field(String label) => inForm(find.widgetWithText(TextFormField, label));

    testWidgets('abre con los campos de la web, la dirección de llegada del cliente y el RUC propio', (tester) async {
      final (repo, _, _) = await pump(tester);

      expect(repo.defaultsCalls, [30]);
      expect(find.text('Guía de remisión'), findsOneWidget);
      expect(find.text('Boleta Nro: B001-00077'), findsOneWidget);
      for (final label in [
        'Tipo de guía *',
        'Motivo de traslado *',
        'Fecha de emisión',
        'Fecha de traslado',
        'Peso total (KG) *',
        'DNI / RUC *',
        'Razón social *',
        'DNI del chofer *',
        'Placa del vehículo *',
        'Nombre(s) del chofer *',
        'Apellido(s) del chofer *',
        'Licencia de conducir *',
        'Dirección de salida *',
        'Dirección de llegada *',
      ]) {
        expect(inForm(find.text(label)), findsWidgets, reason: label);
      }
      // Guía privada por defecto: no hay registro MTC.
      expect(inForm(find.text('Registro MTC *')), findsNothing);
      // Llegada = dirección del cliente; el RUC del transportista es el de la empresa.
      expect(tester.widget<TextFormField>(field('Dirección de llegada *')).controller!.text, 'JR. LOS ALAMOS 456');
      expect(tester.widget<TextFormField>(field('DNI / RUC *')).controller!.text, '20999999999');
      expect(inForm(find.textContaining('31/10/2026')), findsNWidgets(2)); // las dos fechas, hoy
    });

    testWidgets('una guía pública pide el registro MTC en lugar del chofer', (tester) async {
      await pump(tester);

      await tester.tap(inForm(find.text('Privada')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pública').last);
      await tester.pumpAndSettle();

      expect(inForm(find.text('Registro MTC *')), findsOneWidget);
      expect(inForm(find.text('DNI del chofer *')), findsNothing);
      expect(inForm(find.text('Placa del vehículo *')), findsNothing);
    });

    testWidgets('una venta que ya tiene guía lo dice y no deja crear otra', (tester) async {
      final repo = _FakeGuideRepo()..defaults = const GuideDefaultsEntity(tieneGuia: true);
      await pump(tester, guideRepo: repo);

      expect(inForm(find.text('Este documento ya tiene una guía de remisión.')), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear')).onPressed,
        isNull,
      );
    });

    testWidgets('sin boleta (guía local) se crea sobre la venta', (tester) async {
      final repo = _FakeGuideRepo();
      await pump(tester, document: _localDoc, guideRepo: repo);

      expect(repo.defaultsCalls, [31]);
      expect(find.text('Nota de venta Nro: V001-0005'), findsOneWidget);
    });

    testWidgets('el DNI de un chofer registrado trae su nombre, apellido y licencia', (tester) async {
      final (repo, _, _) = await pump(tester);

      await tester.ensureVisible(field('DNI del chofer *'));
      await tester.enterText(field('DNI del chofer *'), '12345678');
      await tester.pumpAndSettle();

      expect(repo.driverCalls, ['12345678']);
      expect(tester.widget<TextFormField>(field('Nombre(s) del chofer *')).controller!.text, 'JUAN');
      expect(tester.widget<TextFormField>(field('Apellido(s) del chofer *')).controller!.text, 'PÉREZ');
      expect(tester.widget<TextFormField>(field('Licencia de conducir *')).controller!.text, 'Q12345');
    });

    testWidgets('la lupa trae al transportista y su dirección de salida con su ubigeo', (tester) async {
      final (_, clients, _) = await pump(tester);

      await tester.ensureVisible(field('DNI / RUC *'));
      await tester.enterText(field('DNI / RUC *'), '20111111111');
      await tester.tap(inForm(find.byTooltip('Buscar transportista')));
      await tester.pumpAndSettle();

      expect(clients.calls, ['lookup:e:20111111111']);
      expect(tester.widget<TextFormField>(field('Razón social *')).controller!.text, 'TRANSPORTES DEL SUR SAC');
      expect(tester.widget<TextFormField>(field('Dirección de salida *')).controller!.text, 'AV. UNO 123');
    });

    testWidgets('con un DNI trae nombre y apellido como razón social', (tester) async {
      final (_, clients, _) = await pump(tester);

      await tester.ensureVisible(field('DNI / RUC *'));
      await tester.enterText(field('DNI / RUC *'), '12345678');
      await tester.tap(inForm(find.byTooltip('Buscar transportista')));
      await tester.pumpAndSettle();

      expect(clients.calls, ['lookup:p:12345678']);
      expect(tester.widget<TextFormField>(field('Razón social *')).controller!.text, 'JUAN PEREZ');
    });

    testWidgets('un número que no es DNI ni RUC avisa antes de consultar', (tester) async {
      final (_, clients, _) = await pump(tester);

      await tester.ensureVisible(field('DNI / RUC *'));
      await tester.enterText(field('DNI / RUC *'), '12345');
      await tester.tap(inForm(find.byTooltip('Buscar transportista')));
      await tester.pumpAndSettle();

      expect(inForm(find.text('El DNI debe tener 8 dígitos y el RUC 11')), findsOneWidget);
      expect(clients.calls, isEmpty);
    });

    Future<void> choose(WidgetTester tester, String label, String option) async {
      final dropdown = inForm(find.text(label)).first;
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    testWidgets('crear manda la guía con los datos llenados y cierra el modal', (tester) async {
      final (repo, _, created) = await pump(tester);

      await tester.enterText(field('Peso total (KG) *'), '12,5');
      await tester.enterText(field('Razón social *'), 'TRANSPORTES SAC');
      await tester.ensureVisible(field('DNI del chofer *'));
      await tester.enterText(field('DNI del chofer *'), '12345678');
      await tester.pumpAndSettle();
      await tester.enterText(field('Placa del vehículo *'), 'abc-123');
      await choose(tester, 'Departamento *', 'LIMA'); // la salida (primer ubigeo)
      await choose(tester, 'Provincia *', 'PROVINCIA 15');
      await choose(tester, 'Distrito *', 'DISTRITO 1501');
      await tester.ensureVisible(field('Dirección de salida *'));
      await tester.enterText(field('Dirección de salida *'), 'AV. LIMA 123');

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear'));
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      final sent = repo.created.single;
      expect(sent.boletaId, 8);
      expect(sent.saleId, isNull);
      expect(sent.tipo, GuideKind.privada);
      expect(sent.codTraslado, '01');
      expect(sent.pesoTotal, 12.5);
      expect(sent.docTransportista, '20999999999');
      expect(sent.razonSocialTransportista, 'TRANSPORTES SAC');
      expect(sent.dniChofer, '12345678');
      expect(sent.placaChofer, 'abc-123');
      expect(sent.nombreChofer, 'JUAN'); // del chofer registrado
      expect(sent.ubigeoSalida, '150101');
      expect(sent.direccionSalida, 'AV. LIMA 123');
      expect(sent.ubigeoLlegada, '150101'); // la del cliente
      expect(sent.direccionLlegada, 'JR. LOS ALAMOS 456');
      expect(sent.fechaEmision, DateTime(2026, 10, 31));
      expect(created.value!.numero, 'TG01-0003');
      expect(find.text('Guía de remisión'), findsNothing); // se cerró
    });

    testWidgets('con campos sin llenar no se envía nada', (tester) async {
      final (repo, _, created) = await pump(tester);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear'));
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      expect(repo.created, isEmpty);
      expect(created.value, isNull);
      expect(inForm(find.text('Escribe el peso total')), findsOneWidget);
      expect(inForm(find.text('Escribe la razón social')), findsOneWidget);
    });

    testWidgets('si el servidor rechaza la guía el modal sigue abierto con el motivo', (tester) async {
      final repo = _FakeGuideRepo()..createResult = Either.left(const ValidationFailure('SUNAT rechazó la guía'));
      final (_, _, created) = await pump(tester, guideRepo: repo);

      await tester.enterText(field('Peso total (KG) *'), '3');
      await tester.enterText(field('Razón social *'), 'TRANSPORTES SAC');
      await tester.ensureVisible(field('DNI del chofer *'));
      await tester.enterText(field('DNI del chofer *'), '12345678');
      await tester.pumpAndSettle();
      await tester.enterText(field('Placa del vehículo *'), 'ABC123');
      await choose(tester, 'Departamento *', 'LIMA');
      await choose(tester, 'Provincia *', 'PROVINCIA 15');
      await choose(tester, 'Distrito *', 'DISTRITO 1501');
      await tester.ensureVisible(field('Dirección de salida *'));
      await tester.enterText(field('Dirección de salida *'), 'AV. LIMA 123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear'));
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      expect(find.text('SUNAT rechazó la guía'), findsOneWidget);
      expect(find.text('Guía de remisión'), findsOneWidget);
      expect(created.value, isNull);
    });
  });
}
