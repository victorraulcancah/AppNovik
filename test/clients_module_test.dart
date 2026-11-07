import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/core/constants/api_constants.dart';
import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/network/api_request.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/client_record_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/client_record_model.dart';
import 'package:app_novik/domain/entities/client_form_entity.dart';
import 'package:app_novik/domain/entities/client_record_entity.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/sale_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/client_record_repository.dart';
import 'package:app_novik/domain/repositories/client_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/client_record_usecases.dart';
import 'package:app_novik/domain/usecases/client_usecases.dart';
import 'package:app_novik/presentation/pages/clients_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/client_list_provider.dart';
import 'package:app_novik/presentation/providers/clients_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _clientJson({int id = 1, String tipo = 'p'}) => {
      'id': id,
      'codigo': 'CLI-000$id',
      'tipo': tipo,
      'dni_ruc': tipo == 'p' ? '12345678' : '20123456789',
      'name': 'Ana',
      'last_name': 'Pérez',
      'razon_social': tipo == 'e' ? 'ACME SAC' : null,
      'telefono': '+51987654321',
      'email': 'ana@acme.pe',
      'credito': '1500.00',
      'credito_disponible': '1000.00',
      'linea_utilizada': 500,
      'estado': 1,
      'extranjero': false,
      'cumple': '1990-05-12T00:00:00.000000Z',
      'department_id': '15',
      'department': {'id': '15', 'name': 'LIMA'},
      'province': {'id': '1501', 'name': 'LIMA'},
      'district': {'id': '150101', 'name': 'LIMA'},
      'ejecutivo_comercial_id': 4,
      'ejecutivo_comercial': {'id': 4, 'name': 'Juan Pérez'},
      'categoria_cliente_id': 2,
      'categoria_cliente': {'id': 2, 'nombre': 'Distribuidor', 'codigo': 'B'},
      'user': {'id': 9, 'name': 'Ana Registro'},
      'created_at': '2026-01-05T10:00:00.000000Z',
      'adresses': [
        {
          'id': 10,
          'direccion': 'AV. DOS 456',
          'predeterminado': 1,
          'department_id': '15',
          'province_id': '1501',
          'district_id': '150101',
          'latitud': '-12.04',
          'longitud': -77.03,
          'province': {'id': '1501', 'name': 'LIMA'},
          'district': {'id': '150101', 'name': 'MIRAFLORES'},
        },
      ],
      'contacts': [
        {'id': 20, 'name': 'Luis', 'last_name': 'Soto', 'email': 'luis@acme.pe', 'telefono': '999'},
      ],
    };

Map<String, dynamic> _pageJson({int page = 1, int last = 1, int count = 1}) => {
      'current_page': page,
      'last_page': last,
      'total': 25,
      'total_personas': 20,
      'total_empresas': 5,
      'data': [for (var i = 0; i < count; i++) _clientJson(id: (page - 1) * count + i + 1)],
    };

/// Ruta base de la API según la URL con la que se compile (en producción lleva `/7power/public`).
final _apiPath = Uri.parse(ApiConstants.baseUrl).path;

