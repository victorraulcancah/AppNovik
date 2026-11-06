import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart' show DownloadedFile;
import '../entities/other_document_entity.dart';
import '../entities/stock_entity.dart';
import '../entities/stock_manage_entity.dart';
import '../repositories/stock_management_repository.dart';

/// Busca productos para armar un aumento de stock o una transferencia.
class SearchStockProductsUseCase {
  final StockManagementRepository repository;
  SearchStockProductsUseCase({required this.repository});

  Future<Either<Failure, List<StockProductEntity>>> call({
    required int companyId,
    required String search,
  }) async {
    final text = search.trim();
    // El servidor exige un texto; sin él no hay nada que buscar.
    if (text.isEmpty) return Either.right(const []);
    return repository.searchProducts(companyId: companyId, search: text);
  }
}

/// Aumenta el stock de varios productos de un almacén (`POST /stock`).
class AddStockUseCase {
  final StockManagementRepository repository;
  AddStockUseCase({required this.repository});

  Future<Either<Failure, void>> call({
    required int? warehouseId,
    required List<StockEntryLine> lines,
  }) async {
    if (warehouseId == null || warehouseId <= 0) {
      return Either.left(const ValidationFailure('Elige un almacén'));
    }
    if (lines.isEmpty) {
      return Either.left(const ValidationFailure('Agrega al menos un producto'));
    }
    for (final l in lines) {
      if (l.stock < 1) {
        return Either.left(
          ValidationFailure('La cantidad de ${l.product.codigo} debe ser mayor a 0'),
        );
      }
    }
    return repository.addStock(
      warehouseId: warehouseId,
      // Como la web: un costo de 0 se manda como nulo.
      items: [
        for (final l in lines)
          (
            productId: l.product.id,
            costo: (l.costo == null || l.costo == 0) ? null : l.costo,
            stock: l.stock,
          ),
      ],
    );
  }
}

/// Cambia el stock de un producto a un valor nuevo desde la lista (`POST /stock` con la
/// diferencia), con el costo que usa la web.
class UpdateStockUseCase {
  final StockManagementRepository repository;
  UpdateStockUseCase({required this.repository});

  Future<Either<Failure, void>> call({
    required int warehouseId,
    required StockItemEntity item,
    required double newStock,
  }) async {
    if (newStock < 0 || newStock != newStock.roundToDouble()) {
      return Either.left(const ValidationFailure('El stock debe ser un número entero, 0 o más'));
    }
    final diff = newStock - item.disponible;
    if (diff == 0) {
      return Either.left(const ValidationFailure('El stock es el mismo: no hay nada que actualizar'));
    }
    return repository.addStock(
      warehouseId: warehouseId,
      items: [(productId: item.productId, costo: stockUpdateCost(item), stock: diff.round())],
    );
  }
}

/// Plantilla de Excel para subir stocks.
class DownloadStockTemplateUseCase {
  final StockManagementRepository repository;
  DownloadStockTemplateUseCase({required this.repository});

  Future<Either<Failure, DownloadedFile>> call() => repository.downloadStockTemplate();
}

/// Sube el Excel de stocks de un almacén.
class ImportStockUseCase {
  final StockManagementRepository repository;
  ImportStockUseCase({required this.repository});

  Future<Either<Failure, StockImportResultEntity>> call({
    required int companyId,
    required int? warehouseId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (warehouseId == null || warehouseId <= 0) {
      return Either.left(const ValidationFailure('Elige un almacén'));
    }
    return repository.importStock(
      companyId: companyId,
      warehouseId: warehouseId,
      fileName: fileName,
      bytes: bytes,
    );
  }
}

/// Transfiere productos de un almacén a otro, con las mismas reglas que la web.
class TransferStockUseCase {
  final StockManagementRepository repository;
  TransferStockUseCase({required this.repository});

  Future<Either<Failure, OtherDocumentEntity>> call({
    required int companyId,
    required int? userId,
    required int? from,
    required int? to,
    required List<StockTransferLine> lines,
  }) async {
    if (from == null || from <= 0) {
      return Either.left(const ValidationFailure('Elige el almacén de origen'));
    }
    if (to == null || to <= 0) {
      return Either.left(const ValidationFailure('Elige el almacén de destino'));
    }
    if (from == to) {
      return Either.left(const ValidationFailure('No puede transferir al mismo almacén'));
    }
    if (userId == null) {
      return Either.left(const ValidationFailure('No hay un usuario con sesión'));
    }
    if (lines.isEmpty) {
      return Either.left(const ValidationFailure('Agrega al menos un producto'));
    }
    for (final l in lines) {
      if (!l.product.existeEn(from)) {
        return Either.left(
          ValidationFailure('${l.product.codigo} no existe en el almacén de origen'),
        );
      }
      // El servidor pide al menos 1 unidad.
      if (l.cantidad < 1) {
        return Either.left(ValidationFailure('La cantidad de ${l.product.codigo} debe ser 1 o más'));
      }
      if (l.cantidad > l.product.stockEn(from)) {
        return Either.left(ValidationFailure('Stock insuficiente de ${l.product.codigo}'));
      }
    }
    return repository.transferStock(
      companyId: companyId,
      userId: userId,
      from: from,
      to: to,
      items: [for (final l in lines) (productId: l.product.id, cantidad: l.cantidad)],
    );
  }
}
