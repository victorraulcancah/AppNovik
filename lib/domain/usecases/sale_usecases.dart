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

/// Los vendedores que se pueden elegir como "vendedor encargado" de una cotización.
class GetSellersUseCase {
  final SaleRepository repository;
  GetSellersUseCase({required this.repository});

  Future<Either<Failure, List<SellerEntity>>> call(int companyId) => repository.getSellers(companyId);
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
      if (line.esLibre) {
        // El backend de cotizaciones exige un producto del catálogo en cada línea.
        if (isQuote) return 'Una cotización no admite ítems libres. Quita "$name" o emite una venta';
        if ((line.conceptoLibre ?? '').trim().isEmpty) return 'Escribe la descripción del ítem libre';
      }
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
      if (form.totalEnSoles >= 700) {
        return 'No se puede emitir boleta sin documento para montos de S/700 o más';
      }
    }
    if (form.total <= 0) return 'El total de la venta debe ser mayor a 0';
    return withPayments ? validatePayments(form) : null;
  }

  /// Los pagos deben tener forma y monto, sumar el total de la venta y cumplir las reglas del
  /// crédito (cuotas y línea disponible) y de los puntos. En dólares, el tipo de cambio debe estar
  /// en el rango que exige el backend.
  static String? validatePayments(SaleFormEntity form) => checkPayments(
        payments: form.payments,
        total: form.total,
        dolares: form.dolares,
        tipoCambio: form.tipoCambio,
        client: form.client,
        minimoCanjePuntos: form.minimoCanjePuntos,
      );

  /// Las reglas de [validatePayments] sobre lo que se llena en el modal "Crear venta" (sin armar
  /// la venta entera): el modal las usa para saber cuándo se puede crear.
  static String? checkPayments({
    required List<SalePaymentEntity> payments,
    required double total,
    required bool dolares,
    required double? tipoCambio,
    required ClientEntity? client,
    required double minimoCanjePuntos,
  }) {
    if (payments.isEmpty) return 'Elige la forma de pago';

    final tc = tipoCambio ?? 1;
    if (dolares && (tipoCambio == null || tc < saleExchangeRateMin || tc > saleExchangeRateMax)) {
      return 'El tipo de cambio debe estar entre 3.000 y 4.300';
    }

    var paid = 0.0;
    var credits = 0;
    for (final p in payments) {
      if (p.monto <= 0) return 'Escribe el monto de cada forma de pago';
      // Los puntos se canjean en soles: en una venta en dólares se convierten.
      paid += dolares && p.kind == PaymentKind.puntos ? p.monto / tc : p.monto;

      if (p.kind == PaymentKind.puntos) {
        final points = client?.creditoAFavor ?? 0;
        if (p.monto > points) return 'El cliente solo tiene S/. ${points.toStringAsFixed(2)} en puntos';
        if (p.monto < minimoCanjePuntos) {
          return 'El mínimo para canjear puntos es ${formatQuantity(minimoCanjePuntos)}';
        }
      }

      if (p.conCuotas) {
        credits++;
        // La línea de crédito está en soles: en una venta en dólares se compara en dólares.
        final available = (client?.creditoDisponible ?? 0) / (dolares ? tc : 1);
        if (roundMoney(p.monto) > roundMoney(available)) {
          return 'No tiene suficiente crédito para esta operación '
              '(disponible: ${dolares ? r'$' : 'S/.'} ${available.toStringAsFixed(2)})';
        }
        if (p.installments.isEmpty) return 'Agrega las cuotas del crédito';
        var cuotas = 0.0;
        for (final i in p.installments) {
          if (i.monto <= 0) return 'Escribe el monto de cada cuota';
          cuotas += i.monto;
        }
        if (roundMoney(cuotas) != roundMoney(p.monto)) {
          return 'La suma de las cuotas debe ser igual al monto del crédito';
        }
      }
    }
    if (credits > 1) return 'Solo se puede usar una forma de pago a crédito por venta';
    if (roundMoney(paid) != roundMoney(total)) {
      return 'Los métodos de pago deben sumar el total de la venta';
    }
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
