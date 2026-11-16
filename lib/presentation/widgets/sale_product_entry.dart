import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sales_provider.dart';
import 'sale_free_item.dart';
import 'sale_product_picker.dart';

/// "Buscar producto" de la venta: un solo buscador. Al tocar el campo se abre el buscador de
/// productos (se marcan uno o varios y se agregan de una vez con cantidad 1; la cantidad, el precio
/// y el descuento se ajustan después en la tarjeta de cada línea del carrito).
class SaleProductEntry extends StatelessWidget {
  const SaleProductEntry({super.key});

  Future<void> _addFree(BuildContext context) async {
    final info = await showFreeItemForm(context);
    if (info != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(info)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sales = context.watch<SalesProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Buscar producto',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => showSaleProductPicker(context),
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              suffixIcon: Icon(Icons.manage_search, color: scheme.onSurfaceVariant),
            ),
            child: Text(
              'Producto',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        if (sales.puedeItemLibre) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _addFree(context),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Agregar ítem libre'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ],
      ],
    );
  }
}
