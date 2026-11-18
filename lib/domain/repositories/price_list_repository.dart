import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/import_entity.dart';
import '../entities/price_list_entity.dart';

/// El módulo Lista de precios: las listas de la empresa, el precio de cada producto en una lista,
/// y el Excel para llenarlas de golpe.
abstract class PriceListRepository {
  Future<Either<Failure, PriceListPageEntity>> getPriceLists({
    required int companyId,
    required int page,
    required int pageSize,
    required PriceListFiltersEntity filters,
  });

  /// Crea la lista, o la edita si se pasa [id].
  Future<Either<Failure, PriceListEntity>> savePriceList({
    required int companyId,
    required PriceListFormEntity form,
    int? id,
  });

  /// Los productos con su precio en la lista [listPriceId].
  Future<Either<Failure, PriceListProductPageEntity>> getProducts({
    required int listPriceId,
    required int page,
    required int pageSize,
    required PriceListProductFiltersEntity filters,
  });

  /// Cambia el precio de un producto en la lista; devuelve el producto con su precio nuevo.
  Future<Either<Failure, PriceListProductEntity>> updatePrice({
    required int listPriceId,
    required int productId,
    required double precio,
  });

  /// Excel con todos los productos y su precio en la lista (la plantilla para subir precios).
  Future<Either<Failure, Uint8List>> exportTemplate({required int listPriceId});

  /// Sube el Excel con los precios; las filas con error no frenan al resto.
  Future<Either<Failure, ImportResultEntity>> importPrices({
    required int listPriceId,
    required int companyId,
    required String fileName,
    required Uint8List bytes,
  });
}
