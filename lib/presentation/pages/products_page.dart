import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/product_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/products_provider.dart';
import '../widgets/product_modals.dart';

/// Módulo Productos: lista paginada con búsqueda y filtro de tipo, detalle,
/// y crear/editar según los permisos del usuario. Plantilla, subir, exportar e
/// importar marcas/categorías aún no están disponibles.
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  Timer? _debounce;

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
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<ProductsProvider>().setSearch(text);
    });
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
      ],
    );
    if (result != null) provider.setTipo(result['tipo']);
  }

  /// Mientras la app es de solo lectura, estas acciones avisan que aún no existen.
  void _proximamente(String accion) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$accion: disponible pronto')));
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
      onSubmit: (form) => products.saveProduct(form),
    );
  }

  Future<void> _editar(ProductEntity p) async {
    final products = context.read<ProductsProvider>();
    await showProductForm(
      context,
      product: p,
      loadCatalogs: products.loadCatalogs,
      onSubmit: (form) => products.saveProduct(form, id: p.id),
    );
  }

  Future<void> _verDetalle(ProductEntity p) async {
    final editar = await showProductDetail(
      context,
      p,
      canEdit: _can('productos.update'),
    );
    if (editar == true && mounted) _editar(p);
  }

  // Las mismas acciones que la web en `/productos`: crear, plantilla, subir,
  // exportar, y las importaciones de marcas y categorías.

  void _importar(String titulo, String plantilla, IconData icono) {
    showAppImportModal(
      context,
      title: titulo,
      subtitle: 'Importación masiva',
      icon: icono,
      templateName: plantilla,
      onDownloadTemplate: () => _proximamente('Descargar plantilla'),
      onPickFile: () async {
        _proximamente('Elegir archivo');
        return null;
      },
      onUpload: (_) => _proximamente('Subir archivo'),
    );
  }

  List<AppSpeedDialAction> _actions() => [
        if (_can('productos.store'))
          AppSpeedDialAction(
            label: 'Crear',
            icon: Icons.add,
            color: const Color(0xFF16A34A),
            onPressed: _crear,
          ),
        AppSpeedDialAction(
          label: 'Descargar plantilla',
          icon: Icons.download_outlined,
          color: const Color(0xFF0E90C7),
          onPressed: () => _proximamente('Descargar plantilla'),
        ),
        AppSpeedDialAction(
          label: 'Subir productos',
          icon: Icons.upload_outlined,
          color: const Color(0xFFE8891D),
          onPressed: () =>
              _importar('Subir productos', 'plantilla de productos', Icons.upload_outlined),
        ),
        AppSpeedDialAction(
          label: 'Exportar',
          icon: Icons.description_outlined,
          color: const Color(0xFF0D9488),
          onPressed: () => _proximamente('Exportar'),
        ),
        AppSpeedDialAction(
          label: 'Importar marcas',
          icon: Icons.sell_outlined,
          color: const Color(0xFF7C3AED),
          onPressed: () =>
              _importar('Importar marcas', 'plantilla de marcas', Icons.sell_outlined),
        ),
        AppSpeedDialAction(
          label: 'Importar categorías',
          icon: Icons.account_tree_outlined,
          color: const Color(0xFFDB2777),
          onPressed: () => _importar(
            'Importar categorías',
            'plantilla de categorías',
            Icons.account_tree_outlined,
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductsProvider>();

    return Stack(
      children: [
        Column(
          children: [
            const AppPageHeader(
              icon: Icons.category_outlined,
              title: 'Productos',
              subtitle: 'Qué se compra y se vende, y en qué presentaciones.',
              trailing: AppAccountMenu(),
            ),
            AppSearchBar(
              hint: 'Buscar por nombre, código…',
              onChanged: _onSearchChanged,
              onFilter: _openFilters,
              filterActive: products.filtersActive,
            ),
            if (products.total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${products.total} productos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            Expanded(child: _body(products)),
          ],
        ),
        // Botón "Acciones": abajo a la derecha, sobre la lista.
        Positioned(
          right: 16,
          bottom: 16,
          child: AppSpeedDial(actions: _actions()),
        ),
      ],
    );
  }

  Widget _body(ProductsProvider products) {
    if (products.loading && products.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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
      onTap: () => _verDetalle(p),
      actions: [
        AppActionButton(type: AppActionType.view, onPressed: () => _verDetalle(p)),
        if (_can('productos.update'))
          AppActionButton(type: AppActionType.edit, onPressed: () => _editar(p)),
      ],
    );
  }
}