void main() {
  group('Modelo del cliente', () {
    test('lee un cliente del listado con sus relaciones y números como texto', () {
      final c = clientRecordFromJson(_clientJson());

      expect(c.id, 1);
      expect(c.codigo, 'CLI-0001');
      expect(c.displayName, 'Ana Pérez');
      expect(c.credito, 1500);
      expect(c.creditoDisponible, 1000);
      expect(c.lineaUtilizada, 500);
      expect(c.estado, true);
      expect(c.cumple, '1990-05-12');
      expect(c.ejecutivoNombre, 'Juan Pérez');
      expect(c.categoriaNombre, 'Distribuidor');
      expect(c.categoriaCodigo, 'B');
      expect(c.departmentName, 'LIMA');
      expect(c.registradoPor, 'Ana Registro');
      expect(c.addresses.single.districtName, 'MIRAFLORES');
      expect(c.addresses.single.predeterminado, true);
      expect(c.addresses.single.latitud, -12.04);
      expect(c.contacts.single.name, 'Luis');
    });

    test('una empresa se muestra con su razón social', () {
      final c = clientRecordFromJson(_clientJson(tipo: 'e'));
      expect(c.esEmpresa, true);
      expect(c.displayName, 'ACME SAC');
    });

    test('la página trae los contadores de personas y empresas', () {
      final page = clientPageFromJson(_pageJson(page: 1, last: 3, count: 2));
      expect(page.items, hasLength(2));
      expect(page.hasMore, true);
      expect(page.total, 25);
      expect(page.totalPersonas, 20);
      expect(page.totalEmpresas, 5);
    });

    test('los catálogos de los filtros salen de categorías, ejecutivos y ubicaciones', () {
      final c = clientFilterCatalogsFromJson(
        categorias: {
          'categorias': [
            {'id': 1, 'nombre': 'Socio', 'clientes': 3},
          ],
          'sin_categoria': 7,
          'con_categoria': 3,
        },
        ejecutivos: [
          {'id': 4, 'name': 'Juan', 'clientes_count': 9},
        ],
        ubicaciones: {
          'departamentos': [
            {'id': '15', 'nombre': 'Lima', 'clientes': 12},
          ],
          'distritos': [],
        },
      );
      expect(c.categorias.single.name, 'Socio');
      expect(c.categorias.single.clientes, 3);
      expect(c.sinCategoria, 7);
      expect(c.conCategoria, 3);
      expect(c.ejecutivos.single.id, '4');
      expect(c.ejecutivos.single.clientes, 9);
      expect(c.departamentos.single.id, '15');
    });

    test('las categorías traen los rangos de cada ciclo y los periodos', () {
      final config = categoriesConfigFromJson({
        'data': [
          {
            'id': 1,
            'nombre': 'Socio',
            'codigo': 'A',
            'orden': 1,
            'monto_desde': 5000,
            'monto_hasta': null,
            'rangos': {
              'mensual': {'desde': 5000, 'hasta': null},
              'anual': {'desde': '60000', 'hasta': null},
            },
          },
        ],
        'ciclo': {
          'tipo': 'Mensual',
          'periodos': {
            'mensual': {
              'evaluado_desde': '2026-09-01',
              'evaluado_hasta': '2026-09-30',
              'vigente_desde': '2026-10-01',
              'cambia_el': '2026-11-01',
            },
          },
        },
      });
      expect(config.ciclo, 'mensual');
      expect(config.categorias.single.rangoDe('anual').desde, 60000);
      expect(config.categorias.single.rangoDe('trimestral').desde, isNull);
      expect(config.periodos['mensual']!.cambiaEl, '2026-11-01');
    });

    test('crear manda solo lo escrito; editar manda null en lo que se vació', () {
      const create = ClientFormEntity(
        tipo: 'p',
        dniRuc: '12345678',
        name: 'Ana',
        telefono: '+51987654321',
        email: 'ana@acme.pe',
        departmentId: '15',
        provinceId: '1501',
        districtId: '150101',
        giro: '',
        ejecutivoId: null,
      );
      final created = clientFormToJson(create, companyId: 7, editing: false);
      expect(created['company_id'], 7);
      expect(created['dni_ruc'], '12345678');
      expect(created.containsKey('giro'), false);
      expect(created.containsKey('ejecutivo_comercial_id'), false);
      expect(created.containsKey('adresses'), false);
      expect(created.containsKey('credito'), false);

      final edited = clientFormToJson(create, companyId: 7, editing: true);
      expect(edited['giro'], isNull);
      expect(edited.containsKey('giro'), true);
      expect(edited.containsKey('ejecutivo_comercial_id'), true);
      expect(edited['ejecutivo_comercial_id'], isNull);
    });

    test('sin permiso de un bloque, no se manda (el backend lo deja como estaba)', () {
      const form = ClientFormEntity(
        incluyeBasica: false,
        incluyeCondiciones: false,
        addresses: [ClientAddressEntity(direccion: 'AV. UNO', predeterminado: true)],
        contacts: null,
      );
      final json = clientFormToJson(form, companyId: 7, editing: true);
      expect(json.keys.toSet(), {'company_id', 'adresses'});
      expect((json['adresses'] as List).single['predeterminado'], true);
    });
  });

  group('Datasource', () {
    ClientRecordRemoteDataSourceImpl ds(http.Client c) => ClientRecordRemoteDataSourceImpl(client: c);

    test('la lista manda los mismos parámetros que la web', () async {
      late Uri uri;
      final client = MockClient((request) async {
        uri = request.url;
        return http.Response(json.encode(_pageJson()), 200);
      });

      final page = await ds(client).getClients(
        'tok',
        companyId: 7,
        page: 2,
        pageSize: 20,
        filters: const ClientFiltersEntity(
          search: ['ana', 'perez'],
          tipo: 'p',
          estado: true,
          categorias: {'1', 'sin'},
          ejecutivos: {'4'},
          departamentos: {'15'},
        ),
      );

      expect(page.items, hasLength(1));
      expect(uri.path, endsWith('/clientes'));
      final raw = Uri.decodeFull(uri.query);
      expect(raw, contains('company_id=7'));
      expect(raw, contains('pagination[current]=2'));
      expect(raw, contains('pagination[pageSize]=20'));
      expect(raw, contains('search[]=ana'));
      expect(raw, contains('search[]=perez'));
      expect(raw, contains('filters[tipo][]=p'));
      expect(raw, contains('filters[estado][]=true'));
      expect(raw, contains('filters[categoria_cliente_id][]=1'));
      expect(raw, contains('filters[categoria_cliente_id][]=sin'));
      expect(raw, contains('filters[ejecutivo_comercial_id][]=4'));
      expect(raw, contains('filters[department_id][]=15'));
    });

    test('crear es POST y editar es PUT al cliente', () async {
      final calls = <String>[];
      Map<String, dynamic>? sent;
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        sent = json.decode(request.body) as Map<String, dynamic>;
        return http.Response(json.encode(_clientJson()), 200);
      });
      const form = ClientFormEntity(dniRuc: '12345678', name: 'Ana', telefono: '+51987654321', email: 'a@b.pe');

      await ds(client).saveClient('tok', companyId: 7, form: form);
      await ds(client).saveClient('tok', companyId: 7, form: form, id: 5);

      expect(calls[0], endsWith('POST $_apiPath/clientes'));
      expect(calls[1], endsWith('PUT $_apiPath/clientes/5'));
      expect(sent!['name'], 'Ana');
    });

    test('exportar es POST con la búsqueda y los filtros', () async {
      late http.Request request;
      final client = MockClient((r) async {
        request = r;
        return http.Response.bytes([1, 2, 3], 200);
      });

      final bytes = await ds(client).exportClients(
        'tok',
        companyId: 7,
        filters: const ClientFiltersEntity(search: ['ana'], tipo: 'e'),
      );

      expect(bytes, [1, 2, 3]);
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/clientes/export'));
      expect(Uri.decodeFull(request.url.query), contains('filters[tipo][]=e'));
    });

    test('los ejecutivos del formulario se piden con los roles Vendedor y Ceo', () async {
      final queries = <String, String>{};
      final client = MockClient((request) async {
        queries[request.url.path] = Uri.decodeQueryComponent(request.url.query);
        if (request.url.path.endsWith('/categorias-cliente')) {
          return http.Response(json.encode({'data': [], 'ciclo': {'tipo': 'mensual'}}), 200);
        }
        if (request.url.path.endsWith('/usuarios/list')) {
          return http.Response(json.encode([{'id': 4, 'name': 'Juan'}]), 200);
        }
        if (request.url.path.endsWith('/lista-de-precios/list')) {
          return http.Response(json.encode([{'id': 1, 'name': 'General'}]), 200);
        }
        return http.Response(json.encode([{'id': 3, 'name': 'EFECTIVO'}]), 200);
      });

      final catalogs = await ds(client).getFormCatalogs('tok', companyId: 7);

      expect(catalogs.ejecutivos.single.name, 'Juan');
      expect(catalogs.listasDePrecios.single.name, 'General');
      expect(catalogs.metodosDePago.single.name, 'EFECTIVO');
      final users = queries.entries.firstWhere((e) => e.key.endsWith('/usuarios/list')).value;
      expect(users, contains('company_id=7'));
      expect(users, contains('roles[0]=Vendedor'));
      expect(users, contains('roles[1]=Ceo Empresa'));
    });

    test('guardar las categorías manda nombre y rangos de cada una y luego el ciclo', () async {
      final calls = <String>[];
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        bodies.add(json.decode(request.body) as Map<String, dynamic>);
        return http.Response(
          json.encode(request.url.path.endsWith('/ciclo') ? {'tipo': 'mensual', 'calculo': null} : {}),
          200,
        );
      });

      final calc = await ds(client).saveCategories(
        'tok',
        categorias: const [
          ClientCategoryEntity(
            id: 1,
            nombre: 'Socio',
            codigo: 'A',
            rangos: {'mensual': CategoryRange(desde: 5000)},
          ),
        ],
        ciclo: 'mensual',
      );

      expect(calc, isNull);
      expect(calls[0], endsWith('PUT $_apiPath/categorias-cliente/1'));
      expect(calls[1], endsWith('POST $_apiPath/categorias-cliente/ciclo'));
      expect(bodies[0]['nombre'], 'Socio');
      expect(bodies[0]['rangos']['mensual']['desde'], 5000);
      expect(bodies[1]['tipo'], 'mensual');
    });

    test('un DNI repetido se dice como la web', () {
      final message = apiErrorMessage(json.encode({
        'error': {'dni_ruc': ['The dni ruc has already been taken.']},
      }));
      expect(message, 'El Cliente ya existe');
    });
  });

  group('SaveClientUseCase.validate', () {
    const full = ClientFormEntity(
      tipo: 'p',
      dniRuc: '12345678',
      name: 'Ana',
      telefono: '+51987654321',
      email: 'ana@acme.pe',
      departmentId: '15',
      provinceId: '1501',
      districtId: '150101',
    );

    test('un cliente completo se puede crear', () {
      expect(SaveClientUseCase.validate(full, editing: false), isNull);
    });

    test('al crear exige documento, nombre, teléfono, correo y distrito', () {
      String? check(ClientFormEntity f) => SaveClientUseCase.validate(f, editing: false);
      expect(check(const ClientFormEntity(dniRuc: '')), 'El DNI es obligatorio');
      expect(check(const ClientFormEntity(dniRuc: '123')), 'El DNI debe tener 8 dígitos');
      expect(check(const ClientFormEntity(tipo: 'e', dniRuc: '20123456789')), 'La razón social es obligatoria');
      expect(check(const ClientFormEntity(dniRuc: '12345678')), 'El nombre es obligatorio');
      expect(check(const ClientFormEntity(dniRuc: '12345678', name: 'Ana')), 'El teléfono es obligatorio');
      expect(
        check(const ClientFormEntity(dniRuc: '12345678', name: 'Ana', telefono: '+51987654321')),
        'El correo es obligatorio',
      );
      expect(
        check(const ClientFormEntity(dniRuc: '12345678', name: 'Ana', telefono: '+51987654321', email: 'ana@x.pe')),
        'Elige el departamento, la provincia y el distrito',
      );
    });

    test('al editar no se bloquea por campos que quedaron vacíos de antes', () {
      const old = ClientFormEntity(dniRuc: '12345678');
      expect(SaveClientUseCase.validate(old, editing: true), isNull);
    });

    test('al editar un correo mal escrito de antes no bloquea, uno nuevo sí se valida', () {
      const bad = ClientFormEntity(dniRuc: '12345678', email: 'ana@gmailcom');
      expect(SaveClientUseCase.validate(bad, editing: true, originalEmail: 'ana@gmailcom'), isNull);
      expect(
        SaveClientUseCase.validate(bad, editing: true, originalEmail: 'otro@x.pe'),
        'Debe ser un correo válido',
      );
    });

    test('las páginas deben ser URL', () {
      final f = ClientFormEntity(
        dniRuc: full.dniRuc,
        name: full.name,
        telefono: full.telefono,
        email: full.email,
        departmentId: '15',
        provinceId: '1501',
        districtId: '150101',
        redes: 'facebook.com/ana',
      );
      expect(SaveClientUseCase.validate(f, editing: false), contains('URL válida'));
    });

    test('cada dirección y contacto agregado al crear lleva sus datos', () {
      ClientFormEntity with_({List<ClientAddressEntity>? a, List<ClientContactEntity>? c}) => ClientFormEntity(
            dniRuc: full.dniRuc,
            name: full.name,
            telefono: full.telefono,
            email: full.email,
            departmentId: '15',
            provinceId: '1501',
            districtId: '150101',
            addresses: a,
            contacts: c,
          );

      expect(
        SaveClientUseCase.validate(with_(a: const [ClientAddressEntity()]), editing: false),
        'Escribe la dirección de cada dirección agregada',
      );
      expect(
        SaveClientUseCase.validate(with_(a: const [ClientAddressEntity(direccion: 'AV. UNO')]), editing: false),
        contains('departamento'),
      );
      expect(
        SaveClientUseCase.validate(with_(c: const [ClientContactEntity()]), editing: false),
        'Escribe el nombre de cada contacto agregado',
      );
      expect(
        SaveClientUseCase.validate(
          with_(
            a: const [
              ClientAddressEntity(direccion: 'AV. UNO', departmentId: '15', provinceId: '1501', districtId: '150101'),
            ],
            c: const [ClientContactEntity(name: 'Luis')],
          ),
          editing: false,
        ),
        isNull,
      );
    });

    test('guardar las categorías exige un "Desde" en el ciclo elegido', () {
      const sinRangos = [ClientCategoryEntity(id: 1, nombre: 'Socio', codigo: 'A')];
      expect(
        SaveClientCategoriesUseCase.validate(sinRangos, 'trimestral'),
        'Llena los rangos del ciclo Trimestral antes de guardar o calcular',
      );
      const conRango = [
        ClientCategoryEntity(id: 1, nombre: 'Socio', codigo: 'A', rangos: {'trimestral': CategoryRange(desde: 0)}),
      ];
      expect(SaveClientCategoriesUseCase.validate(conRango, 'trimestral'), isNull);
    });
  });

  group('ClientListProvider', () {
    test('carga la primera página, pagina y los contadores salen del backend', () async {
      final repo = _FakeRecordRepository();
      final provider = _provider(repo);

      await provider.ensureLoaded();
      expect(provider.items, hasLength(1));
      expect(provider.total, 25);
      expect(provider.totalPersonas, 20);
      expect(provider.totalEmpresas, 5);
      expect(provider.hasMore, true);

      await provider.loadMore();
      expect(provider.items, hasLength(2));
      expect(repo.listCalls.last.page, 2);
    });

    test('la búsqueda parte en palabras y reinicia la lista', () async {
      final repo = _FakeRecordRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      await provider.setSearch('  ana   perez ');

      expect(repo.listCalls.last.filters.search, ['ana', 'perez']);
      expect(repo.listCalls.last.page, 1);
    });

    test('al elegir un tipo, el otro contador conserva el último conocido', () async {
      final repo = _FakeRecordRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      repo.page = ClientPageEntity(
        items: [clientRecordFromJson(_clientJson(tipo: 'e'))],
        currentPage: 1,
        lastPage: 1,
        total: 5,
        totalPersonas: 0,
        totalEmpresas: 5,
      );
      await provider.setTipo('e');

      expect(repo.listCalls.last.filters.tipo, 'e');
      expect(provider.totalEmpresas, 5);
      expect(provider.totalPersonas, 20);
      expect(provider.allCount, 25);
    });

    test('un cliente nuevo entra arriba y uno editado se reemplaza en su lugar', () async {
      final repo = _FakeRecordRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      repo.saved = clientRecordFromJson(_clientJson(id: 99));
      final created = await provider.saveClient(const ClientFormEntity(
        dniRuc: '12345678',
        name: 'Nuevo',
        telefono: '+51987654321',
        email: 'n@x.pe',
        departmentId: '15',
        provinceId: '1501',
        districtId: '150101',
      ));
      expect(created, isNull);
      expect(provider.items.first.id, 99);
      expect(provider.total, 26);

      repo.saved = clientRecordFromJson({..._clientJson(id: 1), 'name': 'Editada'});
      final edited = await provider.saveClient(const ClientFormEntity(dniRuc: '12345678'), id: 1);
      expect(edited, isNull);
      expect(provider.items.firstWhere((c) => c.id == 1).name, 'Editada');
      expect(provider.items, hasLength(2));
    });

    test('un error al guardar vuelve como mensaje y no toca la lista', () async {
      final repo = _FakeRecordRepository()..saveError = const ValidationFailure('El Cliente ya existe');
      final provider = _provider(repo);
      await provider.ensureLoaded();

      final error = await provider.saveClient(const ClientFormEntity(
        dniRuc: '12345678',
        name: 'Ana',
        telefono: '+51987654321',
        email: 'a@b.pe',
        departmentId: '15',
        provinceId: '1501',
        districtId: '150101',
      ));

      expect(error, 'El Cliente ya existe');
      expect(provider.items, hasLength(1));
    });

    test('un Vendedor sin otro rol de mando no elige el ejecutivo', () {
      final provider = _provider(_FakeRecordRepository());

      provider.syncSession(_session(roles: const ['Vendedor']));
      expect(provider.isOnlySeller, true);

      provider.syncSession(_session(roles: const ['Vendedor', 'JEFE COMERCIAL']));
      expect(provider.isOnlySeller, false);

      provider.syncSession(_session(roles: const ['Ceo Empresa']));
      expect(provider.isOnlySeller, false);
    });

    test('al cambiar de empresa se descarta todo', () async {
      final repo = _FakeRecordRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      provider.syncSession(_session(companyId: 8));

      expect(provider.items, isEmpty);
      expect(provider.total, 0);
    });

    test('los catálogos del formulario se piden una vez', () async {
      final repo = _FakeRecordRepository();
      final provider = _provider(repo);

      await provider.loadFormCatalogs();
      await provider.loadFormCatalogs();

      expect(repo.formCatalogCalls, 1);
    });

    test('guardar categorías recalculadas recarga la lista', () async {
      final repo = _FakeRecordRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();
      final before = repo.listCalls.length;

      final calc = await provider.saveCategories(
        categorias: const [
          ClientCategoryEntity(id: 1, nombre: 'Socio', codigo: 'A', rangos: {'mensual': CategoryRange(desde: 0)}),
        ],
        ciclo: 'mensual',
        calculate: true,
      );

      expect(calc!.recalculado, true);
      expect(repo.calculated, 1);
      expect(repo.listCalls.length, before + 1);
    });

    test('exportar baja el Excel con lo filtrado', () async {
      final repo = _FakeRecordRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();
      await provider.setTipo('p');

      final result = await provider.exportAll();

      expect(result.isRight, true);
      expect(result.right.name, 'Lista de Clientes.xlsx');
      expect(repo.exportFilters!.tipo, 'p');
    });
  });

  group('Pantalla de clientes', () {
    testWidgets('lista los clientes con su categoría, estado y ejecutivo', (tester) async {
      await _pump(tester, const {'clientes.index', 'clientes.update'});

      expect(find.text('Ana Pérez'), findsWidgets);
      expect(find.text('Persona · DNI 12345678'), findsWidgets);
      expect(find.text('Distribuidor'), findsWidgets);
      expect(find.text('Activo'), findsWidgets);
      expect(find.text('Ejecutivo: Juan Pérez'), findsWidgets);
      expect(find.text('Todos: 25'), findsOneWidget);
      expect(find.text('Personas: 20'), findsOneWidget);
      expect(find.text('Empresas: 5'), findsOneWidget);
    });

    testWidgets('sin el permiso show-telefono el teléfono no se ve', (tester) async {
      await _pump(tester, const {'clientes.index'});
      expect(find.textContaining('+51987654321'), findsNothing);
    });

    testWidgets('con el permiso show-telefono el teléfono se ve', (tester) async {
      await _pump(tester, const {'clientes.index', 'clientes.show-telefono'});
      expect(find.textContaining('+51987654321'), findsWidgets);
    });

    testWidgets('sin el permiso de ver clientes se avisa', (tester) async {
      final repo = await _pump(tester, const {});
      expect(find.text('Sin acceso'), findsOneWidget);
      expect(repo.listCalls, isEmpty);
    });

    testWidgets('tocar Empresas filtra la lista por tipo', (tester) async {
      final repo = await _pump(tester, const {'clientes.index'});

      await tester.tap(find.text('Empresas: 5'));
      await tester.pumpAndSettle();

      expect(repo.listCalls.last.filters.tipo, 'e');
    });

    testWidgets('el detalle muestra datos, direcciones, contactos y crédito', (tester) async {
      await _pump(tester, const {'clientes.index', 'clientes.update', 'clientes.show-telefono'});

      await tester.tap(find.byIcon(Icons.description_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Línea de crédito'), findsOneWidget);
      // Está en la tarjeta de atrás y en el detalle.
      expect(find.text('S/. 1,500.00'), findsNWidgets(2));
      expect(find.text('Línea utilizada'), findsOneWidget);
      expect(find.text('Editar'), findsWidgets);

      await tester.tap(find.text('Direcciones'));
      await tester.pumpAndSettle();
      expect(find.text('AV. DOS 456'), findsOneWidget);

      await tester.tap(find.textContaining('Contactos'));
      await tester.pumpAndSettle();
      expect(find.text('Luis Soto'), findsOneWidget);
    });

    testWidgets('crear: las pestañas dependen de los permisos', (tester) async {
      await _pump(tester, const {'clientes.index', 'clientes.store'});
      await tester.tap(find.text('Crear cliente'));
      await tester.pumpAndSettle();

      expect(find.text('Información básica'), findsOneWidget);
      expect(find.text('Direcciones'), findsOneWidget);
      expect(find.text('Contactos'), findsOneWidget);
      expect(find.text('Información adicional'), findsOneWidget);
      // Sin el permiso de condiciones de venta (y sin ser Ceo) no sale esa pestaña.
      expect(find.text('Condiciones de venta'), findsNothing);
    });

    testWidgets('el Ceo ve también las condiciones de venta', (tester) async {
      await _pump(tester, const {'clientes.index', 'clientes.store'}, roles: const ['Ceo Empresa']);
      await tester.tap(find.text('Crear cliente'));
      await tester.pumpAndSettle();

      expect(find.text('Condiciones de venta'), findsOneWidget);
    });

    testWidgets('crear con datos incompletos muestra el motivo y no guarda', (tester) async {
      final repo = await _pump(tester, const {'clientes.index', 'clientes.store'});
      await tester.tap(find.text('Crear cliente'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(repo.saves, isEmpty);
      expect(find.text('El DNI es obligatorio'), findsWidgets);
    });

    testWidgets('crear un cliente completo lo manda con los campos de la web', (tester) async {
      final repo = await _pump(
        tester,
        const {'clientes.index', 'clientes.store'},
        roles: const ['Vendedor'],
      );
      // Con dos acciones (crear y ver categorías) salen dentro de "Acciones".
      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Crear cliente'));
      await tester.pumpAndSettle();
      // El formulario es largo y la prueba no desplaza: se agranda la pantalla ya abierto el modal.
      _tall(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'DNI'), '12345678');
      await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono'), '987654321');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana');
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'ana@acme.pe');

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LIMA').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PROVINCIA 15').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DISTRITO 1501').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(repo.saves, hasLength(1));
      final form = repo.saves.single.form;
      expect(repo.saves.single.id, isNull);
      expect(form.dniRuc, '12345678');
      expect(form.name, 'Ana');
      expect(form.telefono, '+51987654321');
      expect(form.email, 'ana@acme.pe');
      expect(form.departmentId, '15');
      expect(form.districtId, '150101');
      expect(form.incluyeBasica, true);
      // El Vendedor queda como ejecutivo de su cliente.
      expect(form.ejecutivoId, 9);
      expect(find.text('Cliente creado'), findsOneWidget);
    });

    testWidgets('editar no deja guardar hasta cambiar algo y manda el cliente con su id', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await _pump(tester, const {
        'clientes.index',
        'clientes.update',
        'clientes.update.informacion-basica',
        'clientes.update.direcciones',
        'clientes.update.contactos',
      });

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Guardar');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana María');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repo.saves, hasLength(1));
      expect(repo.saves.single.id, 1);
      expect(repo.saves.single.form.name, 'Ana María');
      expect(repo.saves.single.form.addresses!.single.id, 10);
      expect(repo.saves.single.form.addresses!.single.predeterminado, true);
      expect(repo.saves.single.form.contacts!.single.id, 20);
      expect(find.text('Cliente editado'), findsOneWidget);
    });

    testWidgets('con solo el permiso de contactos, la edición no manda lo básico', (tester) async {
      _tall(tester);
      final repo = await _pump(tester, const {'clientes.index', 'clientes.update', 'clientes.update.contactos'});

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Información básica'), findsNothing);
      expect(find.text('Contactos'), findsOneWidget);

      await tester.tap(find.text('Agregar contacto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombres').last, 'Marta');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final form = repo.saves.single.form;
      expect(form.incluyeBasica, false);
      expect(form.addresses, isNull);
      expect(form.contacts, hasLength(2));
      expect(form.contacts!.last.name, 'Marta');
    });

    testWidgets('un error del servidor se ve en el formulario y no lo cierra', (tester) async {
      _tall(tester);
      final repo = await _pump(tester, const {'clientes.index', 'clientes.update', 'clientes.update.contactos'});
      repo.saveError = const ValidationFailure('El Cliente ya existe');

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar contacto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombres').last, 'Marta');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('El Cliente ya existe'), findsOneWidget);
      expect(find.text('Editar cliente'), findsOneWidget);
    });

    testWidgets('el panel de filtros aplica tipo, estado y categoría', (tester) async {
      final repo = await _pump(tester, const {'clientes.index'});

      await tester.tap(find.byIcon(Icons.filter_list).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empresas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactivos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin categoría (7)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      final f = repo.listCalls.last.filters;
      expect(f.tipo, 'e');
      expect(f.estado, false);
      expect(f.categorias, {'sin'});
    });

    testWidgets('con permiso de categorizar se configuran las categorías y se guardan', (tester) async {
      final repo = await _pump(tester, const {'clientes.index', 'clientes.categorizar'});

      // Es la única acción: sale directa, sin "Acciones".
      await tester.tap(find.text('Configurar categorías'));
      await tester.pumpAndSettle();

      expect(find.text('CICLO DE ACTUALIZACIÓN'), findsOneWidget);
      expect(find.text('Trimestral'), findsOneWidget);

      await tester.tap(find.text('Trimestral'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Desde (S/) · trimestral'), '1000');
      await tester.tap(find.text('Guardar configuración'));
      await tester.pumpAndSettle();

      expect(repo.savedCategories, hasLength(1));
      expect(repo.savedCycle, 'trimestral');
      expect(repo.savedCategories!.single.rangoDe('trimestral').desde, 1000);
    });

    testWidgets('el Vendedor sin permiso de categorizar solo mira las categorías', (tester) async {
      await _pump(tester, const {'clientes.index'}, roles: const ['Vendedor']);

      await tester.tap(find.text('Ver categorías'));
      await tester.pumpAndSettle();

      expect(find.text('Categorías de clientes'), findsOneWidget);
      expect(find.text('Socio'), findsOneWidget);
      expect(find.text('Guardar configuración'), findsNothing);
    });
  });
}

