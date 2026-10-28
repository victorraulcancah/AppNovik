import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_entity.dart';
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
