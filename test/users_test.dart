import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/core/constants/api_constants.dart';
import 'package:app_novik/core/constants/user_permissions.dart';
import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/datasources/user_record_remote_datasource.dart';
import 'package:app_novik/data/models/user_record_model.dart';
import 'package:app_novik/domain/entities/client_form_entity.dart' show UbigeoItemEntity;
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/entities/user_record_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/user_record_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/user_record_usecases.dart';
import 'package:app_novik/presentation/pages/users_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/presentation/providers/users_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _userJson({
  int id = 1,
  String name = 'Ana Pérez',
  List<Map<String, dynamic>>? roles,
  List<Map<String, dynamic>>? permissions,
  String? foto,
  bool estado = true,
}) =>
    {
      'id': id,
      'codigo': 'USR00$id',
      'usuario': 'ANAPEREZ',
      'name': name,
      'email': 'ana@acme.pe',
      'telefono': '987654321',
      'estado': estado,
      'ventas_ajenas': false,
      'tipo_documento': 'DNI',
      'numero_documento': '12345678',
      'nombres': 'Ana',
      'apellidos': 'Pérez',
      'cumple': '1995-05-28T00:00:00.000000Z',
      'fecha_ingreso': '2024-02-01',
      'direccion': 'AV. UNO 123',
      'department_id': '15',
      'province_id': '1501',
      'district_id': '150101',
      'contacto_emergencia': 'Luis (padre)',
      'telefono_emergencia': '999111222',
      'foto': foto,
      'warehouse_id': 1,
      'list_price_id': 1,
      'payment_method_id': 1,
      'metodo_entrega': 'd',
      'created_at': '2026-01-05T10:00:00.000000Z',
      'roles': roles ?? [
        {'id': 7, 'name': 'Vendedor'},
      ],
      'warehouses': [
        {'id': 1, 'name': 'Principal'},
        {'id': 2, 'name': 'Sucursal Norte'},
      ],
      'list_prices': [
        {'id': 1, 'name': 'General'},
      ],
      'payment_methods': [
        {'id': 1, 'name': 'EFECTIVO'},
      ],
      'permissions': permissions ?? const [],
    };

Map<String, dynamic> _pageJson({int page = 1, int last = 1, int count = 1}) => {
      'current_page': page,
      'last_page': last,
      'total': 25,
      'data': [for (var i = 0; i < count; i++) _userJson(id: (page - 1) * count + i + 1)],
    };

/// Ruta base de la API según la URL con la que se compile (en producción lleva `/7power/public`).
final _apiPath = Uri.parse(ApiConstants.baseUrl).path;

const _roles = [
  UserOption(id: 2, name: 'Ceo Empresa'),
  UserOption(id: 3, name: 'Admin Empresa'),
  UserOption(id: 4, name: 'Contador'),
  UserOption(id: 5, name: 'Almacenero'),
  UserOption(id: 6, name: 'Cajero'),
  UserOption(id: 7, name: 'Vendedor'),
];

const _catalogs = UserCatalogsEntity(
  roles: _roles,
  warehouses: [UserOption(id: 1, name: 'Principal'), UserOption(id: 2, name: 'Sucursal Norte')],
  listPrices: [UserOption(id: 1, name: 'General')],
  paymentMethods: [UserOption(id: 1, name: 'EFECTIVO'), UserOption(id: 2, name: 'YAPE')],
  permissions: [
    UserPermissionEntity(id: 1, name: 'clientes.store'),
    UserPermissionEntity(id: 2, name: 'clientes.index'),
    UserPermissionEntity(id: 3, name: 'documentos.ventas.index'),
    UserPermissionEntity(id: 4, name: 'ajustes.update'),
    // No está en la lista de la web: no se ofrece.
    UserPermissionEntity(id: 5, name: 'interno.secreto'),
  ],
);

/// Un formulario completo (un Almacenero: no pide métodos de pago ni listas de precios).
const _validForm = UserFormEntity(
  numeroDocumento: '12345678',
  nombres: 'Ana',
  apellidos: 'Pérez',
  cumple: '1995-05-28',
  telefono: '987654321',
  email: 'ana@acme.pe',
  roles: [5],
  almacenes: [1],
  warehouseId: 1,
);

