import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/import_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/products_provider.dart';
import '../utils/import_file.dart';
import '../utils/download_file.dart';
import '../utils/success_snack.dart';
import '../widgets/product_modals.dart';

/// Módulo Productos: lista paginada con búsqueda y filtro de tipo, detalle, crear y editar, y
/// las acciones de la web según los permisos del usuario: descargar la plantilla, subir
/// productos, exportar, e importar marcas y categorías.
class ProductsPage extends StatefulWidget {
  /// Selector del Excel a subir; se cambia en las pruebas.
  final Future<PickedImportFile?> Function() pickFile;

  /// Selector de la foto del producto; se cambia en las pruebas.
  final Future<PickedPhoto?> Function() pickPhoto;

  const ProductsPage({
    super.key,
    this.pickFile = pickImportFile,
    this.pickPhoto = pickProductPhoto,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  Timer? _debounce;
  final _searchController = TextEditingController();

  /// Panel de detalle (tablet).
  final _pane = AppPaneController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProductsProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _pane.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<ProductsProvider>().setSearch(text);
    });
  }

  /// "Buscar" en el teclado: lo escrito pasa a ser un chip (puede ser una frase) y el campo queda
  /// libre para otro término, como en la web.
  void _onSearchSubmitted(String text) {
    _debounce?.cancel();
    _searchController.clear();
    context.read<ProductsProvider>().addSearchTerm(text);
  }

  Future<void> _openFilters() async {
    final provider = context.read<ProductsProvider>();
    final result = await showAppFilterSheet(
      context,
      fields: [
        AppFilterField(
          id: 'tipo',
          label: 'Tipo',
          allLabel: 'Todos',
          value: provider.tipo,
          options: const [
            AppFilterOption('p', 'Productos'),
            AppFilterOption('s', 'Servicios'),
          ],
        ),
        AppFilterField(
          id: 'estado',
          label: 'Estado',
          allLabel: 'Todos',
          value: provider.activo == null ? null : '${provider.activo}',
          options: const [
            AppFilterOption('true', 'Activos'),
            AppFilterOption('false', 'Inactivos'),
          ],
        ),
      ],
    );
    if (result != null) {
      final estado = result['estado'];
      provider.setFilters(tipo: result['tipo'], activo: estado == null ? null : estado == 'true');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Permisos del usuario (los mismos que valida la web: `productos.store`,
  /// `productos.update`).
  bool _can(String permission) =>
      context.read<AuthProvider>().session?.can(permission) ?? false;

  void _crear() {
    final products = context.read<ProductsProvider>();
    showProductForm(
      context,
      loadCatalogs: products.loadCatalogs,
      createCatalogItem: products.createCatalogItem,
      pickPhoto: widget.pickPhoto,
      onSubmit: (form) => products.saveProduct(form),
    );
  }

  Future<void> _editar(ProductEntity p) async {
    final products = context.read<ProductsProvider>();
    final saved = await showProductForm(
      context,
      product: p,
      loadCatalogs: products.loadCatalogs,
      createCatalogItem: products.createCatalogItem,
      pickPhoto: widget.pickPhoto,
      onSubmit: (form) => products.saveProduct(form, id: p.id),
    );
    // En tablet el detalle seguía a la vista: si se guardó, vuelve con los datos nuevos (si se
    // canceló, queda como estaba).
    if (saved != true || !mounted || !_pane.isWide || _pane.selectedId != p.id) return;
    await whenIdle(products, () => products.loading);
    if (!mounted || _pane.selectedId != p.id) return;
    final updated = products.items.where((x) => x.id == p.id).firstOrNull;
    if (updated == null) {
      // Con los filtros puestos el producto ya no sale en la lista.
      _pane.close();
    } else {
      unawaited(_verDetalle(updated));
    }
  }

  Future<void> _verDetalle(ProductEntity p) async {
    final editar = await showProductDetail(
      context,
      p,
      canEdit: _can('productos.update'),
      pane: _pane,
    );
    if (editar == true && mounted) _editar(p);
  }

  // Las mismas acciones que la web en `/productos`: crear, plantilla, subir, exportar, y las
  // importaciones de marcas y categorías.

  /// Descarga la plantilla de Excel al dispositivo.
  Future<void> _plantilla(ImportKind kind) async {
    final DownloadedFile template;
    try {
      template = await loadImportTemplate(kind);
    } catch (_) {
      if (mounted) _snack('No se pudo abrir la plantilla');
      return;
    }
    if (mounted) await downloadFile(context, template);
  }

  /// Excel con todos los productos, como el botón Exportar de la web.
  Future<void> _exportar() async {
    final result = await context.read<ProductsProvider>().exportAll();
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await downloadFile(context, result.right);
  }

  /// Sube un Excel de productos, marcas o categorías. El servidor importa las filas buenas y
  /// devuelve las que fallaron, que se muestran al terminar.
  Future<void> _importar(ImportKind kind, IconData icono) async {
    final products = context.read<ProductsProvider>();
    PickedImportFile? picked;
    ImportResultEntity? result;

    await showAppImportModal(
      context,
      title: kind == ImportKind.productos ? 'Subir productos' : 'Importar ${kind.label.toLowerCase()}',
      subtitle: 'Importación masiva',
      icon: icono,
      templateName: 'plantilla de ${kind.label.toLowerCase()}',
      onDownloadTemplate: () => _plantilla(kind),
      onPickFile: () async {
        final file = await widget.pickFile();
        if (file == null) return null;
        picked = file;
        return file.name;
      },
      onUpload: (_) async {
        final file = picked;
        if (file == null) return 'Elige el archivo Excel';
        final response = await products.importFile(kind, fileName: file.name, bytes: file.bytes);
        if (response.isLeft) return response.left.message;
        result = response.right;
        return null;
      },
    );

    final done = result;
    if (done == null || !mounted) return;
    if (done.hasFailures) {
      _snack('${kind.label} subidos');
    } else {
      showSuccessSnack(context, '${kind.label} subidos');
    }
    if (done.hasFailures) {
      await showImportFailures(context, kind: kind, failures: done.failures);
    }
  }

  List<AppSpeedDialAction> _actions(ProductsProvider products) => [
        if (_can('productos.store'))
          AppSpeedDialAction(
            label: 'Crear',
            icon: Icons.add,
            color: const Color(0xFF16A34A),
            onPressed: _crear,
          ),
        if (_can('productos.acciones-adicionales')) ...[
          AppSpeedDialAction(
            label: 'Descargar plantilla',
            icon: Icons.download_outlined,
            color: const Color(0xFF0E90C7),
            onPressed: () => _plantilla(ImportKind.productos),
          ),
          if (_can('productos.store') || _can('productos.import'))
            AppSpeedDialAction(
              label: 'Subir productos',
              icon: Icons.upload_outlined,
              color: const Color(0xFFE8891D),
              onPressed: () => _importar(ImportKind.productos, Icons.upload_outlined),
            ),
          if (_can('productos.export'))
            AppSpeedDialAction(
              label: 'Exportar',
              icon: Icons.description_outlined,
              color: const Color(0xFF0D9488),
              onPressed: _exportar,
            ),
        ],
        if (_can('brand.store'))
          AppSpeedDialAction(
            label: 'Importar marcas',
            icon: Icons.sell_outlined,
            color: const Color(0xFF7C3AED),
            onPressed: () => _importar(ImportKind.marcas, Icons.sell_outlined),
          ),
        if (_can('category.store'))
          AppSpeedDialAction(
            label: 'Importar categorías',
            icon: Icons.account_tree_outlined,
            color: const Color(0xFFDB2777),
            onPressed: () => _importar(ImportKind.categorias, Icons.account_tree_outlined),
          ),
        AppSpeedDialAction(
          label: 'Totales',
          icon: Icons.functions,
          color: const Color(0xFF0E90C7),
          onPressed: () => _showTotals(products),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductsProvider>();
    final actions = _actions(products);

    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.category_outlined,
          title: 'Productos',
          subtitle: 'Qué se compra y se vende, y en qué presentaciones.',
          trailing: AppAccountMenu(),
        ),
        // En tablet, la lista a la izquierda y el detalle del producto a la derecha.
        Expanded(
          child: AppMasterDetail(
            controller: _pane,
            emptyIcon: Icons.category_outlined,
            emptyTitle: 'Selecciona un producto',
            emptyMessage: 'Toca un producto para ver su detalle.',
            listBuilder: (context) => _listPane(products, actions),
          ),
        ),
      ],
    );
  }

  /// La lista: búsqueda, filtros, tarjetas y el botón "Acciones" abajo a la derecha
  /// (sin acciones, no se muestra).
  Widget _listPane(ProductsProvider products, List<AppSpeedDialAction> actions) {
    return Stack(
      children: [
        Column(
          children: [
            AppSearchBar(
              hint: 'Buscar por nombre, código…',
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              onFilter: _openFilters,
              filterCount: _activeFilters(products).length,
            ),
            AppActiveFilters(
              filters: _activeFilters(products),
              onClear: () => products.setFilters(tipo: null, activo: null),
            ),
            AppSearchChips(
              terms: products.searchTerms,
              onRemove: products.removeSearchTerm,
              onClear: products.clearSearchTerms,
            ),
            Expanded(child: _body(products)),
          ],
        ),
        if (actions.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: AppSpeedDial(actions: actions),
          ),
      ],
    );
  }

  /// Los filtros del panel que están puestos (el tipo y el estado), para mostrarlos como chips.
  List<AppActiveFilter> _activeFilters(ProductsProvider products) => [
        if (products.tipo != null)
          AppActiveFilter(
            id: 'tipo',
            label: 'Tipo: ${products.tipo == 's' ? 'Servicios' : 'Productos'}',
            onRemove: () => products.setTipo(null),
          ),
        if (products.activo != null)
          AppActiveFilter(
            id: 'estado',
            label: 'Estado: ${products.activo! ? 'Activos' : 'Inactivos'}',
            onRemove: () => products.setActivo(null),
          ),
      ];

  /// Todos / Productos / Servicios en un modal de totales (como el "Totales" de Stock): son los
  /// números del servidor para la búsqueda y los filtros que están puestos. El tipo se sigue
  /// filtrando desde el panel de filtros.
  void _showTotals(ProductsProvider products) {
    showAppSummary(
      context,
      title: 'Totales',
      subtitle: 'Productos',
      metrics: [
        AppSummaryMetric(
          label: 'Todos',
          value: '${products.total}',
          color: const Color(0xFF0E90C7),
        ),
        AppSummaryMetric(
          label: 'Productos',
          value: '${products.totalProductos}',
          color: const Color(0xFF16A34A),
        ),
        AppSummaryMetric(
          label: 'Servicios',
          value: '${products.totalServicios}',
          color: const Color(0xFF7C3AED),
        ),
      ],
      note: 'Según la búsqueda y los filtros que están puestos.',
    );
  }

  Widget _body(ProductsProvider products) {
    if (products.loading && products.items.isEmpty) {
      return const AppSkeletonList();
    }
    if (products.error != null && products.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los productos',
        message: products.error,
        action: AppButton(
          label: 'Reintentar',
          icon: Icons.refresh,
          onPressed: products.refresh,
        ),
      );
    }

    return AppCardList<ProductEntity>(
      items: products.items,
      emptyIcon: Icons.category_outlined,
      emptyTitle: 'No hay productos',
      emptyMessage: products.search.isNotEmpty || products.filtersActive
          ? 'Prueba con otra búsqueda o quita los filtros.'
          : null,
      onRefresh: products.refresh,
      onLoadMore: products.loadMore,
      loadingMore: products.loadingMore,
      bottomPadding: 96,
      itemBuilder: (context, p, number) => _card(context, p, number),
    );
  }

  Widget _card(BuildContext context, ProductEntity p, int number) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Los mismos datos que la tabla de la web: tipo, código, descripción,
    // marca, categoría, unidad de medida y estado.
    final detalle = [p.marca, p.categoria]
        .whereType<String>()
        .where((t) => t.isNotEmpty)
        .join(' · ');

    return AppListCard(
      number: number,
      title: p.name,
      lines: [
        [p.esServicio ? 'Servicio' : 'Producto', if (p.codigo.isNotEmpty) p.codigo]
            .join(' · '),
        if (detalle.isNotEmpty) detalle,
      ],
      trailingTitle: p.unidadLabel,
      trailingCaption: p.activo ? 'Activo' : 'Inactivo',
      trailingCaptionColor: p.activo
          ? (dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
          : scheme.onSurfaceVariant,
      selected: _pane.selectedId == p.id,
      onTap: () => _verDetalle(p),
      actions: [
        AppActionButton(type: AppActionType.view, onPressed: () => _verDetalle(p)),
        if (_can('productos.update'))
          AppActionButton(type: AppActionType.edit, onPressed: () => _editar(p)),
      ],
    );
  }
}
