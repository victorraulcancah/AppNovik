import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/sale_entity.dart';
import '../components/components.dart';
import '../providers/sales_provider.dart';
import 'product_image.dart';
import 'product_image_viewer.dart';

typedef _Pick = ({SaleProductEntity product, int cantidad});

/// Buscador de productos de la venta (el único), en un modal de alto fijo: se busca por nombre,
/// código, marca o categoría, se puede filtrar por categoría y marca, y se marcan uno o varios
/// productos para agregarlos de una vez con cantidad 1 (la cantidad, el precio y el descuento se
/// ajustan después en la tarjeta del carrito). Devuelve `true` si se agregó algo.
Future<bool> showSaleProductPicker(BuildContext context) async {
  final sales = context.read<SalesProvider>();
  // Las categorías, para mostrar la de cada producto.
  sales.ensureProductFilters();

  // El aviso de un cambio de lista de precios se muestra aunque el modal ya se haya cerrado.
  final messenger = ScaffoldMessenger.of(context);
  final selection = ValueNotifier<Map<int, _Pick>>({});
  final hasSelection = ValueNotifier<bool>(false);
  final error = ValueNotifier<String?>(null);
  selection.addListener(() => hasSelection.value = selection.value.isNotEmpty);

  final added = await showAppModal(
    context,
    title: 'Buscar productos',
    subtitle: 'Marca los que quieres agregar',
    icon: Icons.add_shopping_cart_outlined,
    fixedHeight: true,
    primaryLabel: 'Agregar a la venta',
    primaryEnabled: hasSelection,
    error: error,
    child: AppDisposer(
      onDispose: [selection.dispose, hasSelection.dispose, error.dispose],
      child: _PickerBody(sales: sales, selection: selection),
    ),
    onPrimary: () {
      error.value = null;
      final problems = sales.addProducts(selection.value.values.toList());
      final listNotice = sales.takeListNotice();
      if (listNotice != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(listNotice), persist: false, duration: const Duration(seconds: 6)));
      }
      if (problems.isNotEmpty) {
        // El modal sigue abierto con los motivos (por ejemplo, falta de stock).
        error.value = problems.join('\n');
        throw StateError('No se pudo agregar');
      }
    },
  );

  return added == true;
}

class _PickerBody extends StatefulWidget {
  final SalesProvider sales;
  final ValueNotifier<Map<int, _Pick>> selection;

  const _PickerBody({required this.sales, required this.selection});

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  String _query = '';
  String _text = '';
  bool _loading = false;
  String? _error;
  List<SaleProductEntity> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Código de barras leído con la cámara: se busca de una vez (el servidor busca por código de barras).
  void _onScanned(String code) {
    _searchController.text = code;
    _onChanged(code);
  }

  /// Los que se pueden agregar primero y, al final, los "Sin stock" / "Todo en la venta" (cada grupo
  /// conserva el orden del servidor).
  List<SaleProductEntity> get _visible {
    bool blocked(SaleProductEntity p) => (widget.sales.disponibleParaAgregar(p) ?? 1) < 1;
    return [
      for (final p in _results)
        if (!blocked(p)) p,
      for (final p in _results)
        if (blocked(p)) p,
    ];
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _text = text.trim();
    final query = text.trim();
    if (query.isEmpty) {
      _request++;
      setState(() {
        _query = '';
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(query));
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    final result = await widget.sales.searchProducts(query);
    if (!mounted || request != _request) return;
    // Con la respuesta a la vista, el teclado baja para ver bien los resultados (la ventana es de
    // alto fijo y no se mueve). Solo si no se siguió escribiendo.
    if (_text == query) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = false;
      result.fold(
        (failure) {
          _results = [];
          _error = failure.message;
        },
        (items) => _results = items,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = _visible;
    // La ventana mide el 85 % de la pantalla: la lista ocupa lo que queda bajo el buscador.
    final maxHeight = math.max(220.0, MediaQuery.sizeOf(context).height * 0.85 - 360);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Nombre, código, marca…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: VoiceSearchButton(onResult: _onScanned),
                ),
                onChanged: _onChanged,
              ),
            ),
            const SizedBox(width: 8),
            // Sin botón de filtros: en su lugar va el escáner de código de barras.
            BarcodeScanButton(onScanned: _onScanned),
          ],
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<Map<int, _Pick>>(
          valueListenable: widget.selection,
          builder: (context, selected, _) => Row(
            children: [
              Expanded(
                child: Text(
                  _query.isEmpty ? '' : '${visible.length} ${visible.length == 1 ? 'producto' : 'productos'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                '${selected.length} ${selected.length == 1 ? 'seleccionado' : 'seleccionados'}',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        SizedBox(height: maxHeight, child: _results_(visible, theme)),
      ],
    );
  }

  Widget _results_(List<SaleProductEntity> visible, ThemeData theme) {
    final scheme = theme.colorScheme;

    Widget message(IconData icon, String text) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: scheme.outline),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );

    if (_error != null) return Align(alignment: Alignment.topCenter, child: ErrorBanner(message: _error!));
    if (_loading && _results.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_query.isEmpty) return message(Icons.search, 'Escribe para buscar productos');
    if (visible.isEmpty && !_loading) {
      return message(
        Icons.search_off,
        'Sin resultados',
      );
    }

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ProductCard(
        key: ValueKey(visible[i].id),
        product: visible[i],
        sales: widget.sales,
        selection: widget.selection,
      ),
    );
  }
}

