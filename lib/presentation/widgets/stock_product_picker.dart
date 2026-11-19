import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/stock_manage_entity.dart';
import '../components/components.dart';
import 'product_image.dart';
import 'product_image_viewer.dart';

/// El mismo buscador de productos de Ventas, para armar un aumento de stock: un modal de alto fijo donde
/// se busca por nombre, código o marca (con voz y escáner de código de barras), se marcan uno o varios
/// productos y se agregan de una vez ([confirmLabel]). Cada resultado se ve como en Ventas: el código y, a
/// la derecha, el último costo; la foto, el nombre y la casilla; y abajo lo que hay en el almacén
/// [warehouseId] (con su unidad) y la marca. [search] hace la consulta. Devuelve los productos marcados
/// (vacío si se cerró sin agregar).
Future<List<StockProductEntity>> showStockProductPicker(
  BuildContext context, {
  required Future<Either<Failure, List<StockProductEntity>>> Function(String text) search,
  required int? warehouseId,
  String confirmLabel = 'Agregar al stock',
}) async {
  final selection = ValueNotifier<Map<int, StockProductEntity>>({});
  final hasSelection = ValueNotifier<bool>(false);
  selection.addListener(() => hasSelection.value = selection.value.isNotEmpty);
  List<StockProductEntity> picked = const [];

  await showAppModal(
    context,
    title: 'Buscar productos',
    subtitle: 'Marca los que quieres agregar',
    icon: Icons.add_box_outlined,
    fixedHeight: true,
    primaryLabel: confirmLabel,
    primaryEnabled: hasSelection,
    child: AppDisposer(
      onDispose: [selection.dispose, hasSelection.dispose],
      child: _PickerBody(search: search, warehouseId: warehouseId, selection: selection),
    ),
    onPrimary: () {
      picked = selection.value.values.toList();
    },
  );
  return picked;
}

class _PickerBody extends StatefulWidget {
  final Future<Either<Failure, List<StockProductEntity>>> Function(String text) search;
  final int? warehouseId;
  final ValueNotifier<Map<int, StockProductEntity>> selection;

  const _PickerBody({required this.search, required this.warehouseId, required this.selection});

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
  List<StockProductEntity> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Código de barras (o voz): se busca de una vez.
  void _onScanned(String code) {
    _searchController.text = code;
    _onChanged(code);
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
    final result = await widget.search(query);
    if (!mounted || request != _request) return;
    // Con la respuesta a la vista, el teclado baja para ver bien los resultados.
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
    // La ventana mide el 85 % de la pantalla: la lista ocupa lo que queda bajo el buscador.
    final maxHeight = math.max(220.0, MediaQuery.sizeOf(context).height * 0.85 - 360);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('buscador-productos'),
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
            BarcodeScanButton(onScanned: _onScanned),
          ],
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<Map<int, StockProductEntity>>(
          valueListenable: widget.selection,
          builder: (context, selected, _) => Row(
            children: [
              Expanded(
                child: Text(
                  _query.isEmpty ? '' : '${_results.length} ${_results.length == 1 ? 'producto' : 'productos'}',
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
        SizedBox(height: maxHeight, child: _resultsView(theme)),
      ],
    );
  }

  Widget _resultsView(ThemeData theme) {
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
    if (_results.isEmpty && !_loading) return message(Icons.search_off, 'Sin resultados');

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ProductCard(
        key: ValueKey('resultado-${_results[i].id}'),
        product: _results[i],
        warehouseId: widget.warehouseId,
        selection: widget.selection,
      ),
    );
  }
}

/// Un producto del buscador, igual que el de Ventas: código y último costo arriba; foto, nombre y casilla en
/// medio; y abajo lo que hay en el almacén (con su unidad) y la marca.
class _ProductCard extends StatelessWidget {
  final StockProductEntity product;
  final int? warehouseId;
  final ValueNotifier<Map<int, StockProductEntity>> selection;

  const _ProductCard({super.key, required this.product, required this.warehouseId, required this.selection});

  /// "50 unidades", "1 unidad", "12 set": la cantidad con la unidad del producto.
  String _stockWithUnit(double stock) {
    final unit = (product.unidad ?? '').trim().toLowerCase();
    final quantity = formatQuantity(stock);
    if (unit.isEmpty) return quantity;
    if (unit == 'unidad') return '$quantity ${stock == 1 ? 'unidad' : 'unidades'}';
    return '$quantity $unit';
  }

  void _select(bool on) {
    final next = {...selection.value};
    if (on) {
      next[product.id] = product;
    } else {
      next.remove(product.id);
    }
    selection.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final id = warehouseId;
    final stockText = product.esServicio
        ? 'Servicio'
        : _stockWithUnit(id == null ? 0 : product.stockEn(id));
    final costo = product.ultimoCosto;

    return ValueListenableBuilder<Map<int, StockProductEntity>>(
      valueListenable: selection,
      builder: (context, selected, _) {
        final checked = selected.containsKey(product.id);
        return Material(
          color: checked ? scheme.secondaryContainer : scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: checked ? scheme.outline : scheme.outlineVariant, width: checked ? 1.5 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _select(!checked),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Arriba: el código, grande, y el último costo.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          product.codigo,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          costo != null && costo > 0 ? formatMoney(costo, symbol: 'S/') : 'Sin costo',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: costo != null && costo > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
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
                      product.imagen == null
                          ? const ProductImagePlaceholder(size: 64, radius: 12)
                          : Semantics(
                              button: true,
                              label: 'Ver la imagen de ${product.name}',
                              child: GestureDetector(
                                onTap: () => openProductImage(context, path: product.imagen!, title: product.name),
                                child: ProductImage(path: product.imagen!, size: 64, radius: 12),
                              ),
                            ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(product.name, style: theme.textTheme.bodyMedium)),
                      Checkbox(value: checked, onChanged: (v) => _select(v ?? false)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Abajo: lo que hay en el almacén con su unidad y la marca.
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          stockText,
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      if (product.marca != null && product.marca!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(product.marca!, style: theme.textTheme.bodyMedium),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