void main() {
  group('Modelo del usuario', () {
    test('lee un usuario con su ficha, roles, accesos y permisos', () {
      final u = userRecordFromJson(_userJson(
        foto: 'images/usuarios/1.png',
        permissions: [
          {'id': 2, 'name': 'clientes.index'},
        ],
      ));

      expect(u.id, 1);
      expect(u.codigo, 'USR001');
      expect(u.name, 'Ana Pérez');
      expect(u.estado, true);
      expect(u.cumple, '1995-05-28');
      expect(u.fechaIngreso, '2024-02-01');
      expect(u.tipoDocumento, 'DNI');
      expect(u.departmentId, '15');
      expect(u.roles.single.name, 'Vendedor');
      expect(u.rolesLabel, 'Ejecutivo Comercial');
      expect(u.warehouses.map((w) => w.name), ['Principal', 'Sucursal Norte']);
      expect(u.warehouseId, 1);
      expect(u.paymentMethods.single.name, 'EFECTIVO');
      expect(u.permissions.single.name, 'clientes.index');
      expect(u.foto, 'images/usuarios/1.png');
      expect(u.creado, isNotNull);
    });

    test('el estado y las ventas ajenas aceptan 0 y 1', () {
      final u = userRecordFromJson({..._userJson(), 'estado': 0, 'ventas_ajenas': 1});
      expect(u.estado, false);
      expect(u.ventasAjenas, true);
    });

    test('la página sabe si hay más', () {
      final page = userPageFromJson(_pageJson(page: 1, last: 3, count: 2));
      expect(page.items, hasLength(2));
      expect(page.hasMore, true);
      expect(page.total, 25);
      expect(userPageFromJson(_pageJson(page: 3, last: 3)).hasMore, false);
    });

    test('el Ceo y el Admin de la empresa trabajan con todo', () {
      expect(userRecordFromJson(_userJson(roles: [{'id': 2, 'name': 'Ceo Empresa'}])).seesEverything, true);
      expect(userRecordFromJson(_userJson(roles: [{'id': 3, 'name': 'Admin Empresa'}])).seesEverything, true);
      expect(userRecordFromJson(_userJson()).seesEverything, false);
    });

    test('crear manda solo lo escrito y nunca una contraseña', () {
      final json = userFormToJson(_validForm, companyId: 7, editing: false);

      expect(json['company_id'], 7);
      expect(json['name'], 'Ana Pérez');
      expect(json['nombres'], 'Ana');
      expect(json['tipo_documento'], 'DNI');
      expect(json['cumple'], '1995-05-28');
      expect(json['roles'], [5]);
      expect(json['almacenes'], [1]);
      expect(json['warehouse_id'], 1);
      expect(json.keys.any((k) => k.contains('password') || k.contains('contraseña')), false);
      // Lo vacío no va al crear.
      expect(json.containsKey('direccion'), false);
      expect(json.containsKey('fecha_ingreso'), false);
      expect(json.containsKey('permisos'), false);
      // Y lo que no aplica al rol tampoco.
      expect(json.containsKey('payment_methods'), false);
      expect(json.containsKey('listPrices'), false);
      expect(json.containsKey('ventas_ajenas'), false);
    });

    test('editar manda null en lo que se vació y siempre los permisos', () {
      final json = userFormToJson(_validForm, companyId: 7, editing: true);

      expect(json['direccion'], isNull);
      expect(json.containsKey('direccion'), true);
      expect(json['contacto_emergencia'], isNull);
      expect(json['fecha_ingreso'], isNull);
      expect(json['permisos'], isEmpty);
    });

    test('un Vendedor manda ventas ajenas y método de entrega; los métodos de pago y listas según el rol', () {
      const form = UserFormEntity(
        roles: [7],
        esVendedor: true,
        conPagos: true,
        conListas: true,
        ventasAjenas: true,
        metodoEntrega: 'e',
        paymentMethods: [1, 2],
        paymentMethodId: 2,
        listPrices: [1],
        listPriceId: 1,
        permisos: [2, 5],
      );
      final json = userFormToJson(form, companyId: 7, editing: false);

      expect(json['ventas_ajenas'], true);
      expect(json['metodo_entrega'], 'e');
      expect(json['payment_methods'], [1, 2]);
      expect(json['payment_method_id'], 2);
      expect(json['listPrices'], [1]);
      expect(json['list_price_id'], 1);
      expect(json['permisos'], [2, 5]);
    });
  });

  group('Reglas del formulario', () {
    test('el DNI tiene 8 dígitos; el carné y el pasaporte solo se piden', () {
      expect(UserFormRules.documentNumber('DNI', '1234567'), 'El DNI tiene 8 dígitos');
      expect(UserFormRules.documentNumber('DNI', '12345678'), isNull);
      expect(UserFormRules.documentNumber('CE', 'AB123'), isNull);
      expect(UserFormRules.documentNumber('PASAPORTE', ''), 'Obligatorio');
    });

    test('el correo se pide y debe ser válido', () {
      expect(UserFormRules.email(''), 'Obligatorio');
      expect(UserFormRules.email('ana@'), 'Debe ser un correo válido');
      expect(UserFormRules.email('ana@acme.pe'), isNull);
    });

    test('la fecha de nacimiento se pide y no puede ser futura', () {
      final today = DateTime(2026, 11, 17);
      expect(UserFormRules.birthday(null, today: today), 'Obligatorio');
      expect(UserFormRules.birthday('2026-11-18', today: today), 'No puede ser futura');
      expect(UserFormRules.birthday('2026-11-17', today: today), isNull);
    });

    test('un formulario completo no tiene problemas', () {
      expect(SaveUserUseCase.problems(_validForm, editing: false), isEmpty);
      expect(SaveUserUseCase.validate(_validForm, editing: false), isNull);
    });

    test('el aviso dice qué falta, como la web, y en qué pestaña está', () {
      final problems = SaveUserUseCase.problems(const UserFormEntity(numeroDocumento: '123'), editing: false);
      final labels = problems.map((p) => p.label).toList();

      expect(labels, containsAll(['N° de documento', 'Nombres', 'Apellidos', 'Fecha de nacimiento', 'Celular', 'Correo']));
      expect(problems.firstWhere((p) => p.field == 'numero_documento').reason, 'El DNI tiene 8 dígitos');
      expect(problems.firstWhere((p) => p.field == 'roles').inAccess, true);
      expect(problems.firstWhere((p) => p.field == 'nombres').inAccess, false);
      final message = SaveUserUseCase.validate(const UserFormEntity(), editing: false)!;
      expect(message, startsWith('Completa estos campos: '));
      expect(message, contains('Rol en el sistema'));
      expect(message, contains('Sucursales autorizadas'));
    });

    test('con un rol de pagos se piden los métodos de pago', () {
      final f = UserFormEntity(
        nombres: _validForm.nombres,
        apellidos: _validForm.apellidos,
        numeroDocumento: _validForm.numeroDocumento,
        cumple: _validForm.cumple,
        telefono: _validForm.telefono,
        email: _validForm.email,
        roles: const [6],
        almacenes: const [1],
        warehouseId: 1,
        conPagos: true,
      );
      final fields = SaveUserUseCase.problems(f, editing: true).map((p) => p.field);
      expect(fields, containsAll(['payment_methods', 'payment_method_id']));
    });

    test('las listas de precios solo se piden al crear', () {
      const base = UserFormEntity(roles: [3], conListas: true);
      expect(SaveUserUseCase.problems(base, editing: false).map((p) => p.field), contains('listPrices'));
      expect(SaveUserUseCase.problems(base, editing: true).map((p) => p.field), isNot(contains('listPrices')));
    });

    test('guardar un formulario incompleto ni llega al servidor', () async {
      final repo = _FakeUserRepository();
      final result = await SaveUserUseCase(repository: repo)(companyId: 7, form: const UserFormEntity());
      expect(result.isLeft, true);
      expect(result.left, isA<ValidationFailure>());
      expect(repo.saves, isEmpty);
    });

    test('la foto no puede pesar más de 2 MB', () async {
      final repo = _FakeUserRepository();
      final result = await UploadUserPhotoUseCase(repository: repo)(
        id: 1,
        bytes: Uint8List(2 * 1024 * 1024 + 1),
        name: 'a.png',
      );
      expect(result.isLeft, true);
      expect(repo.uploads, isEmpty);
    });

    test('un rol sin nombre no se guarda', () async {
      final repo = _FakeUserRepository();
      final result = await SaveRoleUseCase(repository: repo)(name: '   ');
      expect(result.left.message, 'El nombre es requerido');
      expect(repo.savedRoles, isEmpty);
    });
  });

  group('Permisos', () {
    test('la lista es la misma de la web y se agrupa por módulo', () {
      expect(userPermissionLabels, hasLength(127));
      expect(userPermissionLabels['usuarios.store.contador'], 'Crear Usuario Contador');
      expect(userPermissionModule('documentos.ventas.index'), 'documentos');
      expect(userPermissionModuleLabel('documentos.ventas.index'), 'Documentos');
      expect(userPermissionModuleLabel('pagos-vendedores.store'), 'Pagos de vendedores');
      // Un módulo que no está en el mapa se nombra solo.
      expect(userPermissionModuleLabel('nuevo-modulo.index'), 'Nuevo modulo');
    });
  });

  group('Datasource', () {
    UserRecordRemoteDataSourceImpl ds(http.Client c) => UserRecordRemoteDataSourceImpl(client: c);

    test('la lista manda los mismos parámetros que la web', () async {
      late Uri uri;
      final client = MockClient((request) async {
        uri = request.url;
        return http.Response(json.encode(_pageJson()), 200);
      });

      final page = await ds(client).getUsers(
        'tok',
        companyId: 7,
        page: 2,
        pageSize: 20,
        filters: const UserFiltersEntity(search: 'ana perez', estado: false, role: 'Vendedor'),
      );

      expect(page.items, hasLength(1));
      expect(uri.path, endsWith('/usuarios'));
      final raw = Uri.decodeFull(uri.query).replaceAll('+', ' ');
      expect(raw, contains('company_id=7'));
      expect(raw, contains('pagination[current]=2'));
      expect(raw, contains('pagination[pageSize]=20'));
      expect(raw, contains('search=ana perez'));
      expect(raw, contains('filters[estado][]=false'));
      expect(raw, contains('filters[roles.name][]=Vendedor'));
    });

    test('sin búsqueda ni filtros solo manda empresa y página', () {
      final params = UserRecordRemoteDataSourceImpl.listParams(
        companyId: 7,
        filters: const UserFiltersEntity(),
        page: 1,
        pageSize: 20,
      );
      expect(params.map((e) => e.key), ['company_id', 'pagination[current]', 'pagination[pageSize]']);
    });

    test('crear es POST y editar es PUT al usuario, con el token', () async {
      final calls = <String>[];
      Map<String, dynamic>? sent;
      String? auth;
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        auth = request.headers['Authorization'];
        sent = json.decode(request.body) as Map<String, dynamic>;
        return http.Response(json.encode(_userJson()), 200);
      });

      final created = await ds(client).saveUser('tok', companyId: 7, form: _validForm);
      await ds(client).saveUser('tok', companyId: 7, form: _validForm, id: 5);

      expect(created.name, 'Ana Pérez');
      expect(calls[0], endsWith('POST $_apiPath/usuarios'));
      expect(calls[1], endsWith('PUT $_apiPath/usuarios/5'));
      expect(auth, 'Bearer tok');
      expect(sent!['email'], 'ana@acme.pe');
      expect(sent!.containsKey('password'), false);
    });

    test('un error de validación del servidor llega con su mensaje', () async {
      final client = MockClient((request) async => http.Response(
            json.encode({
              'error': {
                'email': ['El correo ya está en uso'],
              },
            }),
            422,
          ));

      await expectLater(
        ds(client).saveUser('tok', companyId: 7, form: _validForm),
        throwsA(predicate((e) => '$e'.contains('El correo ya está en uso'))),
      );
    });

    test('los catálogos del formulario se piden con la empresa', () async {
      final queries = <String, String>{};
      final client = MockClient((request) async {
        queries[request.url.path] = Uri.decodeQueryComponent(request.url.query);
        if (request.url.path.endsWith('/usuarios/permisos')) {
          return http.Response(json.encode([{'id': 1, 'name': 'clientes.store', 'guard_name': 'web'}]), 200);
        }
        if (request.url.path.endsWith('/roles/list')) {
          return http.Response(json.encode([{'id': 7, 'name': 'Vendedor'}]), 200);
        }
        return http.Response(json.encode([{'id': 3, 'name': 'Principal'}]), 200);
      });

      final c = await ds(client).getCatalogs('tok', companyId: 7);

      expect(c.roles.single.name, 'Vendedor');
      expect(c.warehouses.single.name, 'Principal');
      expect(c.listPrices.single.id, 3);
      expect(c.paymentMethods, hasLength(1));
      expect(c.permissions.single.name, 'clientes.store');
      expect(queries['$_apiPath/almacenes/list'], 'company_id=7');
      expect(queries['$_apiPath/lista-de-precios/list'], 'company_id=7');
      expect(queries.keys, contains('$_apiPath/metodos-de-pago/list'));
      expect(queries.keys, contains('$_apiPath/usuarios/permisos'));
    });

    test('la foto se sube como archivo y se pide como bytes (204 = sin foto)', () async {
      http.BaseRequest? upload;
      var status = 200;
      final client = MockClient.streaming((request, body) async {
        if (request.method == 'POST') {
          upload = request;
          final bytes = await body.toBytes();
          expect(bytes, isNotEmpty);
          return http.StreamedResponse(Stream.value(utf8.encode('{"success":true}')), 200);
        }
        return http.StreamedResponse(Stream.value(status == 204 ? <int>[] : <int>[1, 2, 3]), status);
      });

      await ds(client).uploadPhoto('tok', id: 4, bytes: Uint8List.fromList([1, 2, 3]), name: 'a.png');
      expect(upload!.url.path, endsWith('/usuarios/4/foto'));
      expect(upload!.headers['content-type'], startsWith('multipart/form-data'));

      expect(await ds(client).getPhoto('tok', 4), [1, 2, 3]);
      status = 204;
      expect(await ds(client).getPhoto('tok', 4), isNull);
    });

    test('los roles: crear es POST, renombrar es PUT y eliminar es DELETE sin leer respuesta', () async {
      final calls = <String>[];
      Object? body;
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'DELETE') return http.Response('', 204);
        body = json.decode(request.body);
        return http.Response(json.encode({'id': 9, 'name': 'Supervisor'}), 200);
      });

      final created = await ds(client).saveRole('tok', name: 'Supervisor');
      await ds(client).saveRole('tok', name: 'Supervisor', id: 9);
      await ds(client).deleteRole('tok', 9);

      expect(created.id, 9);
      expect(body, {'name': 'Supervisor'});
      expect(calls, [
        'POST $_apiPath/roles',
        'PUT $_apiPath/roles/9',
        'DELETE $_apiPath/roles/9',
      ]);
    });

    test('eliminar un rol en uso muestra el motivo del servidor', () async {
      final client = MockClient((request) async => http.Response(
            json.encode({'error': 'No se puede eliminar el rol porque está asignado a 2 usuario(s)'}),
            422,
          ));
      await expectLater(
        ds(client).deleteRole('tok', 9),
        throwsA(predicate((e) => '$e'.contains('asignado a 2 usuario(s)'))),
      );
    });

    test('la ubicación se pide por departamento, provincia y distrito', () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add('${request.url.path}?${request.url.query}');
        return http.Response(json.encode([{'id': '15', 'name': 'LIMA'}]), 200);
      });
      final d = await ds(client).getDepartments('tok');
      await ds(client).getProvinces('tok', '15');
      await ds(client).getDistricts('tok', '1501');

      expect(d.single.id, '15');
      expect(paths[0], endsWith('/ubigeo/search/departments?'));
      expect(paths[1], endsWith('/ubigeo/search/provinces?department_id=15'));
      expect(paths[2], endsWith('/ubigeo/search/districts?province_id=1501'));
    });
  });

  group('UsersProvider', () {
    test('carga la primera página y pagina', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);

      await provider.ensureLoaded();
      expect(provider.items, hasLength(1));
      expect(provider.total, 25);
      expect(provider.hasMore, true);

      await provider.loadMore();
      expect(provider.items, hasLength(2));
      expect(repo.listCalls.last.page, 2);
    });

    test('la búsqueda se limpia de espacios y reinicia la lista', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      await provider.setSearch('  ana  ');

      expect(repo.listCalls.last.filters.search, 'ana');
      expect(repo.listCalls.last.page, 1);
    });

    test('los filtros de estado y rol reinician la lista', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      await provider.setFilters(const UserFiltersEntity(estado: true, role: 'Cajero'));

      expect(repo.listCalls.last.filters.estado, true);
      expect(repo.listCalls.last.filters.role, 'Cajero');
      expect(provider.filters.hasPanelFilters, true);
      expect(provider.filters.copyWith(clearEstado: true, clearRole: true).active, false);
    });

    test('un error al cargar deja el mensaje y avisa si la sesión venció', () async {
      final repo = _FakeUserRepository()..listError = const AuthenticationFailure('Sesión expirada');
      var expired = 0;
      final provider = _provider(repo, onExpired: () => expired++);

      await provider.ensureLoaded();

      expect(provider.error, 'Sesión expirada');
      expect(provider.items, isEmpty);
      expect(expired, 1);
    });

    test('al cambiar de empresa se descarta todo', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      provider.syncSession(_session(companyId: 8));

      expect(provider.items, isEmpty);
      expect(provider.total, 0);
      expect(provider.roles, isNull);
    });

    test('un usuario nuevo entra arriba y uno editado se reemplaza en su lugar', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      repo.saved = userRecordFromJson(_userJson(id: 99, name: 'Nuevo Usuario'));
      final created = await provider.saveUser(_validForm);
      expect(created.error, isNull);
      expect(provider.items.first.id, 99);
      expect(provider.total, 26);

      repo.saved = userRecordFromJson(_userJson(id: 1, name: 'Ana Editada'));
      await provider.saveUser(_validForm, id: 1);
      expect(provider.items.map((u) => u.name), ['Nuevo Usuario', 'Ana Editada']);
      expect(provider.total, 26);
      expect(repo.saves.last.id, 1);
      expect(repo.saves.last.companyId, 7);
    });

    test('un error al guardar se devuelve y la lista no cambia', () async {
      final repo = _FakeUserRepository()..saveError = const ValidationFailure('El correo ya está en uso');
      final provider = _provider(repo);
      await provider.ensureLoaded();

      final result = await provider.saveUser(_validForm);

      expect(result.error, 'El correo ya está en uso');
      expect(provider.items, hasLength(1));
    });

    test('con foto: se sube después de guardar y el usuario queda con foto', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();
      repo.saved = userRecordFromJson(_userJson(id: 50));

      final result = await provider.saveUser(
        _validForm,
        photo: (name: 'yo.png', bytes: Uint8List.fromList([1, 2, 3])),
      );

      expect(result.error, isNull);
      expect(result.warning, isNull);
      expect(repo.uploads.single.id, 50);
      expect(repo.uploads.single.name, 'yo.png');
      expect(provider.items.first.foto, isNotNull);
    });

    test('si la foto falla, el usuario se guarda igual y se avisa', () async {
      final repo = _FakeUserRepository()..photoError = const ValidationFailure('foto inválida');
      final provider = _provider(repo);
      await provider.ensureLoaded();
      repo.saved = userRecordFromJson(_userJson(id: 50));

      final result = await provider.saveUser(
        _validForm,
        photo: (name: 'yo.gif', bytes: Uint8List.fromList([1])),
      );

      expect(result.error, isNull);
      expect(result.warning, contains('JPG, PNG o WEBP de hasta 2 MB'));
      expect(provider.items.first.id, 50);
      expect(provider.items.first.foto, isNull);

      repo.photoError = const ServerFailure('Error del servidor');
      final other = await provider.saveUser(
        _validForm,
        photo: (name: 'yo.png', bytes: Uint8List.fromList([1])),
      );
      expect(other.warning, contains('no se pudo subir la foto'));
    });

    test('la foto se pide una vez por usuario', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);

      expect(await provider.loadPhoto(1), [9, 9]);
      await provider.loadPhoto(1);

      expect(repo.photoCalls, 1);
    });

    test('los catálogos del formulario se piden una vez', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);

      await provider.loadCatalogs();
      await provider.loadCatalogs();

      expect(repo.catalogCalls, 1);
    });

    test('los roles que se pueden asignar dependen del usuario, como en la web', () {
      final provider = _provider(_FakeUserRepository());
      List<String> names(List<UserOption> l) => l.map((r) => r.name).toList();

      // Un Admin de empresa sin permiso de contadores no asigna Ceo, Admin Empresa ni Contador.
      provider.syncSession(_session(roles: const ['Admin Empresa']));
      expect(names(provider.assignableRoles(_roles)), ['Almacenero', 'Cajero', 'Vendedor']);

      // Con el permiso de contadores, también el Contador.
      provider.syncSession(_session(permissions: const {'usuarios.store.contador'}));
      expect(names(provider.assignableRoles(_roles)), ['Contador', 'Almacenero', 'Cajero', 'Vendedor']);

      // El Ceo asigna Ceo y Admin Empresa.
      provider.syncSession(_session(roles: const ['Ceo Empresa'], permissions: const {'usuarios.store.contador'}));
      expect(provider.assignableRoles(_roles), hasLength(6));
    });

    test('crear, renombrar y eliminar roles actualiza la lista', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);
      await provider.loadRoles();

      expect(await provider.saveRole('Supervisor'), isNull);
      expect(provider.roles!.first.name, 'Supervisor');

      repo.roleResult = const UserOption(id: 5, name: 'Almacén central');
      expect(await provider.saveRole('Almacén central', id: 5), isNull);
      expect(provider.roles!.firstWhere((r) => r.id == 5).name, 'Almacén central');

      expect(await provider.deleteRole(5), isNull);
      expect(provider.roles!.any((r) => r.id == 5), false);
      expect(repo.deletedRoles, [5]);
    });

    test('eliminar un rol en uso devuelve el motivo y lo deja', () async {
      final repo = _FakeUserRepository()
        ..deleteError = const ValidationFailure('No se puede eliminar el rol porque está asignado a 2 usuario(s)');
      final provider = _provider(repo);
      await provider.loadRoles();

      final error = await provider.deleteRole(7);

      expect(error, contains('asignado a 2 usuario(s)'));
      expect(provider.roles!.any((r) => r.id == 7), true);
    });

    test('la ubicación se guarda para no pedirla otra vez', () async {
      final repo = _FakeUserRepository();
      final provider = _provider(repo);

      await provider.departments();
      await provider.departments();
      await provider.provincesOf('15');
      await provider.provincesOf('15');
      await provider.districtsOf('1501');

      expect(repo.ubigeoCalls, 3);
    });
  });

  group('Pantalla de usuarios', () {
    testWidgets('lista los usuarios con su código, rol, correo, teléfono, sucursales y estado', (tester) async {
      await _pump(tester, const {'usuarios.index', 'usuarios.update'});

      expect(find.text('Ana Pérez'), findsWidgets);
      expect(find.text('Código: USR001'), findsOneWidget);
      // En pantalla el rol Vendedor se lee "Ejecutivo Comercial".
      expect(find.text('Roles: Ejecutivo Comercial'), findsOneWidget);
      expect(find.text('Correo: ana@acme.pe'), findsOneWidget);
      expect(find.text('Teléfono: 987654321'), findsOneWidget);
      expect(find.text('Sucursales: Principal, Sucursal Norte'), findsOneWidget);
      expect(find.text('Activo'), findsWidgets);
    });

    testWidgets('el Ceo y el Admin de la empresa muestran todas las sucursales', (tester) async {
      final repo = _FakeUserRepository()
        ..page = userPageFromJson({
          'current_page': 1,
          'last_page': 1,
          'total': 1,
          'data': [
            _userJson(roles: [{'id': 2, 'name': 'Ceo Empresa'}]),
          ],
        });
      await _pump(tester, const {'usuarios.index'}, repo: repo);

      expect(find.text('Sucursales: Todos los Almacenes'), findsOneWidget);
    });

    testWidgets('un usuario inactivo se marca como tal', (tester) async {
      final repo = _FakeUserRepository()
        ..page = userPageFromJson({
          'current_page': 1,
          'last_page': 1,
          'total': 1,
          'data': [_userJson(estado: false)],
        });
      await _pump(tester, const {'usuarios.index'}, repo: repo);

      expect(find.text('Inactivo'), findsOneWidget);
    });

    testWidgets('sin el permiso de ver usuarios se avisa y no se pide nada', (tester) async {
      final repo = await _pump(tester, const {});

      expect(find.text('No tienes permiso para ver usuarios.'), findsOneWidget);
      expect(repo.listCalls, isEmpty);
    });

    testWidgets('sin usuarios se muestra el estado vacío', (tester) async {
      final repo = _FakeUserRepository()..page = const UserPageEntity(items: [], currentPage: 1, lastPage: 1, total: 0);
      await _pump(tester, const {'usuarios.index'}, repo: repo);

      expect(find.text('No hay usuarios'), findsOneWidget);
    });

    testWidgets('un error al cargar se ve con el botón Reintentar', (tester) async {
      final repo = _FakeUserRepository()..listError = const NetworkFailure('Sin conexión a internet');
      await _pump(tester, const {'usuarios.index'}, repo: repo);

      expect(find.text('No se pudieron cargar los usuarios'), findsOneWidget);
      expect(find.text('Sin conexión a internet'), findsOneWidget);

      repo.listError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Pérez'), findsWidgets);
    });

    testWidgets('buscar manda el texto al servidor', (tester) async {
      final repo = await _pump(tester, const {'usuarios.index'});

      await tester.enterText(find.byType(SearchBar), 'ana');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(repo.listCalls.last.filters.search, 'ana');
    });

    testWidgets('sin permiso de editar no hay lápiz', (tester) async {
      await _pump(tester, const {'usuarios.index'});
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('con permiso de editar cada tarjeta tiene su lápiz', (tester) async {
      await _pump(tester, const {'usuarios.index', 'usuarios.update'});
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    });

    testWidgets('el panel de filtros aplica estado y rol, y salen como chips', (tester) async {
      final repo = await _pump(tester, const {'usuarios.index'});
      _tall(tester);

      await tester.tap(find.byIcon(Icons.filter_list).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactivos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos').last);
      await tester.pumpAndSettle();
      // El rol Vendedor se ofrece como "Ejecutivo Comercial".
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Ejecutivo Comercial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      final f = repo.listCalls.last.filters;
      expect(f.estado, false);
      expect(f.role, 'Vendedor');
      expect(find.text('Estado: Inactivos'), findsOneWidget);
      expect(find.text('Rol: Ejecutivo Comercial'), findsOneWidget);

      // Quitar un chip vuelve a pedir la lista sin ese filtro.
      await tester.tap(find.byTooltip('Quitar Estado: Inactivos'));
      await tester.pumpAndSettle();
      expect(repo.listCalls.last.filters.estado, isNull);
      expect(repo.listCalls.last.filters.role, 'Vendedor');
    });

    testWidgets('el detalle muestra la ficha, los accesos y los permisos adicionales con su nombre', (tester) async {
      final repo = _FakeUserRepository()
        ..page = userPageFromJson({
          'current_page': 1,
          'last_page': 1,
          'total': 1,
          'data': [
            _userJson(permissions: [
              {'id': 1, 'name': 'clientes.store'},
              {'id': 5, 'name': 'interno.secreto'},
            ]),
          ],
        });
      await _pump(tester, const {'usuarios.index'}, repo: repo);

      await tester.tap(find.text('Ana Pérez').first);
      await tester.pumpAndSettle();

      expect(find.text('USR001'), findsWidgets);
      expect(find.text('ANAPEREZ'), findsOneWidget);
      expect(find.text('Ejecutivo Comercial'), findsOneWidget);

      await tester.tap(find.text('Datos personales'));
      await tester.pumpAndSettle();
      expect(find.text('12345678'), findsOneWidget);
      expect(find.text('28/05/1995'), findsOneWidget);
      expect(find.text('Luis (padre)'), findsOneWidget);

      await tester.tap(find.text('Accesos'));
      await tester.pumpAndSettle();
      expect(find.text('Principal, Sucursal Norte'), findsOneWidget);
      expect(find.text('EFECTIVO'), findsWidgets);
      expect(find.text('Despacho'), findsOneWidget);
      expect(find.text('Crear Cliente'), findsOneWidget);
      // Un permiso que la web no ofrece no se muestra.
      expect(find.text('interno.secreto'), findsNothing);
    });

    testWidgets('sin permiso de editar el detalle no tiene Editar', (tester) async {
      await _pump(tester, const {'usuarios.index'});
      await tester.tap(find.text('Ana Pérez').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Editar'), findsNothing);
      expect(find.text('Cerrar'), findsOneWidget);
    });

    group('Crear y editar', () {
      testWidgets('crear: sin el permiso no hay acción de crear', (tester) async {
        await _pump(tester, const {'usuarios.index'});

        // Solo queda la acción de roles: sale directa.
        expect(find.text('Roles'), findsOneWidget);
        expect(find.byTooltip('Crear usuario'), findsNothing);
      });

      testWidgets('crear: el formulario tiene las dos pestañas de la web y avisa que llega un correo', (tester) async {
        await _openCreate(tester);

        expect(find.text('Crear usuario'), findsWidgets);
        expect(find.text('Datos personales'), findsOneWidget);
        expect(find.text('Accesos y permisos'), findsOneWidget);
        // No pide contraseña: la cuenta se activa con el correo.
        expect(find.textContaining('Contraseña'), findsNothing);
        expect(find.text('Recibirá un correo para activar su cuenta y crear su contraseña.'), findsOneWidget);
        expect(find.text('Tipo de documento'), findsOneWidget);
        expect(find.text('Departamento'), findsOneWidget);
      });

      testWidgets('crear con datos incompletos dice qué falta y no guarda', (tester) async {
        final repo = await _openCreate(tester);

        await tester.tap(find.text('Crear'));
        await tester.pumpAndSettle();

        expect(repo.saves, isEmpty);
        expect(find.textContaining('Completa estos campos:'), findsOneWidget);
        expect(find.textContaining('Nombres'), findsWidgets);
        expect(find.textContaining('Rol en el sistema'), findsWidgets);
      });

      testWidgets('un DNI de menos de 8 dígitos se marca con su motivo', (tester) async {
        final repo = await _openCreate(tester);

        await tester.enterText(find.widgetWithText(TextFormField, 'N° de documento'), '123');
        await tester.tap(find.text('Crear'));
        await tester.pumpAndSettle();

        expect(repo.saves, isEmpty);
        expect(find.text('El DNI tiene 8 dígitos'), findsOneWidget);
      });

      testWidgets('crear un usuario completo lo manda con los campos de la web', (tester) async {
        final repo = await _openCreate(tester);

        await _fillPersonal(tester);
        await tester.tap(find.text('Accesos y permisos'));
        await tester.pumpAndSettle();

        // Rol: Almacenero (no pide métodos de pago ni listas de precios).
        await tester.tap(find.text('Asignar roles'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Almacenero'));
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();
        expect(find.text('Operaciones permitidas'), findsNothing);
        expect(find.text('Listas de precios'), findsNothing);

        // Sucursales y almacén predeterminado.
        await tester.tap(find.text('Elige una o varias'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Principal'));
        await tester.pump();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Sucursal Norte'));
        await tester.pump();
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elige uno'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Sucursal Norte'));
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Crear'));
        await tester.pumpAndSettle();

        expect(repo.saves, hasLength(1));
        final call = repo.saves.single;
        expect(call.id, isNull);
        final f = call.form;
        expect(f.tipoDocumento, 'DNI');
        expect(f.numeroDocumento, '12345678');
        expect(f.nombres, 'Ana');
        expect(f.apellidos, 'Pérez');
        expect(f.fullName, 'Ana Pérez');
        expect(f.telefono, '987654321');
        expect(f.email, 'ana@acme.pe');
        expect(f.cumple, isNotNull);
        expect(f.roles, [5]);
        expect(f.almacenes, [1, 2]);
        expect(f.warehouseId, 2);
        expect(f.estado, true);
        expect(f.conPagos, false);
        expect(f.conListas, false);
        expect(find.text('Usuario creado'), findsOneWidget);
      });

      testWidgets('un Vendedor pide métodos de pago, listas de precios y puede ver ventas ajenas', (tester) async {
        await _openCreate(tester);
        await tester.tap(find.text('Accesos y permisos'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Asignar roles'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Ejecutivo Comercial'));
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();

        expect(find.text('Ver ventas ajenas'), findsOneWidget);
        expect(find.text('Operaciones permitidas'), findsOneWidget);
        expect(find.text('Método de pago predeterminado'), findsOneWidget);
        expect(find.text('Método de entrega predeterminado'), findsOneWidget);
        expect(find.text('Listas de precios'), findsOneWidget);
        expect(find.text('Lista de precios predeterminada'), findsOneWidget);
      });

      testWidgets('un Admin sin ser Ceo no puede asignar Ceo ni Admin Empresa ni Contador', (tester) async {
        await _openCreate(tester, roles: const ['Admin Empresa']);
        await tester.tap(find.text('Accesos y permisos'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Asignar roles'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(CheckboxListTile, 'Almacenero'), findsOneWidget);
        expect(find.widgetWithText(CheckboxListTile, 'Cajero'), findsOneWidget);
        expect(find.widgetWithText(CheckboxListTile, 'Ceo Empresa'), findsNothing);
        expect(find.widgetWithText(CheckboxListTile, 'Admin Empresa'), findsNothing);
        expect(find.widgetWithText(CheckboxListTile, 'Contador'), findsNothing);
      });

      testWidgets('los permisos adicionales se eligen agrupados por módulo y con búsqueda', (tester) async {
        await _openCreate(tester);
        await tester.tap(find.text('Accesos y permisos'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ninguno'));
        await tester.pumpAndSettle();

        // Los módulos como encabezados y cada permiso con su nombre; el que la web no ofrece no sale.
        expect(find.text('Clientes'), findsOneWidget);
        expect(find.text('Documentos'), findsOneWidget);
        expect(find.text('Ajustes'), findsOneWidget);
        expect(find.text('Crear Cliente'), findsOneWidget);
        expect(find.text('Ver Página Clientes'), findsOneWidget);
        expect(find.text('interno.secreto'), findsNothing);

        await tester.enterText(find.byType(TextField).last, 'pagina cli');
        await tester.pumpAndSettle();
        expect(find.text('Ver Página Clientes'), findsOneWidget);
        expect(find.text('Crear Cliente'), findsNothing);
        expect(find.text('Documentos'), findsNothing);

        await tester.tap(find.text('Ver Página Clientes'));
        await tester.pumpAndSettle();
        expect(find.text('1 elegidos'), findsOneWidget);
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();

        expect(find.text('1 permiso'), findsOneWidget);
      });

      testWidgets('un error del servidor se ve en el formulario y no lo cierra', (tester) async {
        final repo = await _openCreate(tester);
        repo.saveError = const ValidationFailure('El correo ya está en uso');

        await _fillPersonal(tester);
        await tester.tap(find.text('Accesos y permisos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Asignar roles'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Almacenero'));
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elige una o varias'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Principal'));
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elige uno'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Principal'));
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Crear'));
        await tester.pumpAndSettle();

        expect(repo.saves, hasLength(1));
        expect(find.text('El correo ya está en uso'), findsOneWidget);
        expect(find.text('Datos personales'), findsOneWidget);
      });

      testWidgets('editar trae los datos del usuario y no deja guardar hasta cambiar algo', (tester) async {
        final repo = await _pump(tester, const {'usuarios.index', 'usuarios.update'});
        _tall(tester);

        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();

        expect(find.text('Editar usuario'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Nombres'), findsOneWidget);
        expect(find.text('Ana'), findsOneWidget);
        expect(find.text('12345678'), findsOneWidget);
        expect(find.text('28/05/1995'), findsOneWidget);
        // Al editar no se avisa del correo de activación.
        expect(find.textContaining('Recibirá un correo'), findsNothing);

        // Sin cambios el botón está apagado.
        final save = find.widgetWithText(FilledButton, 'Guardar');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);

        await tester.enterText(find.widgetWithText(TextFormField, 'Nombres'), 'Ana María');
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(repo.saves, hasLength(1));
        expect(repo.saves.single.id, 1);
        final f = repo.saves.single.form;
        expect(f.nombres, 'Ana María');
        expect(f.roles, [7]);
        expect(f.almacenes, [1, 2]);
        expect(f.warehouseId, 1);
        expect(f.esVendedor, true);
        expect(f.conPagos, true);
        expect(f.paymentMethodId, 1);
        expect(f.listPriceId, 1);
        expect(f.metodoEntrega, 'd');
        expect(find.text('Usuario editado'), findsOneWidget);
      });

      testWidgets('editar conserva los permisos que la web no ofrece', (tester) async {
        final repo = _FakeUserRepository()
          ..page = userPageFromJson({
            'current_page': 1,
            'last_page': 1,
            'total': 1,
            'data': [
              _userJson(permissions: [
                {'id': 2, 'name': 'clientes.index'},
                {'id': 5, 'name': 'interno.secreto'},
              ]),
            ],
          });
        await _pump(tester, const {'usuarios.index', 'usuarios.update'}, repo: repo);
        _tall(tester);

        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accesos y permisos'));
        await tester.pumpAndSettle();
        // Solo cuenta el permiso que se ve.
        expect(find.text('1 permiso'), findsOneWidget);

        await tester.tap(find.byTooltip('Quitar').last);
        await tester.pumpAndSettle();
        expect(find.text('Ninguno'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        await tester.pumpAndSettle();

        // Se quitó el visible (2) pero el oculto (5) se manda igual.
        expect(repo.saves.single.form.permisos, [5]);
      });

      testWidgets('una foto que falla avisa, pero el usuario se guardó', (tester) async {
        // La foto se prueba en el provider; aquí solo se comprueba que el aviso se muestra.
        final repo = _FakeUserRepository()..photoError = const ServerFailure('Error del servidor');
        await _pump(tester, const {'usuarios.index', 'usuarios.update'}, repo: repo);
        _tall(tester);
        final provider = tester.element(find.byType(UsersPage)).read<UsersProvider>();

        final result = await provider.saveUser(
          _validForm,
          id: 1,
          photo: (name: 'a.png', bytes: Uint8List.fromList([1])),
        );

        expect(result.error, isNull);
        expect(result.warning, contains('no se pudo subir la foto'));
      });
    });

    group('En tablet', () {
      void tablet(WidgetTester tester) {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      testWidgets('sin selección el panel pide elegir un usuario', (tester) async {
        tablet(tester);
        await _pump(tester, const {'usuarios.index'});

        expect(find.text('Selecciona un usuario'), findsOneWidget);
      });

      testWidgets('tocar un usuario muestra su detalle a la derecha, sin modal', (tester) async {
        tablet(tester);
        await _pump(tester, const {'usuarios.index', 'usuarios.update'});

        await tester.tap(find.text('Ana Pérez').first);
        await tester.pumpAndSettle();

        expect(find.text('Selecciona un usuario'), findsNothing);
        expect(find.text('ANAPEREZ'), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Editar'), findsOneWidget);
      });
    });

    group('Roles', () {
      testWidgets('lista los roles y "Vendedor" se lee Ejecutivo Comercial', (tester) async {
        await _pump(tester, const {'usuarios.index'});
        _tall(tester);
        await tester.tap(find.text('Roles'));
        await tester.pumpAndSettle();

        expect(find.text('Gestión de roles'), findsOneWidget);
        expect(find.text('Almacenero'), findsOneWidget);
        expect(find.text('Ejecutivo Comercial'), findsOneWidget);
        // Sin permisos de crear, editar ni eliminar no hay acciones.
        expect(find.text('Nuevo rol'), findsNothing);
        expect(find.byTooltip('Editar'), findsNothing);
        expect(find.byTooltip('Eliminar'), findsNothing);
      });

      testWidgets('crear un rol lo manda y aparece en la lista', (tester) async {
        final repo = await _pump(tester, const {'usuarios.index', 'usuarios.store'});
        await tester.tap(find.text('Acciones'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Roles'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Nuevo rol'));
        await tester.pumpAndSettle();
        // Sin nombre no guarda.
        await tester.tap(find.text('Crear rol'));
        await tester.pumpAndSettle();
        expect(find.text('El nombre es requerido'), findsOneWidget);
        expect(repo.savedRoles, isEmpty);

        await tester.enterText(find.widgetWithText(TextFormField, 'Nombre del rol'), 'Supervisor');
        await tester.tap(find.text('Crear rol'));
        await tester.pumpAndSettle();

        expect(repo.savedRoles.single, (name: 'Supervisor', id: null));
        expect(find.text('Supervisor'), findsOneWidget);
      });

      testWidgets('renombrar un rol con el permiso de actualizar', (tester) async {
        final repo = await _pump(tester, const {'usuarios.index', 'usuarios.update'});
        _tall(tester);
        await tester.tap(find.text('Roles'));
        await tester.pumpAndSettle();

        // Hay un lápiz por cada usuario detrás del modal: el del rol es el último.
        await tester.tap(find.byTooltip('Editar').last);
        await tester.pumpAndSettle();
        expect(find.text('Editar rol'), findsOneWidget);
        await tester.enterText(find.widgetWithText(TextFormField, 'Nombre del rol'), 'Jefe');
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();

        expect(repo.savedRoles.single.id, 7);
        expect(repo.savedRoles.single.name, 'Jefe');
      });

      testWidgets('eliminar pide confirmación; un rol en uso muestra el motivo', (tester) async {
        final repo = await _pump(tester, const {'usuarios.index', 'usuarios.destroy'});
        repo.deleteError = const ValidationFailure('No se puede eliminar el rol porque está asignado a 2 usuario(s)');
        _tall(tester);
        await tester.tap(find.text('Roles'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Eliminar').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('¿Estás seguro de eliminar el rol'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
        await tester.pumpAndSettle();

        expect(repo.deletedRoles, [2]);
        expect(find.textContaining('asignado a 2 usuario(s)'), findsOneWidget);
        expect(find.text('Ceo Empresa'), findsOneWidget);

        // Sin el error se elimina de verdad.
        repo.deleteError = null;
        await tester.tap(find.byTooltip('Eliminar').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
        await tester.pumpAndSettle();
        expect(find.text('Ceo Empresa'), findsNothing);
      });
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

UsersProvider _provider(_FakeUserRepository repo, {VoidCallback? onExpired}) => UsersProvider(
      getUsersUseCase: GetUsersUseCase(repository: repo),
      getCatalogsUseCase: GetUserCatalogsUseCase(repository: repo),
      saveUserUseCase: SaveUserUseCase(repository: repo),
      uploadPhotoUseCase: UploadUserPhotoUseCase(repository: repo),
      getPhotoUseCase: GetUserPhotoUseCase(repository: repo),
      getRolesUseCase: GetRolesUseCase(repository: repo),
      saveRoleUseCase: SaveRoleUseCase(repository: repo),
      deleteRoleUseCase: DeleteRoleUseCase(repository: repo),
      getDepartmentsUseCase: GetUserDepartmentsUseCase(repository: repo),
      getProvincesUseCase: GetUserProvincesUseCase(repository: repo),
      getDistrictsUseCase: GetUserDistrictsUseCase(repository: repo),
      onSessionExpired: onExpired,
    )..syncSession(_session());

class _FakeUserRepository implements UserRecordRepository {
  final List<({int page, UserFiltersEntity filters})> listCalls = [];
  final List<({int companyId, UserFormEntity form, int? id})> saves = [];
  final List<({int id, String name})> uploads = [];
  final List<({String name, int? id})> savedRoles = [];
  final List<int> deletedRoles = [];
  int catalogCalls = 0;
  int photoCalls = 0;
  int ubigeoCalls = 0;

  UserPageEntity page = userPageFromJson(_pageJson(page: 1, last: 2));
  UserRecordEntity? saved;
  Failure? listError;
  Failure? saveError;
  Failure? photoError;
  Failure? deleteError;
  UserOption? roleResult;
  List<UserOption> roles = [..._roles];

  @override
  Future<Either<Failure, UserPageEntity>> getUsers({
    required int companyId,
    required int page,
    required int pageSize,
    required UserFiltersEntity filters,
  }) async {
    listCalls.add((page: page, filters: filters));
    if (listError != null) return Either.left(listError!);
    if (page == 1) return Either.right(this.page);
    return Either.right(userPageFromJson(_pageJson(page: page, last: 2)));
  }

  @override
  Future<Either<Failure, UserCatalogsEntity>> getCatalogs({required int companyId}) async {
    catalogCalls++;
    return Either.right(_catalogs);
  }

  @override
  Future<Either<Failure, UserRecordEntity>> saveUser({
    required int companyId,
    required UserFormEntity form,
    int? id,
  }) async {
    saves.add((companyId: companyId, form: form, id: id));
    if (saveError != null) return Either.left(saveError!);
    return Either.right(saved ?? userRecordFromJson(_userJson(id: id ?? 99)));
  }

  @override
  Future<Either<Failure, void>> uploadPhoto({required int id, required Uint8List bytes, required String name}) async {
    uploads.add((id: id, name: name));
    if (photoError != null) return Either.left(photoError!);
    return Either.rightVoid();
  }

  @override
  Future<Either<Failure, Uint8List?>> getPhoto(int id) async {
    photoCalls++;
    return Either.right(Uint8List.fromList([9, 9]));
  }

  @override
  Future<Either<Failure, List<UserOption>>> getRoles() async => Either.right([...roles]);

  @override
  Future<Either<Failure, UserOption>> saveRole({required String name, int? id}) async {
    savedRoles.add((name: name, id: id));
    return Either.right(roleResult ?? UserOption(id: id ?? 100, name: name));
  }

  @override
  Future<Either<Failure, void>> deleteRole(int id) async {
    deletedRoles.add(id);
    if (deleteError != null) return Either.left(deleteError!);
    roles = [for (final r in roles) if (r.id != id) r];
    return Either.rightVoid();
  }

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDepartments() async {
    ubigeoCalls++;
    return Either.right(const [UbigeoItemEntity(id: '15', name: 'LIMA')]);
  }

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getProvinces(String departmentId) async {
    ubigeoCalls++;
    return Either.right([UbigeoItemEntity(id: '${departmentId}01', name: 'PROVINCIA $departmentId')]);
  }

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDistricts(String provinceId) async {
    ubigeoCalls++;
    return Either.right([UbigeoItemEntity(id: '${provinceId}01', name: 'DISTRITO $provinceId')]);
  }
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
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<_FakeUserRepository> _pump(
  WidgetTester tester,
  Set<String> permissions, {
  List<String> roles = const [],
  _FakeUserRepository? repo,
}) async {
  repo ??= _FakeUserRepository();
  final session = _session(permissions: permissions, roles: roles);
  final provider = _provider(repo)..syncSession(session);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
        ChangeNotifierProvider<UsersProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: UsersPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Abre el formulario de crear usuario (con los permisos de ver y crear).
Future<_FakeUserRepository> _openCreate(WidgetTester tester, {List<String> roles = const []}) async {
  final repo = await _pump(tester, const {'usuarios.index', 'usuarios.store'}, roles: roles);
  // Con dos acciones (crear y roles) salen dentro de "Acciones".
  await tester.tap(find.text('Acciones'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Crear usuario'));
  await tester.pumpAndSettle();
  // El formulario es largo y la prueba no desplaza: se agranda la pantalla ya abierto el modal.
  _tall(tester);
  await tester.pumpAndSettle();
  return repo;
}

/// Llena la pestaña Datos personales con lo mínimo que pide la web.
Future<void> _fillPersonal(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'N° de documento'), '12345678');
  await tester.enterText(find.widgetWithText(TextFormField, 'Nombres'), 'Ana');
  await tester.enterText(find.widgetWithText(TextFormField, 'Apellidos'), 'Pérez');
  await tester.enterText(find.widgetWithText(TextFormField, 'Celular'), '987654321');
  await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'ana@acme.pe');
  await tester.tap(find.text('Elige la fecha'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
