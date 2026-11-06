import 'import_entity.dart';
import 'stock_entity.dart';

/// Lo que tiene un producto en un almacén (de `warehouses[].pivot` de `GET /productos/search`).
class StockWarehouseLevel {
  final double stock;
  final double costoPromedio;

  const StockWarehouseLevel({this.stock = 0, this.costoPromedio = 0});
}

/// Un producto encontrado por `GET /productos/search`, con lo que se necesita para agregarle
/// stock o transferirlo: su último costo de entrada y lo que tiene en cada almacén.
class StockProductEntity {
  final int id;
  final String codigo;
  final String name;
  final String? marca;

  /// Costo de la última entrada de stock (`stocks[0].pivot.costo`); sirve de costo inicial al
  /// agregar stock.
  final double? ultimoCosto;
  final Map<int, StockWarehouseLevel> levels;

  const StockProductEntity({
    required this.id,
    required this.codigo,
    required this.name,
    this.marca,
    this.ultimoCosto,
    this.levels = const {},
  });

  /// `true` si el producto ya tiene registro de stock en ese almacén (aunque sea 0).
  bool existeEn(int warehouseId) => levels.containsKey(warehouseId);

  double stockEn(int warehouseId) => levels[warehouseId]?.stock ?? 0;

  double costoPromedioEn(int warehouseId) => levels[warehouseId]?.costoPromedio ?? 0;
}

/// Una línea del aumento de stock: producto, cuántas unidades entran y a qué costo.
class StockEntryLine {
  final StockProductEntity product;
  final int stock;

  /// Costo por unidad; `null` o 0 se manda como `null` (el servidor lo toma como 0).
  final double? costo;

  const StockEntryLine({required this.product, this.stock = 1, this.costo});

  StockEntryLine copyWith({int? stock, double? costo, bool clearCosto = false}) => StockEntryLine(
        product: product,
        stock: stock ?? this.stock,
        costo: clearCosto ? null : (costo ?? this.costo),
      );

  double get totalCosto => (costo ?? 0) * stock;
}

/// Una línea de la transferencia: producto y cuántas unidades salen del almacén de origen.
class StockTransferLine {
  final StockProductEntity product;
  final double cantidad;

  const StockTransferLine({required this.product, this.cantidad = 1});

  StockTransferLine copyWith({double? cantidad}) =>
      StockTransferLine(product: product, cantidad: cantidad ?? this.cantidad);
}

/// Una fila del Excel de stocks que el servidor leyó (con su número de fila).
class StockImportRow {
  final int row;
  final String codigo;
  final String? costo;
  final String stock;

  const StockImportRow({required this.row, required this.codigo, this.costo, required this.stock});
}

/// Respuesta de `POST /stock/import`: las filas leídas y las que fallaron con su motivo.
class StockImportResultEntity {
  final List<StockImportRow> rows;
  final List<ImportFailureEntity> failures;

  const StockImportResultEntity({this.rows = const [], this.failures = const []});

  bool get hasFailures => failures.isNotEmpty;

  /// Los errores de una fila del Excel, o `null` si esa fila salió bien.
  ImportFailureEntity? failureOf(int row) {
    for (final f in failures) {
      if (f.row == row) return f;
    }
    return null;
  }
}

/// El costo que usa la web al actualizar el stock de un producto desde la lista: el costo
/// promedio, o el último costo si el promedio es 0 o no hay stock.
double stockUpdateCost(StockItemEntity item) {
  var costo = item.costoPromedio ?? 0;
  final ultimo = item.ultimoCosto ?? 0;
  if ((costo == 0 || item.disponible == 0) && ultimo > 0) costo = ultimo;
  return costo;
}
