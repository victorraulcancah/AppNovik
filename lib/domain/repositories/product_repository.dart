import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import 'dart:typed_data';

import '../entities/document_entity.dart' show DownloadedFile;
import '../entities/import_entity.dart';
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

  /// Crea una marca, categoría, unidad de medida, canal o giro (el "+" del formulario).
  Future<Either<Failure, CatalogItemEntity>> createCatalogItem({
    required CatalogKind kind,
    required String name,
  });

  /// Excel con todos los productos de la empresa (`POST /productos/export`).
  Future<Either<Failure, DownloadedFile>> exportProducts();

  /// Sube un Excel de productos, marcas o categorías (importación masiva).
  Future<Either<Failure, ImportResultEntity>> importFile({
    required int companyId,
    required ImportKind kind,
    required String fileName,
    required Uint8List bytes,
  });

  /// Crea el producto, o lo edita si se pasa [id].
  Future<Either<Failure, ProductEntity>> saveProduct({
    required int companyId,
    required ProductFormEntity form,
    int? id,
  });
}
