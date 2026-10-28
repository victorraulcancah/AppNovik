import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/stock_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_modals.dart';

/// Roles que ven los totales de costo y venta del almacén (igual que la web).
const _rolesConTotales = ['Admin Global', 'Ceo Empresa', 'Contador'];

/// Módulo Stock: existencias por almacén, como el detalle del almacén de la web.
/// Costo, precio y totales solo se ven con los permisos de la web.
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StockProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<StockProvider>().setSearch(text);
    });
  }

  Future<void> _openFilters() async {
    final stock = context.read<StockProvider>();
    final result = await showAppFilterSheet(
      context,
      fields: [
        AppFilterField(
          id: 'productos',
          label: 'Productos',
          allLabel: 'Solo con stock',
          value: stock.includeZero ? 'todos' : null,
          options: const [AppFilterOption('todos', 'Incluir los que no tienen stock')],
        ),
      ],
    );
    if (result != null) stock.setIncludeZero(result['productos'] != null);
  }

  bool _can(String permission) =>
      context.read<AuthProvider>().session?.can(permission) ?? false;

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockProvider>();
    final session = context.watch<AuthProvider>().session;

    final canListPrices = session?.can('almacenes.show.list_prices') ?? false;
    final canSeeTotals = (session?.can('almacenes.show.totales') ?? false) &&
        _rolesConTotales.any((r) => session?.hasRole(r) ?? false);
    final symbol = stock.priceList?.simboloMoneda ?? 'S/';

    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.inventory_2_outlined,
          title: 'Stock',
          subtitle: 'Existencias de cada producto por almacén.',
          trailing: AppAccountMenu(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: AppDropdownField<int>(
                  label: 'Almacén',
                  value: stock.warehouseId,
                  items: [
                    for (final w in stock.warehouses)
                      DropdownMenuItem(
                        value: w.id,
                        child: Text(w.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => stock.selectWarehouse(id),
                ),
              ),
              if (canListPrices && stock.priceLists.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: AppDropdownField<int>(
                    label: 'Lista de precios',
                    value: stock.priceListId,
                    items: [
                      for (final p in stock.priceLists)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) => stock.selectPriceList(id),
                  ),
                ),
              ],
            ],
          ),
        ),
        AppSearchBar(
          hint: 'Buscar por nombre, código…',
          onChanged: _onSearchChanged,
          onFilter: _openFilters,
          filterActive: stock.filtersActive,
        ),
        if (stock.total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Wrap(
              spacing: 16,
              children: [
                Text('${stock.total} productos', style: _small(context)),
                if (canSeeTotals) ...[
                  Text('Costo total ${formatMoney(stock.costoTotal)}', style: _small(context)),
                  Text(
                    'Total venta ${formatMoney(stock.totalVenta, symbol: symbol)}',
                    style: _small(context),
                  ),
                ],
              ],
            ),
          ),
        Expanded(child: _body(stock, symbol)),
      ],
    );
  }

  TextStyle? _small(BuildContext context) => Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  Widget _body(StockProvider stock, String symbol) {
    if (stock.loading && stock.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stock.error != null && stock.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo cargar el stock',
        message: stock.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: stock.refresh),
      );
    }
    if (stock.warehouseId == null && stock.warehouses.isEmpty) {
      return const AppEmptyState(
        icon: Icons.warehouse_outlined,
        title: 'Sin almacenes',
        message: 'No tienes almacenes asignados.',
      );
    }

    return AppCardList<StockItemEntity>(
      items: stock.items,
      emptyIcon: Icons.inventory_2_outlined,
      emptyTitle: 'No hay productos',
      emptyMessage: stock.search.isNotEmpty || stock.includeZero
          ? 'Prueba con otra búsqueda o cambia el filtro.'
          : 'Este almacén no tiene productos con stock.',
      onRefresh: stock.refresh,
      onLoadMore: stock.loadMore,
      loadingMore: stock.loadingMore,
      itemBuilder: (context, s, number) => _card(context, s, number, symbol),
    );
  }

  Widget _card(BuildContext context, StockItemEntity s, int number, String symbol) {
    final canCost = _can('almacenes.show.costo_promedio');
    final canPrice = _can('almacenes.show.precio');
    final brightness = Theme.of(context).brightness;

    final valores = [
      if (canCost) 'Costo ${formatMoney(s.costoPromedio ?? 0)}',
      if (canPrice) 'Precio ${formatMoney(s.precio ?? 0, symbol: symbol)}',
    ].join(' · ');

    return AppListCard(
      number: number,
      title: s.name,
      lines: [
        [s.esServicio ? 'Servicio' : 'Producto', if (s.codigo.isNotEmpty) s.codigo].join(' · '),
        if (s.marca != null && s.marca!.isNotEmpty) s.marca!,
        'Por despachar ${formatQuantity(s.porDespachar)} · Por recibir ${formatQuantity(s.porRecibir)}',
        if (valores.isNotEmpty) valores,
      ],
      trailingTitle: stockLabel(s),
      trailingTitleColor: stockColor(s, brightness),
      trailingCaption: 'Total ${formatQuantity(s.stockTotal)}',
      onTap: () => _verDetalle(s, symbol),
      actions: [
        AppActionButton(type: AppActionType.view, onPressed: () => _verDetalle(s, symbol)),
      ],
    );
  }

  void _verDetalle(StockItemEntity s, String symbol) {
    final stock = context.read<StockProvider>();
    String warehouseName = '';
    for (final w in stock.warehouses) {
      if (w.id == stock.warehouseId) warehouseName = w.name;
    }
    showStockDetail(
      context,
      s,
      warehouseName: warehouseName,
      currencySymbol: symbol,
      canSeeCost: _can('almacenes.show.costo_promedio'),
      canSeePrice: _can('almacenes.show.precio'),
    );
  }
}
