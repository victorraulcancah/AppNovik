import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_entity.dart';

abstract class ProductRepository {
  /// [tipo]: `'p'` productos, `'s'` servicios, `null` ambos.
  /// [search]: términos; cada uno debe aparecer en nombre, código, marca, etc.
  Future<Either<Failure, ProductPageEntity>> getProducts({
    required int companyId,
    int page = 1,
    int pageSize = 20,
    List<String> search = const [],
    String? tipo,
  });
}
