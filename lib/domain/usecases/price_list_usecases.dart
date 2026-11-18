import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/import_entity.dart';
import '../entities/price_list_entity.dart';
import '../repositories/price_list_repository.dart';

class GetPriceListPageUseCase {
  final PriceListRepository repository;
  GetPriceListPageUseCase({required this.repository});

  Future<Either<Failure, PriceListPageEntity>> call({
    required int companyId,
    required int page,
    required int pageSize,
    required PriceListFiltersEntity filters,
  }) => repository.getPriceLists(
    companyId: companyId,
    page: page,
    pageSize: pageSize,
    filters: filters,
  );
}

class SavePriceListUseCase {
  final PriceListRepository repository;
  SavePriceListUseCase({required this.repository});

  Future<Either<Failure, PriceListEntity>> call({
    required int companyId,
    required PriceListFormEntity form,
    int? id,
  }) => repository.savePriceList(companyId: companyId, form: form, id: id);
}

class GetPriceListProductsUseCase {
  final PriceListRepository repository;
  GetPriceListProductsUseCase({required this.repository});

  Future<Either<Failure, PriceListProductPageEntity>> call({
    required int listPriceId,
    required int page,
    required int pageSize,
    required PriceListProductFiltersEntity filters,
  }) => repository.getProducts(
    listPriceId: listPriceId,
    page: page,
    pageSize: pageSize,
    filters: filters,
  );
}

class UpdatePriceListPriceUseCase {
  final PriceListRepository repository;
  UpdatePriceListPriceUseCase({required this.repository});

  Future<Either<Failure, PriceListProductEntity>> call({
    required int listPriceId,
    required int productId,
    required double precio,
  }) => repository.updatePrice(
    listPriceId: listPriceId,
    productId: productId,
    precio: precio,
  );
}

class ExportPriceListTemplateUseCase {
  final PriceListRepository repository;
  ExportPriceListTemplateUseCase({required this.repository});

  Future<Either<Failure, Uint8List>> call({required int listPriceId}) =>
      repository.exportTemplate(listPriceId: listPriceId);
}

class ImportPriceListUseCase {
  final PriceListRepository repository;
  ImportPriceListUseCase({required this.repository});

  Future<Either<Failure, ImportResultEntity>> call({
    required int listPriceId,
    required int companyId,
    required String fileName,
    required Uint8List bytes,
  }) => repository.importPrices(
    listPriceId: listPriceId,
    companyId: companyId,
    fileName: fileName,
    bytes: bytes,
  );
}
