import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/product_form_entity.dart';
import '../../domain/entities/sale_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../../domain/usecases/stock_usecases.dart';

/// Estado del módulo Ventas: el borrador de una venta al contado en soles
/// (comprobante, cliente, almacén, lista de precios, productos y forma de pago).
class SalesProvider extends ChangeNotifier {
  final GetWarehousesUseCase _getWarehouses;
  final GetPriceListsUseCase _getPriceLists;
  final GetPaymentMethodsUseCase _getPaymentMethods;
  final GetSaleProductFiltersUseCase _getProductFilters;
  final GetExchangeRateUseCase _getExchangeRate;
  final GetWalkInClientUseCase _getWalkInClient;
  final SearchClientsUseCase _searchClients;
  final SearchSaleProductsUseCase _searchProducts;
  final CreateSaleUseCase _createSale;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  SalesProvider({
    required GetWarehousesUseCase getWarehousesUseCase,
    required GetPriceListsUseCase getPriceListsUseCase,
    required GetPaymentMethodsUseCase getPaymentMethodsUseCase,
    required GetSaleProductFiltersUseCase getSaleProductFiltersUseCase,
    required GetExchangeRateUseCase getExchangeRateUseCase,
    required GetWalkInClientUseCase getWalkInClientUseCase,
    required SearchClientsUseCase searchClientsUseCase,
    required SearchSaleProductsUseCase searchSaleProductsUseCase,
    required CreateSaleUseCase createSaleUseCase,
    VoidCallback? onSessionExpired,
  })  : _getWarehouses = getWarehousesUseCase,
        _getPriceLists = getPriceListsUseCase,
        _getPaymentMethods = getPaymentMethodsUseCase,
        _getProductFilters = getSaleProductFiltersUseCase,
        _getExchangeRate = getExchangeRateUseCase,
        _getWalkInClient = getWalkInClientUseCase,
        _searchClients = searchClientsUseCase,
        _searchProducts = searchSaleProductsUseCase,
        _createSale = createSaleUseCase,
        _onSessionExpired = onSessionExpired;

  int? _companyId;
  int? _userId;
  int? _defaultWarehouseId;
  int? _defaultPriceListId;
  bool _emiteComprobantes = false;
  bool _initialized = false;
  int _request = 0;

  /// La lista la eligió el usuario a mano: cambiar de cliente ya no la pisa.
  bool _listaElegidaAMano = false;

  List<CatalogItemEntity> warehouses = [];

  /// Solo listas en soles: las ventas en dólares llegan en una próxima versión.
  List<PriceListEntity> priceLists = [];
  List<PaymentMethodEntity> paymentMethods = [];

  /// Categorías y marcas del buscador de productos; se piden la primera vez que se abre.
  SaleProductFiltersEntity productFilters = const SaleProductFiltersEntity();
  bool _productFiltersLoaded = false;
  bool loading = false;
  String? error;

  /// Tipo de cambio comercial vigente, para mostrarlo en pantalla.
  ExchangeRateEntity? exchangeRate;
  bool exchangeRateLoading = false;
  String? exchangeRateError;

  // Borrador de la venta.
  SaleDocumentType tipoDocumento = SaleDocumentType.ticket;
  ClientEntity? client;
  int? warehouseId;
  int? priceListId;
  int? paymentMethodId;
  String observaciones = '';
  List<SaleLineEntity> lines = [];

  /// Boleta sin documento del cliente: se vende a "CLIENTE VARIOS" (solo boletas menores a S/ 700).
  bool sinDocumento = false;
  bool sinDocumentoLoading = false;

  bool submitting = false;
  String? submitError;

  /// Última venta registrada, para mostrar la confirmación.
  SaleResultEntity? lastSale;

  /// Boleta y factura solo si la empresa tiene certificado digital. La cotización siempre.
  List<SaleDocumentType> get documentTypes => _emiteComprobantes
      ? SaleDocumentType.values
      : const [SaleDocumentType.ticket, SaleDocumentType.cotizacion];