// ----------------------------------------------------------------------------------------------

SessionContextEntity _session({
  int companyId = 7,
  Set<String> permissions = const {},
  List<String> roles = const [],
}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME'),
      modules: const [],
      permissions: permissions,
      roles: roles,
      warehouses: const [],
    );

ClientListProvider _provider(_FakeRecordRepository repo) => ClientListProvider(
      getClientsUseCase: GetClientsUseCase(repository: repo),
      getFilterCatalogsUseCase: GetClientFilterCatalogsUseCase(repository: repo),
      getFormCatalogsUseCase: GetClientFormCatalogsUseCase(repository: repo),
      saveClientUseCase: SaveClientUseCase(repository: repo),
      exportClientsUseCase: ExportClientsUseCase(repository: repo),
      getCategoriesUseCase: GetClientCategoriesUseCase(repository: repo),
      saveCategoriesUseCase: SaveClientCategoriesUseCase(repository: repo),
    )..syncSession(_session());

class _SavedCall {
  final ClientFormEntity form;
  final int? id;
  _SavedCall(this.form, this.id);
}

class _FakeRecordRepository implements ClientRecordRepository {
  final List<({int page, ClientFiltersEntity filters})> listCalls = [];
  final List<_SavedCall> saves = [];
  ClientPageEntity? page;
  ClientRecordEntity? saved;
  Failure? saveError;
  int formCatalogCalls = 0;
  int calculated = 0;
  ClientFiltersEntity? exportFilters;
  List<ClientCategoryEntity>? savedCategories;
  String? savedCycle;

