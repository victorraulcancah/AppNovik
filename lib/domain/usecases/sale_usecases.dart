import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/utils/format.dart';
import '../entities/sale_entity.dart';
import '../repositories/sale_repository.dart';

class SearchClientsUseCase {
  final SaleRepository repository;
  SearchClientsUseCase({required this.repository});

  Future<Either<Failure, List<ClientEntity>>> call({
    required int companyId,
    required String search,
  }) {
    if (search.trim().isEmpty) return Future.value(Either.right(const []));
    return repository.searchClients(companyId: companyId, search: search.trim());
  }
}

class SearchSaleProductsUseCase {
  final SaleRepository repository;
  SearchSaleProductsUseCase({required this.repository});

  Future<Either<Failure, List<SaleProductEntity>>> call({
    required int companyId,
    required String search,
  }) {
    if (search.trim().isEmpty) return Future.value(Either.right(const []));
    return repository.searchProducts(companyId: companyId, search: search.trim());
  }
}

class GetExchangeRateUseCase {
  final SaleRepository repository;
  GetExchangeRateUseCase({required this.repository});

  Future<Either<Failure, ExchangeRateEntity>> call() => repository.getExchangeRate();
}

class GetWalkInClientUseCase {
  final SaleRepository repository;
  GetWalkInClientUseCase({required this.repository});

  Future<Either<Failure, ClientEntity>> call(int companyId) => repository.getWalkInClient(companyId);
}

class GetSaleProductFiltersUseCase {
  final SaleRepository repository;
  GetSaleProductFiltersUseCase({required this.repository});

  Future<Either<Failure, SaleProductFiltersEntity>> call() => repository.getProductFilters();
}

class GetPaymentMethodsUseCase {
  final SaleRepository repository;
  GetPaymentMethodsUseCase({required this.repository});

  Future<Either<Failure, List<PaymentMethodEntity>>> call() =>
      repository.getPaymentMethods();
}

/// Registra una venta al contado en soles. Valida lo que el backend y la web
/// exigen antes de llamar a la API, para no dejar al usuario esperando un rechazo.
class CreateSaleUseCase {
  final SaleRepository repository;
  CreateSaleUseCase({required this.repository});

  /// Mensaje del primer problema de [form], o `null` si se puede enviar. Una cotización no
  /// necesita forma de pago ni revisa stock salvo que lo reserve. Con [withPayments] en `false`
  /// se revisa todo menos los pagos (aún no se eligieron: se piden en el modal "Crear venta").
  static String? validate(SaleFormEntity form, {bool withPayments = true}) {
    final isQuote = form.tipoDocumento.esCotizacion;
    final client = form.client;
    if (client == null) return 'Elige el cliente';
    if (form.warehouseId == null) return 'Elige el almacén';
    if (form.lines.isEmpty) return 'Agrega al menos un producto';
    if (isQuote && form.priceListId == null) return 'Elige una lista de precios';

    final revisaStock = !isQuote || form.reservarStock;
    for (final line in form.lines) {
      final name = line.product.name;
      if (line.cantidad < 1) return '"$name": la cantidad mínima es 1';
      if (line.precio <= 0) {
        return '"$name" no tiene precio. Escríbelo antes de ${isQuote ? 'cotizar' : 'vender'}';
      }
      final max = line.product.maximoEn(form.warehouseId!);
      if (revisaStock && max != null && line.cantidad > max) {
        return 'No hay stock suficiente de "$name" (disponible: ${formatQuantity(max)})';
      }
    }

    if (isQuote) {
      if (form.reservarStock && form.vencimientoStock == null) {
        return 'Indica hasta qué día se reserva el stock';
      }
      if (form.total <= 0) return 'El total de la cotización debe ser mayor a 0';
      return null;
    }

    if (form.tipoDocumento == SaleDocumentType.factura && client.esPersona) {
      return 'La factura necesita un cliente con RUC. Elige una empresa o emite una boleta';
    }
    if (client.esVarios) {
      if (form.tipoDocumento != SaleDocumentType.boleta) {
        return 'Sin documento del cliente solo se puede emitir Boleta de Venta';
      }
      if (form.total >= 700) {
        return 'No se puede emitir boleta sin documento para montos de S/700 o más';
      }
    }
    if (form.total <= 0) return 'El total de la venta debe ser mayor a 0';
    return withPayments ? validatePayments(form.payments, form.total) : null;
  }

  /// Los pagos deben tener forma y monto, y sumar el total de la venta.
  static String? validatePayments(List<SalePaymentEntity> payments, double total) {
    if (payments.isEmpty) return 'Elige la forma de pago';
    for (final p in payments) {
      if (p.monto <= 0) return 'Escribe el monto de cada forma de pago';
    }
    final paid = roundMoney(payments.fold<double>(0, (sum, p) => sum + p.monto));
    if (paid != roundMoney(total)) return 'Los métodos de pago deben sumar el total de la venta';
    return null;
  }

  Future<Either<Failure, SaleResultEntity>> call({
    required int companyId,
    required int userId,
    required SaleFormEntity form,
  }) async {
    final problem = validate(form);
    if (problem != null) return Either.left(ValidationFailure(problem));
    return repository.createSale(companyId: companyId, userId: userId, form: form);
  }
}