  /// Se puede vender sin documento del cliente: boleta, en soles y menor a S/ 700 (regla SUNAT).
  bool get puedeSinDocumento =>
      tipoDocumento == SaleDocumentType.boleta && total > 0 && total < 700;

  /// La factura no se emite a un cliente de tipo persona.
  bool get facturaAPersona =>
      tipoDocumento == SaleDocumentType.factura && (client?.esPersona ?? false);

  @override
  void notifyListeners() {
    // Si dejan de cumplirse las condiciones (otro comprobante, un total de S/ 700 o más),
    // la venta sin documento se descarta, igual que en la web.
    if (sinDocumento && !puedeSinDocumento) {
      sinDocumento = false;
      client = null;
    }
    super.notifyListeners();
  }

  double get total =>
      roundMoney(lines.fold<double>(0, (sum, l) => sum + l.subtotal));

  SaleFormEntity get form => _buildForm();

  SaleFormEntity _buildForm({bool reservarStock = false, DateTime? vencimientoStock}) =>
      SaleFormEntity(
        tipoDocumento: tipoDocumento,
        client: client,
        warehouseId: warehouseId,
        paymentMethodId: paymentMethodId,
        lines: lines,
        observaciones: observaciones,
        priceListId: priceListId,
        reservarStock: reservarStock,
        vencimientoStock: vencimientoStock,
      );

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo.
  /// No notifica: corre mientras se construye el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    _defaultWarehouseId = session?.defaultWarehouseId;
    _defaultPriceListId = session?.defaultListPriceId;
    _emiteComprobantes = session?.company.emiteComprobantes ?? false;
    final companyId = session?.company.id;
    final userId = session?.user.id;
    if (companyId == _companyId && userId == _userId) return;
    _companyId = companyId;
    _userId = userId;
    _initialized = false;
    _request++;
    warehouses = [];
    priceLists = [];
    paymentMethods = [];
    productFilters = const SaleProductFiltersEntity();
    _productFiltersLoaded = false;
    exchangeRate = null;
    exchangeRateLoading = false;
    exchangeRateError = null;
    loading = false;
    error = null;
    lastSale = null;
    _resetDraft();
  }

  void _resetDraft() {
    tipoDocumento = SaleDocumentType.ticket;
    client = null;
    warehouseId = null;
    priceListId = null;
    paymentMethodId = null;
    observaciones = '';
    lines = [];
    sinDocumento = false;
    sinDocumentoLoading = false;
    submitting = false;
    submitError = null;
    _listaElegidaAMano = false;
  }

  /// Carga almacenes, listas de precios y formas de pago la primera vez.
  Future<void> ensureLoaded() async {
    if (_companyId == null || _initialized || loading) return;
    await _initialize();
  }

  Future<void> retry() async {
    _initialized = false;
    await ensureLoaded();
  }

  Future<void> _initialize() async {
    final companyId = _companyId!;
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();

    final results = await Future.wait([
      _getWarehouses(companyId),
      _getPriceLists(companyId),
      _getPaymentMethods(),
    ]);
    if (request != _request) return;

    for (final r in results) {
      if (r.isLeft) {
        final failure = r.left;
        error = failure.message;
        loading = false;
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
        notifyListeners();
        return;
      }
    }

    warehouses = results[0].right as List<CatalogItemEntity>;
    priceLists = (results[1].right as List<PriceListEntity>)
        .where((p) => !p.esDolares)
        .toList();
    paymentMethods = (results[2].right as List<PaymentMethodEntity>)
        .where((m) => m.alContado)
        .toList();

    // Como la web: el predeterminado del usuario, o el último de la lista.
    warehouseId ??= _pick(warehouses.map((w) => w.id).toList(), _defaultWarehouseId);
    priceListId ??= _pick(priceLists.map((p) => p.id).toList(), _defaultPriceListId);
    paymentMethodId ??= _defaultPaymentMethod();
    _initialized = true;
    loading = false;
    notifyListeners();

    // El tipo de cambio no bloquea la venta: se pide aparte y, si falla, solo se avisa.
    loadExchangeRate();
  }

  /// Pide el tipo de cambio comercial vigente (también al tocar actualizar).
  Future<void> loadExchangeRate() async {
    final companyId = _companyId;
    if (companyId == null || exchangeRateLoading) return;
    exchangeRateLoading = true;
    exchangeRateError = null;
    notifyListeners();

    final result = await _getExchangeRate();
    if (companyId != _companyId) return;
    exchangeRateLoading = false;
    result.fold(
      (failure) {
        exchangeRate = null;
        exchangeRateError = failure.message;
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
      },
      (rate) => exchangeRate = rate,
    );
    notifyListeners();
  }

  /// Marca o desmarca "sin documento del cliente". Al marcar se elige a "CLIENTE VARIOS";
  /// al desmarcar se quita el cliente. Devuelve el motivo si no se pudo.
  Future<String?> toggleSinDocumento(bool on) async {
    if (!on) {
      sinDocumento = false;
      client = null;
      notifyListeners();
      return null;
    }
    final companyId = _companyId;
    if (companyId == null || !puedeSinDocumento) return null;

    sinDocumentoLoading = true;
    notifyListeners();
    final result = await _getWalkInClient(companyId);
    sinDocumentoLoading = false;
    if (companyId != _companyId) return null;

    if (result.isLeft) {
      _checkSession(result);
      notifyListeners();
      return result.left.message;
    }
    sinDocumento = true;
    selectClient(result.right);
    return null;
  }

  int? _pick(List<int> ids, int? preferred) {
    if (ids.isEmpty) return null;
    return ids.contains(preferred) ? preferred : ids.last;
  }

  /// La del cliente si se puede usar al contado; si no, EFECTIVO o la primera.
  int? _defaultPaymentMethod() {
    if (paymentMethods.isEmpty) return null;
    final preferred = client?.paymentMethodId;
    if (paymentMethods.any((m) => m.id == preferred)) return preferred;
    for (final m in paymentMethods) {
      if (m.name.toUpperCase() == 'EFECTIVO') return m.id;
    }
    return paymentMethods.first.id;
  }

  // --- Búsquedas (las usa la interfaz con su propio debounce) ---

  Future<Either<Failure, List<ClientEntity>>> searchClients(String text) async {
    final result = await _searchClients(companyId: _companyId!, search: text);
    _checkSession(result);
    return result;
  }

  Future<Either<Failure, List<SaleProductEntity>>> searchProducts(String text) async {
    final result = await _searchProducts(companyId: _companyId!, search: text);
    _checkSession(result);
    return result;
  }

  /// Categorías y marcas para el buscador. Si fallan, el buscador sigue sin esos filtros.
  Future<void> ensureProductFilters() async {
    final companyId = _companyId;
    if (companyId == null || _productFiltersLoaded) return;
    final result = await _getProductFilters();
    if (companyId != _companyId) return;
    if (result.isRight) {
      productFilters = result.right;
      _productFiltersLoaded = true;
      notifyListeners();
    } else {
      _checkSession(result);
    }
  }

  void _checkSession(Either<Failure, Object?> result) {
    if (result.isLeft && result.left is AuthenticationFailure) _onSessionExpired?.call();
  }

  // --- Borrador ---

  void selectTipoDocumento(SaleDocumentType value) {
    tipoDocumento = value;
    submitError = null;
    notifyListeners();
  }

  void selectClient(ClientEntity? value) {
    client = value;
    submitError = null;
    // La lista del cliente manda, salvo que el usuario haya elegido otra a mano
    // o que esté en dólares (esta versión solo vende en soles).
    final listId = value?.listPriceId;
    if (!_listaElegidaAMano && priceLists.any((p) => p.id == listId)) {
      priceListId = listId;
      _repriceLines();
    }
    final preferred = value?.paymentMethodId;
    if (paymentMethods.any((m) => m.id == preferred)) paymentMethodId = preferred;
    notifyListeners();
  }

  void selectWarehouse(int? id) {
    warehouseId = id;
    submitError = null;
    notifyListeners();
  }

  void selectPriceList(int? id) {
    priceListId = id;
    _listaElegidaAMano = true;
    _repriceLines();
    notifyListeners();
  }

  void selectPaymentMethod(int? id) {
    paymentMethodId = id;
    notifyListeners();
  }

  void setObservaciones(String text) {
    observaciones = text;
  }

  /// Al cambiar de lista, cada línea toma el precio de la nueva (0 si el
  /// producto no está en ella, igual que la web).
  void _repriceLines() {
    final list = priceListId;
    if (list == null) return;
    lines = [for (final l in lines) l.copyWith(precio: l.product.precioEn(list))];
  }

  /// Unidades de [productId] que ya están en la venta.
  int cantidadEnVenta(int productId) {
    for (final l in lines) {
      if (l.product.id == productId) return l.cantidad;
    }
    return 0;
  }

  /// Cuántas unidades más se pueden agregar de [product] con el almacén actual;
  /// `null` si no hay tope (servicio o venta sin stock).
  double? disponibleParaAgregar(SaleProductEntity product) {
    final warehouse = warehouseId;
    if (warehouse == null) return 0;
    final max = product.maximoEn(warehouse);
    if (max == null) return null;
    final left = max - cantidadEnVenta(product.id);
    return left < 0 ? 0 : left;
  }

  /// Motivo por el que no se pueden agregar [cantidad] unidades más de [product].
  String? _problemaAlAgregar(SaleProductEntity product, int cantidad) {
    if (cantidad < 1) return '"${product.name}": la cantidad mínima es 1';
    final available = disponibleParaAgregar(product);
    if (available == null || cantidad <= available) return null;

    final enVenta = cantidadEnVenta(product.id);
    final max = product.maximoEn(warehouseId!)!;
    if (max <= 0) return '"${product.name}" no tiene stock en este almacén';
    return 'Solo hay ${formatQuantity(max)} de "${product.name}" en este almacén'
        '${enVenta > 0 ? ' (ya hay $enVenta en la venta)' : ''}';
  }

  /// Agrega el producto, o suma [cantidad] si ya estaba. Con [precio] la línea queda con ese
  /// precio en lugar del de la lista. Devuelve el motivo si no se pudo.
  String? addProduct(SaleProductEntity product, {int cantidad = 1, double? precio}) {
    final problems = addProducts([(product: product, cantidad: cantidad)]);
    if (problems.isNotEmpty) return problems.first;

    if (precio != null && precio >= 0) {
      final index = lines.indexWhere((l) => l.product.id == product.id);
      if (index != -1) {
        lines = [...lines]..[index] = lines[index].copyWith(precio: precio);
        notifyListeners();
      }
    }
    return null;
  }

  /// Agrega varios productos a la vez, cada uno con su cantidad (los que ya están suman).
  /// Si alguno no se puede (sin stock, cantidad inválida...) no se agrega ninguno y se
  /// devuelven los motivos.
  List<String> addProducts(List<({SaleProductEntity product, int cantidad})> entries) {
    if (warehouseId == null) return ['Elige el almacén primero'];
    final list = priceListId;
    if (list == null) return ['Elige una lista de precios primero'];

    final problems = <String>[];
    for (final e in entries) {
      final problem = _problemaAlAgregar(e.product, e.cantidad);
      if (problem != null) problems.add(problem);
    }
    if (problems.isNotEmpty || entries.isEmpty) return problems;

    final next = [...lines];
    for (final e in entries) {
      final index = next.indexWhere((l) => l.product.id == e.product.id);
      if (index == -1) {
        next.add(SaleLineEntity(
          product: e.product,
          cantidad: e.cantidad,
          precio: e.product.precioEn(list),
        ));
      } else {
        next[index] = next[index].copyWith(cantidad: next[index].cantidad + e.cantidad);
      }
    }
    lines = next;
    submitError = null;
    notifyListeners();
    return const [];
  }

  /// Fija la cantidad. Devuelve el motivo si se recortó por falta de stock.
  String? setCantidad(int index, int cantidad) {
    if (index < 0 || index >= lines.length) return null;
    final line = lines[index];
    var value = cantidad < 1 ? 1 : cantidad;
    String? aviso;
    final max = warehouseId == null ? null : line.product.maximoEn(warehouseId!);
    if (max != null && value > max) {
      value = max.floor() < 1 ? 1 : max.floor();
      aviso = 'Solo hay ${formatQuantity(max)} de "${line.product.name}" en este almacén';
    }
    lines = [...lines]..[index] = line.copyWith(cantidad: value);
    submitError = null;
    notifyListeners();
    return aviso;
  }

  void setPrecio(int index, double precio) {
    if (index < 0 || index >= lines.length) return;
    lines = [...lines]..[index] = lines[index].copyWith(precio: precio < 0 ? 0 : precio);
    submitError = null;
    notifyListeners();
  }

  void removeLine(int index) {
    if (index < 0 || index >= lines.length) return;
    lines = [...lines]..removeAt(index);
    notifyListeners();
  }

  /// Problema de una línea con el almacén y precio actuales (para marcarla en pantalla).
  String? lineProblem(SaleLineEntity line) {
    if (line.precio <= 0) return 'Sin precio. Escríbelo para poder vender';
    final warehouse = warehouseId;
    final max = warehouse == null ? null : line.product.maximoEn(warehouse);
    if (max != null && line.cantidad > max) {
      return max <= 0
          ? 'Sin stock en este almacén'
          : 'Solo hay ${formatQuantity(max)} en este almacén';
    }
    return null;
  }

  void clearDraft() {
    final keepWarehouse = warehouseId;
    _resetDraft();
    warehouseId = keepWarehouse;
    priceListId = _pick(priceLists.map((p) => p.id).toList(), _defaultPriceListId);
    paymentMethodId = _defaultPaymentMethod();
    notifyListeners();
  }

  /// Revisa el borrador antes de pedir confirmación. Deja el motivo en [submitError].
  bool prepare() {
    submitError = CreateSaleUseCase.validate(form);
    notifyListeners();
    return submitError == null;
  }

  /// Registra la venta o la cotización. Si sale bien, deja el borrador limpio para la siguiente.
  /// [reservarStock] y [vencimientoStock] solo valen para cotizaciones.
  Future<bool> submit({bool reservarStock = false, DateTime? vencimientoStock}) async {
    final companyId = _companyId;
    final userId = _userId;
    if (companyId == null || userId == null || submitting) return false;

    submitting = true;
    submitError = null;
    notifyListeners();

    final result = await _createSale(
      companyId: companyId,
      userId: userId,
      form: _buildForm(reservarStock: reservarStock, vencimientoStock: vencimientoStock),
    );

    submitting = false;
    var ok = false;
    result.fold(
      (failure) {
        // Un rechazo del backend (400/422) revierte todo, se puede reintentar.
        // Una caída de red o un error del servidor puede haber dejado la venta registrada.
        final incierto = failure is NetworkFailure || failure is ServerFailure || failure is UnknownFailure;
        submitError = incierto
            ? '${failure.message}. Antes de reintentar, revisa en Documentos si ${tipoDocumento.esCotizacion ? 'la cotización' : 'la venta'} ya quedó registrada.'
            : failure.message;
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
      },
      (sale) {
        lastSale = sale;
        ok = true;
      },
    );
    if (ok) clearDraft();
    notifyListeners();
    return ok;
  }
}
