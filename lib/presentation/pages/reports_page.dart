import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/report_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import '../utils/download_file.dart';
import '../widgets/report_filters.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canView) context.read<ReportsProvider>().ensureLoaded();
    });
  }

  bool get _canView {
    final session = context.read<AuthProvider>().session;
    return (session?.can('reportes.index') ?? false) && (session?.can('reportes.ventas.index') ?? false);
  }

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
    return showAppModal(
      context,
      title: 'Documentos',
      subtitle: product.name,
      icon: Icons.description_outlined,
      primaryLabel: null,
      secondaryLabel: 'Cerrar',
      child: docs.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No hay documentos')),
            )
          : Column(
              children: [
                for (final d in docs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${d.tipo} Nro: ${d.numero}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openSale(d),
                  ),
              ],
            ),
    );
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
        const AppPageHeader(
          icon: Icons.bar_chart_outlined,
          title: 'Reportes',
          subtitle: 'Ventas General',
          trailing: AppAccountMenu(),
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
    return Column(
      children: [
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: reports.compare,
                  onChanged: (v) => reports.setCompare(v ?? false),
                  title: const Text('Comparar año anterior'),
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
      return const Center(child: CircularProgressIndicator());
    }

    final products = report.products;
    // Cifras, gráfica y encabezado de productos, luego cada producto y el cargando.
    const lead = 3;
    final count = lead + (products.isEmpty ? 1 : products.length) + (reports.loadingMore ? 1 : 0);

    return RefreshIndicator(
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
            if (i == 0) {
              child = _cards(reports, report);
            } else if (i == 1) {
              child = _chart(reports, report);
            } else if (i == 2) {
              child = _productsHeader(reports, report);
            } else if (products.isEmpty) {
              child = const AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No hay ventas',
                message: 'Prueba con otro rango de fechas o quita los filtros.',
              );
            } else if (i - lead < products.length) {
              child = _productCard(reports, report, products[i - lead], i - lead + 1);
            } else {
              child = const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.only(bottom: i >= lead ? 8 : 16),
                  child: child,
                ),
              ),
            );
          },
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

    final cards = <Widget>[
      if (importes)
        _StatCard(
          title: 'Venta Total',
          value: _soles(report.totalVentas),
          icon: Icons.shopping_cart_outlined,
          variation: showCompare ? _variation(report.totalVentas, previous.totalVentas) : null,
          showVariation: showCompare,
        ),
      _StatCard(
        title: 'Unidades Vendidas',
        value: formatQuantity(report.unidades),
        icon: Icons.inventory_2_outlined,
        variation: showCompare ? _variation(report.unidades, previous.unidades) : null,
        showVariation: showCompare,
      ),
      _StatCard(
        title: 'N° de Ventas',
        value: '${report.countVentas}',
        icon: Icons.receipt_long_outlined,
        variation:
            showCompare ? _variation(report.countVentas.toDouble(), previous.countVentas.toDouble()) : null,
        showVariation: showCompare,
      ),
      if (importes)
        _StatCard(
          title: 'Ticket Promedio',
          value: _soles(report.ticketPromedio),
          icon: Icons.confirmation_number_outlined,
          variation: showCompare ? _variation(report.ticketPromedio, previous.ticketPromedio) : null,
          showVariation: showCompare,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final c in cards) SizedBox(width: width, child: c)],
        );
      },
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
    final sortable = reports.ocultarImportes ? [ReportSort.cantidad] : ReportSort.values;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Productos y servicios · ${report.totalProducts}',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        PopupMenuButton<ReportSort>(
          tooltip: 'Ordenar',
          icon: const Icon(Icons.sort),
          onSelected: reports.selectSort,
          itemBuilder: (context) => [
            for (final s in sortable)
              PopupMenuItem(
                value: s,
                child: Row(
                  children: [
                    Expanded(child: Text(s.label)),
                    if (reports.sort == s)
                      Icon(reports.sortDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 18),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _productCard(
    ReportsProvider reports,
    SalesReportEntity report,
    SalesReportProductEntity p,
    int number,
  ) {
    final importes = !reports.ocultarImportes;
    final showMargin = importes && !reports.ocultarMargen;
    final detail = [if (p.codigo.isNotEmpty) p.codigo, if (p.marca != null) p.marca!].join(' · ');

    return AppListCard(
      number: number,
      title: p.name,
      lines: [
        if (detail.isNotEmpty) detail,
        if (importes) 'Subtotal ${_soles(p.subtotal)} · Desc. ${_soles(p.descuento)}',
        if (showMargin) 'Margen ${_marginVisible ? _soles(p.margen) : 'S/. *******'}',
      ],
      trailingTitle: importes ? _soles(p.venta) : '${formatQuantity(p.cantidad)} uds.',
      trailingCaption: importes ? 'Cant. ${formatQuantity(p.cantidad)}' : null,
      onTap: () => _showDocuments(p, report),
      actions: [
        AppActionButton(
          type: AppActionType.view,
          label: 'Ver documentos',
          onPressed: () => _showDocuments(p, report),
        ),
      ],
    );
  }
}

/// Una cifra del reporte: título, valor grande y, al comparar, la variación contra el año pasado.
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final double? variation;
  final bool showVariation;

  const _StatCard({
    required this.title,
    required this.value,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(icon, size: 20, color: _limeColor),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
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