  @override
  Future<Either<Failure, ClientPageEntity>> getClients({
    required int companyId,
    required int page,
    required int pageSize,
    required ClientFiltersEntity filters,
  }) async {
    listCalls.add((page: page, filters: filters));
    return Either.right(
      this.page ?? clientPageFromJson(_pageJson(page: page, last: 2)),
    );
  }

  @override
  Future<Either<Failure, ClientFilterCatalogsEntity>> getFilterCatalogs() async => Either.right(
        const ClientFilterCatalogsEntity(
          categorias: [ClientFilterOption(id: '1', name: 'Socio', clientes: 3)],
          sinCategoria: 7,
          conCategoria: 3,
          ejecutivos: [ClientFilterOption(id: '4', name: 'Juan', clientes: 9)],
          departamentos: [ClientFilterOption(id: '15', name: 'Lima', clientes: 12)],
        ),
      );

  @override
  Future<Either<Failure, ClientFormCatalogsEntity>> getFormCatalogs({required int companyId}) async {
    formCatalogCalls++;
    return Either.right(const ClientFormCatalogsEntity(
      ejecutivos: [ClientOption(id: 9, name: 'Ana'), ClientOption(id: 4, name: 'Juan Pérez')],
      listasDePrecios: [ClientOption(id: 1, name: 'General')],
      metodosDePago: [ClientOption(id: 3, name: 'EFECTIVO')],
      categorias: [ClientCategoryEntity(id: 1, nombre: 'Socio', codigo: 'A')],
    ));
  }

