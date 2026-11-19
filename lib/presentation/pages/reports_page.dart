import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/entities/report_ranking_entity.dart';
import '../components/components.dart';
import '../providers/reports_provider.dart';
import '../utils/download_file.dart';
import '../widgets/report_filters.dart';
import '../widgets/report_products.dart';
import '../widgets/report_rankings.dart';
import 'receipt_page.dart';

const _limeColor = Color(0xFF84CC16);
const _amberColor = Color(0xFFEAB308);
const _blueColor = Color(0xFF60A5FA);

String _soles(double v) => formatMoney(v, symbol: 'S/.');

/// Módulo Reportes: el reporte **Ventas General** de la web. Las cifras del rango (venta total,
/// unidades, número de ventas, ticket promedio y margen) con su comparación contra el año
/// anterior, la gráfica de ventas y los productos vendidos con sus documentos; filtros
/// avanzados y descarga del Excel. Según el rol no se ven los importes ni el margen.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static final _day = DateFormat(AppConstants.dateFormat);

  /// El margen se muestra oculto (`S/. ****`) hasta que se toca el ojo, como en la web.
  bool _marginVisible = false;

  /// La lista completa de productos y servicios: en Venta general solo sale el top 3 en una tarjeta y
  /// la lista se abre con su flecha.
  bool _productsView = false;

  /// El buscador de la lista de productos (por código, nombre o marca). Solo filtra lo vendido en el rango.
  final _productSearch = TextEditingController();
  String _productQuery = '';

  @override
  void dispose() {
    _productSearch.dispose();
    super.dispose();
  }

  void _closeProducts() {
    _productSearch.clear();
    setState(() {
      _productsView = false;
      _productQuery = '';
    });
  }

  /// Busca en toda la lista: el servidor pagina los productos, así que al buscar se piden las páginas
  /// que faltan (en lotes de 50) para no dejar fuera ninguno.
  Future<void> _searchProducts(String text) async {
    final reports = context.read<ReportsProvider>();
    setState(() => _productQuery = text.trim());
    while (mounted && _productQuery.isNotEmpty && reports.hasMore) {
      final before = reports.report?.products.length ?? 0;
      await reports.loadMore();
      if ((reports.report?.products.length ?? 0) <= before) break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canView) context.read<ReportsProvider>().ensureLoaded();
    });
  }

  /// Se puede entrar si el usuario tiene alguno de los reportes (Venta general o uno por entidad).
  bool get _canView => context.read<ReportsProvider>().availableKinds.isNotEmpty;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickCustom() async {
    final reports = context.read<ReportsProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: reports.dates,
      helpText: 'Elegir fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) reports.selectCustom(picked);
  }

  Future<void> _export() async {
    final result = await context.read<ReportsProvider>().exportCurrent();
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await downloadFile(context, result.right);
  }

  /// Las ventas del rango que incluyen [product]: tocar una abre su comprobante.
  Future<void> _showDocuments(SalesReportProductEntity product, SalesReportEntity report) {
    final docs = [for (final d in report.documents) if (d.productIds.contains(product.id)) d];
    return showReportDocuments(context, productName: product.name, docs: docs, onOpen: _openSale);
  }

  /// Los productos vendidos a la fila tocada de un reporte por entidad (sus documentos y comprobantes
  /// se abren desde ahí).
  Future<void> _showEntityProducts(ReportKind kind, RankingRow row) {
    if (ReportsProvider.entityId(kind, row) == null) {
      _snack('Este registro no tiene productos para mostrar');
      return Future.value();
    }
    return showEntityProducts(context, kind: kind, row: row, onOpenSale: _openSale);
  }

  Future<void> _openSale(SalesReportDocumentEntity doc) async {
    final navigator = Navigator.of(context);
    final result = await context.read<ReportsProvider>().loadSale(doc.id);
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await navigator.push(MaterialPageRoute<void>(builder: (_) => ReceiptPage(document: result.right)));
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    final canView = _canView;

    return Column(
      children: [
        AppPageHeader(
          icon: Icons.bar_chart_outlined,
          title: 'Reportes',
          subtitle: reports.kind.subtitle,
          trailing: const AppAccountMenu(),
        ),
        if (canView) _toolbar(reports),
        if (canView && reports.loading && reports.report != null)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _body(reports, canView)),
      ],
    );
  }

  Widget _toolbar(ReportsProvider reports) {
    final scheme = Theme.of(context).colorScheme;
    final kinds = reports.availableKinds;
    final general = reports.kind == ReportKind.general;
    return Column(
      children: [
        // Los reportes por entidad se abren desde las tarjetas de Venta general (con su flecha para
        // volver). Solo si el usuario no tiene Venta general queda el selector para cambiar de uno a otro.
        if (kinds.length > 1 && !kinds.contains(ReportKind.general))
          ReportKindSelector(kinds: kinds, selected: reports.kind, onSelect: reports.selectKind),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            itemCount: ReportRange.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final range = ReportRange.values[i];
              final custom = range == ReportRange.personalizado;
              final selected = reports.range == range;
              return ChoiceChip(
                label: Text(
                  custom && selected
                      ? '${_day.format(reports.dates.start)} – ${_day.format(reports.dates.end)}'
                      : range.label,
                ),
                avatar: custom ? const Icon(Icons.date_range, size: 18) : null,
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => custom ? _pickCustom() : reports.selectRange(range),
              );
            },
          ),
        ),
        // Venta general: las fechas en consulta, los filtros (con "Comparar año anterior" dentro) y el Excel. Los
        // reportes por entidad no tienen esa fila: su filtro va en la fila del buscador.
        if (general && !_productsView)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              // Las fechas que se están consultando ("Comparar año anterior" está dentro de los filtros).
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.date_range_outlined, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${_day.format(reports.dates.start)} – ${_day.format(reports.dates.end)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Filtros avanzados',
                onPressed: () => showReportFilters(context),
                icon: Badge(
                  isLabelVisible: reports.advancedCount > 0,
                  label: Text('${reports.advancedCount}'),
                  child: Icon(Icons.filter_list, color: scheme.primary),
                ),
              ),
              IconButton(
                  tooltip: 'Descargar Excel',
                  onPressed: reports.exporting ? null : _export,
                  icon: Icon(Icons.download_outlined, color: scheme.primary),
                ),
            ],
          ),
        ),
        AppActiveFilters(
          filters: reportActiveFilters(reports),
          onClear: reports.clearAdvancedFilters,
        ),
      ],
    );
  }

  Widget _body(ReportsProvider reports, bool canView) {
    if (!canView) {
      return const AppEmptyState(
        icon: Icons.lock_outline,
        title: 'Sin acceso',
        message: 'No tienes permiso para ver este reporte.',
      );
    }
    if (reports.kind.isRanking) return _ranking(reports, reports.kind);
    final report = reports.report;
    if (report == null) {
      if (reports.error != null) {
        return AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'No se pudo cargar el reporte',
          message: reports.error,
          action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: reports.refresh),
        );
      }
      return const AppSkeletonReport();
    }

    final products = report.products;
    if (_productsView) return _productsList(reports, report, products);

    // Venta general: las cifras, la gráfica y las tarjetas (productos primero, luego departamentos,
    // vendedores, marcas, categorías y clientes). La lista de productos se abre desde su tarjeta.
    return RefreshIndicator(
      onRefresh: reports.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final child in [_cards(reports, report), _chart(reports, report), _dashboard(reports, report)])
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
              ),
            ),
        ],
      ),
    );
  }

  /// La lista completa de productos y servicios (con su flecha para volver a Venta general).
  Widget _productsList(ReportsProvider reports, SalesReportEntity report, List<SalesReportProductEntity> products) {
    // Como los reportes por entidad: encabezado, buscador con los filtros al lado y la lista. El buscador
    // filtra por código, nombre o marca.
    final query = _productQuery.toLowerCase();
    final shown = query.isEmpty
        ? products
        : [
            for (final p in products)
              if (p.codigo.toLowerCase().contains(query) ||
                  p.name.toLowerCase().contains(query) ||
                  (p.marca?.toLowerCase().contains(query) ?? false))
                p,
          ];
    final count = (shown.isEmpty ? 1 : shown.length) + (reports.loadingMore ? 1 : 0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _productsHeader(reports, report),
            AppSearchBar(
              hint: 'Buscar por código o nombre',
              controller: _productSearch,
              onChanged: _searchProducts,
              onFilter: () => showReportFilters(context),
              filterCount: reports.advancedCount,
              actions: [
                IconButton(
                  tooltip: 'Descargar Excel',
                  onPressed: reports.exporting ? null : _export,
                  icon: Icon(Icons.download_outlined, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            if (reports.loadingMore && query.isNotEmpty) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: reports.refresh,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 400) reports.loadMore();
                    return false;
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: count,
                    itemBuilder: (context, i) {
                      Widget child;
                      if (shown.isEmpty) {
                        child = products.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: 'No hay ventas',
                                message: 'Prueba con otro rango de fechas o quita los filtros.',
                              )
                            : const AppEmptyState(
                                icon: Icons.search_off,
                                title: 'Sin resultados',
                                message: 'Ninguno coincide con la búsqueda.',
                              );
                      } else if (i < shown.length) {
                        child = _productCard(reports, report, shown[i], i + 1);
                      } else {
                        child = const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(padding: const EdgeInsets.only(bottom: 8), child: child);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Las tarjetas "Ventas por departamentos / vendedores / marcas / categorías / clientes": el top 3
  /// de cada reporte, y al tocarlas se abre la lista completa.
  Widget _dashboard(ReportsProvider reports, SalesReportEntity report) {
    // El top 3 de productos: lo que cada uno representa de la venta total (o de las unidades, si el rol
    // no ve importes).
    final byAmount = !reports.ocultarImportes;
    final base = byAmount ? report.totalVentas : report.unidades;
    final top = [
      for (final p in report.products.take(RankingSummaryCard.top))
        (
          // Solo el código del producto (el nombre largo no cabe en la tarjeta).
          row: RankingRow(
            id: p.id,
            name: p.codigo.trim().isEmpty ? p.name : p.codigo,
            venta: byAmount ? p.venta : p.cantidad,
          ),
          share: base > 0 ? (byAmount ? p.venta : p.cantidad) / base * 100 : 0.0,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductsSummaryCard(
          top: top,
          showAmounts: byAmount,
          onOpen: () {
            setState(() => _productsView = true);
          },
        ),
        if (reports.dashboardKinds.isNotEmpty) const SizedBox(height: 12),
        for (final kind in reports.dashboardKinds) ...[
          RankingSummaryCard(
            kind: kind,
            state: reports.ranking(kind),
            showAmounts: !reports.ocultarImportes,
            onOpen: () => reports.selectKind(kind),
            onRetry: () => reports.retryRanking(kind),
          ),
          if (kind != reports.dashboardKinds.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// La lista completa de un reporte por entidad.
  Widget _ranking(ReportsProvider reports, ReportKind kind) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: RankingView(
          key: ValueKey('ranking-${kind.name}'),
          kind: kind,
          state: reports.ranking(kind),
          showAmounts: !reports.ocultarImportes,
          onFilter: () => showReportFilters(context),
          filterCount: reports.advancedCount,
          showMargin: !reports.ocultarMargen,
          marginVisible: _marginVisible,
          onToggleMargin: () => setState(() => _marginVisible = !_marginVisible),
          onBack: reports.availableKinds.contains(ReportKind.general)
              ? () => reports.selectKind(ReportKind.general)
              : null,
          onSearch: (text) => reports.setRankingSearch(kind, text),
          // Lo escrito también se busca como código de producto: elegir uno filtra el reporte por él.
          onSearchCodes: (text) async =>
              (await reports.searchProductCodes(text)).fold((_) => <ReportProductOption>[], (list) => list),
          onPickCode: (code) => reports.applyFilters(reports.filters.copyWith(productCode: code)),
          onRefresh: reports.refresh,
          onRetry: () => reports.retryRanking(kind),
          onLoadMore: () => reports.loadMoreRanking(kind),
          onRowTap: (row) => _showEntityProducts(kind, row),
        ),
      ),
    );
  }

  /// Variación porcentual contra el año anterior; `null` sin base de comparación.
  double? _variation(double current, double? before) =>
      before == null || before <= 0 ? null : (current - before) / before * 100;

  Widget _cards(ReportsProvider reports, SalesReportEntity report) {
    final previous = reports.compare ? reports.previous : null;
    final showCompare = reports.compare && previous != null;
    final importes = !reports.ocultarImportes;

    final stats = <Widget>[
      if (importes)
        _StatCard(
          title: 'Venta Total',
          amount: report.totalVentas,
          format: _soles,
          icon: Icons.shopping_cart_outlined,
          variation: showCompare ? _variation(report.totalVentas, previous.totalVentas) : null,
          showVariation: showCompare,
        ),
      _StatCard(
        title: 'Unidades Vendidas',
        amount: report.unidades,
        format: formatQuantity,
        icon: Icons.inventory_2_outlined,
        variation: showCompare ? _variation(report.unidades, previous.unidades) : null,
        showVariation: showCompare,
      ),
      _StatCard(
        title: 'N° de Ventas',
        amount: report.countVentas.toDouble(),
        format: (v) => '${v.round()}',
        icon: Icons.receipt_long_outlined,
        variation:
            showCompare ? _variation(report.countVentas.toDouble(), previous.countVentas.toDouble()) : null,
        showVariation: showCompare,
      ),
      if (importes)
        _StatCard(
          title: 'Ticket Promedio',
          amount: report.ticketPromedio,
          format: _soles,
          icon: Icons.confirmation_number_outlined,
          variation: showCompare ? _variation(report.ticketPromedio, previous.ticketPromedio) : null,
          showVariation: showCompare,
        ),
    ];

    // De a dos por fila y con la misma altura; el margen va solo, a todo el ancho.
    final rows = <Widget>[
      for (var i = 0; i < stats.length; i += 2)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: stats[i]),
              const SizedBox(width: 12),
              Expanded(child: i + 1 < stats.length ? stats[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      if (importes && !reports.ocultarMargen)
        _MarginCard(
          report: report,
          previous: showCompare ? previous : null,
          igv: reports.igv,
          renta: reports.renta,
          visible: _marginVisible,
          onToggle: () => setState(() => _marginVisible = !_marginVisible),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }

  Widget _chart(ReportsProvider reports, SalesReportEntity report) {
    final theme = Theme.of(context);
    final days = report.days;
    final previous = reports.compare ? reports.previous : null;

    final List<AreaSeries> series;
    if (reports.ocultarImportes) {
      // Sin permiso de importes, la curva es de unidades vendidas.
      series = [AreaSeries(name: 'Unidades', color: _limeColor, values: [for (final d in days) d.unidades])];
    } else {
      series = [
        AreaSeries(name: 'Soles', color: _limeColor, values: [for (final d in days) d.ventasSoles]),
        if (days.any((d) => d.ventasDolares > 0))
          AreaSeries(name: 'Dólares', color: _amberColor, values: [for (final d in days) d.ventasDolares]),
        if (previous != null)
          AreaSeries(
            name: 'Soles (año pasado)',
            color: _blueColor,
            values: [
              for (var i = 0; i < days.length; i++)
                i < previous.days.length ? previous.days[i].ventasSoles : 0,
            ],
          ),
      ];
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reports.ocultarImportes ? 'Unidades vendidas' : 'Ventas',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (days.isEmpty)
            const SizedBox(height: 120, child: Center(child: Text('Sin datos en el rango')))
          else
            AppAreaChart(
              labels: [for (final d in days) d.name],
              series: series,
              format: (v) => reports.ocultarImportes ? formatQuantity(v) : _soles(v),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final s in series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(s.name, style: theme.textTheme.labelSmall),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productsHeader(ReportsProvider reports, SalesReportEntity report) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = '${report.totalProducts} productos y servicios';

    // El mismo encabezado de los reportes por entidad: flecha, título con su total y el ojo del margen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver a Venta general',
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeProducts,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productos y servicios',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  reports.ocultarImportes ? count : 'Total ${_soles(report.totalVentas)} · $count',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!reports.ocultarImportes && !reports.ocultarMargen)
            IconButton(
              tooltip: _marginVisible ? 'Ocultar el margen' : 'Ver el margen',
              icon: Icon(_marginVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _marginVisible = !_marginVisible),
            ),
        ],
      ),
    );
  }

  Widget _productCard(
    ReportsProvider reports,
    SalesReportEntity report,
    SalesReportProductEntity p,
    int number,
  ) {
    final importes = !reports.ocultarImportes;
    return ReportProductCard(
      title: p.name,
      detail: [if (p.codigo.isNotEmpty) p.codigo, if (p.marca != null) p.marca!].join(' · '),
      subtotal: p.subtotal,
      descuento: p.descuento,
      venta: p.venta,
      cantidad: p.cantidad,
      margen: p.margen,
      showAmounts: importes,
      showMargin: importes && !reports.ocultarMargen,
      marginVisible: _marginVisible,
      onTap: () => _showDocuments(p, report),
    );
  }
}

/// Una cifra del reporte: título, valor grande y, al comparar, la variación contra el año pasado.
class _StatCard extends StatelessWidget {
  final String title;
  final double amount;
  final String Function(double) format;
  final IconData icon;
  final double? variation;
  final bool showVariation;

  const _StatCard({
    required this.title,
    required this.amount,
    required this.format,
    required this.icon,
    this.variation,
    this.showVariation = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El título ocupa todo el ancho de la tarjeta y va en una sola línea; el ícono baja junto al valor.
          Text(
            title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AppCountUp(
                    value: amount,
                    format: format,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 20, color: _limeColor),
            ],
          ),
          if (showVariation) ...[
            const SizedBox(height: 6),
            AppVariationBadge(value: variation),
          ],
        ],
      ),
    );
  }
}

/// El margen bruto o neto del rango (se elige con el menú del título). Por defecto sale oculto.
class _MarginCard extends StatefulWidget {
  final SalesReportEntity report;
  final SalesReportEntity? previous;
  final double igv;
  final double renta;
  final bool visible;
  final VoidCallback onToggle;

  const _MarginCard({
    required this.report,
    required this.previous,
    required this.igv,
    required this.renta,
    required this.visible,
    required this.onToggle,
  });

  @override
  State<_MarginCard> createState() => _MarginCardState();
}

class _MarginCardState extends State<_MarginCard> {
  bool _net = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = widget.report;
    final now = MarginFigures.of(r.totalVentas, r.totalCostos, igv: widget.igv, renta: widget.renta);
    final before = widget.previous == null
        ? null
        : MarginFigures.of(
            widget.previous!.totalVentas,
            widget.previous!.totalCostos,
            igv: widget.igv,
            renta: widget.renta,
          );

    final amount = _net ? now.neto : now.bruto;
    final pct = _net ? now.netoPct : now.brutoPct;
    final pctBefore = before == null ? null : (_net ? before.netoPct : before.brutoPct);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<bool>(
                  tooltip: 'Tipo de margen',
                  onSelected: (net) => setState(() => _net = net),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: false, child: Text('Margen Bruto')),
                    PopupMenuItem(value: true, child: Text('Margen Neto')),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _net ? 'Margen Neto' : 'Margen Bruto',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: widget.onToggle,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    widget.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: _limeColor,
                    semanticLabel: widget.visible ? 'Ocultar margen' : 'Mostrar margen',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              widget.visible ? _soles(amount) : 'S/. *******',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                widget.visible ? '${pct.toStringAsFixed(1)} %' : '** %',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.visible && pctBefore != null && pctBefore != 0) ...[
                const SizedBox(width: 8),
                AppVariationBadge(value: pct - pctBefore),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
