import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
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
import 'package:app_novik/presentation/pages/sales_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/clients_provider.dart';
import 'package:app_novik/presentation/providers/sales_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/presentation/widgets/sale_modals.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      Either.right(products ?? [_product()]);

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
}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME', emiteComprobantes: certificado),
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
  );
}

Future<SalesProvider> _ready(_FakeSaleRepository repo, {bool certificado = false}) async {
  final p = _provider(repo)..syncSession(_session(certificado: certificado));
  await p.ensureLoaded();
  return p;
}

const _acme = ClientEntity(id: 7, name: 'ACME SAC', documento: '20123456789', tipo: 'e');

SaleFormEntity _form({
  ClientEntity? client = _acme,
  SaleDocumentType tipo = SaleDocumentType.ticket,
  int? warehouseId = 1,
  int? paymentMethodId = 2,
  List<SaleLineEntity>? lines,
}) =>
    SaleFormEntity(
      tipoDocumento: tipo,
      client: client,
      warehouseId: warehouseId,
      paymentMethodId: paymentMethodId,
      lines: lines ?? [SaleLineEntity(product: _product(), cantidad: 2, precio: 50)],
    );

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
      expect(CreateSaleUseCase.validate(_form(paymentMethodId: null)), 'Elige la forma de pago');
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

    test('las formas de pago a plazo, con puntos o contraentrega no son al contado', () {
      expect(const PaymentMethodEntity(id: 1, name: 'CRÉDITO').alContado, isFalse);
      expect(const PaymentMethodEntity(id: 1, name: 'PLAZO 30 DÍAS').alContado, isFalse);
      expect(const PaymentMethodEntity(id: 1, name: 'PUNTOS').alContado, isFalse);
      expect(const PaymentMethodEntity(id: 1, name: 'CONTRAENTREGA').alContado, isFalse);
      expect(const PaymentMethodEntity(id: 1, name: 'YAPE').alContado, isTrue);
    });
  });

  group('SalesProvider', () {
    test('carga solo listas en soles y formas de pago al contado, con los predeterminados', () async {
      final p = await _ready(_FakeSaleRepository());
      expect(p.priceLists.map((l) => l.id), [10, 11]);
      expect(p.paymentMethods.map((m) => m.name), ['EFECTIVO', 'YAPE']);
      expect(p.warehouseId, 2); // el del usuario
      expect(p.priceListId, 11); // el del usuario
      expect(p.paymentMethodId, 2); // EFECTIVO
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

    test('la lista del cliente manda, salvo que se haya elegido a mano o sea en dólares', () async {
      final p = await _ready(_FakeSaleRepository());
      p.selectClient(const ClientEntity(id: 1, name: 'A', listPriceId: 10));
      expect(p.priceListId, 10);

      p.selectClient(const ClientEntity(id: 2, name: 'B', listPriceId: 12)); // dólares
      expect(p.priceListId, 10);

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
      p.setObservaciones('Entregar mañana');

      expect(p.prepare(), isTrue);
      expect(await p.submit(), isTrue);

      expect(repo.sentCompany, 1);
      expect(repo.sentUser, 9);
      expect(repo.sent!.total, 40);
      expect(repo.sent!.observaciones, 'Entregar mañana');
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

      expect(await p.submit(), isFalse);
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

      expect(await p.submit(), isFalse);
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

    testWidgets('registrar pide confirmación y muestra la venta registrada', (tester) async {
      final (sales, repo) = await pump(tester);
      sales.selectWarehouse(1);
      sales.selectClient(_acme);
      sales.addProduct(_product());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar'), findsOneWidget);
      expect(repo.sent, isNull);

      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(repo.sent, isNotNull);
      expect(find.text('Venta registrada'), findsOneWidget);
      expect(find.text('V001-0001'), findsOneWidget);
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
        ['Nota de venta', 'Cotización'],
      );
      expect(
        (await _ready(_FakeSaleRepository(), certificado: true)).documentTypes.map((t) => t.label),
        ['Nota de venta', 'Boleta', 'Factura', 'Cotización'],
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
      p.selectPaymentMethod(null);
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
        paymentMethodId: null,
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
          paymentMethodId: null,
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
      expect(find.text('Nota de venta'), findsOneWidget);
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
}
