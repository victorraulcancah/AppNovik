import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/sale_entity.dart';

abstract class SaleRepository {
  /// Clientes de la empresa que coinciden con [search] (nombre, documento o código).
  Future<Either<Failure, List<ClientEntity>>> searchClients({
    required int companyId,
    required String search,
  });

  /// Productos activos de la empresa que coinciden con [search], con su stock y precios.
  Future<Either<Failure, List<SaleProductEntity>>> searchProducts({
    required int companyId,
    required String search,
  });

  /// Tipo de cambio comercial vigente (el que se aplica en cotizaciones y ventas en dólares).
  Future<Either<Failure, ExchangeRateEntity>> getExchangeRate();

  /// El cliente genérico "CLIENTE VARIOS" de la empresa (ventas sin documento del cliente).
  Future<Either<Failure, ClientEntity>> getWalkInClient(int companyId);

  /// Categorías y marcas de la empresa, para filtrar el buscador de productos.
  Future<Either<Failure, SaleProductFiltersEntity>> getProductFilters();

  /// Formas de pago que el usuario puede usar.
  Future<Either<Failure, List<PaymentMethodEntity>>> getPaymentMethods();

  /// Registra la venta, o la cotización si el tipo de documento lo es, y devuelve el documento creado.
  Future<Either<Failure, SaleResultEntity>> createSale({
    required int companyId,
    required int userId,
    required SaleFormEntity form,
  });
}
