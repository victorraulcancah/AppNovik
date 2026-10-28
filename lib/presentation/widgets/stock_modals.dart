import 'package:flutter/material.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/stock_entity.dart';
import '../components/components.dart';

/// Cuánto se muestra de disponible: con "venta sin stock" y stock positivo,
/// además del número va el símbolo ∞ (como la web).
String stockLabel(StockItemEntity s) {
  final value = formatQuantity(s.disponible);
  return (s.ventaSinStock && s.disponible > 0) ? '$value ∞' : value;
}

/// Color del disponible: rojo si es negativo, rosado si es cero, verde si hay.
Color stockColor(StockItemEntity s, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  if (s.disponible < 0) return dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  if (s.disponible == 0) return dark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);
  return dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
}

/// Modal "ver detalle" de las existencias de un producto en un almacén. Las
/// pestañas de valores solo salen si el usuario puede ver costo o precio.
Future<bool?> showStockDetail(
  BuildContext context,
  StockItemEntity s, {
  required String warehouseName,
  required String currencySymbol,
  bool canSeeCost = false,
  bool canSeePrice = false,
}) {
  final brightness = Theme.of(context).brightness;

  return showAppModal(
    context,
    title: s.name,
    subtitle: 'Almacén: $warehouseName',
    icon: Icons.inventory_2_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    tabs: [
      AppTabItem(
        label: 'Existencias',
        icon: Icons.inventory_2_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailRow(
              label: 'Disponible',
              valueWidget: Text(
                stockLabel(s),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: stockColor(s, brightness),
                    ),
              ),
            ),
            AppDetailRow(label: 'Por despachar', value: formatQuantity(s.porDespachar)),
            AppDetailRow(label: 'Por recibir', value: formatQuantity(s.porRecibir)),
            AppDetailRow(label: 'Stock total', value: formatQuantity(s.stockTotal)),
            AppDetailRow(
              label: 'Venta sin stock',
              valueWidget: AppStatusBadge(
                label: s.ventaSinStock ? 'Sí' : 'No',
                tone: s.ventaSinStock ? AppBadgeTone.success : AppBadgeTone.neutral,
              ),
            ),
          ],
        ),
      ),
      AppTabItem(
        label: 'Producto',
        icon: Icons.category_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailRow(label: 'Tipo', value: s.esServicio ? 'Servicio' : 'Producto'),
            AppDetailRow(label: 'Código', value: s.codigo),
            AppDetailRow(label: 'Descripción', value: s.name),
            AppDetailRow(label: 'Marca', value: s.marca),
          ],
        ),
      ),
      if (canSeeCost || canSeePrice)
        AppTabItem(
          label: 'Valores',
          icon: Icons.payments_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canSeeCost)
                AppDetailRow(
                  label: 'Costo promedio',
                  value: formatMoney(s.costoPromedio ?? 0),
                ),
              if (canSeePrice)
                AppDetailRow(
                  label: 'Precio',
                  value: formatMoney(s.precio ?? 0, symbol: currencySymbol),
                ),
            ],
          ),
        ),
    ],
  );
}
