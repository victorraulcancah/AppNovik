import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/import_entity.dart';
import '../../domain/entities/price_list_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/price_lists_provider.dart';
import '../utils/download_file.dart';
import '../utils/import_file.dart';
import '../utils/success_snack.dart';
import '../widgets/price_list_modals.dart';
import '../widgets/product_image.dart';

/// El detalle de una lista de precios (`/lista-de-precios/:id` de la web): los productos con el
/// precio que tienen en la lista, búsqueda, filtro de tipo, cambiar un precio, descargar la
/// plantilla de Excel y subir los precios desde Excel. Permiso `lista-de-precios.show`.
class PriceListDetailPage extends StatefulWidget {
  final PriceListEntity list;

  /// Selector del Excel a subir; se cambia en las pruebas.
  final Future<PickedImportFile?> Function() pickFile;

  const PriceListDetailPage({
    super.key,
    required this.list,
    this.pickFile = pickImportFile,
  });

  @override
  State<PriceListDetailPage> createState() => _PriceListDetailPageState();
}

class _PriceListDetailPageState extends State<PriceListDetailPage> {
  static const _permission = 'lista-de-precios';

  Timer? _debounce;
  final _searchController = TextEditingController();

  PriceListEntity get _list => widget.list;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _can('$_permission.show')) {
        context.read<PriceListsProvider>().openList(_list);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _can(String permission) =>
      context.read<AuthProvider>().session?.can(permission) ?? false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<PriceListsProvider>().setProductSearch(text);
    });
  }

  void _onSearchSubmitted(String text) {
    _debounce?.cancel();
    context.read<PriceListsProvider>().setProductSearch(text);
  }

  Future<void> _openFilters() async {
    final provider = context.read<PriceListsProvider>();
    final values = await showAppFilterSheet(
      context,
      title: 'Filtros',
      fields: [
        AppFilterField(
          id: 'tipo',
          label: 'Tipo',
          allLabel: 'Todos',
          value: provider.productFilters.tipo,
          options: const [
            AppFilterOption('p', 'Producto'),
            AppFilterOption('s', 'Servicio'),
          ],
        ),
      ],
    );
    if (values == null) return;
    provider.setProductTipo(values['tipo']);
  }

  Future<void> _editPrice(PriceListProductEntity product) async {
    final provider = context.read<PriceListsProvider>();
    final saved = await showPriceEditor(
      context,
      list: _list,
      product: product,
      onSubmit: (precio) => provider.updatePrice(product, precio),
    );
    if (saved && mounted) showSuccessSnack(context, 'Precio Actualizado');
  }

  /// Descarga el Excel con los productos y su precio en esta lista (la plantilla).
  Future<void> _template() async {
    final result = await context.read<PriceListsProvider>().downloadTemplate();
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await downloadFile(context, result.right);
  }

  /// Sube el Excel con los precios. El servidor guarda las filas buenas y devuelve las que fallaron,
  /// que se muestran al terminar.
  Future<void> _import() async {
    final provider = context.read<PriceListsProvider>();
    PickedImportFile? picked;
    ImportResultEntity? result;

    await showAppImportModal(
      context,
      title: 'Subir precios',
      subtitle: _list.name,
      icon: Icons.upload_outlined,
      templateName: 'plantilla de precios',
      onDownloadTemplate: _template,
      onPickFile: () async {
        final file = await widget.pickFile();
        if (file == null) return null;
        picked = file;
        return file.name;
      },
      onUpload: (_) async {
        final file = picked;
        if (file == null) return 'Elige el archivo Excel';
        final response = await provider.importPrices(
          fileName: file.name,
          bytes: file.bytes,
        );
        if (response.isLeft) return response.left.message;
        result = response.right;
        return null;
      },
    );

    final done = result;
    if (done == null || !mounted) return;
    if (done.hasFailures) {
      _snack('Lista de Precios Subidos');
      await showPriceListImportFailures(context, failures: done.failures);
    } else {
      showSuccessSnack(context, 'Lista de Precios Subidos');
    }
  }

  List<AppActiveFilter> _activeFilters(PriceListsProvider provider) {
    final tipo = provider.productFilters.tipo;
    return [
      if (tipo != null)
        AppActiveFilter(
          id: 'tipo',
          label: 'Tipo: ${tipo == 's' ? 'Servicio' : 'Producto'}',
          onRemove: () => provider.setProductTipo(null),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PriceListsProvider>();
    final session = context.watch<AuthProvider>().session;
    final list = provider.current?.id == _list.id ? provider.current! : _list;

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: session != null && !session.can('$_permission.show')
            ? const AppEmptyState(
                icon: Icons.lock_outline,
                title: 'Sin acceso',
                message: 'No tienes permiso para ver esta lista de precios.',
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _content(provider, list),
                ),
              ),
      ),
    );
  }

  Widget _content(PriceListsProvider provider, PriceListEntity list) {
    final filters = _activeFilters(provider);
    final canImport = _can('$_permission.store') || _can('$_permission.import');
    return Stack(
      children: [
        Column(
          children: [
            AppSearchBar(
              hint: 'Búsqueda por nombre, código…',
              voice: false,
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              onFilter: _openFilters,
              filterCount: filters.length,
            ),
            AppActiveFilters(
              filters: filters,
              onClear: () => provider.setProductTipo(null),
            ),
            _summary(provider, list),
            Expanded(child: _body(provider, list)),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: AppSpeedDial(
            actions: [
              AppSpeedDialAction(
                label: provider.exporting ? 'Descargando…' : 'Plantilla',
                icon: Icons.download_outlined,
                color: const Color(0xFF0E90C7),
                onPressed: provider.exporting ? null : _template,
              ),
              if (canImport)
                AppSpeedDialAction(
                  label: 'Subir precios',
                  icon: Icons.upload_outlined,
                  color: const Color(0xFFE8891D),
                  onPressed: _import,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// La moneda de la lista y cuántos productos hay con la búsqueda y el filtro puestos.
  Widget _summary(PriceListsProvider provider, PriceListEntity list) {
    final theme = Theme.of(context);
    final count = provider.productsTotal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${list.symbol} ${list.currencyLabel} · $count ${count == 1 ? 'producto' : 'productos'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _body(PriceListsProvider provider, PriceListEntity list) {
    if (provider.loadingProducts && provider.products.isEmpty) {
      return const AppSkeletonList();
    }
    if (provider.productsError != null && provider.products.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los productos',
        message: provider.productsError,
        action: AppButton(
          label: 'Reintentar',
          icon: Icons.refresh,
          onPressed: provider.refreshProducts,
        ),
      );
    }

    return AppCardList<PriceListProductEntity>(
      items: provider.products,
      emptyIcon: Icons.category_outlined,
      emptyTitle: 'No hay productos',
      emptyMessage: provider.productFilters.isActive
          ? 'Prueba con otra búsqueda o quita los filtros.'
          : null,
      onRefresh: provider.refreshProducts,
      onLoadMore: provider.loadMoreProducts,
      loadingMore: provider.loadingMoreProducts,
      bottomPadding: 96,
      itemBuilder: (context, p, number) => _card(context, list, p),
    );
  }

  Widget _card(
    BuildContext context,
    PriceListEntity list,
    PriceListProductEntity p,
  ) {
    final canUpdate = _can('$_permission.update');
    final detalle = [
      if (p.esServicio) 'Servicio',
      p.marca,
    ].whereType<String>().where((t) => t.isNotEmpty).join(' · ');

    // Las mismas columnas que la tabla de la web: tipo, código, descripción, marca y precio.
    return AppListCard(
      leading: p.imagen == null ? null : ProductImage(path: p.imagen!),
      title: p.name,
      lines: [
        if (p.codigo.isNotEmpty) 'Código · ${p.codigo}',
        if (detalle.isNotEmpty) detalle,
      ],
      trailingTitle: priceLabel(list, p.precio),
      onTap: canUpdate ? () => _editPrice(p) : null,
      actions: [
        if (canUpdate)
          AppActionButton(
            type: AppActionType.edit,
            label: 'Cambiar precio',
            onPressed: () => _editPrice(p),
          ),
      ],
    );
  }
}