  @override
  Future<Either<Failure, ClientRecordEntity>> saveClient({
    required int companyId,
    required ClientFormEntity form,
    int? id,
  }) async {
    saves.add(_SavedCall(form, id));
    if (saveError != null) return Either.left(saveError!);
    return Either.right(saved ?? clientRecordFromJson(_clientJson(id: id ?? 50)));
  }

  @override
  Future<Either<Failure, Uint8List>> exportClients({
    required int companyId,
    required ClientFiltersEntity filters,
  }) async {
    exportFilters = filters;
    return Either.right(Uint8List.fromList([1, 2, 3]));
  }

  @override
  Future<Either<Failure, CategoriesConfigEntity>> getCategories() async => Either.right(
        const CategoriesConfigEntity(
          ciclo: 'mensual',
          categorias: [
            ClientCategoryEntity(
              id: 1,
              nombre: 'Socio',
              codigo: 'A',
              montoDesde: 5000,
              rangos: {'mensual': CategoryRange(desde: 5000)},
            ),
          ],
        ),
      );

  @override
  Future<Either<Failure, CategoryCalcEntity?>> saveCategories({
    required List<ClientCategoryEntity> categorias,
    required String ciclo,
  }) async {
    savedCategories = categorias;
    savedCycle = ciclo;
    return Either.right(null);
  }

