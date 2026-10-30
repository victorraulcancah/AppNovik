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

  /// Categorías y marcas de la empresa, para filtrar el buscador de productos.
  Future<Either<Failure, SaleProductFiltersEntity>> getProductFilters();

  /// Formas de pago que el usuario puede usar.
  Future<Either<Failure, List<PaymentMethodEntity>>> getPaymentMethods();

  /// Registra la venta y devuelve el documento creado.
  Future<Either<Failure, SaleResultEntity>> createSale({
    required int companyId,
    required int userId,
    required SaleFormEntity form,
  });
}