/// Un producto del buscador: casilla, nombre, stock y precio.
class _ProductCard extends StatefulWidget {
  final SaleProductEntity product;
  final SalesProvider sales;
  final ValueNotifier<Map<int, _Pick>> selection;

  const _ProductCard({
    super.key,
    required this.product,
    required this.sales,
    required this.selection,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  SaleProductEntity get _product => widget.product;

  /// Lo que todavía se puede agregar (menos lo que ya está en la venta); `null` sin tope.
  int? get _limit {
    final available = widget.sales.disponibleParaAgregar(_product);
    return available?.floor();
  }

  bool get _blocked => _limit != null && _limit! < 1;

  /// "50 unidades", "1 unidad", "12 set": la cantidad con la unidad del producto.
  String _stockWithUnit(double stock) {
    final unit = (_product.unidad ?? '').trim().toLowerCase();
    final quantity = formatQuantity(stock);
    if (unit.isEmpty) return quantity;
    if (unit == 'unidad') return '$quantity ${stock == 1 ? 'unidad' : 'unidades'}';
    return '$quantity $unit';
  }

  void _select(bool on) {
    final next = {...widget.selection.value};
    if (on) {
      if (_blocked) return;
      next[_product.id] = (product: _product, cantidad: 1);
    } else {
      next.remove(_product.id);
    }
    widget.selection.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sales = widget.sales;
    final warehouse = sales.warehouseId;
    final list = sales.priceListId;
    final stock = warehouse == null ? 0.0 : _product.stockEn(warehouse);
    final ownPrice = list == null ? 0.0 : _product.precioEn(list);
    // Sin precio en la lista en soles pero con él en la de dólares: se muestra ya el de dólares (a esa
    // lista pasará la venta al agregarlo), en vez de "Sin precio".
    final alt = ownPrice > 0 ? null : sales.listaEnDolaresConPrecio(_product);
    final price = alt != null ? _product.precioEn(alt.id) : ownPrice;
    final symbol = alt != null ? alt.simboloMoneda : widget.sales.moneySymbol;
    final inSale = sales.cantidadEnVenta(_product.id);

    final String stockText;
    if (_product.esServicio) {
      stockText = 'Servicio';
    } else if (_blocked) {
      stockText = inSale > 0 ? 'Todo en la venta' : 'Sin stock';
    } else if (_product.ventaSinStock && stock <= 0) {
      stockText = 'Sin tope';
    } else {
      stockText = _stockWithUnit(stock);
    }

    return ValueListenableBuilder<Map<int, _Pick>>(
      valueListenable: widget.selection,
      builder: (context, selected, _) {
        final checked = selected.containsKey(_product.id);
        return Opacity(
          opacity: _blocked ? 0.55 : 1,
          child: Material(
            color: checked ? scheme.secondaryContainer : scheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: checked ? scheme.outline : scheme.outlineVariant,
                width: checked ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _blocked ? null : () => _select(!checked),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Arriba: el código, grande, y el precio.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            _product.codigo,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            price > 0 ? formatMoney(price, symbol: symbol) : 'Sin precio',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: price > 0 ? scheme.onSurface : scheme.error,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // En medio: la foto (o un recuadro vacío), el nombre completo y la casilla.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _product.imagen == null
                            ? const ProductImagePlaceholder(size: 64, radius: 12)
                            : Semantics(
                                button: true,
                                label: 'Ver la imagen de ${_product.name}',
                                child: GestureDetector(
                                  onTap: () => openProductImage(
                                    context,
                                    path: _product.imagen!,
                                    title: _product.name,
                                    code: _product.codigo,
                                  ),
                                  child: ProductImage(path: _product.imagen!, size: 64, radius: 12),
                                ),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_product.name, style: theme.textTheme.bodyMedium),
                              if (inSale > 0)
                                Text(
                                  'Ya en la venta: $inSale',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: checked,
                          onChanged: _blocked ? null : (v) => _select(v ?? false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Abajo: el stock con su unidad y la marca.
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _blocked ? scheme.errorContainer : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            stockText,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _blocked ? scheme.onErrorContainer : scheme.onSurface,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_product.marca != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(_product.marca!, style: theme.textTheme.bodyMedium),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
