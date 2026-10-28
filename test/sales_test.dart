import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/models/sale_model.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart';
import 'package:app_novik/domain/entities/product_form_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/sale_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/stock_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/sale_repository.dart';
import 'package:app_novik/domain/repositories/stock_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/sale_usecases.dart';
import 'package:app_novik/domain/usecases/stock_usecases.dart';
import 'package:app_novik/presentation/pages/sales_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/sales_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
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
      Either.right([_product()]);

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
    return result ?? Either.right(_sale());
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
  Map<int, double> stock = const {1: 5, 2: 0},
  Map<int, double> prices = const {10: 50, 11: 40},
  bool sinStock = false,
}) =>
    SaleProductEntity(
      id: id,
      codigo: 'SUB-12',
      name: 'SUBWOOFER 12"',
      marca: 'PIONEER',
      ventaSinStock: sinStock,
      stockPorAlmacen: stock,
      precioPorLista: prices,
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

SessionContextEntity _session({int companyId = 1, bool certificado = false}) => SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME', emiteComprobantes: certificado),
      modules: const [],
      permissions: const {'ventas.store'},
      roles: const [],
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
      expect((await _ready(_FakeSaleRepository())).documentTypes, [SaleDocumentType.ticket]);
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
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'sub');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SUBWOOFER 12"'));
      await tester.pumpAndSettle();
      expect(sales.lines.single.cantidad, 1);
      expect(find.text('×1'), findsOneWidget);

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.text('SUBWOOFER 12"'), findsOneWidget);
      expect(find.text('S/ 40.00'), findsWidgets);

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(sales.lines.single.cantidad, 2);
      expect(sales.total, 80);
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
}
