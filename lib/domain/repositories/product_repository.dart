import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_entity.dart';
import '../entities/product_form_entity.dart';

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

  /// Marcas, categorías, medidas, proveedores, canales y giros de la empresa.
  Future<Either<Failure, ProductCatalogsEntity>> getCatalogs();

  /// Crea el producto, o lo edita si se pasa [id].
  Future<Either<Failure, ProductEntity>> saveProduct({
    required int companyId,
    required ProductFormEntity form,
    int? id,
  });
}
