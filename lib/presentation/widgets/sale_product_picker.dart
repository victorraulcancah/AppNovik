import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/sale_entity.dart';
import '../components/components.dart';
import '../providers/sales_provider.dart';

typedef _Pick = ({SaleProductEntity product, int cantidad});

/// Buscador de productos de la venta, en un modal: se busca por nombre, código, marca o
/// categoría, se puede filtrar por categoría y marca, y se marcan varios productos con su
/// cantidad para agregarlos de una vez. Devuelve `true` si se agregó algo.
Future<bool> showSaleProductPicker(BuildContext context) async {
  final sales = context.read<SalesProvider>();
  sales.ensureProductFilters();

  final selection = ValueNotifier<Map<int, _Pick>>({});
  final hasSelection = ValueNotifier<bool>(false);
  final error = ValueNotifier<String?>(null);
  selection.addListener(() => hasSelection.value = selection.value.isNotEmpty);

  final added = await showAppModal(
    context,
    title: 'Buscar productos',
    subtitle: 'Marca los que quieres y su cantidad',
    icon: Icons.add_shopping_cart_outlined,
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
  Timer? _debounce;
  int _request = 0;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<SaleProductEntity> _results = [];

  bool _filtersOpen = false;
  int? _categoryId;
  int? _brandId;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool get _filtersActive => _categoryId != null || _brandId != null;

  List<SaleProductEntity> get _visible => [
        for (final p in _results)
          if ((_categoryId == null || p.categoryId == _categoryId) &&
              (_brandId == null || p.brandId == _brandId))
            p,
      ];

  void _onChanged(String text) {
    _debounce?.cancel();
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
    final maxHeight = math.min(420.0, MediaQuery.sizeOf(context).height * 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Nombre, código, marca…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _onChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Filtros',
              isSelected: _filtersOpen,
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
              icon: Badge(
                isLabelVisible: _filtersActive,
                smallSize: 8,
                child: const Icon(Icons.tune),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: !_filtersOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: ListenableBuilder(
                      listenable: widget.sales,
                      builder: (context, _) {
                        final filters = widget.sales.productFilters;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppDropdownField<int?>(
                                label: 'Categoría',
                                value: _categoryId,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Todas')),
                                  for (final c in filters.categorias)
                                    DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                                    ),
                                ],
                                onChanged: (v) => setState(() => _categoryId = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppDropdownField<int?>(
                                label: 'Marca',
                                value: _brandId,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Todas')),
                                  for (final m in filters.marcas)
                                    DropdownMenuItem(
                                      value: m.id,
                                      child: Text(m.name, overflow: TextOverflow.ellipsis),
                                    ),
                                ],
                                onChanged: (v) => setState(() => _brandId = v),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
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
        _results.isEmpty ? 'Sin resultados' : 'Ningún resultado con esos filtros',
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

/// Un producto del buscador: casilla, nombre, stock, unidad y cantidad.
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
  late final TextEditingController _quantity;

  SaleProductEntity get _product => widget.product;

  /// Lo que todavía se puede agregar (menos lo que ya está en la venta); `null` sin tope.
  int? get _limit {
    final available = widget.sales.disponibleParaAgregar(_product);
    return available?.floor();
  }

  bool get _blocked => _limit != null && _limit! < 1;

  @override
  void initState() {
    super.initState();
    final current = widget.selection.value[_product.id]?.cantidad;
    _quantity = TextEditingController(text: '${current ?? 1}');
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  int _parsed() {
    final n = int.tryParse(_quantity.text) ?? 1;
    final limit = _limit;
    final clamped = n < 1 ? 1 : (limit != null && n > limit ? limit : n);
    return clamped;
  }

  void _select(bool on) {
    final next = {...widget.selection.value};
    if (on) {
      if (_blocked) return;
      final n = _parsed();
      _quantity.text = '$n';
      next[_product.id] = (product: _product, cantidad: n);
    } else {
      next.remove(_product.id);
    }
    widget.selection.value = next;
  }

  void _onQuantityChanged(String text) {
    if (text.isEmpty || _blocked) return;
    final n = _parsed();
    if ('$n' != text) {
      _quantity.value = TextEditingValue(
        text: '$n',
        selection: TextSelection.collapsed(offset: '$n'.length),
      );
    }
    // Escribir una cantidad marca el producto.
    widget.selection.value = {
      ...widget.selection.value,
      _product.id: (product: _product, cantidad: n),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sales = widget.sales;
    final warehouse = sales.warehouseId;
    final list = sales.priceListId;
    final stock = warehouse == null ? 0.0 : _product.stockEn(warehouse);
    final price = list == null ? 0.0 : _product.precioEn(list);
    final inSale = sales.cantidadEnVenta(_product.id);
    final category = sales.productFilters.categoriaName(_product.categoryId);

    final String stockText;
    if (_product.esServicio) {
      stockText = 'Servicio';
    } else if (_blocked) {
      stockText = inSale > 0 ? 'Todo en la venta' : 'Sin stock';
    } else if (_product.ventaSinStock && stock <= 0) {
      stockText = 'Sin tope';
    } else {
      stockText = '${formatQuantity(stock)}${_product.unidad != null ? ' ${_product.unidad}' : ''}';
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
                padding: const EdgeInsets.fromLTRB(4, 8, 10, 10),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: checked,
                          onChanged: _blocked ? null : (v) => _select(v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  [
                                    _product.codigo,
                                    ?_product.marca,
                                    ?category,
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
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
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 110),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _blocked ? scheme.errorContainer : scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    stockText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _blocked ? scheme.onErrorContainer : scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                price > 0 ? formatMoney(price) : 'Sin precio',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: price > 0 ? scheme.onSurface : scheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Unidad',
                                enabled: false,
                                isDense: true,
                                suffixIcon: Icon(Icons.straighten_outlined, size: 18),
                              ),
                              child: Text(
                                _product.unidad ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _quantity,
                              enabled: !_blocked,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(labelText: 'Cant.', isDense: true),
                              onChanged: _onQuantityChanged,
                            ),
                          ),
                        ],
                      ),
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
