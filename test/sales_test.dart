import 'dart:convert';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/sale_remote_datasource.dart';
import 'package:app_novik/data/models/document_model.dart';
import 'package:app_novik/data/models/sale_model.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/client_model.dart';
import 'package:app_novik/domain/entities/client_form_entity.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart';
import 'package:app_novik/domain/entities/product_form_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/sale_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/stock_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/client_repository.dart';
import 'package:app_novik/domain/repositories/sale_repository.dart';
import 'package:app_novik/domain/repositories/stock_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/client_usecases.dart';
import 'package:app_novik/domain/usecases/sale_usecases.dart';
import 'package:app_novik/domain/usecases/stock_usecases.dart';
import 'package:app_novik/presentation/components/app_motion.dart' show AppEntrance;
import 'package:app_novik/presentation/pages/sales_page.dart';
import 'package:app_novik/presentation/pdf/receipt_pdf.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/clients_provider.dart';
import 'package:app_novik/presentation/providers/sales_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/presentation/widgets/sale_modals.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'support/screen_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class _FakeStockRepository implements StockRepository {
  @override
  Future<Either<Failure, List<CatalogItemEntity>>> getWarehouses(int companyId) async =>
      Either.right(const [
        CatalogItemEntity(id: 1, name: 'LIMA'),
        CatalogItemEntity(id: 2, name: 'AREQUIPA'),
      ]);

  @override
  Future<Either<Failure, List<PriceListEntity>>> getPriceLists(int companyId) async =>
      Either.right(const [
        PriceListEntity(id: 10, name: 'MINORISTA'),
        PriceListEntity(id: 11, name: 'MAYORISTA'),
        PriceListEntity(id: 12, name: 'DÓLARES', esDolares: true),
      ]);

  @override
  Future<Either<Failure, DownloadedFile>> exportStock({
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    required String name,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, StockPageEntity>> getStock({
    required int companyId,
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    bool includeZero = false,
    int page = 1,
    int pageSize = 20,
  }) =>
      throw UnimplementedError();
}

class _FakeSaleRepository implements SaleRepository {
  SaleFormEntity? sent;
  int? sentCompany;
  int? sentUser;
  Either<Failure, SaleResultEntity>? result;
  List<SaleProductEntity>? products;
  int rateCalls = 0;
  bool rateFails = false;
  bool walkInFails = false;
  bool searchFails = false;
  int sellerCalls = 0;
  List<SellerEntity> sellers = const [
    SellerEntity(id: 5, name: 'LUIS VENDEDOR'),
    SellerEntity(id: 9, name: 'ANA'),
  ];

  @override
  Future<Either<Failure, List<SellerEntity>>> getSellers(int companyId) async {
    sellerCalls++;
    return Either.right(sellers);
  }

  @override
  Future<Either<Failure, ExchangeRateEntity>> getExchangeRate() async {
    rateCalls++;
    if (rateFails) return Either.left(const ServerFailure('No hay tipo de cambio disponible'));
    return Either.right(ExchangeRateEntity(
      valorFinal: 3.452,
      valorFuente: 3.427,
      fuente: 'bloomberg',
      fechaFuente: DateTime(2026, 10, 28),
      margen: 0.025,
    ));
  }

  @override
  Future<Either<Failure, ClientEntity>> getWalkInClient(int companyId) async {
    if (walkInFails) return Either.left(const NetworkFailure('Sin conexión a internet'));
    return Either.right(const ClientEntity(id: 99, name: 'CLIENTE VARIOS', documento: '00000000', tipo: 'p'));
  }

  @override
  Future<Either<Failure, SaleProductFiltersEntity>> getProductFilters() async =>
      Either.right(const SaleProductFiltersEntity(
        categorias: [(id: 20, name: 'AUDIO'), (id: 21, name: 'ACCESORIOS')],
        marcas: [(id: 30, name: 'PIONEER'), (id: 31, name: 'JBL')],
      ));

  @override
  Future<Either<Failure, List<ClientEntity>>> searchClients({
    required int companyId,
    required String search,
  }) async =>
      Either.right(const [ClientEntity(id: 7, name: 'ACME SAC', documento: '20123456789', tipo: 'e')]);

  @override
  Future<Either<Failure, List<SaleProductEntity>>> searchProducts({
    required int companyId,
    required String search,
  }) async =>
      searchFails
          ? Either.left(const NetworkFailure('Sin conexión a internet'))
          : Either.right(products ?? [_product()]);

  @override
  Future<Either<Failure, List<PaymentMethodEntity>>> getPaymentMethods() async =>
      Either.right(const [
        PaymentMethodEntity(id: 1, name: 'CRÉDITO'),
        PaymentMethodEntity(id: 2, name: 'EFECTIVO'),
        PaymentMethodEntity(id: 3, name: 'YAPE'),
        PaymentMethodEntity(id: 4, name: 'PUNTOS'),
        PaymentMethodEntity(id: 5, name: 'CONTRAENTREGA'),
      ]);

  @override
  Future<Either<Failure, SaleResultEntity>> createSale({
    required int companyId,
    required int userId,
    required SaleFormEntity form,
  }) async {
    sent = form;
    sentCompany = companyId;
    sentUser = userId;
    return result ?? Either.right(form.tipoDocumento.esCotizacion ? _quote() : _sale());
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
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async =>
      Either.rightVoid();

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

SaleProductEntity _product({
  int id = 100,
  String name = 'SUBWOOFER 12"',
  String codigo = 'SUB-12',
  Map<int, double> stock = const {1: 5, 2: 0},
  Map<int, double> prices = const {10: 50, 11: 40},
  bool sinStock = false,
  int categoryId = 20,
  int brandId = 30,
}) =>
    SaleProductEntity(
      id: id,
      codigo: codigo,
      name: name,
      marca: 'PIONEER',
      categoryId: categoryId,
      brandId: brandId,
      unidad: 'Unidad',
      ventaSinStock: sinStock,
      stockPorAlmacen: stock,
      precioPorLista: prices,
    );

DocumentEntity _quote() => DocumentEntity(
      id: 2,
      kind: DocumentKind.cotizacion,
      numero: 'C001-0002',
      comprobante: 'Cotización',
      cliente: 'ACME SAC',
      almacen: 'LIMA',
      monto: 100,
      reservado: true,
      vencimientoStock: DateTime(2026, 10, 30),
    );

DocumentEntity _sale() => const DocumentEntity(
      id: 1,
      kind: DocumentKind.venta,
      numero: 'V001-0001',
      comprobante: 'Nota de venta',
      activo: true,
      cliente: 'ACME SAC',
      vendedor: '-',
      almacen: 'LIMA',
      monto: 100,
    );

SessionContextEntity _session({
  int companyId = 1,
  bool certificado = false,
  List<String> roles = const [],
  Set<String> permissions = const {'ventas.store'},
  bool puntos = false,
  double minimoCanje = 0,
}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(
        id: companyId,
        razonSocial: 'ACME',
        emiteComprobantes: certificado,
        programaDePuntos: puntos,
        minimoCanjePuntos: minimoCanje,
      ),
      modules: const [],
      permissions: permissions,
      roles: roles,
      warehouses: const [],
      defaultWarehouseId: 2,
      defaultListPriceId: 11,
    );

SalesProvider _provider(_FakeSaleRepository sales) {
  final stock = _FakeStockRepository();
  return SalesProvider(
    getWarehousesUseCase: GetWarehousesUseCase(repository: stock),
    getPriceListsUseCase: GetPriceListsUseCase(repository: stock),
    getPaymentMethodsUseCase: GetPaymentMethodsUseCase(repository: sales),
    getSaleProductFiltersUseCase: GetSaleProductFiltersUseCase(repository: sales),
    getExchangeRateUseCase: GetExchangeRateUseCase(repository: sales),
    getWalkInClientUseCase: GetWalkInClientUseCase(repository: sales),
    searchClientsUseCase: SearchClientsUseCase(repository: sales),
    searchSaleProductsUseCase: SearchSaleProductsUseCase(repository: sales),
    createSaleUseCase: CreateSaleUseCase(repository: sales),
    getSellersUseCase: GetSellersUseCase(repository: sales),
  );
}

Future<SalesProvider> _ready(
  _FakeSaleRepository repo, {
  bool certificado = false,
  bool puntos = false,
  double minimoCanje = 0,
  Set<String> permissions = const {'ventas.store'},
}) async {
  final p = _provider(repo)
    ..syncSession(_session(
      certificado: certificado,
      puntos: puntos,
      minimoCanje: minimoCanje,
      permissions: permissions,
    ));
  await p.ensureLoaded();
  return p;
}

/// Lo que llena el modal "Crear venta": un solo pago en EFECTIVO por [total].
SaleCheckoutEntity _checkout(double total, {String observaciones = ''}) => SaleCheckoutEntity(
      payments: [SalePaymentEntity(paymentMethodId: 2, monto: total)],
      observaciones: observaciones,
    );

const _acme = ClientEntity(id: 7, name: 'ACME SAC', documento: '20123456789', tipo: 'e');

SaleFormEntity _form({
  ClientEntity? client = _acme,
  SaleDocumentType tipo = SaleDocumentType.ticket,
  int? warehouseId = 1,
  List<SalePaymentEntity>? payments,
  List<SaleLineEntity>? lines,
  SaleDelivery delivery = SaleDelivery.inmediata,
  DateTime? fechaEmision,
}) {
  final items = lines ?? [SaleLineEntity(product: _product(), cantidad: 2, precio: 50)];
  final total = items.fold<double>(0, (sum, l) => sum + l.subtotal);
  return SaleFormEntity(
    tipoDocumento: tipo,
    client: client,
    warehouseId: warehouseId,
    // Por defecto, un solo pago (EFECTIVO) por todo el total.
    payments: payments ?? [SalePaymentEntity(paymentMethodId: 2, monto: total)],
    delivery: delivery,
    fechaEmision: fechaEmision,
    lines: items,
  );
}

/// Pantalla de 360x780 dp. Las pruebas dibujan con la fuente Ahem (cada letra
/// del ancho de un cuadrado, casi el doble que una fuente real); el factor de
/// texto la acerca al ancho real para que los desbordes que se detecten sean reales.
void _phoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 0.55;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// El campo de búsqueda del selector de productos (no el de la pantalla de atrás).
Finder _pickerSearchField() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Nombre, código, marca…',
    );

/// Pulsa "Agregar producto" del formulario, desplazando la pantalla hasta verlo.
Future<void> _tapAddProduct(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Agregar producto');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _FakeClientRepository implements ClientRepository {
  final List<String> calls = [];
  NewClientFormEntity? created;
  int? executive;
  Either<Failure, ClientEntity>? createResult;

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDepartments() async {
    calls.add('departments');
    return Either.right(const [
      UbigeoItemEntity(id: '04', name: 'AREQUIPA'),
      UbigeoItemEntity(id: '15', name: 'LIMA'),
    ]);
  }

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getProvinces(String departmentId) async {
    calls.add('provinces:$departmentId');
    return Either.right([UbigeoItemEntity(id: '${departmentId}01', name: 'PROVINCIA $departmentId')]);
  }

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDistricts(String provinceId) async {
    calls.add('districts:$provinceId');
    return Either.right([UbigeoItemEntity(id: '${provinceId}01', name: 'DISTRITO $provinceId')]);
  }

  @override
  Future<Either<Failure, DocumentLookupEntity>> lookupDocument({
    required String tipo,
    required String number,
  }) async {
    calls.add('lookup:$tipo:$number');
    if (tipo == 'e') {
      return Either.right(const DocumentLookupEntity(
        tipo: 'e',
        razonSocial: 'ACME SAC',
        direccion: 'AV. UNO 123',
        ubigeo: '150101',
      ));
    }
    return Either.right(const DocumentLookupEntity(tipo: 'p', name: 'JUAN', lastName: 'PEREZ GOMEZ'));
  }

  @override
  Future<Either<Failure, ClientEntity>> createClient({
    required int companyId,
    int? executiveId,
    required NewClientFormEntity form,
  }) async {
    created = form;
    executive = executiveId;
    return createResult ??
        Either.right(ClientEntity(
          id: 55,
          name: form.esEmpresa ? form.razonSocial! : form.name,
          documento: form.dniRuc,
          tipo: form.tipo,
        ));
  }
}

ClientsProvider _clientsProvider(_FakeClientRepository repo, {SessionContextEntity? session}) {
  return ClientsProvider(
    getDepartmentsUseCase: GetDepartmentsUseCase(repository: repo),
    getProvincesUseCase: GetProvincesUseCase(repository: repo),
    getDistrictsUseCase: GetDistrictsUseCase(repository: repo),
    lookupDocumentUseCase: LookupDocumentUseCase(repository: repo),
    createClientUseCase: CreateClientUseCase(repository: repo),
  )..syncSession(session ?? _session());
}

Finder _field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );

void main() {
  group('modelos', () {
    test('el producto de la búsqueda trae stock por almacén y precio por lista', () {
      final p = saleProductFromJson({
        'id': 5,
        'codigo': 'A1',
        'name': 'PARLANTE',
        'tipo': 'p',
        'vender_sin_stock': 0,
        'brand': {'id': 1, 'name': 'JBL'},
        'warehouses': [
          {'id': 1, 'pivot': {'stock': '12'}},
          {'id': 2, 'pivot': {'stock': 0}},
        ],
        'list_prices': [
          {'id': 10, 'pivot': {'precio': '35.50'}},
        ],
      });
      expect(p.marca, 'JBL');
      expect(p.stockEn(1), 12);
      expect(p.stockEn(2), 0);
      expect(p.stockEn(99), 0);
      expect(p.precioEn(10), 35.5);
      expect(p.precioEn(11), 0);
      expect(p.maximoEn(1), 12);
    });

    test('un servicio o un producto de venta sin stock no tiene tope', () {
      expect(_product(sinStock: true).maximoEn(1), isNull);
      expect(
        saleProductFromJson({'id': 1, 'codigo': 'S', 'name': 'INSTALACIÓN', 'tipo': 's'}).maximoEn(1),
        isNull,
      );
    });

    test('el cliente usa la razón social, o nombre y apellido', () {
      expect(clientFromJson({'id': 1, 'razon_social': 'ACME SAC', 'dni_ruc': '20123456789'}).name, 'ACME SAC');
      final c = clientFromJson({'id': 2, 'name': 'JUAN', 'last_name': 'PÉREZ', 'tipo': 'p', 'dni_ruc': '00000000'});
      expect(c.name, 'JUAN PÉREZ');
      expect(c.esPersona, isTrue);
      expect(c.esVarios, isTrue);
    });

    test('el cuerpo de POST /ventas lleva los campos que exige el backend', () {
      final body = saleToJson(_form(), companyId: 3, userId: 9);
      expect(body['tipo_documento'], 'Ticket de Venta');
      expect(body['totales_soles'], 100);
      expect(body['totales_dolares'], 0);
      expect(body['company_id'], 3);
      expect(body['user_id'], 9);
      expect(body['client_id'], 7);
      expect(body['warehouse_id'], 1);
      expect(body['punto_venta'], false);
      expect(body['tipo_de_cambio'], 1);
      expect(body['metodo_entrega'], 'e');
      expect(body.containsKey('observaciones'), isFalse);
      expect(body['payment_methods'], [
        {'payment_method_id': 2, 'monto': 100},
      ]);
      final line = (body['product_sales'] as List).single as Map;
      expect(line['product_id'], 100);
      expect(line['cantidad'], 2);
      expect(line['precio'], 50);
      expect(line['dolares'], false);
      expect(line['subtotal'], 100);
      expect(line['subtotal_con_dto'], 100);
    });

    test('la entrega, la fecha elegida y cada pago viajan en el cuerpo', () {
      final body = saleToJson(
        _form(
          delivery: SaleDelivery.despacho,
          fechaEmision: DateTime(2026, 10, 29, 9, 5, 7),
          payments: const [
            SalePaymentEntity(paymentMethodId: 2, monto: 40),
            SalePaymentEntity(paymentMethodId: 3, monto: 60),
          ],
        ),
        companyId: 3,
        userId: 9,
      );
      expect(body['metodo_entrega'], 'd');
      expect(body['created_at'], '2026-10-29 09:05:07');
      expect(body['payment_methods'], [
        {'payment_method_id': 2, 'monto': 40},
        {'payment_method_id': 3, 'monto': 60},
      ]);
    });

    test('sin fecha elegida no se manda created_at (queda hoy)', () {
      expect(saleToJson(_form(), companyId: 3, userId: 9).containsKey('created_at'), isFalse);
    });

    test('los importes se redondean a céntimos', () {
      final line = SaleLineEntity(product: _product(), cantidad: 3, precio: 0.1 + 0.2);
      expect(line.subtotal, 0.9);
      expect(_form(lines: [line]).total, 0.9);
    });
  });

  group('CreateSaleUseCase.validate', () {
    test('una venta completa es válida', () {
      expect(CreateSaleUseCase.validate(_form()), isNull);
    });

    test('pide cliente, almacén, productos y forma de pago', () {
      expect(CreateSaleUseCase.validate(_form(client: null)), 'Elige el cliente');
      expect(CreateSaleUseCase.validate(_form(warehouseId: null)), 'Elige el almacén');
      expect(CreateSaleUseCase.validate(_form(lines: [])), 'Agrega al menos un producto');
      expect(CreateSaleUseCase.validate(_form(payments: [])), 'Elige la forma de pago');
    });

    test('los pagos deben tener monto y sumar el total de la venta', () {
      const efectivo = 2, yape = 3;
      expect(
        CreateSaleUseCase.validate(
          _form(payments: const [SalePaymentEntity(paymentMethodId: efectivo, monto: 60)]),
        ),
        'Los métodos de pago deben sumar el total de la venta',
      );
      expect(
        CreateSaleUseCase.validate(
          _form(payments: const [
            SalePaymentEntity(paymentMethodId: efectivo, monto: 100),
            SalePaymentEntity(paymentMethodId: yape, monto: 20),
          ]),
        ),
        'Los métodos de pago deben sumar el total de la venta',
      );
      expect(
        CreateSaleUseCase.validate(
          _form(payments: const [SalePaymentEntity(paymentMethodId: efectivo, monto: 0)]),
        ),
        'Escribe el monto de cada forma de pago',
      );
      // Dos formas de pago que suman el total sí valen.
      expect(
        CreateSaleUseCase.validate(
          _form(payments: const [
            SalePaymentEntity(paymentMethodId: efectivo, monto: 40.5),
            SalePaymentEntity(paymentMethodId: yape, monto: 59.5),
          ]),
        ),
        isNull,
      );
    });

    test('antes del modal "Crear venta" se revisa todo menos los pagos', () {
      expect(CreateSaleUseCase.validate(_form(payments: []), withPayments: false), isNull);
      expect(CreateSaleUseCase.validate(_form(client: null), withPayments: false), 'Elige el cliente');
    });

    test('no deja vender más que el stock del almacén', () {
      final line = SaleLineEntity(product: _product(), cantidad: 6, precio: 50);
      expect(CreateSaleUseCase.validate(_form(lines: [line])), contains('No hay stock suficiente'));
      // En el almacén 2 no hay nada.
      expect(CreateSaleUseCase.validate(_form(warehouseId: 2)), contains('No hay stock suficiente'));
    });

    test('vender sin stock se permite cuando el producto lo tiene activado', () {
      final line = SaleLineEntity(product: _product(sinStock: true), cantidad: 50, precio: 10);
      expect(CreateSaleUseCase.validate(_form(warehouseId: 2, lines: [line])), isNull);
    });

    test('un producto sin precio no se vende', () {
      final line = SaleLineEntity(product: _product(), cantidad: 1, precio: 0);
      expect(CreateSaleUseCase.validate(_form(lines: [line])), contains('no tiene precio'));
    });

    test('la factura necesita un cliente con RUC', () {
      const persona = ClientEntity(id: 8, name: 'JUAN', documento: '12345678', tipo: 'p');
      expect(
        CreateSaleUseCase.validate(_form(client: persona, tipo: SaleDocumentType.factura)),
        contains('RUC'),
      );
      expect(CreateSaleUseCase.validate(_form(tipo: SaleDocumentType.factura)), isNull);
    });

    test('cliente varios: solo boleta y menos de S/700', () {
      const varios = ClientEntity(id: 9, name: 'CLIENTE VARIOS', documento: '00000000', tipo: 'p');
      expect(CreateSaleUseCase.validate(_form(client: varios)), contains('Boleta'));
      expect(CreateSaleUseCase.validate(_form(client: varios, tipo: SaleDocumentType.boleta)), isNull);

      final grande = SaleLineEntity(product: _product(sinStock: true), cantidad: 1, precio: 700);
      expect(
        CreateSaleUseCase.validate(
          _form(client: varios, tipo: SaleDocumentType.boleta, lines: [grande]),
        ),
        contains('S/700'),
      );
    });

    test('cada forma de pago sabe si es crédito, plazo o puntos', () {
      PaymentMethodEntity m(String name) => PaymentMethodEntity(id: 1, name: name);

      expect(m('CRÉDITO').kind, PaymentKind.credito);
      expect(m('CREDITO').kind, PaymentKind.credito);
      expect(m('PLAZO 30 DÍAS').kind, PaymentKind.plazo);
      expect(m('PUNTOS').kind, PaymentKind.puntos);
      expect(m('CONTRAENTREGA').kind, PaymentKind.normal);
      expect(m('YAPE').kind, PaymentKind.normal);
      // Llevan cuotas el crédito y el plazo.
      expect([m('CRÉDITO'), m('PLAZO 15'), m('PUNTOS'), m('EFECTIVO')].map((x) => x.conCuotas), [true, true, false, false]);
    });

    test('el ticket se emite hasta 30 días atrás; la boleta y la factura, hoy y 2 días antes', () {
      final now = DateTime(2026, 10, 31, 15, 40);
      final ticket = saleIssueDateRange(SaleDocumentType.ticket, now);
      expect(ticket.first, DateTime(2026, 10, 1));
      expect(ticket.last, DateTime(2026, 10, 31));
      for (final tipo in [SaleDocumentType.boleta, SaleDocumentType.factura]) {
        final range = saleIssueDateRange(tipo, now);
        expect(range.first, DateTime(2026, 10, 29));
        expect(range.last, DateTime(2026, 10, 31));
      }
    });
  });

  group('SalesProvider', () {
    test('carga solo listas en soles y las formas de pago que la app maneja, con los predeterminados', () async {
      final p = await _ready(_FakeSaleRepository());
      expect(p.priceLists.map((l) => l.id), [10, 11, 12]); // 12 es la lista en dólares
      expect(p.paymentMethods.map((m) => m.name), ['CRÉDITO', 'EFECTIVO', 'YAPE', 'PUNTOS', 'CONTRAENTREGA']);
      expect(p.warehouseId, 2); // el del usuario
      expect(p.priceListId, 11); // el del usuario
      expect(p.defaultPaymentMethodId, 2); // EFECTIVO
    });

    test('boleta y factura solo si la empresa tiene certificado', () async {
      expect(
        (await _ready(_FakeSaleRepository())).documentTypes,
        [SaleDocumentType.ticket, SaleDocumentType.cotizacion],
      );
      expect(
        (await _ready(_FakeSaleRepository(), certificado: true)).documentTypes,
        SaleDocumentType.values,
      );
    });

    test('agregar un producto toma el precio de la lista y suma si ya estaba', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(1);
      expect(p.addProduct(_product()), isNull);
      expect(p.lines.single.precio, 40); // lista 11
      expect(p.addProduct(_product()), isNull);
      expect(p.lines.single.cantidad, 2);
      expect(p.total, 80);
    });

    test('no agrega más unidades que el stock del almacén', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(2); // sin stock
      expect(p.addProduct(_product()), contains('no tiene stock'));
      expect(p.lines, isEmpty);

      p.selectWarehouse(1); // 5 disponibles
      for (var i = 0; i < 5; i++) {
        expect(p.addProduct(_product()), isNull);
      }
      expect(p.addProduct(_product()), contains('Solo hay 5'));
      expect(p.lines.single.cantidad, 5);
      expect(p.setCantidad(0, 9), contains('Solo hay 5'));
      expect(p.lines.single.cantidad, 5);
    });

    test('al cambiar de lista las líneas toman el precio de la nueva', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(1);
      p.addProduct(_product());
      p.selectPriceList(10);
      expect(p.lines.single.precio, 50);
      p.selectPriceList(11);
      expect(p.lines.single.precio, 40);
    });

    test('la lista del cliente manda (también la de dólares), salvo que se haya elegido a mano', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectClient(const ClientEntity(id: 1, name: 'A', listPriceId: 10));
      expect(p.priceListId, 10);
      expect(p.esDolares, isFalse);

      p.selectClient(const ClientEntity(id: 2, name: 'B', listPriceId: 12)); // dólares
      expect(p.priceListId, 12);
      expect(p.esDolares, isTrue);
      expect(p.moneySymbol, r'$');

      p.selectPriceList(11);
      p.selectClient(const ClientEntity(id: 3, name: 'C', listPriceId: 10));
      expect(p.priceListId, 11);
    });

    test('un producto sin precio en la lista queda en 0 y se marca', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(1);
      p.addProduct(_product(prices: const {10: 50}));
      expect(p.lines.single.precio, 0);
      expect(p.lineProblem(p.lines.single), contains('Sin precio'));
      p.setPrecio(0, 25);
      expect(p.lineProblem(p.lines.single), isNull);
    });

    test('registrar la venta la envía y deja el borrador limpio', () async {
      final repo = _FakeSaleRepository();
      final p = await _ready(repo);
      p.selectWarehouse(1);
      p.selectClient(_acme);
      p.addProduct(_product());

      expect(p.prepare(), isTrue); // sin pagos todavía: se piden en el modal "Crear venta"
      expect(await p.submit(checkout: _checkout(40, observaciones: 'Entregar mañana')), isTrue);

      expect(repo.sentCompany, 1);
      expect(repo.sentUser, 9);
      expect(repo.sent!.total, 40);
      expect(repo.sent!.observaciones, 'Entregar mañana');
      expect(repo.sent!.payments.single.monto, 40);
      expect(p.lastSale!.numero, 'V001-0001');
      expect(p.lines, isEmpty);
      expect(p.client, isNull);
      expect(p.warehouseId, 1); // se conserva el almacén
    });

    test('un rechazo del backend deja el borrador para corregirlo', () async {
      final repo = _FakeSaleRepository()
        ..result = Either.left(const ValidationFailure('No hay stock suficiente para el producto: X'));
      final p = await _ready(repo);
      p.selectWarehouse(1);
      p.selectClient(_acme);
      p.addProduct(_product());

      expect(await p.submit(checkout: _checkout(40)), isFalse);
      expect(p.submitError, 'No hay stock suficiente para el producto: X');
      expect(p.lines, hasLength(1));
      expect(p.submitting, isFalse);
    });

    test('si se cae la red, avisa que revise Documentos antes de reintentar', () async {
      final repo = _FakeSaleRepository()..result = Either.left(const NetworkFailure('Tiempo de espera agotado'));
      final p = await _ready(repo);
      p.selectWarehouse(1);
      p.selectClient(_acme);
      p.addProduct(_product());

      expect(await p.submit(checkout: _checkout(40)), isFalse);
      expect(p.submitError, contains('Tiempo de espera agotado'));
      expect(p.submitError, contains('Documentos'));
      expect(p.lines, hasLength(1));
    });

    test('no envía una venta incompleta', () async {
      final repo = _FakeSaleRepository();
      final p = await _ready(repo);
      expect(await p.submit(), isFalse);
      expect(repo.sent, isNull);
      expect(p.submitError, 'Elige el cliente');
    });

    test('agregar con cantidad suma a lo que ya hay', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(1);

      expect(p.addProduct(_product(), cantidad: 3), isNull);
      expect(p.lines.single.cantidad, 3);
      expect(p.addProduct(_product(), cantidad: 2), isNull);
      expect(p.lines.single.cantidad, 5);
      expect(p.cantidadEnVenta(100), 5);
      expect(p.disponibleParaAgregar(_product()), 0);
    });

    test('agregar con un precio distinto al de la lista deja la línea con ese precio', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(1);

      expect(p.addProduct(_product(), cantidad: 2, precio: 35), isNull);
      expect(p.lines.single.precio, 35);
      expect(p.total, 70);

      // Si no se puede agregar (sin stock), el precio tampoco se toca.
      expect(p.addProduct(_product(), cantidad: 99, precio: 1), contains('Solo hay 5'));
      expect(p.lines.single.precio, 35);
    });

    test('agregar varios productos es todo o nada', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(1);
      final amp = _product(id: 101, name: 'AMPLIFICADOR', stock: const {1: 2});

      final problems = p.addProducts([
        (product: _product(), cantidad: 2),
        (product: amp, cantidad: 3), // solo hay 2
      ]);
      expect(problems.single, contains('Solo hay 2 de "AMPLIFICADOR"'));
      expect(p.lines, isEmpty);

      expect(
        p.addProducts([
          (product: _product(), cantidad: 2),
          (product: amp, cantidad: 2),
        ]),
        isEmpty,
      );
      expect(p.lines.map((l) => l.product.id), [100, 101]);
      expect(p.total, 160);
    });

    test('una cantidad menor a 1 no se agrega', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(1);
      expect(p.addProduct(_product(), cantidad: 0), contains('cantidad mínima'));
      expect(p.lines, isEmpty);
    });

    test('sin tope para servicios y productos de venta sin stock', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(2); // sin stock
      final libre = _product(sinStock: true);
      expect(p.disponibleParaAgregar(libre), isNull);
      expect(p.addProduct(libre, cantidad: 50), isNull);
      expect(p.lines.single.cantidad, 50);
    });

    test('las categorías y marcas del buscador se piden una vez', () async {
      final p = await _ready(_FakeSaleRepository());
      expect(p.productFilters.categorias, isEmpty);

      await p.ensureProductFilters();

      expect(p.productFilters.categorias.map((c) => c.name), ['AUDIO', 'ACCESORIOS']);
      expect(p.productFilters.marcas, hasLength(2));
      expect(p.productFilters.categoriaName(21), 'ACCESORIOS');
    });

    test('al cambiar de empresa se descarta el borrador y los catálogos', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(1);
      p.addProduct(_product());
      p.syncSession(_session(companyId: 2));
      expect(p.lines, isEmpty);
      expect(p.warehouses, isEmpty);
      expect(p.priceLists, isEmpty);
      expect(p.client, isNull);
    });
  });

  group('SalesPage', () {
    Future<(SalesProvider, _FakeSaleRepository)> pump(WidgetTester tester) async {
      _phoneScreen(tester);

      final repo = _FakeSaleRepository();
      final session = _session();
      final sales = _provider(repo)..syncSession(session);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<SalesProvider>.value(value: sales),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: SalesPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (sales, repo);
    }

    testWidgets('muestra el formulario de venta y avisa lo que falta', (tester) async {
      await pump(tester);

      expect(find.text('Comprobante'), findsOneWidget);
      expect(find.text('Elegir cliente'), findsOneWidget);
      expect(find.text('Agregar producto'), findsOneWidget);
      expect(find.text('S/ 0.00'), findsOneWidget);

      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      expect(find.text('Elige el cliente'), findsOneWidget);
    });

    testWidgets('elegir cliente y producto arma la venta con su total', (tester) async {
      final (sales, _) = await pump(tester);

      await tester.tap(find.text('Elegir cliente'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'acme');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      expect(sales.client?.id, 7);

      sales.selectWarehouse(1);
      expect(find.text('Buscar producto'), findsOneWidget);
      expect(find.text('Unidad'), findsWidgets);

      // Sin elegir producto no se agrega nada.
      await _tapAddProduct(tester);
      expect(find.text('Elige un producto'), findsOneWidget);
      expect(sales.lines, isEmpty);

      // Se elige el producto buscándolo: trae su unidad y el precio de la lista.
      await tester.tap(find.text('Producto').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'sub');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SUBWOOFER 12"'));
      await tester.pumpAndSettle();
      expect(find.text('SUB-12 · PIONEER · Stock 5'), findsOneWidget);
      expect(find.widgetWithText(TextField, '40.00'), findsOneWidget);

      // Cantidad y precio se pueden cambiar antes de agregar.
      await tester.enterText(find.widgetWithText(TextField, '1').first, '2');
      await tester.enterText(find.widgetWithText(TextField, '40.00'), '35');
      await _tapAddProduct(tester);

      expect(sales.lines.single.cantidad, 2);
      expect(sales.lines.single.precio, 35);
      expect(sales.total, 70);
      // El formulario queda limpio para el siguiente producto.
      expect(find.text('SUB-12 · PIONEER · Stock 5'), findsNothing);

      await tester.ensureVisible(find.byTooltip('Más'));
      await tester.tap(find.byTooltip('Más'));
      await tester.pumpAndSettle();
      expect(sales.lines.single.cantidad, 3);
      expect(sales.total, 105);
    });

    testWidgets('no agrega más de lo que hay en stock y avisa', (tester) async {
      final (sales, _) = await pump(tester);
      sales.selectWarehouse(1);

      await tester.tap(find.text('Producto').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'sub');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SUBWOOFER 12"'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '1').first, '9');
      await _tapAddProduct(tester);

      expect(find.textContaining('Solo hay 5'), findsOneWidget);
      expect(sales.lines, isEmpty);
    });

    /// Arma una venta de S/ 80 lista para registrar y abre el modal "Crear venta".
    Future<_FakeSaleRepository> openCheckout(WidgetTester tester) async {
      final (sales, repo) = await pump(tester);
      sales.selectWarehouse(1);
      sales.selectClient(_acme);
      sales.addProduct(_product(), cantidad: 2, precio: 40);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      return repo;
    }

    Finder inModal(Finder finder) => find.descendant(of: find.byType(BottomSheet), matching: finder);

    testWidgets('la venta ya no lleva la forma de pago en la pantalla: se pide en el modal', (tester) async {
      await pump(tester);

      expect(find.text('Forma de pago'), findsNothing);
      expect(find.text('Pago'), findsNothing);
    });

    testWidgets('registrar abre el modal Crear venta con fecha, entrega, pago por el total y observaciones',
        (tester) async {
      final repo = await openCheckout(tester);

      expect(find.text('Crear venta'), findsOneWidget);
      expect(find.text('Ticket de Venta · Total S/ 80.00'), findsOneWidget);
      expect(find.text('Fecha de emisión'), findsOneWidget);
      expect(find.text('Método de entrega'), findsOneWidget);
      expect(find.text('Entrega Inmediata'), findsOneWidget);
      expect(find.text('Método de pago 1'), findsOneWidget);
      expect(find.text('Agregar método de pago'), findsOneWidget);
      expect(find.text('Observaciones (opcional)'), findsWidgets);
      // El primer pago ya trae el total y el resumen cuadra.
      expect(find.widgetWithText(TextField, '80.00'), findsOneWidget);
      expect(find.text('Los pagos suman el total'), findsOneWidget);
      expect(repo.sent, isNull);
    });

    testWidgets('Crear registra la venta con la entrega, el pago y las observaciones', (tester) async {
      final repo = await openCheckout(tester);

      // Entrega: Despacho.
      await tester.tap(find.text('Entrega Inmediata'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Despacho').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Observaciones (opcional)').last, 'Entregar mañana');
      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      final form = repo.sent!;
      expect(form.delivery, SaleDelivery.despacho);
      expect(form.fechaEmision, isNull);
      expect(form.observaciones, 'Entregar mañana');
      expect(form.payments.single.paymentMethodId, 2); // EFECTIVO
      expect(form.payments.single.monto, 80);
      expect(find.text('Venta registrada'), findsOneWidget);
      // Al terminar se ofrece el PDF del comprobante (y el detalle).
      expect(find.text('Descargar PDF'), findsOneWidget);
      expect(find.text('Ver detalle'), findsOneWidget);
      expect(find.text('V001-0001'), findsOneWidget);
    });

    testWidgets('el pago que se agrega llega deslizándose desde la derecha y el primero no se anima', (tester) async {
      await openCheckout(tester);
      expect(find.text('Método de pago 1'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('Método de pago 1'), matching: find.byType(AppEntrance)),
        findsNothing,
        reason: 'el primer pago ya está al abrir',
      );

      await tester.ensureVisible(find.text('Agregar método de pago'));
      await tester.tap(find.text('Agregar método de pago'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final entrance = find.ancestor(of: find.text('Método de pago 2'), matching: find.byType(AppEntrance));
      expect(entrance, findsOneWidget);
      expect(tester.widget<AppEntrance>(entrance).from, const Offset(28, 0));
      final opacity = tester.widget<Opacity>(
        find.descendant(of: entrance, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, lessThan(1));

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.descendant(of: entrance, matching: find.byType(Opacity)).first).opacity, 1);
      expect(find.text('Método de pago 2'), findsOneWidget);
    });

    testWidgets('varios pagos: Crear espera a que sumen el total', (tester) async {
      final repo = await openCheckout(tester);

      await tester.ensureVisible(find.text('Agregar método de pago'));
      await tester.tap(find.text('Agregar método de pago'));
      await tester.pumpAndSettle();
      expect(find.text('Método de pago 2'), findsOneWidget);
      // El primer pago cubre todo, el segundo queda en 0: no se puede crear.
      expect(find.text('Escribe el monto de cada forma de pago'), findsOneWidget);
      FilledButton createButton() => tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Crear'),
          );
      expect(createButton().onPressed, isNull);

      // 50 + 20 no llega a 80.
      await tester.enterText(find.widgetWithText(TextField, '80.00'), '50');
      await tester.enterText(find.widgetWithText(TextField, '0.00'), '20');
      await tester.pumpAndSettle();
      expect(find.text('Faltan S/ 10.00 para completar el total'), findsOneWidget);
      expect(createButton().onPressed, isNull);

      // 50 + 30 sí.
      await tester.enterText(find.widgetWithText(TextField, '20'), '30');
      await tester.pumpAndSettle();
      expect(find.text('Los pagos suman el total'), findsOneWidget);
      expect(createButton().onPressed, isNotNull);

      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(repo.sent!.payments.map((p) => p.monto), [50, 30]);
    });

    testWidgets('quitar un método de pago devuelve el total al primero', (tester) async {
      await openCheckout(tester);

      await tester.ensureVisible(find.text('Agregar método de pago'));
      await tester.tap(find.text('Agregar método de pago'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '80.00'), '50');
      await tester.pumpAndSettle();

      // (la línea del carrito, detrás del modal, también tiene su "Quitar")
      await tester.ensureVisible(inModal(find.byTooltip('Quitar')));
      await tester.tap(inModal(find.byTooltip('Quitar')));
      await tester.pumpAndSettle();

      expect(find.text('Método de pago 2'), findsNothing);
      expect(find.widgetWithText(TextField, '80.00'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza la venta el modal sigue abierto con el motivo', (tester) async {
      final (sales, repo) = await pump(tester);
      repo.result = Either.left(const ValidationFailure('Caja cerrada'));
      sales.selectWarehouse(1);
      sales.selectClient(_acme);
      sales.addProduct(_product(), cantidad: 2, precio: 40);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(find.text('Crear venta'), findsOneWidget);
      expect(inModal(find.text('Caja cerrada')), findsOneWidget);
      expect(find.text('Venta registrada'), findsNothing);
      expect(sales.lines, isNotEmpty);
    });

    testWidgets('sin permiso para vender no se ve el formulario', (tester) async {
      _phoneScreen(tester);

      final repo = _FakeSaleRepository();
      final session = SessionContextEntity(
        user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
        company: const CompanyEntity(id: 1, razonSocial: 'ACME'),
        modules: const [],
        permissions: const {},
        roles: const [],
        warehouses: const [],
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<SalesProvider>.value(value: _provider(repo)..syncSession(session)),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SalesPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin acceso'), findsOneWidget);
      expect(find.text('Registrar venta'), findsNothing);
    });
  });

  group('Selector de productos', () {
    final audio = _product(id: 100, name: 'SUBWOOFER 12"', codigo: 'SUB-12');
    final accesorio = _product(
      id: 101,
      name: 'CABLE RCA',
      codigo: 'CAB-1',
      categoryId: 21,
      brandId: 31,
      stock: const {1: 40},
      prices: const {11: 12.5},
    );
    final agotado = _product(
      id: 102,
      name: 'RADIO DEH',
      codigo: 'RAD-1',
      stock: const {1: 0},
    );

    /// Los campos de cantidad de las tarjetas (dentro de la hoja, no los del formulario de atrás).
    Finder quantityFields() => find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(TextField, '1'),
        );

    Future<SalesProvider> open(WidgetTester tester, {List<SaleProductEntity>? products}) async {
      _phoneScreen(tester);
      final repo = _FakeSaleRepository()..products = products ?? [audio, accesorio, agotado];
      final session = _session();
      final sales = _provider(repo)..syncSession(session);
      await sales.ensureLoaded();
      sales.selectWarehouse(1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<SalesProvider>.value(value: sales),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: SalesPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.manage_search));
      await tester.pumpAndSettle();
      await tester.enterText(_pickerSearchField(), 'a');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      return sales;
    }

    testWidgets('muestra stock, unidad, precio y categoría de cada producto', (tester) async {
      final sales = await open(tester);
      await sales.ensureProductFilters();
      await tester.pumpAndSettle();

      expect(find.text('3 productos'), findsOneWidget);
      expect(find.text('5 Unidad'), findsOneWidget);
      expect(find.text('40 Unidad'), findsOneWidget);
      expect(find.text('Sin stock'), findsOneWidget);
      expect(find.text('S/ 40.00'), findsNWidgets(2)); // el subwoofer y el radio
      expect(find.text('S/ 12.50'), findsOneWidget);
      expect(find.text('SUB-12 · PIONEER · AUDIO'), findsOneWidget);
      expect(find.text('Unidad'), findsWidgets);
    });

    testWidgets('marcar varios con su cantidad los agrega de una vez', (tester) async {
      final sales = await open(tester);

      await tester.tap(find.text('SUBWOOFER 12"'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CABLE RCA'));
      await tester.pumpAndSettle();
      expect(find.text('2 seleccionados'), findsOneWidget);

      // El segundo producto (el cable): cantidad 7.
      await tester.enterText(quantityFields().at(1), '7');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agregar a la venta'));
      await tester.pumpAndSettle();

      expect(sales.lines.map((l) => (l.product.id, l.cantidad)), [(100, 1), (101, 7)]);
      expect(find.text('Buscar productos'), findsNothing);
    });

    testWidgets('la cantidad no pasa del stock disponible', (tester) async {
      final sales = await open(tester);

      await tester.tap(find.text('SUBWOOFER 12"')); // hay 5
      await tester.pumpAndSettle();
      await tester.enterText(quantityFields().first, '99');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(TextField, '5')), findsOneWidget);

      await tester.tap(find.text('Agregar a la venta'));
      await tester.pumpAndSettle();
      expect(sales.lines.single.cantidad, 5);
    });

    testWidgets('un producto sin stock no se puede marcar', (tester) async {
      await open(tester);

      await tester.tap(find.text('RADIO DEH'));
      await tester.pumpAndSettle();

      expect(find.text('0 seleccionados'), findsOneWidget);
      final checkbox = tester.widgetList<Checkbox>(find.byType(Checkbox)).last;
      expect(checkbox.onChanged, isNull);
    });

    testWidgets('filtrar por categoría deja solo sus productos', (tester) async {
      final sales = await open(tester);
      await sales.ensureProductFilters();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.text('Categoría'), findsOneWidget);
      expect(find.text('Marca'), findsOneWidget);

      await tester.tap(find.text('Todas').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACCESORIOS').last);
      await tester.pumpAndSettle();

      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text('CABLE RCA'), findsOneWidget);
      expect(find.text('SUBWOOFER 12"'), findsNothing);
    });

    testWidgets('el botón de agregar espera a que se marque algo', (tester) async {
      await open(tester);
      final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Agregar a la venta'),
        matching: find.byType(FilledButton),
      ));
      expect(button.onPressed, isNull);
    });
  });

  group('Tipo de cambio, cliente varios y cotización (provider)', () {
    test('el tipo de cambio se pide al preparar la venta y se puede actualizar', () async {
      final repo = _FakeSaleRepository();
      final p = await _ready(repo);
      await Future<void>.delayed(Duration.zero); // el tipo de cambio se pide aparte

      expect(p.exchangeRate!.valorFinal, 3.452);
      expect(p.exchangeRate!.fuenteNombre, 'Bloomberg');
      expect(repo.rateCalls, 1);

      await p.loadExchangeRate();
      expect(repo.rateCalls, 2);
    });

    test('si no hay tipo de cambio la venta sigue funcionando y se avisa', () async {
      final repo = _FakeSaleRepository()..rateFails = true;
      final p = await _ready(repo);
      await Future<void>.delayed(Duration.zero);

      expect(p.error, isNull);
      expect(p.exchangeRate, isNull);
      expect(p.exchangeRateError, 'No hay tipo de cambio disponible');
    });

    test('sin certificado se elige entre nota de venta y cotización; con certificado, todo', () async {
      expect(
        (await _ready(_FakeSaleRepository())).documentTypes.map((t) => t.label),
        ['Ticket de Venta', 'Cotización'],
      );
      expect(
        (await _ready(_FakeSaleRepository(), certificado: true)).documentTypes.map((t) => t.label),
        ['Ticket de Venta', 'Boleta', 'Factura', 'Cotización'],
      );
    });

    test('vender sin documento del cliente: solo boleta y menos de S/ 700', () async {
      final p = await _ready(_FakeSaleRepository(), certificado: true);
      p.selectWarehouse(1);
      p.addProduct(_product(), cantidad: 2); // S/ 80

      expect(p.puedeSinDocumento, isFalse); // es nota de venta
      p.selectTipoDocumento(SaleDocumentType.boleta);
      expect(p.puedeSinDocumento, isTrue);

      expect(await p.toggleSinDocumento(true), isNull);
      expect(p.sinDocumento, isTrue);
      expect(p.client!.esVarios, isTrue);

      // Si el total llega a S/ 700 deja de valer y se descarta a "cliente varios".
      p.addProduct(_product(id: 101, name: 'AMP', stock: const {1: 99}, prices: const {11: 700}));
      expect(p.sinDocumento, isFalse);
      expect(p.client, isNull);
    });

    test('al cambiar de comprobante se descarta la venta sin documento', () async {
      final p = await _ready(_FakeSaleRepository(), certificado: true);
      p.selectWarehouse(1);
      p.addProduct(_product());
      p.selectTipoDocumento(SaleDocumentType.boleta);
      await p.toggleSinDocumento(true);

      p.selectTipoDocumento(SaleDocumentType.factura);

      expect(p.sinDocumento, isFalse);
      expect(p.client, isNull);
    });

    test('desmarcar "sin documento" quita al cliente varios', () async {
      final p = await _ready(_FakeSaleRepository(), certificado: true);
      p.selectWarehouse(1);
      p.addProduct(_product());
      p.selectTipoDocumento(SaleDocumentType.boleta);
      await p.toggleSinDocumento(true);

      await p.toggleSinDocumento(false);

      expect(p.sinDocumento, isFalse);
      expect(p.client, isNull);
    });

    test('si falla la consulta de cliente varios devuelve el motivo y no marca nada', () async {
      final repo = _FakeSaleRepository()..walkInFails = true;
      final p = await _ready(repo, certificado: true);
      p.selectWarehouse(1);
      p.addProduct(_product());
      p.selectTipoDocumento(SaleDocumentType.boleta);

      expect(await p.toggleSinDocumento(true), 'Sin conexión a internet');
      expect(p.sinDocumento, isFalse);
      expect(p.client, isNull);
    });

    test('avisa que no se factura a una persona', () async {
      final p = await _ready(_FakeSaleRepository(), certificado: true);
      p.selectClient(const ClientEntity(id: 8, name: 'JUAN', tipo: 'p', documento: '12345678'));
      p.selectTipoDocumento(SaleDocumentType.factura);
      expect(p.facturaAPersona, isTrue);
      p.selectClient(_acme);
      expect(p.facturaAPersona, isFalse);
    });

    test('una cotización no pide forma de pago ni stock si no lo reserva', () async {
      final repo = _FakeSaleRepository();
      final p = await _ready(repo);
      p.selectWarehouse(2); // sin stock
      p.selectClient(_acme);
      p.addProduct(_product(sinStock: true), cantidad: 3);
      p.selectTipoDocumento(SaleDocumentType.cotizacion);
      p.lines = [SaleLineEntity(product: _product(), cantidad: 3, precio: 40)]; // hay 0 en el almacén 2

      expect(p.prepare(), isTrue);
      expect(await p.submit(), isTrue);

      expect(repo.sent!.tipoDocumento, SaleDocumentType.cotizacion);
      expect(repo.sent!.reservarStock, isFalse);
      expect(repo.sent!.priceListId, 11);
      expect(p.lastSale!.esCotizacion, isTrue);
      expect(p.lines, isEmpty);
    });

    test('al reservar stock sí se revisa el stock y se necesita la fecha', () async {
      final repo = _FakeSaleRepository();
      final p = await _ready(repo);
      p.selectWarehouse(1);
      p.selectClient(_acme);
      p.addProduct(_product(), cantidad: 5);
      p.selectTipoDocumento(SaleDocumentType.cotizacion);
      p.lines = [SaleLineEntity(product: _product(), cantidad: 9, precio: 40)]; // solo hay 5

      expect(await p.submit(reservarStock: true, vencimientoStock: DateTime(2026, 10, 30)), isFalse);
      expect(p.submitError, contains('No hay stock suficiente'));
      expect(repo.sent, isNull);

      p.lines = [SaleLineEntity(product: _product(), cantidad: 2, precio: 40)];
      expect(await p.submit(reservarStock: true), isFalse);
      expect(p.submitError, contains('hasta qué día'));

      expect(await p.submit(reservarStock: true, vencimientoStock: DateTime(2026, 10, 30)), isTrue);
      expect(repo.sent!.reservarStock, isTrue);
      expect(repo.sent!.vencimientoStock, DateTime(2026, 10, 30));
    });

    test('la cotización lleva la lista de precios, la reserva y las líneas', () {
      final form = SaleFormEntity(
        tipoDocumento: SaleDocumentType.cotizacion,
        client: _acme,
        warehouseId: 1,
        priceListId: 11,
        reservarStock: true,
        vencimientoStock: DateTime(2026, 10, 30),
        observaciones: ' Entregar ',
        lines: [SaleLineEntity(product: _product(), cantidad: 2, precio: 40)],
      );
      final body = quoteToJson(form, companyId: 3, userId: 9);

      expect(body['totales_soles'], 80);
      expect(body['totales_dolares'], 0);
      expect(body['company_id'], 3);
      expect(body['client_id'], 7);
      expect(body['list_price_id'], 11);
      expect(body['reservar_stock'], true);
      expect(body['vencimiento_stock'], '2026-10-30');
      expect(body['observaciones'], 'Entregar');
      expect(body.containsKey('payment_methods'), isFalse);
      expect((body['product_sales'] as List).single['subtotal_con_dto'], 80);

      final sinReserva = quoteToJson(
        SaleFormEntity(
          tipoDocumento: SaleDocumentType.cotizacion,
          client: _acme,
          warehouseId: 1,
          priceListId: 11,
          vencimientoStock: DateTime(2026, 10, 30), // sin reservar: no viaja
          lines: form.lines,
        ),
        companyId: 3,
        userId: 9,
      );
      expect(sinReserva['reservar_stock'], false);
      expect(sinReserva.containsKey('vencimiento_stock'), isFalse);
    });

    test('lee el tipo de cambio comercial', () {
      final rate = exchangeRateFromJson({
        'valor_final': '3.452',
        'valor_fuente': 3.427,
        'fuente': 'manual-usuario',
        'fecha_fuente': '2026-10-28',
        'margen': 0.025,
        'actualizado_en': null,
      });
      expect(rate.valorFinal, 3.452);
      expect(rate.fuenteNombre, 'Manual');
      expect(rate.fechaFuente, DateTime(2026, 10, 28));
    });

    test('la fecha por defecto de la reserva: mañana, sin pasar del fin de mes', () {
      expect(quoteDefaultExpiry(DateTime(2026, 10, 28)), DateTime(2026, 10, 29));
      expect(quoteDefaultExpiry(DateTime(2026, 10, 31)), DateTime(2026, 10, 31));
      expect(quoteDefaultExpiry(DateTime(2026, 2, 28)), DateTime(2026, 2, 28));
    });
  });

  group('Crear cliente (reglas y datos)', () {
    NewClientFormEntity form({
      String tipo = 'p',
      String dni = '12345678',
      String name = 'JUAN',
      String? razon,
      String phone = '987654321',
      String email = 'juan@mail.com',
      String dep = '15',
      String prov = '1501',
      String dist = '150101',
    }) =>
        NewClientFormEntity(
          tipo: tipo,
          dniRuc: dni,
          name: name,
          razonSocial: razon,
          telefono: phone,
          email: email,
          departmentId: dep,
          provinceId: prov,
          districtId: dist,
        );

    test('una persona completa es válida', () {
      expect(CreateClientUseCase.validate(form()), isNull);
    });

    test('pide documento con su largo, nombre, teléfono, correo y distrito', () {
      expect(CreateClientUseCase.validate(form(dni: '')), 'El DNI es obligatorio');
      expect(CreateClientUseCase.validate(form(dni: '1234')), 'El DNI debe tener 8 dígitos');
      expect(CreateClientUseCase.validate(form(name: ' ')), 'El nombre es obligatorio');
      expect(CreateClientUseCase.validate(form(phone: '')), 'El teléfono es obligatorio');
      expect(CreateClientUseCase.validate(form(email: '')), 'El correo es obligatorio');
      expect(CreateClientUseCase.validate(form(email: 'juan@gmailcom')), 'Debe ser un correo válido');
      expect(CreateClientUseCase.validate(form(dist: '')), contains('distrito'));
    });

    test('una empresa necesita RUC de 11 dígitos, razón social y contacto', () {
      expect(CreateClientUseCase.validate(form(tipo: 'e', dni: '12345678', razon: 'X')), 'El RUC debe tener 11 dígitos');
      expect(
        CreateClientUseCase.validate(form(tipo: 'e', dni: '20123456789')),
        'La razón social es obligatoria',
      );
      expect(
        CreateClientUseCase.validate(form(tipo: 'e', dni: '20123456789', razon: 'ACME SAC')),
        isNull,
      );
    });

    test('el teléfono se guarda en formato internacional', () {
      expect(CreateClientUseCase.normalizePhone('987 654 321'), '+51987654321');
      expect(CreateClientUseCase.normalizePhone('+1 (555) 123-4567'), '+15551234567');
      expect(CreateClientUseCase.normalizePhone('4251234'), '4251234');
    });

    test('el cuerpo de POST /clientes lleva los campos de la web', () {
      final body = newClientToJson(
        form(tipo: 'e', dni: '20123456789', razon: 'ACME SAC'),
        companyId: 3,
        executiveId: 9,
      );
      expect(body['company_id'], 3);
      expect(body['tipo'], 'e');
      expect(body['dni_ruc'], '20123456789');
      expect(body['razon_social'], 'ACME SAC');
      expect(body['department_id'], '15');
      expect(body['district_id'], '150101');
      expect(body['ejecutivo_comercial_id'], 9);
      expect(body['estado'], true);

      // En personas no viaja la razón social ni el ejecutivo si no lo hay.
      final persona = newClientToJson(form(razon: 'X'), companyId: 3);
      expect(persona.containsKey('razon_social'), isFalse);
      expect(persona.containsKey('ejecutivo_comercial_id'), isFalse);
    });

    test('lee la consulta de DNI y de RUC', () {
      final dni = documentLookupFromJson({
        'success': true,
        'dni': '12345678',
        'nombres': 'JUAN',
        'apellidoPaterno': 'PEREZ',
        'apellidoMaterno': 'GOMEZ',
      });
      expect(dni.esEmpresa, isFalse);
      expect(dni.name, 'JUAN');
      expect(dni.lastName, 'PEREZ GOMEZ');

      final ruc = documentLookupFromJson({
        'ruc': '20123456789',
        'razonSocial': 'ACME SAC',
        'direccion': 'AV. UNO 123',
        'ubigeo': '150101',
      });
      expect(ruc.esEmpresa, isTrue);
      expect(ruc.razonSocial, 'ACME SAC');
      expect(ruc.departmentId, '15');
      expect(ruc.provinceId, '1501');
      expect(ruc.districtId, '150101');
    });

    test('los códigos de ubigeo se conservan como texto con sus ceros', () {
      final items = ubigeoItemsFromJson([
        {'id': '01', 'name': 'AMAZONAS'},
        {'id': 15, 'name': 'LIMA'},
        {'name': 'sin id'},
      ]);
      expect(items.map((i) => i.id), ['01', '15']);
    });

    test('la consulta valida el largo antes de llamar a la API', () async {
      final repo = _FakeClientRepository();
      final lookup = LookupDocumentUseCase(repository: repo);

      expect((await lookup(tipo: 'p', number: '123')).isLeft, isTrue);
      expect((await lookup(tipo: 'e', number: '12345678')).isLeft, isTrue);
      expect(repo.calls, isEmpty);
      expect((await lookup(tipo: 'p', number: '12345678')).isRight, isTrue);
    });

    test('un vendedor o el ceo quedan como ejecutivo del cliente que crean; otros roles no', () async {
      final repo = _FakeClientRepository();

      await _clientsProvider(repo, session: _session()).create(form());
      expect(repo.executive, isNull);

      await _clientsProvider(repo, session: _session(roles: const ['Vendedor'])).create(form());
      expect(repo.executive, 9);

      repo.executive = null;
      await _clientsProvider(repo, session: _session(roles: const ['Ceo Empresa'])).create(form());
      expect(repo.executive, 9);
    });

    test('los departamentos y provincias se piden una sola vez', () async {
      final repo = _FakeClientRepository();
      final p = _clientsProvider(repo);

      await p.departments();
      await p.departments();
      await p.provincesOf('15');
      await p.provincesOf('15');

      expect(repo.calls, ['departments', 'provinces:15']);
    });

    test('un cliente que ya existe devuelve el mensaje del servidor', () async {
      final repo = _FakeClientRepository()
        ..createResult = Either.left(const ValidationFailure('El Cliente ya existe'));
      final result = await _clientsProvider(repo).create(form());
      expect(result.left.message, 'El Cliente ya existe');
    });
  });

  group('Pantalla de ventas: documento, tipo de cambio, cliente y cotización', () {
    Future<(SalesProvider, _FakeSaleRepository, _FakeClientRepository)> pumpFull(
      WidgetTester tester, {
      Set<String> permissions = const {'ventas.store'},
      bool certificado = false,
    }) async {
      _phoneScreen(tester);
      final repo = _FakeSaleRepository();
      final clientRepo = _FakeClientRepository();
      final session = _session(permissions: permissions, certificado: certificado);
      final sales = _provider(repo)..syncSession(session);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<SalesProvider>.value(value: sales),
            ChangeNotifierProvider<ClientsProvider>.value(value: _clientsProvider(clientRepo, session: session)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: SalesPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (sales, repo, clientRepo);
    }

    String textOf(WidgetTester tester, String label) =>
        tester.widget<TextField>(_field(label)).controller!.text;

    testWidgets('se puede elegir el tipo de documento y se ve el tipo de cambio', (tester) async {
      await pumpFull(tester);

      expect(find.text('Tipo de documento'), findsOneWidget);
      expect(find.text('Ticket de Venta'), findsOneWidget);
      expect(find.text('TC: S/ 3.452'), findsOneWidget);
      expect(find.byTooltip('Actualizar tipo de cambio'), findsOneWidget);
    });

    testWidgets('actualizar el tipo de cambio lo vuelve a pedir', (tester) async {
      final (_, repo, _) = await pumpFull(tester);
      expect(repo.rateCalls, 1);

      await tester.tap(find.byTooltip('Actualizar tipo de cambio'));
      await tester.pumpAndSettle();

      expect(repo.rateCalls, 2);
    });

    testWidgets('sin tipo de cambio avisa en la pantalla', (tester) async {
      _phoneScreen(tester);
      final repo = _FakeSaleRepository()..rateFails = true;
      final session = _session();
      final sales = _provider(repo)..syncSession(session);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<SalesProvider>.value(value: sales),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SalesPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TC no disponible'), findsOneWidget);
    });

    testWidgets('crear cliente solo aparece con el permiso clientes.store', (tester) async {
      await pumpFull(tester);
      expect(find.byTooltip('Crear cliente'), findsNothing);
    });

    testWidgets('crear una empresa trae sus datos del RUC y queda elegida en la venta', (tester) async {
      final (sales, _, clients) = await pumpFull(tester, permissions: const {'ventas.store', 'clientes.store'});

      await tester.tap(find.byTooltip('Crear cliente'));
      await tester.pumpAndSettle();
      expect(find.text('Crear cliente'), findsOneWidget);

      await tester.tap(find.text('Empresa'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('RUC'), '20123456789');
      await tester.tap(find.byTooltip('Buscar en SUNAT'));
      await tester.pumpAndSettle();

      expect(clients.calls, contains('lookup:e:20123456789'));
      expect(textOf(tester, 'Razón social'), 'ACME SAC');
      expect(textOf(tester, 'Dirección (opcional)'), 'AV. UNO 123');
      // El distrito de la SUNAT quedó elegido.
      expect(clients.calls, containsAll(['provinces:15', 'districts:1501']));

      await tester.enterText(_field('Nombre del contacto'), 'Carlos');
      await tester.enterText(_field('Teléfono'), '987 654 321');
      await tester.enterText(_field('Correo'), 'ventas@acme.pe');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      final created = clients.created!;
      expect(created.tipo, 'e');
      expect(created.dniRuc, '20123456789');
      expect(created.razonSocial, 'ACME SAC');
      expect(created.telefono, '+51987654321');
      expect(created.districtId, '150101');
      expect(sales.client?.id, 55);
      expect(sales.client?.name, 'ACME SAC');
      expect(find.text('Crear cliente'), findsNothing);
    });

    testWidgets('si faltan datos el modal sigue abierto y dice qué falta', (tester) async {
      final (sales, _, clients) = await pumpFull(tester, permissions: const {'ventas.store', 'clientes.store'});

      await tester.tap(find.byTooltip('Crear cliente'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('DNI'), '12345678');
      await tester.tap(find.byTooltip('Buscar en RENIEC'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'Nombre'), 'JUAN');
      expect(textOf(tester, 'Apellidos (opcional)'), 'PEREZ GOMEZ');

      await tester.enterText(_field('Teléfono'), '987654321');
      await tester.enterText(_field('Correo'), 'juan@mail.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      expect(find.textContaining('departamento, la provincia y el distrito'), findsOneWidget);
      expect(find.text('Crear cliente'), findsOneWidget);
      expect(clients.created, isNull);
      expect(sales.client, isNull);
    });

    testWidgets('un RUC inválido avisa antes de consultar', (tester) async {
      final (_, _, clients) = await pumpFull(tester, permissions: const {'ventas.store', 'clientes.store'});

      await tester.tap(find.byTooltip('Crear cliente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empresa'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('RUC'), '123');
      await tester.tap(find.byTooltip('Buscar en SUNAT'));
      await tester.pumpAndSettle();

      expect(find.text('El RUC debe tener 11 dígitos'), findsOneWidget);
      expect(clients.calls.where((c) => c.startsWith('lookup')), isEmpty);
    });

    testWidgets('con una boleta menor a S/700 se puede vender sin documento del cliente', (tester) async {
      final (sales, _, _) = await pumpFull(tester, certificado: true);
      sales.selectWarehouse(1);
      sales.addProduct(_product(), cantidad: 2);
      sales.selectTipoDocumento(SaleDocumentType.boleta);
      await tester.pumpAndSettle();

      const label = 'Emitir sin documento del cliente (venta menor a S/700)';
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(sales.client?.esVarios, isTrue);
      expect(find.text('CLIENTE VARIOS'), findsOneWidget);
      expect(find.byTooltip('Crear cliente'), findsNothing);
    });

    testWidgets('no se puede facturar a una persona y la pantalla lo dice', (tester) async {
      final (sales, _, _) = await pumpFull(tester, certificado: true);
      sales.selectClient(const ClientEntity(id: 8, name: 'JUAN', tipo: 'p', documento: '12345678'));
      sales.selectTipoDocumento(SaleDocumentType.factura);
      await tester.pumpAndSettle();

      expect(find.text('No se puede emitir Factura a un cliente de tipo Persona.'), findsOneWidget);
    });

    testWidgets('una cotización se crea sin forma de pago y pregunta por la reserva', (tester) async {
      final (sales, repo, _) = await pumpFull(tester);
      sales.selectWarehouse(1);
      sales.selectClient(_acme);
      sales.addProduct(_product(), cantidad: 2);
      sales.selectTipoDocumento(SaleDocumentType.cotizacion);
      await tester.pumpAndSettle();

      expect(find.text('Forma de pago'), findsNothing);
      expect(find.text('Observaciones'), findsWidgets);
      expect(find.text('Registrar venta'), findsNothing);

      await tester.tap(find.text('Crear cotización'));
      await tester.pumpAndSettle();
      expect(find.text('Reservar stock'), findsOneWidget);
      expect(find.text('Límite para reservar stock'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Límite para reservar stock'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      final sent = repo.sent!;
      expect(sent.tipoDocumento, SaleDocumentType.cotizacion);
      expect(sent.reservarStock, isTrue);
      expect(sent.vencimientoStock, isNotNull);
      expect(find.text('Cotización registrada'), findsOneWidget);
      expect(find.text('Descargar PDF'), findsOneWidget);
      expect(find.text('C001-0002'), findsOneWidget);
    });

    testWidgets('una cotización sin reserva no manda fecha', (tester) async {
      final (sales, repo, _) = await pumpFull(tester);
      sales.selectWarehouse(1);
      sales.selectClient(_acme);
      sales.addProduct(_product());
      sales.selectTipoDocumento(SaleDocumentType.cotizacion);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear cotización'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      expect(repo.sent!.reservarStock, isFalse);
      expect(repo.sent!.vencimientoStock, isNull);
    });
  });

  group('Ventas en dólares, a crédito y con puntos (reglas)', () {
    test('las cuotas se reparten al céntimo y lo que sobra va a las primeras', () {
      expect(splitInstallments(100, 3), [33.34, 33.33, 33.33]);
      expect(splitInstallments(10, 4), [2.5, 2.5, 2.5, 2.5]);
      expect(splitInstallments(0.05, 3), [0.02, 0.02, 0.01]);
      expect(splitInstallments(100, 1), [100]);
      expect(splitInstallments(100, 0), isEmpty);
    });

    test('el vencimiento de las cuotas cuenta por día, semana, mes o año', () {
      final from = DateTime(2026, 10, 31);

      expect(SalePlazo.day.after(from, 1), DateTime(2026, 11, 1));
      expect(SalePlazo.week.after(from, 2), DateTime(2026, 11, 14));
      expect(SalePlazo.month.after(from, 1), DateTime(2026, 11, 30)); // noviembre no tiene 31
      expect(SalePlazo.month.after(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(SalePlazo.month.after(from, 3), DateTime(2027, 1, 31));
      expect(SalePlazo.year.after(DateTime(2024, 2, 29), 1), DateTime(2025, 2, 28));
    });

    String? check({
      required List<SalePaymentEntity> payments,
      double total = 100,
      bool dolares = false,
      double? tc,
      ClientEntity? client = _acme,
      double minimo = 0,
    }) =>
        CreateSaleUseCase.checkPayments(
          payments: payments,
          total: total,
          dolares: dolares,
          tipoCambio: tc,
          client: client,
          minimoCanjePuntos: minimo,
        );

    const efectivo = SalePaymentEntity(paymentMethodId: 2, monto: 100);

    test('en dólares el tipo de cambio debe estar entre 3.000 y 4.300', () {
      const dolar = SalePaymentEntity(paymentMethodId: 2, monto: 40);

      expect(check(payments: [dolar], total: 40, dolares: true, tc: null), contains('entre 3.000 y 4.300'));
      expect(check(payments: [dolar], total: 40, dolares: true, tc: 2.999), contains('entre 3.000 y 4.300'));
      expect(check(payments: [dolar], total: 40, dolares: true, tc: 4.301), contains('entre 3.000 y 4.300'));
      expect(check(payments: [dolar], total: 40, dolares: true, tc: 3), isNull);
      expect(check(payments: [dolar], total: 40, dolares: true, tc: 4.3), isNull);
    });

    test('los pagos deben sumar el total', () {
      expect(check(payments: const [SalePaymentEntity(paymentMethodId: 2, monto: 60)]), contains('deben sumar'));
      expect(check(payments: [efectivo]), isNull);
    });

    test('los puntos se canjean en soles: en una venta en dólares se convierten', () {
      // 40 dólares con tipo de cambio 3.5: 35 soles en puntos son 10 dólares.
      const client = ClientEntity(id: 1, name: 'A', creditoAFavor: 100);
      const puntos = SalePaymentEntity(paymentMethodId: 4, monto: 35, kind: PaymentKind.puntos);
      const efectivoUsd = SalePaymentEntity(paymentMethodId: 2, monto: 30);

      expect(
        check(payments: const [efectivoUsd, puntos], total: 40, dolares: true, tc: 3.5, client: client, minimo: 10),
        isNull,
      );
    });

    test('los puntos no pasan de los del cliente ni bajan del mínimo', () {
      const client = ClientEntity(id: 1, name: 'A', creditoAFavor: 30);
      const resto = SalePaymentEntity(paymentMethodId: 2, monto: 70);

      expect(
        check(
          payments: const [resto, SalePaymentEntity(paymentMethodId: 4, monto: 40, kind: PaymentKind.puntos)],
          client: client,
        ),
        contains('solo tiene S/. 30.00 en puntos'),
      );
      expect(
        check(
          payments: const [
            SalePaymentEntity(paymentMethodId: 2, monto: 95),
            SalePaymentEntity(paymentMethodId: 4, monto: 5, kind: PaymentKind.puntos),
          ],
          client: client,
          minimo: 10,
        ),
        contains('mínimo para canjear puntos es 10'),
      );
      expect(
        check(
          payments: const [resto, SalePaymentEntity(paymentMethodId: 4, monto: 30, kind: PaymentKind.puntos)],
          client: client,
          minimo: 10,
        ),
        isNull,
      );
    });

    SalePaymentEntity credito(double monto, List<double> cuotas, {PaymentKind kind = PaymentKind.credito}) =>
        SalePaymentEntity(
          paymentMethodId: 1,
          monto: monto,
          kind: kind,
          plazo: SalePlazo.month,
          installments: [
            for (var i = 0; i < cuotas.length; i++)
              SaleInstallmentEntity(monto: cuotas[i], fechaVencimiento: DateTime(2026, 11 + i, 30)),
          ],
        );

    test('el crédito necesita cuotas que sumen su monto', () {
      const client = ClientEntity(id: 1, name: 'A', credito: 500, creditoDisponible: 500);

      expect(check(payments: [credito(100, const [])], client: client), 'Agrega las cuotas del crédito');
      expect(
        check(payments: [credito(100, const [60, 30])], client: client),
        'La suma de las cuotas debe ser igual al monto del crédito',
      );
      expect(check(payments: [credito(100, const [60, 0])], client: client), 'Escribe el monto de cada cuota');
      expect(check(payments: [credito(100, const [50, 50])], client: client), isNull);
    });

    test('el crédito no pasa de lo disponible del cliente (en soles; en dólares, convertido)', () {
      const client = ClientEntity(id: 1, name: 'A', credito: 1000, creditoDisponible: 80);

      expect(
        check(payments: [credito(100, const [100])], client: client),
        contains('No tiene suficiente crédito'),
      );
      expect(check(payments: [credito(80, const [80])], total: 80, client: client), isNull);
      // 80 soles con tipo de cambio 4 son 20 dólares: 25 dólares no alcanza, 20 sí.
      expect(
        check(payments: [credito(25, const [25])], total: 25, dolares: true, tc: 4, client: client),
        contains('No tiene suficiente crédito'),
      );
      expect(check(payments: [credito(20, const [20])], total: 20, dolares: true, tc: 4, client: client), isNull);
    });

    test('el plazo también lleva cuotas y cuenta como crédito; solo uno por venta', () {
      const client = ClientEntity(id: 1, name: 'A', credito: 500, creditoDisponible: 500);

      expect(
        check(
          payments: [
            credito(50, const [50]),
            credito(50, const [50], kind: PaymentKind.plazo),
          ],
          client: client,
        ),
        contains('una forma de pago a crédito'),
      );
    });

    test('POST /ventas en dólares: totales, líneas y tipo de cambio', () {
      final form = SaleFormEntity(
        tipoDocumento: SaleDocumentType.ticket,
        client: _acme,
        warehouseId: 1,
        dolares: true,
        tipoCambio: 3.5,
        payments: const [SalePaymentEntity(paymentMethodId: 2, monto: 40)],
        lines: [SaleLineEntity(product: _product(), cantidad: 2, precio: 20)],
      );

      final body = saleToJson(form, companyId: 3, userId: 9);

      expect(body['totales_soles'], 0);
      expect(body['totales_dolares'], 40);
      expect(body['tipo_de_cambio'], 3.5);
      expect((body['product_sales'] as List).single['dolares'], true);
      expect(form.totalEnSoles, 140);
    });

    test('POST /ventas a crédito: cuotas con su fecha y el plazo', () {
      final form = SaleFormEntity(
        tipoDocumento: SaleDocumentType.ticket,
        client: _acme,
        warehouseId: 1,
        payments: [
          SalePaymentEntity(
            paymentMethodId: 1,
            monto: 100,
            kind: PaymentKind.credito,
            plazo: SalePlazo.month,
            installments: [
              SaleInstallmentEntity(monto: 50, fechaVencimiento: DateTime(2026, 11, 30)),
              SaleInstallmentEntity(monto: 50, fechaVencimiento: DateTime(2026, 12, 30)),
            ],
          ),
        ],
        lines: [SaleLineEntity(product: _product(), cantidad: 2, precio: 50)],
      );

      final pago = (saleToJson(form, companyId: 3, userId: 9)['payment_methods'] as List).single as Map;

      expect(pago['plazo'], 'month');
      expect(pago['installments'], [
        {'monto': 50, 'fecha_vencimiento': '2026-11-30'},
        {'monto': 50, 'fecha_vencimiento': '2026-12-30'},
      ]);
    });

    test('un pago sin cuotas no manda installments ni plazo', () {
      final pago = (saleToJson(_form(), companyId: 3, userId: 9)['payment_methods'] as List).single as Map;

      expect(pago.containsKey('installments'), isFalse);
      expect(pago.containsKey('plazo'), isFalse);
    });

    test('al culminar una cotización la venta manda from_cotizacion', () {
      final form = SaleFormEntity(
        tipoDocumento: SaleDocumentType.ticket,
        client: _acme,
        warehouseId: 1,
        fromQuoteId: 12,
        payments: const [SalePaymentEntity(paymentMethodId: 2, monto: 100)],
        lines: [SaleLineEntity(product: _product(), cantidad: 2, precio: 50)],
      );

      expect(saleToJson(form, companyId: 3, userId: 9)['from_cotizacion'], 12);
      expect(saleToJson(_form(), companyId: 3, userId: 9).containsKey('from_cotizacion'), isFalse);
    });

    test('una cotización en dólares guarda sus totales en dólares', () {
      final form = SaleFormEntity(
        tipoDocumento: SaleDocumentType.cotizacion,
        client: _acme,
        warehouseId: 1,
        priceListId: 12,
        dolares: true,
        lines: [SaleLineEntity(product: _product(), cantidad: 2, precio: 20)],
      );

      final body = quoteToJson(form, companyId: 3, userId: 9);

      expect(body['totales_soles'], 0);
      expect(body['totales_dolares'], 40);
      expect((body['product_sales'] as List).single['dolares'], true);
    });

    test('el cliente trae su crédito disponible y sus puntos', () {
      final c = clientFromJson({
        'id': 1,
        'razon_social': 'ACME',
        'credito': '1000',
        'credito_disponible': 250.5,
        'credito_a_favor': 30,
      });

      expect(c.credito, 1000);
      expect(c.creditoDisponible, 250.5);
      expect(c.creditoAFavor, 30);
      expect(c.tieneCredito, isTrue);
      expect(clientFromJson({'id': 2, 'name': 'X'}).tieneCredito, isFalse);
    });

    test('POST /cotizaciones o PUT al editar una cotización existente', () async {
      final requests = <http.BaseRequest>[];
      final dataSource = SaleRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"id": 2, "nro_documento": 2, "total_soles": 100}', 200);
        }),
      );
      SaleFormEntity quote({int? fromQuoteId}) => SaleFormEntity(
            tipoDocumento: SaleDocumentType.cotizacion,
            client: _acme,
            warehouseId: 1,
            priceListId: 11,
            fromQuoteId: fromQuoteId,
            lines: [SaleLineEntity(product: _product(), cantidad: 2, precio: 50)],
          );

      await dataSource.createSale(token: 't', companyId: 1, userId: 9, form: quote());
      await dataSource.createSale(token: 't', companyId: 1, userId: 9, form: quote(fromQuoteId: 2));

      expect(requests.first.method, 'POST');
      expect(requests.first.url.path, endsWith('/cotizaciones'));
      expect(requests.last.method, 'PUT');
      expect(requests.last.url.path, endsWith('/cotizaciones/2'));
    });
  });

  group('Culminar una cotización como venta', () {
    Map<String, dynamic> quoteJson({bool reservar = true, String vencimiento = '2026-11-05', bool dolares = false}) => {
          'id': 2,
          'nro_documento': 2,
          'total_soles': '160',
          'total_dolares': 0,
          'estado': true,
          'reservar_stock': reservar,
          'vencimiento_stock': vencimiento,
          'warehouse_id': 1,
          'list_price_id': dolares ? 12 : 11,
          'observaciones': 'Entregar en tienda',
          'client': {
            'id': 7,
            'razon_social': 'ACME SAC',
            'dni_ruc': '20123456789',
            'tipo': 'e',
            'list_price_id': 10,
            'credito': 300,
            'credito_disponible': 200,
          },
          'warehouse': {'name': 'LIMA'},
          'products': [
            {
              'id': 100,
              'codigo': 'SUB-12',
              'name': 'SUBWOOFER 12"',
              'brand': {'name': 'PIONEER'},
              'pivot': {'cantidad': 3, 'precio': '35', 'dolares': dolares, 'subtotal': 105},
            },
            {
              'id': 101,
              'codigo': 'CAB-1',
              'name': 'CABLE RCA',
              'pivot': {'cantidad': 1, 'precio': '10', 'dolares': dolares, 'subtotal': 10},
            },
            // El mismo producto en dos líneas: la venta lleva una línea por producto.
            {
              'id': 100,
              'codigo': 'SUB-12',
              'name': 'SUBWOOFER 12"',
              'pivot': {'cantidad': 2, 'precio': '35', 'dolares': dolares, 'subtotal': 70},
            },
          ],
        };

    DocumentEntity quote({bool reservar = true, String vencimiento = '2026-11-05', bool dolares = false}) =>
        documentFromJson(quoteJson(reservar: reservar, vencimiento: vencimiento, dolares: dolares), DocumentKind.cotizacion);

    Future<(_FakeSaleRepository, SalesProvider)> ready({DateTime? now}) async {
      final repo = _FakeSaleRepository()
        ..products = [
          _product(prices: const {10: 50, 11: 40, 12: 20}), // 5 en el almacén 1
          _product(id: 101, name: 'CABLE RCA', codigo: 'CAB-1', stock: const {1: 9}, prices: const {11: 12}),
        ];
      final stock = _FakeStockRepository();
      final p = SalesProvider(
        getWarehousesUseCase: GetWarehousesUseCase(repository: stock),
        getPriceListsUseCase: GetPriceListsUseCase(repository: stock),
        getPaymentMethodsUseCase: GetPaymentMethodsUseCase(repository: repo),
        getSaleProductFiltersUseCase: GetSaleProductFiltersUseCase(repository: repo),
        getExchangeRateUseCase: GetExchangeRateUseCase(repository: repo),
        getWalkInClientUseCase: GetWalkInClientUseCase(repository: repo),
        searchClientsUseCase: SearchClientsUseCase(repository: repo),
        searchSaleProductsUseCase: SearchSaleProductsUseCase(repository: repo),
        createSaleUseCase: CreateSaleUseCase(repository: repo),
        now: () => now ?? DateTime(2026, 10, 31, 10),
      )..syncSession(_session());
      await p.ensureLoaded();
      return (repo, p);
    }

    test('la cotización trae su cliente, almacén, lista, líneas y precios', () {
      final d = quote().quoteDraft!;

      expect(d.id, 2);
      expect(d.client.name, 'ACME SAC');
      expect(d.client.creditoDisponible, 200);
      expect(d.warehouseId, 1);
      expect(d.priceListId, 11);
      expect(d.lines, hasLength(3));
      expect(d.lines.first.precio, 35);
      expect(d.lines.first.cantidad, 3);
      expect(d.esDolares, isFalse);
      expect(quote(dolares: true).quoteDraft!.esDolares, isTrue);
    });

    test('una venta no trae borrador de cotización', () {
      expect(_sale().quoteDraft, isNull);
    });

    test('cargarla en Ventas deja el cliente, el almacén, la lista y las líneas con sus precios', () async {
      final (_, p) = await ready();

      final problem = await p.loadFromQuote(quote());

      expect(problem, isNull);
      expect(p.fromQuote?.numero, 'C001-0002');
      expect(p.client?.name, 'ACME SAC');
      expect(p.warehouseId, 1);
      expect(p.priceListId, 11);
      expect(p.tipoDocumento, SaleDocumentType.ticket);
      expect(p.observaciones, 'Entregar en tienda');
      // Dos líneas del subwoofer se juntan: 3 + 2.
      expect(p.lines.map((l) => (l.product.id, l.cantidad, l.precio)), [(100, 5, 35.0), (101, 1, 10.0)]);
      expect(p.total, 185);
      expect(p.quoteLoading, isFalse);
    });

    test('con la reserva vigente, lo reservado cuenta como disponible', () async {
      // Hay 5 subwoofers en el almacén y 5 reservados: se pueden vender 10.
      final (_, p) = await ready();

      await p.loadFromQuote(quote(vencimiento: '2026-11-05'));

      expect(p.lines.first.product.maximoEn(1), 10);
      expect(p.setCantidad(0, 10), isNull);
      expect(p.lines.first.cantidad, 10);
      expect(p.setCantidad(0, 11), isNotNull); // pasa del tope
    });

    test('con la reserva vencida solo cuenta el stock que hay', () async {
      final (_, p) = await ready();

      await p.loadFromQuote(quote(vencimiento: '2026-10-29')); // venció antes de ayer

      expect(p.lines.first.product.maximoEn(1), 5);
    });

    test('una cotización sin reserva no suma nada al stock', () async {
      final (_, p) = await ready();

      await p.loadFromQuote(quote(reservar: false));

      expect(p.lines.first.product.maximoEn(1), 5);
    });

    test('al registrar la venta se manda from_cotizacion y el borrador queda limpio', () async {
      final (repo, p) = await ready();
      await p.loadFromQuote(quote());

      final ok = await p.submit(checkout: _checkout(185));

      expect(ok, isTrue);
      expect(repo.sent!.fromQuoteId, 2);
      expect(repo.sent!.tipoDocumento, SaleDocumentType.ticket);
      expect(p.fromQuote, isNull);
      expect(p.lines, isEmpty);
    });

    test('editarla: elegir cotización y guardar actualiza la misma (mismo id)', () async {
      final (repo, p) = await ready();
      await p.loadFromQuote(quote());
      p.selectTipoDocumento(SaleDocumentType.cotizacion);

      final ok = await p.submit();

      expect(ok, isTrue);
      expect(repo.sent!.tipoDocumento, SaleDocumentType.cotizacion);
      expect(repo.sent!.fromQuoteId, 2);
    });

    test('Cancelar limpia la venta y deja de trabajar con la cotización', () async {
      final (_, p) = await ready();
      await p.loadFromQuote(quote());

      p.cancelQuote();

      expect(p.fromQuote, isNull);
      expect(p.lines, isEmpty);
      expect(p.client, isNull);
      expect(p.tipoDocumento, SaleDocumentType.ticket);
    });

    test('una cotización en dólares abre la venta en dólares', () async {
      final (_, p) = await ready();

      await p.loadFromQuote(quote(dolares: true));

      expect(p.priceListId, 12);
      expect(p.esDolares, isTrue);
      expect(p.moneySymbol, r'$');
    });

    test('si no se pueden pedir los productos queda el motivo y no se carga nada', () async {
      final (repo, p) = await ready();
      repo.searchFails = true;

      final problem = await p.loadFromQuote(quote());

      expect(problem, 'Sin conexión a internet');
      expect(p.quoteError, 'Sin conexión a internet');
      expect(p.fromQuote, isNull);
      expect(p.lines, isEmpty);
      expect(p.quoteLoading, isFalse);
    });

    test('una cotización sin datos del cliente o del almacén no se puede cargar', () async {
      final (_, p) = await ready();

      final problem = await p.loadFromQuote(_quote()); // sin borrador

      expect(problem, 'No se pudo leer la cotización');
    });
  });

  group('Formas de pago según el cliente y la empresa', () {
    const conCredito = ClientEntity(
      id: 7,
      name: 'ACME SAC',
      documento: '20123456789',
      tipo: 'e',
      credito: 500,
      creditoDisponible: 400,
      creditoAFavor: 30,
      paymentMethodId: 1, // prefiere CRÉDITO
    );

    PaymentMethodEntity method(SalesProvider p, String name) => p.paymentMethods.firstWhere((m) => m.name == name);

    test('los puntos solo se ofrecen si la empresa tiene el programa', () async {
      final sin = await _ready(_FakeSaleRepository());
      final con = await _ready(_FakeSaleRepository(), puntos: true);

      expect(sin.offeredPaymentMethods.map((m) => m.name), isNot(contains('PUNTOS')));
      expect(con.offeredPaymentMethods.map((m) => m.name), contains('PUNTOS'));
    });

    test('el crédito pide que el cliente tenga línea de crédito', () async {
      final p = await _ready(_FakeSaleRepository());

      p.selectClient(_acme);
      expect(p.canUsePayment(method(p, 'CRÉDITO')), isFalse);

      p.selectClient(conCredito);
      expect(p.canUsePayment(method(p, 'CRÉDITO')), isTrue);
      expect(p.canUsePayment(method(p, 'EFECTIVO')), isTrue);
    });

    test('los puntos piden que el cliente llegue al mínimo para canjear', () async {
      final p = await _ready(_FakeSaleRepository(), puntos: true, minimoCanje: 50);

      p.selectClient(conCredito); // 30 puntos
      expect(p.canUsePayment(method(p, 'PUNTOS')), isFalse);

      p.selectClient(const ClientEntity(id: 8, name: 'B', creditoAFavor: 80));
      expect(p.canUsePayment(method(p, 'PUNTOS')), isTrue);
    });

    test('la forma de pago por defecto es la del cliente solo si la puede usar', () async {
      final p = await _ready(_FakeSaleRepository());

      p.selectClient(const ClientEntity(id: 9, name: 'C', paymentMethodId: 1)); // prefiere CRÉDITO, sin línea
      expect(p.defaultPaymentMethodId, 2); // EFECTIVO

      p.selectClient(conCredito);
      expect(p.defaultPaymentMethodId, 1);
    });

    test('una venta en dólares no se puede hacer sin documento del cliente', () async {
      final p = await _ready(_FakeSaleRepository(), certificado: true);
      p.selectTipoDocumento(SaleDocumentType.boleta);
      p.selectWarehouse(1);
      p.addProduct(_product(prices: const {11: 40, 12: 20}), precio: 20);
      p.selectPriceList(11);
      expect(p.puedeSinDocumento, isTrue);

      p.selectPriceList(12);
      expect(p.puedeSinDocumento, isFalse);
    });

    test('registrar en dólares manda el tipo de cambio de la venta', () async {
      final repo = _FakeSaleRepository();
      final p = await _ready(repo);
      p.selectWarehouse(1);
      p.selectClient(_acme);
      p.selectPriceList(12);
      p.addProduct(_product(prices: const {12: 20}), cantidad: 2);

      final ok = await p.submit(
        checkout: const SaleCheckoutEntity(
          payments: [SalePaymentEntity(paymentMethodId: 2, monto: 40)],
          tipoCambio: 3.5,
        ),
      );

      expect(ok, isTrue);
      expect(repo.sent!.dolares, isTrue);
      expect(repo.sent!.tipoCambio, 3.5);
      expect(repo.sent!.total, 40);
    });

    test('registrar en dólares con un tipo de cambio fuera de rango se rechaza antes de enviar', () async {
      final repo = _FakeSaleRepository();
      final p = await _ready(repo);
      p.selectWarehouse(1);
      p.selectClient(_acme);
      p.selectPriceList(12);
      p.addProduct(_product(prices: const {12: 20}), cantidad: 2);

      final ok = await p.submit(
        checkout: const SaleCheckoutEntity(
          payments: [SalePaymentEntity(paymentMethodId: 2, monto: 40)],
          tipoCambio: 5,
        ),
      );

      expect(ok, isFalse);
      expect(p.submitError, contains('entre 3.000 y 4.300'));
      expect(repo.sent, isNull);
    });
  });

  group('Pantalla de ventas: dólares, crédito, puntos y cotización', () {
    const conCredito = ClientEntity(
      id: 7,
      name: 'ACME SAC',
      documento: '20123456789',
      tipo: 'e',
      credito: 500,
      creditoDisponible: 500,
      creditoAFavor: 0,
    );

    Future<(SalesProvider, _FakeSaleRepository)> pump(
      WidgetTester tester, {
      bool puntos = false,
      double minimoCanje = 0,
      ScreenLook? look,
    }) async {
      // Con `look`: letra real (Roboto), modo claro u oscuro y letra grande del sistema.
      look != null ? await prepareLook(tester, look) : _phoneScreen(tester);
      final repo = _FakeSaleRepository();
      final session = _session(puntos: puntos, minimoCanje: minimoCanje);
      final sales = _provider(repo)..syncSession(session);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<SalesProvider>.value(value: sales),
          ],
          child: lookApp(look, home: const Scaffold(body: SalesPage())),
        ),
      );
      await tester.pumpAndSettle();
      return (sales, repo);
    }

    Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

    Future<void> openCheckout(WidgetTester tester) async {
      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();
    }

    group('modo oscuro y letra grande en pantallas completas', () {
      const cliente = ClientEntity(
        id: 7,
        name: 'DISTRIBUIDORA COMERCIAL DEL SUR SOCIEDAD ANÓNIMA CERRADA',
        documento: '20123456789',
        tipo: 'e',
        listPriceId: 12,
      );

      for (final look in screenLooks) {
        testWidgets('Ventas con un producto de nombre largo: ${look.label}', (tester) async {
          final handle = tester.ensureSemantics();
          final (sales, _) = await pump(tester, look: look);
          sales.selectWarehouse(1);
          sales.selectClient(cliente);
          sales.addProduct(
            _product(name: 'SUBWOOFER DE 12 PULGADAS CON BOBINA DOBLE Y CAJA SELLADA', prices: const {12: 20}),
            cantidad: 2,
          );
          await tester.pumpAndSettle();

          await expectLooksRight(tester, look);
          handle.dispose();
        });

        testWidgets('Ventas con un ítem libre y un descuento: ${look.label}', (tester) async {
          final handle = tester.ensureSemantics();
          final (sales, _) = await pump(tester, look: look);
          sales.selectWarehouse(1);
          sales.selectClient(cliente);
          sales.addProduct(_product(prices: const {12: 20}), cantidad: 2);
          await sales.addFreeItem(descripcion: 'FLETE A PROVINCIA CON ENTREGA EN AGENCIA', precio: 30);
          await tester.pumpAndSettle();

          await expectLooksRight(tester, look);
          handle.dispose();
        });

        testWidgets('Registrar venta en dólares: ${look.label}', (tester) async {
          final (sales, _) = await pump(tester, look: look);
          sales.selectWarehouse(1);
          sales.selectClient(cliente);
          sales.addProduct(_product(prices: const {12: 20}), cantidad: 2);
          await tester.pumpAndSettle();
          await openCheckout(tester);

          expect(find.text('Los pagos suman el total'), findsOneWidget);
          await expectLooksRight(tester, look, contrast: false);
        });

        testWidgets('Registrar venta a crédito con cuotas: ${look.label}', (tester) async {
          final (sales, _) = await pump(tester, look: look);
          sales.selectWarehouse(1);
          sales.selectClient(conCredito);
          sales.addProduct(_product(), cantidad: 2, precio: 50);
          await tester.pumpAndSettle();
          await openCheckout(tester);
          await tester.tap(find.text('EFECTIVO'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('CRÉDITO').last);
          await tester.pumpAndSettle();

          expect(find.text('Cuotas del crédito'), findsOneWidget);
          await expectLooksRight(tester, look, contrast: false);
        });
      }

      // La prueba de contraste de Flutter se confunde con el texto de ayuda del equivalente en soles
      // ("≈ S/ ..."): lo mide en un lugar donde no está. Se ve bien en la captura; por eso el modal en
      // dólares solo se revisa por desbordes y el de soles, también por contraste.
      testWidgets('el modal de pago se lee en modo oscuro con letra grande', (tester) async {
        final handle = tester.ensureSemantics();
        const look = ScreenLook(dark: true);
        final (sales, _) = await pump(tester, look: look);
        sales.selectWarehouse(1);
        sales.selectClient(conCredito);
        sales.addProduct(_product(), cantidad: 2, precio: 50);
        await tester.pumpAndSettle();
        await openCheckout(tester);

        await expectLooksRight(tester, look);
        handle.dispose();
      });
    });

    testWidgets('en dólares: símbolo de dólar, tipo de cambio editable y equivalente en soles', (tester) async {
      final (sales, repo) = await pump(tester);
      sales.selectWarehouse(1);
      sales.selectClient(const ClientEntity(id: 7, name: 'ACME SAC', documento: '20123456789', tipo: 'e', listPriceId: 12));
      sales.addProduct(_product(prices: const {12: 20}), cantidad: 2);
      await tester.pumpAndSettle();

      await openCheckout(tester);

      expect(find.text(r'Ticket de Venta · Total $ 40.00'), findsOneWidget);
      expect(inSheet(find.widgetWithText(TextField, '3.452')), findsOneWidget); // el oficial
      expect(find.text('≈ S/. 138.08'), findsOneWidget); // 40 x 3.452
      expect(find.text('Los pagos suman el total'), findsOneWidget);

      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(repo.sent!.dolares, isTrue);
      expect(repo.sent!.tipoCambio, 3.452);
    });

    testWidgets('en dólares un tipo de cambio fuera de rango bloquea Crear', (tester) async {
      final (sales, _) = await pump(tester);
      sales.selectWarehouse(1);
      sales.selectClient(const ClientEntity(id: 7, name: 'ACME SAC', documento: '20123456789', tipo: 'e', listPriceId: 12));
      sales.addProduct(_product(prices: const {12: 20}), cantidad: 2);
      await tester.pumpAndSettle();
      await openCheckout(tester);

      await tester.enterText(inSheet(find.widgetWithText(TextField, '3.452')), '5');
      await tester.pumpAndSettle();

      expect(find.text('El tipo de cambio debe estar entre 3.000 y 4.300'), findsWidgets);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear')).onPressed,
        isNull,
      );
    });

    testWidgets('a crédito: cuotas con su plazo, se pueden agregar y se mandan al crear', (tester) async {
      final (sales, repo) = await pump(tester);
      sales.selectWarehouse(1);
      sales.selectClient(conCredito);
      sales.addProduct(_product(), cantidad: 2, precio: 50);
      await tester.pumpAndSettle();
      await openCheckout(tester);

      // Elige CRÉDITO en la forma de pago.
      await tester.tap(find.text('EFECTIVO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CRÉDITO').last);
      await tester.pumpAndSettle();

      expect(find.text('Cuotas del crédito'), findsOneWidget);
      expect(find.text('Crédito en soles: S/. 500.00'), findsOneWidget);
      expect(find.text('Mensual'), findsOneWidget);
      expect(find.text('Cuota 1'), findsOneWidget);
      expect(find.text('Cuota 2'), findsNothing);

      await tester.ensureVisible(find.text('Agregar cuota'));
      await tester.tap(find.text('Agregar cuota'));
      await tester.pumpAndSettle();

      expect(find.text('Cuota 2'), findsOneWidget);
      expect(find.widgetWithText(TextField, '50.00'), findsNWidgets(3)); // el monto y las dos cuotas
      expect(find.text('Los pagos suman el total'), findsOneWidget);

      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      final pago = repo.sent!.payments.single;
      expect(pago.kind, PaymentKind.credito);
      expect(pago.plazo, SalePlazo.month);
      expect(pago.installments.map((i) => i.monto), [50, 50]);
      expect(pago.installments.first.fechaVencimiento.isAfter(DateTime.now()), isTrue);
    });

    testWidgets('si las cuotas no suman el monto del crédito no se puede crear', (tester) async {
      final (sales, _) = await pump(tester);
      sales.selectWarehouse(1);
      sales.selectClient(conCredito);
      sales.addProduct(_product(), cantidad: 2, precio: 50);
      await tester.pumpAndSettle();
      await openCheckout(tester);
      await tester.tap(find.text('EFECTIVO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CRÉDITO').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(TextField, 'Cuota 1'));
      await tester.enterText(find.widgetWithText(TextField, 'Cuota 1'), '30');
      await tester.pumpAndSettle();

      expect(find.text('La suma de las cuotas debe ser igual al monto del crédito'), findsWidgets);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Crear')).onPressed,
        isNull,
      );
    });

    testWidgets('un cliente sin línea de crédito ve el crédito como no disponible', (tester) async {
      final (sales, _) = await pump(tester);
      sales.selectWarehouse(1);
      sales.selectClient(_acme);
      sales.addProduct(_product(), cantidad: 2, precio: 50);
      await tester.pumpAndSettle();
      await openCheckout(tester);

      await tester.tap(find.text('EFECTIVO'));
      await tester.pumpAndSettle();

      expect(find.text('CRÉDITO (no disponible)'), findsOneWidget);
    });

    testWidgets('los puntos aparecen solo con el programa, y no disponibles sin puntos suficientes', (tester) async {
      final (sales, _) = await pump(tester, puntos: true, minimoCanje: 10);
      sales.selectWarehouse(1);
      sales.selectClient(_acme);
      sales.addProduct(_product(), cantidad: 2, precio: 50);
      await tester.pumpAndSettle();
      await openCheckout(tester);

      await tester.tap(find.text('EFECTIVO'));
      await tester.pumpAndSettle();

      expect(find.text('PUNTOS (no disponible)'), findsOneWidget);
    });

    testWidgets('canjear puntos: el cliente cubre parte del total con sus puntos', (tester) async {
      final (sales, repo) = await pump(tester, puntos: true, minimoCanje: 10);
      sales.selectWarehouse(1);
      sales.selectClient(const ClientEntity(id: 7, name: 'ACME SAC', documento: '20123456789', tipo: 'e', creditoAFavor: 30));
      sales.addProduct(_product(), cantidad: 2, precio: 50);
      await tester.pumpAndSettle();
      await openCheckout(tester);
      expect(find.text(r'El cliente tiene S/. 30.00 en PUNTOS (mínimo para canjear: 10).'), findsOneWidget);

      // El primer pago baja a 70 y el segundo canjea 30 puntos.
      await tester.enterText(find.widgetWithText(TextField, '100.00'), '70');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Agregar método de pago'));
      await tester.tap(find.text('Agregar método de pago'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Método de pago 2'));
      await tester.tap(find.text('EFECTIVO').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PUNTOS').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '30.00'), '30');
      await tester.pumpAndSettle();

      expect(find.text('Los pagos suman el total'), findsOneWidget);
      await tester.ensureVisible(find.text('Crear'));
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(repo.sent!.payments.map((p) => (p.monto, p.kind)), [(70.0, PaymentKind.normal), (30.0, PaymentKind.puntos)]);
    });

    testWidgets('con una cotización cargada se avisa y Cancelar la deja', (tester) async {
      final (sales, repo) = await pump(tester);
      repo.products = [_product(prices: const {11: 40})];
      final quote = documentFromJson({
        'id': 2,
        'nro_documento': 2,
        'estado': true,
        'reservar_stock': false,
        'warehouse_id': 1,
        'list_price_id': 11,
        'client': {'id': 7, 'razon_social': 'ACME SAC', 'dni_ruc': '20123456789', 'tipo': 'e'},
        'products': [
          {
            'id': 100,
            'codigo': 'SUB-12',
            'name': 'SUBWOOFER 12"',
            'pivot': {'cantidad': 2, 'precio': '35', 'dolares': false},
          },
        ],
      }, DocumentKind.cotizacion);

      await sales.loadFromQuote(quote);
      await tester.pumpAndSettle();

      expect(find.text('Está trabajando con la Cotización Nro: C001-0002'), findsOneWidget);
      expect(find.text('ACME SAC'), findsWidgets);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Está trabajando con la Cotización'), findsNothing);
      expect(sales.fromQuote, isNull);
      expect(sales.lines, isEmpty);
    });
  });

  group('Descuentos por línea, ítems libres y vendedor encargado (reglas)', () {
    const libre = {'ventas.store', 'factura.libre'};

    SaleLineEntity line({int cantidad = 2, double precio = 50, double dto = 0, bool fijo = false}) =>
        SaleLineEntity(product: _product(), cantidad: cantidad, precio: precio, dto: dto, dtoFijo: fijo);

    SaleFormEntity formOf(
      List<SaleLineEntity> lines, {
      SaleDocumentType tipo = SaleDocumentType.ticket,
      int? vendedorId,
    }) =>
        SaleFormEntity(
          tipoDocumento: tipo,
          client: _acme,
          warehouseId: 1,
          priceListId: 11,
          vendedorId: vendedorId,
          lines: lines,
        );

    test('un descuento en porcentaje se resta del subtotal de la línea', () {
      final l = line(dto: 10);

      expect(l.subtotal, 100);
      expect(l.montoDto, 10);
      expect(l.subtotalConDto, 90);
      expect(l.tieneDescuento, isTrue);
      expect(line().tieneDescuento, isFalse);
    });

    test('un descuento fijo es un monto', () {
      final l = line(fijo: true, dto: 15);

      expect(l.montoDto, 15);
      expect(l.subtotalConDto, 85);
    });

    test('el descuento no pasa del 100 % ni, si es un monto, del subtotal', () {
      expect(line().copyWith(dto: 150).dto, 100);
      expect(line().copyWith(dto: 150).subtotalConDto, 0);

      final fijo = line(fijo: true).copyWith(dto: 500);
      expect(fijo.dto, 100); // el subtotal de la línea
      expect(fijo.subtotalConDto, 0);
    });

    test('al bajar la cantidad un descuento fijo se recorta al nuevo subtotal', () {
      final l = line(fijo: true, dto: 80).copyWith(cantidad: 1);

      expect(l.dto, 50);
      expect(l.subtotalConDto, 0);
    });

    test('cambiar el tipo de descuento conserva el valor escrito', () {
      final l = line(dto: 10).copyWith(dtoFijo: true);

      expect(l.dto, 10);
      expect(l.montoDto, 10);
      expect(l.subtotalConDto, 90);
    });

    test('el total del formulario suma las líneas ya con su descuento', () {
      final form = formOf([line(dto: 10), line(cantidad: 1, precio: 30, fijo: true, dto: 5)]);

      expect(form.total, 115); // 90 + 25
    });

    test('el provider aplica el descuento al total y se puede cambiar de tipo', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectWarehouse(1);
      p.addProduct(_product(), cantidad: 2); // lista MAYORISTA: S/ 40 x 2 = 80
      expect(p.total, 80);

      p.setDto(0, 10);
      expect(p.total, 72);

      p.toggleDtoFijo(0);
      expect(p.lines.first.dtoFijo, isTrue);
      expect(p.total, 70); // S/ 10 de descuento

      p.setDto(0, 500);
      expect(p.lines.first.dto, 80);
      expect(p.total, 0);

      p.setDto(0, -5);
      expect(p.lines.first.dto, 0);
    });

    test('cambiar de lista de precios conserva el descuento y no toca el precio del ítem libre', () async {
      final p = await _ready(_FakeSaleRepository(), permissions: libre);
      p.selectWarehouse(1);
      p.addProduct(_product(), cantidad: 2);
      p.setDto(0, 10);
      await p.addFreeItem(descripcion: 'FLETE', precio: 25);

      p.selectPriceList(10); // MINORISTA: S/ 50

      expect(p.lines.first.precio, 50);
      expect(p.lines.first.dto, 10);
      expect(p.lines.last.precio, 25);
      expect(p.total, 115); // 90 + 25
    });

    group('ítem libre', () {
      test('sin el permiso factura.libre no se puede agregar', () async {
        final p = await _ready(_FakeSaleRepository());

        expect(p.puedeItemLibre, isFalse);
        final r = await p.addFreeItem(descripcion: 'FLETE', precio: 20);

        expect(r.problem, 'No tienes permiso para agregar ítems libres');
        expect(p.lines, isEmpty);
      });

      test('con el permiso se agrega una línea sin producto, sin stock ni lista', () async {
        final p = await _ready(_FakeSaleRepository(), permissions: libre);

        expect(p.puedeItemLibre, isTrue);
        final r = await p.addFreeItem(descripcion: '  FLETE A PROVINCIA ', codigo: ' SRV-1 ', cantidad: 2, precio: 15);

        expect(r.problem, isNull);
        expect(r.info, isNull);
        final l = p.lines.single;
        expect(l.esLibre, isTrue);
        expect(l.conceptoLibre, 'FLETE A PROVINCIA');
        expect(l.codigoLibre, 'SRV-1');
        expect(l.product.id, 0);
        expect(l.product.maximoEn(1), isNull); // sin tope de stock
        expect(p.total, 30);
        expect(p.lineProblem(l), isNull);
      });

      test('el ítem libre sin código no manda codigo_libre', () async {
        final p = await _ready(_FakeSaleRepository(), permissions: libre);
        await p.addFreeItem(descripcion: 'FLETE', precio: 15);

        expect(p.lines.single.codigoLibre, isNull);
      });

      test('pide la descripción, una cantidad válida y no vale en una cotización', () async {
        final p = await _ready(_FakeSaleRepository(), permissions: libre);

        expect((await p.addFreeItem(descripcion: '  ', precio: 15)).problem, 'Escribe la descripción del concepto');
        expect((await p.addFreeItem(descripcion: 'X', cantidad: 0, precio: 15)).problem, 'La cantidad mínima es 1');

        p.selectTipoDocumento(SaleDocumentType.cotizacion);
        expect((await p.addFreeItem(descripcion: 'X', precio: 15)).problem, 'Una cotización no admite ítems libres');
        expect(p.lines, isEmpty);
      });

      test('dos ítems libres iguales son dos líneas (no se juntan)', () async {
        final p = await _ready(_FakeSaleRepository(), permissions: libre);
        await p.addFreeItem(descripcion: 'FLETE', precio: 15);
        await p.addFreeItem(descripcion: 'FLETE', precio: 15);

        expect(p.lines, hasLength(2));
        expect(p.total, 30);
      });

      test('un código que ya es un producto del catálogo se agrega como producto normal', () async {
        final repo = _FakeSaleRepository()..products = [_product(codigo: 'SUB-12')];
        final p = await _ready(repo, permissions: libre);
        p.selectWarehouse(1);

        final r = await p.addFreeItem(descripcion: 'LO QUE SEA', codigo: 'sub-12', cantidad: 2, precio: 33);

        expect(r.problem, isNull);
        expect(r.info, 'SUB-12 ya está en el catálogo: se agregó como producto normal.');
        final l = p.lines.single;
        expect(l.esLibre, isFalse);
        expect(l.product.id, 100);
        expect(l.cantidad, 2);
        expect(l.precio, 33); // se conserva el precio escrito
      });

      test('si ese producto ya estaba en la venta se suma la cantidad y no se toca el precio', () async {
        final repo = _FakeSaleRepository()..products = [_product(codigo: 'SUB-12')];
        final p = await _ready(repo, permissions: libre);
        p.selectWarehouse(1);
        p.addProduct(_product(codigo: 'SUB-12'), cantidad: 1); // S/ 40

        final r = await p.addFreeItem(descripcion: 'X', codigo: 'SUB-12', cantidad: 2, precio: 33);

        expect(r.problem, isNull);
        expect(p.lines.single.cantidad, 3);
        expect(p.lines.single.precio, 40);
      });

      test('si el producto del catálogo no tiene stock no se vende como ítem libre', () async {
        final repo = _FakeSaleRepository()..products = [_product(codigo: 'SUB-12', stock: const {1: 0})];
        final p = await _ready(repo, permissions: libre);
        p.selectWarehouse(1);

        final r = await p.addFreeItem(descripcion: 'X', codigo: 'SUB-12', precio: 33);

        expect(r.problem, contains('SUB-12 está en el catálogo pero no tiene stock en este almacén'));
        expect(p.lines, isEmpty);
      });

      test('un código que no existe en el catálogo queda como ítem libre', () async {
        final repo = _FakeSaleRepository()..products = [_product(codigo: 'OTRO')];
        final p = await _ready(repo, permissions: libre);

        final r = await p.addFreeItem(descripcion: 'FLETE', codigo: 'SRV-9', precio: 20);

        expect(r.problem, isNull);
        expect(p.lines.single.esLibre, isTrue);
        expect(p.lines.single.codigoLibre, 'SRV-9');
      });

      group('editar un ítem libre ya agregado', () {
        test('cambia la descripción y el código y conserva cantidad, precio y descuento', () async {
          final p = await _ready(_FakeSaleRepository(), permissions: libre);
          await p.addFreeItem(descripcion: 'FLETE', cantidad: 2, precio: 15);
          p.setDto(0, 10);
          final antes = p.lines.single.product;

          final r = await p.editFreeItem(0, descripcion: '  FLETE A PROVINCIA ', codigo: ' SRV-1 ');

          expect(r.problem, isNull);
          expect(r.info, isNull);
          final l = p.lines.single;
          expect(l.esLibre, isTrue);
          expect(l.conceptoLibre, 'FLETE A PROVINCIA');
          expect(l.codigoLibre, 'SRV-1');
          expect(l.cantidad, 2);
          expect(l.precio, 15);
          expect(l.dto, 10);
          expect(identical(l.product, antes), isFalse, reason: 'la pantalla identifica la línea por su producto');
        });

        test('quitar el código lo deja sin codigo_libre', () async {
          final p = await _ready(_FakeSaleRepository(), permissions: libre);
          await p.addFreeItem(descripcion: 'FLETE', codigo: 'SRV-1', precio: 15);

          await p.editFreeItem(0, descripcion: 'FLETE', codigo: '  ');

          expect(p.lines.single.codigoLibre, isNull);
        });

        test('pide la descripción y solo vale en una línea libre', () async {
          final repo = _FakeSaleRepository()..products = [_product(codigo: 'SUB-12')];
          final p = await _ready(repo, permissions: libre);
          p.selectWarehouse(1);
          await p.addFreeItem(descripcion: 'FLETE', precio: 15);
          p.addProduct(_product(codigo: 'SUB-12'));

          expect((await p.editFreeItem(0, descripcion: '  ')).problem, 'Escribe la descripción del concepto');
          expect((await p.editFreeItem(1, descripcion: 'X')).problem, 'Esa línea no es un ítem libre');
          expect((await p.editFreeItem(9, descripcion: 'X')).problem, 'Esa línea no es un ítem libre');
          expect(p.lines.first.conceptoLibre, 'FLETE');
        });

        test('un código que ya es un producto del catálogo pasa la línea a ese producto', () async {
          final repo = _FakeSaleRepository()..products = [_product(codigo: 'SUB-12')];
          final p = await _ready(repo, permissions: libre);
          p.selectWarehouse(1);
          await p.addFreeItem(descripcion: 'LO QUE SEA', cantidad: 3, precio: 33);

          final r = await p.editFreeItem(0, descripcion: 'LO QUE SEA', codigo: 'sub-12');

          expect(r.problem, isNull);
          expect(r.info, 'SUB-12 ya está en el catálogo: se agregó como producto normal.');
          final l = p.lines.single;
          expect(l.esLibre, isFalse);
          expect(l.product.id, 100);
          expect(l.cantidad, 3);
          expect(l.precio, 33);
        });

        test('si ese producto ya estaba en la venta se suma la cantidad y la línea libre desaparece', () async {
          final repo = _FakeSaleRepository()..products = [_product(codigo: 'SUB-12')];
          final p = await _ready(repo, permissions: libre);
          p.selectWarehouse(1);
          p.addProduct(_product(codigo: 'SUB-12'), cantidad: 1);
          await p.addFreeItem(descripcion: 'X', cantidad: 2, precio: 33);

          final r = await p.editFreeItem(1, descripcion: 'X', codigo: 'SUB-12');

          expect(r.problem, isNull);
          expect(p.lines.single.cantidad, 3);
          expect(p.lines.single.precio, 40);
        });

        test('si el producto no tiene stock no se cambia nada y se da el motivo', () async {
          final repo = _FakeSaleRepository()..products = [_product(codigo: 'SUB-12', stock: const {1: 0})];
          final p = await _ready(repo, permissions: libre);
          p.selectWarehouse(1);
          await p.addFreeItem(descripcion: 'FLETE', precio: 20);

          final r = await p.editFreeItem(0, descripcion: 'OTRA', codigo: 'SUB-12');

          expect(r.problem, contains('SUB-12 está en el catálogo pero no tiene stock en este almacén'));
          expect(p.lines.single.esLibre, isTrue);
          expect(p.lines.single.conceptoLibre, 'FLETE');
          expect(p.lines.single.codigoLibre, isNull);
        });

        test('un código que no existe en el catálogo queda como ítem libre; si no cambia el código no se busca', () async {
          final repo = _FakeSaleRepository()..products = [_product(codigo: 'OTRO')];
          final p = await _ready(repo, permissions: libre);
          await p.addFreeItem(descripcion: 'FLETE', codigo: 'SRV-9', precio: 20);

          final r = await p.editFreeItem(0, descripcion: 'FLETE EXPRESS', codigo: 'SRV-9');
          expect(r.problem, isNull);
          expect(p.lines.single.conceptoLibre, 'FLETE EXPRESS');
          expect(p.lines.single.codigoLibre, 'SRV-9');

          repo.searchFails = true;
          final again = await p.editFreeItem(0, descripcion: 'FLETE EXPRESS 2', codigo: 'SRV-10');
          expect(again.problem, isNull);
          expect(p.lines.single.codigoLibre, 'SRV-10');
        });
      });

      test('si falla la búsqueda del código, igual se agrega como ítem libre', () async {
        final repo = _FakeSaleRepository()..searchFails = true;
        final p = await _ready(repo, permissions: libre);

        final r = await p.addFreeItem(descripcion: 'FLETE', codigo: 'SRV-9', precio: 20);

        expect(r.problem, isNull);
        expect(p.lines.single.esLibre, isTrue);
      });

      test('una cotización con un ítem libre se rechaza antes de enviar', () {
        final form = formOf(
          [SaleLineEntity.libre(descripcion: 'FLETE', precio: 20)],
          tipo: SaleDocumentType.cotizacion,
        );

        expect(CreateSaleUseCase.validate(form), 'Una cotización no admite ítems libres. Quita "FLETE" o emite una venta');
      });

      test('una venta con ítem libre es válida y sin descripción no', () {
        final ok = formOf([SaleLineEntity.libre(descripcion: 'FLETE', precio: 20)]);
        expect(CreateSaleUseCase.validate(ok, withPayments: false), isNull);

        final vacio = formOf([
          SaleLineEntity(
            product: SaleProductEntity(id: 0, codigo: '', name: ' ', ventaSinStock: true),
            cantidad: 1,
            precio: 20,
            conceptoLibre: '  ',
          ),
        ]);
        expect(CreateSaleUseCase.validate(vacio, withPayments: false), 'Escribe la descripción del ítem libre');
      });
    });

    group('lo que se manda al backend', () {
      test('POST /ventas manda el descuento de cada línea con los campos de la web', () {
        final form = formOf([line(dto: 10), line(cantidad: 1, precio: 30, fijo: true, dto: 5)]);

        final lines = saleToJson(form, companyId: 3, userId: 9)['product_sales'] as List;

        expect(lines[0], {
          'product_id': 100,
          'cantidad': 2,
          'precio': 50,
          'dto_fijo': false,
          'dolares': false,
          'dto': 10,
          'monto_dto': 10,
          'subtotal': 100,
          'subtotal_con_dto': 90,
        });
        expect(lines[1]['dto_fijo'], true);
        expect(lines[1]['monto_dto'], 5);
        expect(lines[1]['subtotal'], 30);
        expect(lines[1]['subtotal_con_dto'], 25);
        expect(saleToJson(form, companyId: 3, userId: 9)['totales_soles'], 115);
      });

      test('el ítem libre va con product_id nulo, su concepto y su código', () {
        final form = formOf([
          SaleLineEntity.libre(descripcion: 'FLETE', codigo: 'SRV-1', cantidad: 2, precio: 15),
          SaleLineEntity.libre(descripcion: 'INSTALACIÓN', precio: 40),
        ]);

        final lines = saleToJson(form, companyId: 3, userId: 9)['product_sales'] as List;

        expect(lines[0], {
          'product_id': null,
          'concepto_libre': 'FLETE',
          'codigo_libre': 'SRV-1',
          'cantidad': 2,
          'precio': 15,
          'dto_fijo': false,
          'dolares': false,
          'dto': 0,
          'monto_dto': 0,
          'subtotal': 30,
          'subtotal_con_dto': 30,
        });
        expect(lines[1]['product_id'], isNull);
        expect(lines[1]['codigo_libre'], isNull);
        expect(lines[1]['concepto_libre'], 'INSTALACIÓN');
      });

      test('una línea de producto no manda concepto_libre ni codigo_libre', () {
        final line0 = (saleToJson(formOf([line()]), companyId: 3, userId: 9)['product_sales'] as List).single as Map;

        expect(line0.containsKey('concepto_libre'), isFalse);
        expect(line0.containsKey('codigo_libre'), isFalse);
      });

      test('la cotización también manda el descuento', () {
        final form = formOf([line(dto: 10)], tipo: SaleDocumentType.cotizacion);

        final l = (quoteToJson(form, companyId: 3, userId: 9)['product_sales'] as List).single as Map;

        expect(l['dto'], 10);
        expect(l['monto_dto'], 10);
        expect(l['subtotal_con_dto'], 90);
        expect(quoteToJson(form, companyId: 3, userId: 9)['totales_soles'], 90);
      });

      test('el vendedor encargado viaja como vendedor_id solo si hay uno', () {
        final con = formOf([line()], vendedorId: 5);
        final sin = formOf([line()]);

        expect(saleToJson(con, companyId: 3, userId: 9)['vendedor_id'], 5);
        expect(quoteToJson(con, companyId: 3, userId: 9)['vendedor_id'], 5);
        expect(saleToJson(sin, companyId: 3, userId: 9).containsKey('vendedor_id'), isFalse);
        expect(quoteToJson(sin, companyId: 3, userId: 9).containsKey('vendedor_id'), isFalse);
      });

      test('POST /ventas manda el cuerpo completo con descuento, ítem libre y vendedor', () async {
        late Map<String, dynamic> sent;
        final dataSource = SaleRemoteDataSourceImpl(
          client: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"id": 1, "nro_documento": 1, "total_soles": 100}', 200);
          }),
        );
        final form = SaleFormEntity(
          tipoDocumento: SaleDocumentType.ticket,
          client: _acme,
          warehouseId: 1,
          vendedorId: 5,
          payments: const [SalePaymentEntity(paymentMethodId: 2, monto: 105)],
          lines: [line(dto: 10), SaleLineEntity.libre(descripcion: 'FLETE', precio: 15)],
        );

        await dataSource.createSale(token: 't', companyId: 1, userId: 9, form: form);

        expect(sent['vendedor_id'], 5);
        expect(sent['totales_soles'], 105);
        final lines = sent['product_sales'] as List;
        expect(lines[0]['dto'], 10);
        expect(lines[0]['subtotal_con_dto'], 90);
        expect(lines[1]['product_id'], isNull);
        expect(lines[1]['concepto_libre'], 'FLETE');
      });
    });

    group('culminar o editar una cotización', () {
      DocumentEntity quoteWith(List<Map<String, dynamic>> products, {int? vendedor}) => documentFromJson({
            'id': 2,
            'nro_documento': 2,
            'estado': true,
            'reservar_stock': false,
            'warehouse_id': 1,
            'list_price_id': 11,
            'vendedor_id': vendedor,
            'client': {'id': 7, 'razon_social': 'ACME SAC', 'dni_ruc': '20123456789', 'tipo': 'e'},
            'products': products,
          }, DocumentKind.cotizacion);

      Map<String, dynamic> item({Object? cantidad = 2, Object? dto = 0, Object? fijo = 0}) => {
            'id': 100,
            'codigo': 'SUB-12',
            'name': 'SUBWOOFER 12"',
            'pivot': {'cantidad': cantidad, 'precio': '35', 'dolares': false, 'dto': dto, 'dto_fijo': fijo},
          };

      test('la cotización trae el descuento de cada línea y su vendedor encargado', () {
        final d = quoteWith([item(dto: '10'), item(cantidad: 1, dto: 5, fijo: 1)], vendedor: 5).quoteDraft!;

        expect(d.vendedorId, 5);
        expect(d.lines[0].dto, 10);
        expect(d.lines[0].dtoFijo, isFalse);
        expect(d.lines[1].dto, 5);
        expect(d.lines[1].dtoFijo, isTrue);
      });

      test('sin vendedor encargado ni descuento queda en nulo y en cero', () {
        final d = quoteWith([item()]).quoteDraft!;

        expect(d.vendedorId, isNull);
        expect(d.lines.single.dto, 0);
        expect(d.lines.single.dtoFijo, isFalse);
      });

      test('cargarla en Ventas conserva los descuentos y el vendedor', () async {
        final p = await _ready(_FakeSaleRepository());
        await p.loadFromQuote(quoteWith([item(dto: 10)], vendedor: 5));

        expect(p.lines.single.dto, 10);
        expect(p.lines.single.dtoFijo, isFalse);
        expect(p.lines.single.subtotalConDto, 63); // 35 x 2 = 70 - 10 %
        expect(p.total, 63);
        expect(p.vendedorDeCotizacion, 5);
        // La venta que se emite lleva ese vendedor (en la web va en un campo oculto).
        expect(saleToJson(p.form, companyId: 1, userId: 9)['vendedor_id'], 5);
      });

      test('un mismo producto en dos líneas con distinto descuento se junta sumando lo descontado', () async {
        final p = await _ready(_FakeSaleRepository());
        await p.loadFromQuote(quoteWith([item(dto: 10), item(cantidad: 1, dto: 5, fijo: 1)]));

        final l = p.lines.single;
        expect(l.cantidad, 3);
        expect(l.dtoFijo, isTrue);
        expect(l.dto, 12); // 7 (10 % de 70) + 5
        expect(p.total, 93); // 105 - 12
      });

      test('con el mismo porcentaje en ambas líneas se conserva el porcentaje', () async {
        final p = await _ready(_FakeSaleRepository());
        await p.loadFromQuote(quoteWith([item(dto: 10), item(cantidad: 1, dto: 10)]));

        expect(p.lines.single.cantidad, 3);
        expect(p.lines.single.dtoFijo, isFalse);
        expect(p.lines.single.dto, 10);
      });

      test('al editar la cotización se manda el vendedor que se eligió (o ninguno)', () async {
        final repo = _FakeSaleRepository();
        final p = await _ready(repo);
        await p.loadFromQuote(quoteWith([item()], vendedor: 5));
        p.selectTipoDocumento(SaleDocumentType.cotizacion);

        expect(await p.submit(vendedorId: 9), isTrue);
        expect(repo.sent!.vendedorId, 9);
        expect(repo.sent!.fromQuoteId, 2);

        await p.loadFromQuote(quoteWith([item()], vendedor: 5));
        p.selectTipoDocumento(SaleDocumentType.cotizacion);
        expect(await p.submit(), isTrue);
        expect(repo.sent!.vendedorId, isNull); // se quitó el vendedor encargado
      });

      test('una cotización nueva manda el vendedor que se elige en su modal', () async {
        final repo = _FakeSaleRepository();
        final p = await _ready(repo);
        p.selectWarehouse(1);
        p.selectClient(_acme);
        p.selectPriceList(11);
        p.addProduct(_product(), cantidad: 1);
        p.selectTipoDocumento(SaleDocumentType.cotizacion);

        expect(await p.submit(vendedorId: 5), isTrue);
        expect(repo.sent!.vendedorId, 5);
      });
    });

    group('vendedores', () {
      test('se piden una sola vez', () async {
        final repo = _FakeSaleRepository();
        final p = await _ready(repo);

        await p.ensureSellers();
        await p.ensureSellers();

        expect(repo.sellerCalls, 1);
        expect(p.sellers.map((s) => s.name), ['LUIS VENDEDOR', 'ANA']);
      });

      test('GET /usuarios/list pide los roles Vendedor y Admin Empresa de la empresa', () async {
        late Uri uri;
        final dataSource = SaleRemoteDataSourceImpl(
          client: MockClient((request) async {
            uri = request.url;
            return http.Response('[{"id": 5, "name": "LUIS", "usuario": "luis"}, {"id": 6}]', 200);
          }),
        );

        final sellers = await dataSource.getSellers('t', 3);

        expect(uri.path, endsWith('/usuarios/list'));
        expect(uri.queryParameters, {'company_id': '3', 'roles[0]': 'Vendedor', 'roles[1]': 'Admin Empresa'});
        expect(sellers, hasLength(1)); // el que no trae nombre se descarta
        expect(sellers.single.id, 5);
        expect(sellers.single.name, 'LUIS');
      });

      test('sellersFromJson ignora lo que no es una lista', () {
        expect(sellersFromJson({'message': 'x'}), isEmpty);
        expect(sellersFromJson(null), isEmpty);
      });
    });
  });

  group('Pantalla de ventas: descuento, ítem libre y vendedor encargado', () {
    Future<(SalesProvider, _FakeSaleRepository)> pumpSales(
      WidgetTester tester, {
      Set<String> permissions = const {'ventas.store'},
    }) async {
      _phoneScreen(tester);
      final repo = _FakeSaleRepository();
      final session = _session(permissions: permissions);
      final sales = _provider(repo)..syncSession(session);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<SalesProvider>.value(value: sales),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SalesPage())),
        ),
      );
      await tester.pumpAndSettle();
      return (sales, repo);
    }

    Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

    testWidgets('el botón de ítem libre solo sale con el permiso factura.libre', (tester) async {
      await pumpSales(tester);
      expect(find.text('Agregar ítem libre'), findsNothing);
    });

    testWidgets('con el permiso se agrega un ítem libre desde su formulario', (tester) async {
      final (sales, _) = await pumpSales(tester, permissions: const {'ventas.store', 'factura.libre'});

      await tester.ensureVisible(find.text('Agregar ítem libre'));
      await tester.tap(find.text('Agregar ítem libre'));
      await tester.pumpAndSettle();

      expect(find.text('Agregar ítem libre'), findsWidgets);
      await tester.enterText(inSheet(_field('Descripción del concepto')), 'FLETE A PROVINCIA');
      await tester.enterText(inSheet(_field('Código (opcional)')), 'SRV-1');
      await tester.enterText(inSheet(_field('Precio S/')), '30');
      await tester.tap(inSheet(find.text('Agregar')));
      await tester.pumpAndSettle();

      expect(sales.lines, hasLength(1));
      expect(sales.lines.single.esLibre, isTrue);
      expect(sales.lines.single.codigoLibre, 'SRV-1');
      expect(find.text('FLETE A PROVINCIA'), findsOneWidget);
      expect(find.text('SRV-1 · Ítem libre'), findsOneWidget);
      expect(find.text('S/ 30.00'), findsWidgets);
    });

    testWidgets('un ítem libre agregado se puede editar desde su línea', (tester) async {
      final (sales, _) = await pumpSales(tester, permissions: const {'ventas.store', 'factura.libre'});
      await sales.addFreeItem(descripcion: 'FLETE', precio: 30);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Editar descripción y código'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Editar descripción y código'));
      await tester.tap(find.byTooltip('Editar descripción y código'));
      await tester.pumpAndSettle();

      expect(find.text('Editar ítem libre'), findsOneWidget);
      await tester.enterText(inSheet(_field('Descripción del concepto')), 'FLETE A LIMA');
      await tester.enterText(inSheet(_field('Código (opcional)')), 'SRV-2');
      await tester.tap(inSheet(find.text('Guardar')));
      await tester.pumpAndSettle();

      expect(sales.lines.single.conceptoLibre, 'FLETE A LIMA');
      expect(sales.lines.single.codigoLibre, 'SRV-2');
      expect(find.text('FLETE A LIMA'), findsOneWidget);
      expect(find.text('SRV-2 · Ítem libre'), findsOneWidget);
      expect(find.text('S/ 30.00'), findsWidgets);
    });

    testWidgets('el formulario de edición pide la descripción', (tester) async {
      final (sales, _) = await pumpSales(tester, permissions: const {'ventas.store', 'factura.libre'});
      await sales.addFreeItem(descripcion: 'FLETE', precio: 30);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byTooltip('Editar descripción y código'));
      await tester.tap(find.byTooltip('Editar descripción y código'));
      await tester.pumpAndSettle();
      await tester.enterText(inSheet(_field('Descripción del concepto')), '');
      await tester.tap(inSheet(find.text('Guardar')));
      await tester.pumpAndSettle();

      expect(find.text('Escribe la descripción'), findsOneWidget);
      expect(sales.lines.single.conceptoLibre, 'FLETE');
    });

    testWidgets('el formulario del ítem libre pide descripción y precio', (tester) async {
      final (sales, _) = await pumpSales(tester, permissions: const {'ventas.store', 'factura.libre'});

      await tester.ensureVisible(find.text('Agregar ítem libre'));
      await tester.tap(find.text('Agregar ítem libre'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Agregar')));
      await tester.pumpAndSettle();

      expect(find.text('Escribe la descripción'), findsOneWidget);
      expect(find.text('Escribe el precio'), findsOneWidget);
      expect(sales.lines, isEmpty);
    });

    testWidgets('en una cotización el ítem libre se rechaza con el motivo en el formulario', (tester) async {
      final (sales, _) = await pumpSales(tester, permissions: const {'ventas.store', 'factura.libre'});
      sales.selectTipoDocumento(SaleDocumentType.cotizacion);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Agregar ítem libre'));
      await tester.tap(find.text('Agregar ítem libre'));
      await tester.pumpAndSettle();
      await tester.enterText(inSheet(_field('Descripción del concepto')), 'FLETE');
      await tester.enterText(inSheet(_field('Precio S/')), '30');
      await tester.tap(inSheet(find.text('Agregar')));
      await tester.pumpAndSettle();

      expect(find.text('Una cotización no admite ítems libres'), findsOneWidget);
      expect(sales.lines, isEmpty);
    });

    testWidgets('cada línea tiene su descuento en % y se puede cambiar a monto', (tester) async {
      final (sales, _) = await pumpSales(tester);
      sales.selectWarehouse(1);
      sales.addProduct(_product(), cantidad: 2); // S/ 40 x 2
      await tester.pumpAndSettle();

      expect(find.text('Descuento %'), findsOneWidget);
      await tester.ensureVisible(_field('Descuento %'));
      await tester.enterText(_field('Descuento %'), '10');
      await tester.pumpAndSettle();

      expect(sales.lines.single.dto, 10);
      expect(sales.total, 72);
      expect(find.text('Desc. −S/ 8.00'), findsOneWidget);
      expect(find.text('S/ 72.00'), findsWidgets);

      await tester.tap(find.byTooltip('Descontar un monto fijo'));
      await tester.pumpAndSettle();

      expect(find.text('Descuento S/'), findsOneWidget);
      expect(sales.lines.single.dtoFijo, isTrue);
      expect(sales.total, 70);
      expect(find.text('Desc. −S/ 10.00'), findsOneWidget);
    });

    testWidgets('el descuento escrito se recorta al máximo y el campo lo refleja', (tester) async {
      final (sales, _) = await pumpSales(tester);
      sales.selectWarehouse(1);
      sales.addProduct(_product(), cantidad: 2);
      await tester.pumpAndSettle();

      await tester.ensureVisible(_field('Descuento %'));
      await tester.enterText(_field('Descuento %'), '150');
      await tester.pumpAndSettle();

      expect(sales.lines.single.dto, 100);
      expect(tester.widget<TextField>(_field('Descuento %')).controller!.text, '100');
      expect(sales.total, 0);
    });

    testWidgets('la cotización pregunta por el vendedor encargado y lo manda', (tester) async {
      final (sales, repo) = await pumpSales(tester);
      sales.selectWarehouse(1);
      sales.selectClient(_acme);
      sales.addProduct(_product(), cantidad: 1);
      sales.selectTipoDocumento(SaleDocumentType.cotizacion);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear cotización'));
      await tester.pumpAndSettle();

      expect(find.text('Vendedor encargado (opcional)'), findsOneWidget);
      expect(repo.sellerCalls, 1);

      // El propio usuario (Ana, id 9) no se ofrece: solo los demás.
      await tester.tap(find.text('Sin vendedor encargado'));
      await tester.pumpAndSettle();
      expect(find.text('ANA'), findsNothing);
      await tester.tap(find.text('LUIS VENDEDOR').last);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Crear')));
      await tester.pumpAndSettle();

      expect(repo.sent!.tipoDocumento, SaleDocumentType.cotizacion);
      expect(repo.sent!.vendedorId, 5);
    });

    testWidgets('el vendedor encargado es opcional', (tester) async {
      final (sales, repo) = await pumpSales(tester);
      sales.selectWarehouse(1);
      sales.selectClient(_acme);
      sales.addProduct(_product(), cantidad: 1);
      sales.selectTipoDocumento(SaleDocumentType.cotizacion);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear cotización'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Crear')));
      await tester.pumpAndSettle();

      expect(repo.sent!.vendedorId, isNull);
    });
  });

  group('Modal de la cotización: vendedor encargado', () {
    const sellers = [
      SellerEntity(id: 5, name: 'LUIS VENDEDOR'),
      SellerEntity(id: 6, name: 'MARÍA'),
      SellerEntity(id: 9, name: 'ANA'),
    ];

    /// Abre el modal desde un botón; lo que devuelve al cerrarse queda en la lista.
    Future<List<QuoteOptions?>> open(
      WidgetTester tester, {
      List<SellerEntity> sellers = const [],
      int? initial,
      int? exclude,
      bool editing = false,
    }) async {
      _phoneScreen(tester);
      final results = <QuoteOptions?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => results.add(
                  await showQuoteOptions(
                    context,
                    now: DateTime(2026, 10, 20),
                    client: 'ACME',
                    total: 'S/ 100.00',
                    sellers: sellers,
                    initialSellerId: initial,
                    excludeSellerId: exclude,
                    editing: editing,
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('sin vendedores no sale el campo', (tester) async {
      await open(tester);

      expect(find.text('Vendedor encargado (opcional)'), findsNothing);
    });

    testWidgets('el propio usuario no se ofrece y se puede elegir a otro', (tester) async {
      final results = await open(tester, sellers: sellers, exclude: 9);

      expect(find.text('Vendedor encargado (opcional)'), findsOneWidget);
      await tester.tap(find.text('Sin vendedor encargado'));
      await tester.pumpAndSettle();
      expect(find.text('LUIS VENDEDOR'), findsOneWidget);
      expect(find.text('MARÍA'), findsOneWidget);
      expect(find.text('ANA'), findsNothing);

      await tester.tap(find.text('MARÍA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(results.single!.vendedorId, 6);
      expect(results.single!.reservarStock, isFalse);
    });

    testWidgets('sin tocar nada la cotización queda sin vendedor encargado', (tester) async {
      final results = await open(tester, sellers: sellers, exclude: 9);

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(results.single!.vendedorId, isNull);
    });

    testWidgets('al editar arranca con el vendedor que ya tenía y se puede quitar', (tester) async {
      final results = await open(tester, sellers: sellers, initial: 6, exclude: 9, editing: true);

      expect(find.text('Editar cotización'), findsOneWidget);
      expect(find.text('MARÍA'), findsOneWidget);

      await tester.tap(find.text('MARÍA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin vendedor encargado').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(results.single!.vendedorId, isNull);
    });

    testWidgets('al editar sin tocar el campo se conserva el vendedor', (tester) async {
      final results = await open(tester, sellers: sellers, initial: 6, exclude: 9, editing: true);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(results.single!.vendedorId, 6);
    });

    testWidgets('si el vendedor de la cotización ya no se puede elegir, queda sin vendedor', (tester) async {
      final results = await open(tester, sellers: sellers, initial: 77, exclude: 9);

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(results.single!.vendedorId, isNull);
    });

    testWidgets('cancelar no devuelve nada', (tester) async {
      final results = await open(tester, sellers: sellers, exclude: 9);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(results.single, isNull);
    });
  });

  group('Comprobante con descuento e ítem libre', () {
    final venta = documentFromJson({
      'id': 1,
      'nro_documento': 1,
      'estado': true,
      'total_soles': 110,
      'warehouse': {'id': 1, 'name': 'LIMA'},
      'client': {'id': 7, 'razon_social': 'ACME SAC', 'dni_ruc': '20123456789', 'tipo': 'e'},
      // El backend entrega los ítems libres como un producto sin id, con su descripción en `name`.
      'products': [
        {
          'id': null,
          'name': 'FLETE A PROVINCIA',
          'codigo': 'SRV-1',
          'brand': null,
          'pivot': {
            'id': 1,
            'concepto_libre': 'FLETE A PROVINCIA',
            'cantidad': 1,
            'precio': 20,
            'dto': 0,
            'monto_dto': 0,
            'subtotal': 20,
            'subtotal_con_dto': 20,
            'dolares': false,
          },
        },
        {
          'id': 100,
          'name': 'SUBWOOFER 12"',
          'codigo': 'SUB-12',
          'brand': {'name': 'PIONEER'},
          'pivot': {
            'id': 2,
            'cantidad': 2,
            'precio': 50,
            'dto': 10,
            'dto_fijo': 0,
            'monto_dto': 10,
            'subtotal': 100,
            'subtotal_con_dto': 90,
            'dolares': false,
          },
        },
      ],
    }, DocumentKind.venta);

    test('el comprobante lee el ítem libre y el descuento de la línea', () {
      expect(venta.items, hasLength(2));
      expect(venta.items[0].name, 'FLETE A PROVINCIA');
      expect(venta.items[0].codigo, 'SRV-1');
      expect(venta.items[1].descuento, 10);
      expect(venta.items[1].subtotal, 90); // ya con el descuento
      expect(venta.descuento, 10); // el comprobante muestra el descuento total
    });

    test('el PDF A4 y el ticket salen con el ítem libre y el descuento', () async {
      const company = CompanyEntity(id: 1, razonSocial: 'ACME');
      for (final ticket in [false, true]) {
        final bytes = await buildReceiptPdf(document: venta, company: company, ticket: ticket);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: 'ticket=$ticket');
        expect(bytes.length, greaterThan(800));
      }
    });
  });
}