  @override
  Future<Either<Failure, CategoryCalcEntity>> calculateCategories({required String ciclo}) async {
    calculated++;
    return Either.right(const CategoryCalcEntity(recalculado: true, clientesActualizados: 4));
  }
}

class _FakeClientRepository implements ClientRepository {
  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDepartments() async =>
      Either.right(const [UbigeoItemEntity(id: '15', name: 'LIMA')]);

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getProvinces(String departmentId) async =>
      Either.right([UbigeoItemEntity(id: '${departmentId}01', name: 'PROVINCIA $departmentId')]);

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDistricts(String provinceId) async =>
      Either.right([UbigeoItemEntity(id: '${provinceId}01', name: 'DISTRITO $provinceId')]);

  @override
  Future<Either<Failure, DocumentLookupEntity>> lookupDocument({required String tipo, required String number}) async =>
      Either.right(const DocumentLookupEntity(tipo: 'p', name: 'ANA', lastName: 'PEREZ'));

  @override
  Future<Either<Failure, ClientEntity>> createClient({
    required int companyId,
    int? executiveId,
    required NewClientFormEntity form,
  }) async =>
      Either.left(const ServerFailure('no se usa'));
}

class _FakeThemeStorage implements ThemeLocalDataSource {
  @override
  Future<ThemeMode?> read() async => null;

