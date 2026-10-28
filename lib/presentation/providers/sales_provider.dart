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
  final SearchClientsUseCase _searchClients;
  final SearchSaleProductsUseCase _searchProducts;
  final CreateSaleUseCase _createSale;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  SalesProvider({
    required GetWarehousesUseCase getWarehousesUseCase,
    required GetPriceListsUseCase getPriceListsUseCase,
    required GetPaymentMethodsUseCase getPaymentMethodsUseCase,
    required SearchClientsUseCase searchClientsUseCase,
    required SearchSaleProductsUseCase searchSaleProductsUseCase,
    required CreateSaleUseCase createSaleUseCase,
    VoidCallback? onSessionExpired,
  })  : _getWarehouses = getWarehousesUseCase,
        _getPriceLists = getPriceListsUseCase,
        _getPaymentMethods = getPaymentMethodsUseCase,
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
  bool loading = false;
  String? error;

  // Borrador de la venta.
  SaleDocumentType tipoDocumento = SaleDocumentType.ticket;
  ClientEntity? client;
  int? warehouseId;
  int? priceListId;
  int? paymentMethodId;
  String observaciones = '';
  List<SaleLineEntity> lines = [];

  bool submitting = false;
  String? submitError;

  /// Última venta registrada, para mostrar la confirmación.
  SaleResultEntity? lastSale;

  /// Boleta y factura solo si la empresa tiene certificado digital.
  List<SaleDocumentType> get documentTypes => _emiteComprobantes
      ? SaleDocumentType.values
      : const [SaleDocumentType.ticket];

  double get total =>
      roundMoney(lines.fold<double>(0, (sum, l) => sum + l.subtotal));

  SaleFormEntity get form => SaleFormEntity(
        tipoDocumento: tipoDocumento,
        client: client,
        warehouseId: warehouseId,
        paymentMethodId: paymentMethodId,
        lines: lines,
        observaciones: observaciones,
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

  /// Agrega el producto, o suma una unidad si ya estaba. Devuelve el motivo si no se pudo.
  String? addProduct(SaleProductEntity product) {
    final warehouse = warehouseId;
    final list = priceListId;
    if (warehouse == null) return 'Elige el almacén primero';
    if (list == null) return 'Elige una lista de precios primero';

    final max = product.maximoEn(warehouse);
    final index = lines.indexWhere((l) => l.product.id == product.id);
    final current = index == -1 ? 0 : lines[index].cantidad;
    if (max != null && current + 1 > max) {
      return max <= 0
          ? '"${product.name}" no tiene stock en este almacén'
          : 'Solo hay ${formatQuantity(max)} de "${product.name}" en este almacén';
    }

    if (index == -1) {
      lines = [
        ...lines,
        SaleLineEntity(product: product, cantidad: 1, precio: product.precioEn(list)),
      ];
    } else {
      setCantidad(index, current + 1);
      return null;
    }
    submitError = null;
    notifyListeners();
    return null;
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

  /// Registra la venta. Si sale bien, deja el borrador limpio para la siguiente.
  Future<bool> submit() async {
    final companyId = _companyId;
    final userId = _userId;
    if (companyId == null || userId == null || submitting) return false;

    submitting = true;
    submitError = null;
    notifyListeners();

    final result = await _createSale(companyId: companyId, userId: userId, form: form);

    submitting = false;
    var ok = false;
    result.fold(
      (failure) {
        // Un rechazo del backend (400/422) revierte todo, se puede reintentar.
        // Una caída de red o un error del servidor puede haber dejado la venta registrada.
        final incierto = failure is NetworkFailure || failure is ServerFailure || failure is UnknownFailure;
        submitError = incierto
            ? '${failure.message}. Antes de reintentar, revisa en Documentos si la venta ya quedó registrada.'
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
