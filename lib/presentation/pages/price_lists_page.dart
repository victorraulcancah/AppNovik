import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/price_list_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/price_lists_provider.dart';
import '../utils/import_file.dart';
import '../utils/success_snack.dart';
import '../widgets/price_list_modals.dart';
import 'price_list_detail_page.dart';

/// Módulo Lista de precios: las listas de la empresa con su moneda y estado, búsqueda por nombre
/// (cada búsqueda confirmada es un chip, como en la web), filtros de moneda y estado, crear y
/// editar, y el detalle con el precio de cada producto. Permisos `lista-de-precios.index`,
/// `.store`, `.update` y `.show`.
class PriceListsPage extends StatefulWidget {
  /// Selector del Excel a subir en el detalle; se cambia en las pruebas.
  final Future<PickedImportFile?> Function() pickFile;

  const PriceListsPage({super.key, this.pickFile = pickImportFile});

  @override
  State<PriceListsPage> createState() => _PriceListsPageState();
}

class _PriceListsPageState extends State<PriceListsPage> {
  static const _permission = 'lista-de-precios';

  Timer? _debounce;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _can('$_permission.index')) {
        context.read<PriceListsProvider>().ensureLoaded();
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

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<PriceListsProvider>().setSearch(text);
    });
  }

  /// "Buscar" en el teclado: lo escrito pasa a ser un chip y el campo queda libre para otro
  /// término, como en la web.
  void _onSearchSubmitted(String text) {
    _debounce?.cancel();
    _searchController.clear();
    context.read<PriceListsProvider>().addSearchTerm(text);
  }

  Future<void> _openFilters() async {
    final provider = context.read<PriceListsProvider>();
    final values = await showAppFilterSheet(
      context,
      title: 'Filtros',
      fields: [
        AppFilterField(
          id: 'moneda',
          label: 'Moneda',
          allLabel: 'Todas',
          value: provider.currency,
          options: const [
            AppFilterOption('d', 'Dólares'),
            AppFilterOption('s', 'Soles'),
          ],
        ),
        AppFilterField(
          id: 'estado',
          label: 'Estado',
          allLabel: 'Todos',
          value: provider.active == null ? null : '${provider.active}',
          options: const [
            AppFilterOption('true', 'Activo'),
            AppFilterOption('false', 'Inactivo'),
          ],
        ),
      ],
    );
    if (values == null) return;
    final estado = values['estado'];
    provider.setFilters(
      currency: values['moneda'],
      active: estado == null ? null : estado == 'true',
    );
  }

  Future<void> _create() async {
    final provider = context.read<PriceListsProvider>();
    final saved = await showPriceListForm(
      context,
      onSubmit: (form) => provider.save(form),
    );
    if (saved && mounted) showSuccessSnack(context, 'Lista de Precio Creado');
  }

  Future<void> _edit(PriceListEntity list) async {
    final provider = context.read<PriceListsProvider>();
    final saved = await showPriceListForm(
      context,
      list: list,
      onSubmit: (form) => provider.save(form, id: list.id),
    );
    if (saved && mounted) showSuccessSnack(context, 'Lista de Precio Editado');
  }

  void _open(PriceListEntity list) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PriceListDetailPage(list: list, pickFile: widget.pickFile),
      ),
    );
  }

  List<AppActiveFilter> _activeFilters(PriceListsProvider provider) => [
    if (provider.currency != null)
      AppActiveFilter(
        id: 'moneda',
        label: 'Moneda: ${provider.currency == 'd' ? 'Dólares' : 'Soles'}',
        onRemove: () =>
            provider.setFilters(currency: null, active: provider.active),
      ),
    if (provider.active != null)
      AppActiveFilter(
        id: 'estado',
        label: 'Estado: ${provider.active! ? 'Activo' : 'Inactivo'}',
        onRemove: () =>
            provider.setFilters(currency: provider.currency, active: null),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PriceListsProvider>();
    final session = context.watch<AuthProvider>().session;

    if (session != null && !session.can('$_permission.index')) {
      return Column(
        children: const [
          AppPageHeader(
            icon: Icons.sell_outlined,
            title: 'Lista de precios',
            trailing: AppAccountMenu(),
          ),
          Expanded(
            child: AppEmptyState(
              icon: Icons.lock_outline,
              title: 'Sin acceso',
              message: 'No tienes permiso para ver las listas de precios.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.sell_outlined,
          title: 'Lista de precios',
          subtitle: 'Los precios de tus productos por moneda.',
          trailing: AppAccountMenu(),
        ),
        Expanded(
          // En tablet la lista no se estira de lado a lado.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _listPane(provider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _listPane(PriceListsProvider provider) {
    final filters = _activeFilters(provider);
    return Stack(
      children: [
        Column(
          children: [
            AppSearchBar(
              hint: 'Búsqueda por nombre…',
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              onFilter: _openFilters,
              filterCount: filters.length,
            ),
            AppSearchChips(
              terms: provider.searchTerms,
              onRemove: provider.removeSearchTerm,
              onClear: provider.clearSearchTerms,
            ),
            AppActiveFilters(
              filters: filters,
              onClear: () => provider.setFilters(currency: null, active: null),
            ),
            Expanded(child: _body(provider)),
          ],
        ),
        if (_can('$_permission.store'))
          Positioned(
            right: 16,
            bottom: 16,
            child: AppSpeedDial(
              actions: [
                AppSpeedDialAction(
                  label: 'Crear lista',
                  icon: Icons.add,
                  color: const Color(0xFF16A34A),
                  onPressed: _create,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _body(PriceListsProvider provider) {
    if (provider.loading && provider.items.isEmpty) {
      return const AppSkeletonList();
    }
    if (provider.error != null && provider.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar las listas de precios',
        message: provider.error,
        action: AppButton(
          label: 'Reintentar',
          icon: Icons.refresh,
          onPressed: provider.refresh,
        ),
      );
    }

    final filtered = provider.terms.isNotEmpty || provider.filtersActive;
    return AppCardList<PriceListEntity>(
      items: provider.items,
      emptyIcon: Icons.sell_outlined,
      emptyTitle: 'No hay listas de precios',
      emptyMessage: filtered
          ? 'Prueba con otra búsqueda o quita los filtros.'
          : (_can('$_permission.store')
                ? 'Crea la primera con el botón de abajo.'
                : null),
      onRefresh: provider.refresh,
      onLoadMore: provider.loadMore,
      loadingMore: provider.loadingMore,
      bottomPadding: 96,
      itemBuilder: (context, list, number) => _card(context, list),
    );
  }

  Widget _card(BuildContext context, PriceListEntity list) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canShow = _can('$_permission.show');

    // Las mismas columnas que la tabla de la web: nombre, moneda y estado.
    return AppListCard(
      title: list.name,
      lines: ['Moneda · ${list.symbol} ${list.currencyLabel}'],
      trailingCaption: list.active ? 'Activo' : 'Inactivo',
      trailingCaptionColor: list.active
          ? (dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
          : scheme.onSurfaceVariant,
      onTap: canShow ? () => _open(list) : null,
      actions: [
        if (canShow)
          AppActionButton(
            type: AppActionType.view,
            onPressed: () => _open(list),
          ),
        if (_can('$_permission.update'))
          AppActionButton(
            type: AppActionType.edit,
            onPressed: () => _edit(list),
          ),
      ],
    );
  }
}
