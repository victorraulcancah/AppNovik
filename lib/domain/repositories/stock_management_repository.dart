import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart' show DownloadedFile;
import '../entities/other_document_entity.dart';
import '../entities/stock_entity.dart';
import '../entities/stock_manage_entity.dart';
import '../repositories/stock_repository.dart';

/// Lo que el módulo Stock hace además de consultar: filtrar por tipo, aumentar y actualizar
/// stock, subir stocks desde Excel y transferir entre almacenes. Extiende [StockRepository]
/// para que quien solo consulta (por ejemplo Ventas) no dependa de estas operaciones.
abstract class StockManagementRepository extends StockRepository {
  /// Igual que [StockRepository.getStock], con el filtro [tipo] (`'p'` productos, `'s'`
  /// servicios, `null` ambos).
  @override
  Future<Either<Failure, StockPageEntity>> getStock({
    required int companyId,
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    bool includeZero = false,
    int page = 1,
    int pageSize = 20,
    String? tipo,
  });

  /// Productos de la empresa para armar un aumento de stock o una transferencia.
  Future<Either<Failure, List<StockProductEntity>>> searchProducts({
    required int companyId,
    required String search,
  });

  /// Aumenta (o, con cantidades negativas, corrige) el stock de varios productos de un almacén.
  Future<Either<Failure, void>> addStock({
    required int warehouseId,
    required List<({int productId, double? costo, int stock})> items,
  });

  /// Plantilla de Excel para subir stocks (`POST /stock/export`).
  Future<Either<Failure, DownloadedFile>> downloadStockTemplate();

  /// Sube el Excel de stocks de un almacén (`POST /stock/import`).
  Future<Either<Failure, StockImportResultEntity>> importStock({
    required int companyId,
    required int warehouseId,
    required String fileName,
    required Uint8List bytes,
  });

  /// Transfiere productos de un almacén a otro (`POST /stock-transfer`) y devuelve el traslado.
  Future<Either<Failure, OtherDocumentEntity>> transferStock({
    required int companyId,
    required int userId,
    required int from,
    required int to,
    required List<({int productId, double cantidad})> items,
  });
}
