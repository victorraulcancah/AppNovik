import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_entity.dart';
import '../entities/product_form_entity.dart';
import '../repositories/product_repository.dart';

class GetProductsUseCase {
  final ProductRepository repository;
  GetProductsUseCase({required this.repository});

  Future<Either<Failure, ProductPageEntity>> call({
    required int companyId,
    int page = 1,
    int pageSize = 20,
    List<String> search = const [],
    String? tipo,
  }) =>
      repository.getProducts(
        companyId: companyId,
        page: page,
        pageSize: pageSize,
        search: search,
        tipo: tipo,
      );
}

class GetProductCatalogsUseCase {
  final ProductRepository repository;
  GetProductCatalogsUseCase({required this.repository});

  Future<Either<Failure, ProductCatalogsEntity>> call() =>
      repository.getCatalogs();
}

/// Crea un producto, o lo edita si se pasa [id]. Valida lo que el backend exige
/// antes de llamar a la API.
class SaveProductUseCase {
  final ProductRepository repository;
  SaveProductUseCase({required this.repository});

  Future<Either<Failure, ProductEntity>> call({
    required int companyId,
    required ProductFormEntity form,
    int? id,
  }) async {
    if (form.codigo.trim().isEmpty) {
      return Either.left(const ValidationFailure('El código es requerido'));
    }
    if (form.name.trim().isEmpty) {
      return Either.left(const ValidationFailure('La descripción es requerida'));
    }
    // Al editar el backend exige SKU.
    if (id != null && (form.sku == null || form.sku!.trim().isEmpty)) {
      return Either.left(const ValidationFailure('El SKU es requerido'));
    }
    return repository.saveProduct(companyId: companyId, form: form, id: id);
  }
}
