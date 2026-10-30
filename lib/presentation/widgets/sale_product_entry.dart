import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/sale_entity.dart';
import '../components/components.dart';
import '../providers/sales_provider.dart';
import 'sale_product_picker.dart';

/// Formulario "Buscar producto" de la venta: se elige el producto (tocando el campo, o con
/// la búsqueda avanzada para marcar varios), se ve su unidad, y se indica cantidad y precio
/// antes de agregarlo a la venta. El precio sale de la lista del cliente y se puede cambiar.
class SaleProductEntry extends StatefulWidget {
  const SaleProductEntry({super.key});

  @override
  State<SaleProductEntry> createState() => _SaleProductEntryState();
}

class _SaleProductEntryState extends State<SaleProductEntry> {
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();

  SaleProductEntity? _product;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  static String _priceText(double v) => v <= 0 ? '' : v.toStringAsFixed(2);

  void _choose(SaleProductEntity product) {
    final sales = context.read<SalesProvider>();
    final list = sales.priceListId;
    setState(() {
      _product = product;
      _error = null;
      _price.text = list == null ? '' : _priceText(product.precioEn(list));
    });
  }

  Future<void> _search() async {
    final sales = context.read<SalesProvider>();
    await showAppSearchSheet<SaleProductEntity>(
      context,
      title: 'Producto',
      subtitle: 'Busca por nombre, código, marca o categoría',
      icon: Icons.inventory_2_outlined,
      hint: 'Nombre, código, marca…',
      search: sales.searchProducts,
      itemOf: (p) {
        final warehouse = sales.warehouseId;
        final list = sales.priceListId;
        final stock = warehouse == null ? 0.0 : p.stockEn(warehouse);
        return AppSearchItem(
          title: p.name,
          subtitle: [
            p.codigo,
            ?p.marca,
            if (p.esServicio)
              'Servicio'
            else if (p.ventaSinStock)
              'Venta sin stock'
            else
              'Stock ${formatQuantity(stock)}${p.unidad != null ? ' ${p.unidad}' : ''}',
          ].join(' · '),
          trailing: list == null ? null : formatMoney(p.precioEn(list)),
          selectedCount: sales.cantidadEnVenta(p.id),
        );
      },
      onSelect: (p) {
        // Sin stock no se puede vender (salvo servicios y "vender sin stock").
        if ((sales.disponibleParaAgregar(p) ?? 1) < 1) {
          return '"${p.name}" no tiene stock disponible en este almacén';
        }
        _choose(p);
        return null;
      },
    );
  }

  Future<void> _advancedSearch() async {
    final added = await showSaleProductPicker(context);
    if (added && mounted) {
      setState(() {
        _product = null;
        _error = null;
        _quantity.text = '1';
        _price.clear();
      });
    }
  }

  void _add() {
    final product = _product;
    if (product == null) {
      setState(() => _error = 'Elige un producto');
      return;
    }
    final quantity = int.tryParse(_quantity.text) ?? 0;
    final price = double.tryParse(_price.text);

    final problem = context.read<SalesProvider>().addProduct(
          product,
          cantidad: quantity,
          precio: price,
        );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _product = null;
      _error = null;
      _quantity.text = '1';
      _price.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sales = context.watch<SalesProvider>();
    final product = _product;
    final warehouse = sales.warehouseId;

    String? caption;
    if (product != null) {
      final stock = warehouse == null ? 0.0 : product.stockEn(warehouse);
      caption = [
        product.codigo,
        ?product.marca,
        if (product.esServicio)
          'Servicio'
        else if (product.ventaSinStock)
          'Venta sin stock'
        else
          'Stock ${formatQuantity(stock)}',
      ].join(' · ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Buscar producto',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _search,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Búsqueda avanzada: marcar varios productos',
                    icon: const Icon(Icons.manage_search),
                    onPressed: _advancedSearch,
                  ),
                  Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                ],
              ),
              errorText: _error == 'Elige un producto' ? _error : null,
            ),
            child: Text(
              product?.name ?? 'Producto',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: product == null
                  ? theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)
                  : theme.textTheme.bodyLarge,
            ),
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 4),
            child: Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Unidad',
            enabled: false,
            prefixIcon: Icon(Icons.straighten_outlined),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            product?.unidad ?? 'Unidad',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                decoration: const InputDecoration(labelText: 'Precio S/', hintText: '0'),
              ),
            ),
          ],
        ),
        if (_error != null && _error != 'Elige un producto') ...[
          const SizedBox(height: 12),
          ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Agregar producto'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
        ),
      ],
    );
  }
}