  @override
  Future<void> write(ThemeMode mode) async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> login(String usuario, String password) async =>
      Either.right(const UserEntity(id: 9, name: 'Ana', usuario: 'ana'));

  @override
  Future<Either<Failure, void>> logout() async => Either.rightVoid();

  @override
  Future<Either<Failure, SessionContextEntity?>> getSessionContext() async => Either.right(null);

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Either<Failure, SavedCredentialsEntity?>> getSavedCredentials() async => Either.right(null);

  @override
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async => Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

AuthProvider _auth(SessionContextEntity session) {
  final repo = _FakeAuthRepository();
  return AuthProvider(
    loginUseCase: LoginUseCase(repository: repo),
    logoutUseCase: LogoutUseCase(repository: repo),
    getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
    getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
    saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
    clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
  )..session = session;
}

/// Pantalla alta: el formulario es largo y las pruebas no desplazan.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<_FakeRecordRepository> _pump(
  WidgetTester tester,
  Set<String> permissions, {
  List<String> roles = const [],
}) async {
  final repo = _FakeRecordRepository();
  final session = _session(permissions: permissions, roles: roles);
  final provider = _provider(repo)..syncSession(session);
  final ventas = ClientsProvider(
    getDepartmentsUseCase: GetDepartmentsUseCase(repository: _FakeClientRepository()),
    getProvincesUseCase: GetProvincesUseCase(repository: _FakeClientRepository()),
    getDistrictsUseCase: GetDistrictsUseCase(repository: _FakeClientRepository()),
    lookupDocumentUseCase: LookupDocumentUseCase(repository: _FakeClientRepository()),
    createClientUseCase: CreateClientUseCase(repository: _FakeClientRepository()),
  )..syncSession(session);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
        ChangeNotifierProvider<ClientListProvider>.value(value: provider),
        ChangeNotifierProvider<ClientsProvider>.value(value: ventas),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ClientsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}
