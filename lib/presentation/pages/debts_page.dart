import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/debt_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/debts_provider.dart';
import '../utils/download_file.dart';

/// Módulo Deudas (en la web, el módulo "Pagos"): lo que cada cliente debe en soles y en dólares,
/// su línea de crédito usada y su crédito, con los totales, búsqueda por cliente, filtros de
/// cliente y ejecutivo comercial y Excel. Permiso `pagos.index`.
class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _can('pagos.index')) context.read<DebtsProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool _can(String permission) => context.read<AuthProvider>().session?.can(permission) ?? false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<DebtsProvider>().setSearch(text);
    });
  }

  Future<void> _openFilters() async {
    final provider = context.read<DebtsProvider>();
    final draft = ValueNotifier<DebtFiltersEntity>(provider.filters);
    final applied = await showAppModal(
      context,
      title: 'Filtros',
      subtitle: 'Deudas pendientes',
      icon: Icons.filter_list,
      primaryLabel: 'Aplicar filtros',
      child: _FiltersBody(draft: draft, provider: provider),
    );
    final result = applied == true ? draft.value : null;
    draft.dispose();
    if (result != null) provider.setFilters(result);
  }

  Future<void> _export() async {
    final result = await context.read<DebtsProvider>().exportAll();
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await downloadFile(context, result.right);
  }

  List<AppActiveFilter> _activeFilters(DebtsProvider provider) {
    final f = provider.filters;
    return [
      if (f.client != null)
        AppActiveFilter(
          id: 'cliente',
          label: 'Cliente: ${f.client!.name}',
          onRemove: () => provider.setFilters(f.copyWith(clearClient: true)),
        ),
      if (f.seller != null)
        AppActiveFilter(
          id: 'ejecutivo',
          label: 'Ejecutivo: ${shortPersonName(f.seller!.name)}',
          onRemove: () => provider.setFilters(f.copyWith(clearSeller: true)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtsProvider>();
    final session = context.watch<AuthProvider>().session;

    if (session != null && !session.can('pagos.index')) {
      return Column(
        children: const [
          AppPageHeader(
            icon: Icons.payments_outlined,
            title: 'Deudas',
            trailing: AppAccountMenu(),
          ),
          Expanded(
            child: AppEmptyState(
              icon: Icons.lock_outline,
              title: 'Sin acceso',
              message: 'No tienes permiso para ver las deudas.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.payments_outlined,
          title: 'Deudas',
          subtitle: 'Lo que te deben tus clientes.',
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

  Widget _listPane(DebtsProvider provider) {
    final filters = _activeFilters(provider);
    return Stack(
      children: [
        Column(
          children: [
            AppSearchBar(
              hint: 'Buscar por cliente…',
              onChanged: _onSearchChanged,
              onFilter: _openFilters,
              filterCount: filters.length,
            ),
            AppActiveFilters(
              filters: filters,
              onClear: () => provider.setFilters(
                provider.filters.copyWith(clearClient: true, clearSeller: true),
              ),
            ),
            Expanded(child: _body(provider)),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: AppSpeedDial(
            actions: [
              AppSpeedDialAction(
                label: 'Totales',
                icon: Icons.functions,
                color: const Color(0xFF0E90C7),
                onPressed: () => _showTotals(provider),
              ),
              AppSpeedDialAction(
                label: provider.exporting ? 'Exportando…' : 'Exportar Excel',
                icon: Icons.description_outlined,
                color: const Color(0xFF0D9488),
                onPressed: provider.exporting ? null : _export,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Total soles" y "Total dólares" de la cabecera de la web, en el modal de totales (como los de
  /// Stock y Productos): son los del servidor para la búsqueda y los filtros que están puestos.
  void _showTotals(DebtsProvider provider) {
    showAppSummary(
      context,
      title: 'Totales',
      subtitle: 'Deudas',
      metrics: [
        AppSummaryMetric(
          label: 'Total soles',
          value: formatMoney(provider.totalSoles, symbol: 'S/.'),
          color: const Color(0xFF65A30D),
        ),
        AppSummaryMetric(
          label: 'Total dólares',
          value: formatMoney(provider.totalDolares, symbol: r'$.'),
          color: const Color(0xFFCA8A04),
        ),
      ],
      note: 'Según la búsqueda y los filtros que están puestos.',
    );
  }

  Widget _body(DebtsProvider provider) {
    if (provider.loading && provider.items.isEmpty) {
      return const AppSkeletonList();
    }
    if (provider.error != null && provider.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar las deudas',
        message: provider.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: provider.refresh),
      );
    }

    return AppCardList<DebtClientEntity>(
      items: provider.items,
      emptyIcon: Icons.payments_outlined,
      emptyTitle: 'No hay deudas pendientes',
      emptyMessage: provider.filters.active ? 'Prueba con otra búsqueda o quita los filtros.' : null,
      onRefresh: provider.refresh,
      onLoadMore: provider.loadMore,
      loadingMore: provider.loadingMore,
      bottomPadding: 96,
      itemBuilder: (context, d, number) => _card(context, d),
    );
  }

  Widget _card(BuildContext context, DebtClientEntity d) {
    final scheme = Theme.of(context).colorScheme;
    // Las mismas columnas que la tabla de la web: deuda en soles y en dólares, línea utilizada
    // y crédito.
    return AppListCard(
      title: d.cliente,
      lines: [
        'Línea utilizada ${formatMoney(d.lineaUtilizada, symbol: 'S/.')}',
        'Crédito ${formatMoney(d.credito, symbol: 'S/.')}',
      ],
      trailingTitle: formatMoney(d.deudaSoles, symbol: 'S/.'),
      trailingCaption: d.deudaDolares != 0 ? formatMoney(d.deudaDolares, symbol: r'$.') : null,
      trailingCaptionColor: scheme.onSurfaceVariant,
    );
  }
}

/// El cuerpo del panel de filtros: cliente y, si el usuario ve a todos los vendedores, el
/// ejecutivo comercial.
class _FiltersBody extends StatelessWidget {
  final ValueNotifier<DebtFiltersEntity> draft;
  final DebtsProvider provider;

  const _FiltersBody({required this.draft, required this.provider});

  Future<void> _pickClient(BuildContext context) async {
    await showAppSearchSheet<DebtOption>(
      context,
      title: 'Cliente',
      subtitle: 'Busca por nombre, documento o código',
      icon: Icons.person_search_outlined,
      hint: 'Nombre, DNI/RUC o código',
      search: provider.searchClients,
      itemOf: (c) => AppSearchItem(title: c.name),
      onSelect: (c) {
        draft.value = draft.value.copyWith(client: c);
        return null;
      },
    );
  }

  Future<void> _pickSeller(BuildContext context) async {
    await showAppModal(
      context,
      title: 'Ejecutivo comercial',
      icon: Icons.badge_outlined,
      primaryLabel: null,
      secondaryLabel: 'Cerrar',
      child: _SellerList(
        load: provider.loadSellers,
        selected: draft.value.seller,
        onPick: (s) => draft.value = draft.value.copyWith(seller: s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DebtFiltersEntity>(
      valueListenable: draft,
      builder: (context, f, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPickerField(
            label: 'Cliente',
            value: f.client?.name ?? 'Todos',
            icon: Icons.person_outline,
            onTap: () => _pickClient(context),
            onClear: f.client == null ? null : () => draft.value = f.copyWith(clearClient: true),
          ),
          if (provider.canSeeAll) ...[
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Ejecutivo comercial',
              value: f.seller == null ? 'Todos' : shortPersonName(f.seller!.name),
              icon: Icons.badge_outlined,
              onTap: () => _pickSeller(context),
              onClear: f.seller == null ? null : () => draft.value = f.copyWith(clearSeller: true),
            ),
          ],
        ],
      ),
    );
  }
}

/// La lista de ejecutivos comerciales: al tocar uno se elige y se cierra.
class _SellerList extends StatefulWidget {
  final Future<List<DebtOption>> Function() load;
  final DebtOption? selected;
  final ValueChanged<DebtOption> onPick;

  const _SellerList({required this.load, required this.selected, required this.onPick});

  @override
  State<_SellerList> createState() => _SellerListState();
}

class _SellerListState extends State<_SellerList> {
  late final Future<List<DebtOption>> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DebtOption>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: ErrorBanner(message: '${snapshot.error}'.replaceFirst('Exception: ', '')),
          );
        }
        final sellers = snapshot.data ?? const [];
        if (sellers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No hay ejecutivos')),
          );
        }
        return Column(
          children: [
            for (final s in sellers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(shortPersonName(s.name)),
                subtitle: shortPersonName(s.name) == s.name ? null : Text(s.name),
                trailing: widget.selected == s ? const Icon(Icons.check) : null,
                onTap: () {
                  widget.onPick(s);
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }
}
