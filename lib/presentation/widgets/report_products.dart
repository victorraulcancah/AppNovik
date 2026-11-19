import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/entities/report_ranking_entity.dart';
import '../components/components.dart';
import '../providers/reports_provider.dart';
import 'report_rankings.dart';

String _soles(double v) => formatMoney(v, symbol: 'S/.');

/// La tarjeta de un producto vendido, la misma en "Productos y servicios" y en los productos de cada
/// entidad (departamento, vendedor, marca, categoría, cliente): código · marca, subtotal, descuento y
/// margen (con su % de la venta, oculto hasta tocar el ojo), la venta, la cantidad y el botón de documentos.
/// [subtotal] y [descuento] van en `null` cuando el reporte no los trae.
class ReportProductCard extends StatelessWidget {
  final String title;
  final String detail;
  final double venta;
  final double cantidad;
  final double margen;
  final double? subtotal;
  final double? descuento;

  /// `false` cuando el rol no ve importes: solo las unidades.
  final bool showAmounts;
  final bool showMargin;
  final bool marginVisible;
  final VoidCallback onTap;

  /// Lo que representa del total del reporte (en %): de la venta, o de las unidades si no hay importes.
  final double? share;

  const ReportProductCard({
    super.key,
    required this.title,
    required this.detail,
    required this.venta,
    required this.cantidad,
    required this.margen,
    this.subtotal,
    this.descuento,
    required this.showAmounts,
    required this.showMargin,
    required this.marginVisible,
    required this.onTap,
    this.share,
  });

  /// Bajo el monto solo va el % del total; la cantidad está con los datos de la izquierda.
  String? _caption() => share == null ? null : rankingPercent(share!);

  @override
  Widget build(BuildContext context) {
    final margin = marginVisible
        ? '${_soles(margen)}${venta > 0 ? ' (${rankingPercent(margen / venta * 100)})' : ''}'
        : 'S/. *******';
    return AppListCard(
      title: title,
      lines: [
        if (detail.isNotEmpty) detail,
        // La cantidad va a la izquierda, con los demás datos (antes estaba bajo el monto).
        if (showAmounts) 'Cant. ${formatQuantity(cantidad)}',
        if (showAmounts && subtotal != null) 'Subtotal ${_soles(subtotal!)}',
        if (showAmounts && descuento != null) 'Desc. ${_soles(descuento!)}',
        if (showAmounts) 'Venta total ${_soles(venta)}',
        // El margen con su porcentaje de la venta (la ganancia).
        if (showAmounts && showMargin) 'Margen $margin',
      ],
      trailingTitle: showAmounts ? _soles(venta) : '${formatQuantity(cantidad)} uds.',
      trailingCaption: _caption(),
      onTap: onTap,
      actions: [
        AppActionButton(type: AppActionType.view, label: 'Ver documentos', onPressed: onTap),
      ],
    );
  }
}

/// El modal "Documentos": las ventas en que se vendió un producto; tocar una abre su comprobante
/// ([onOpen]). Con [docs] se muestran de una vez (Productos y servicios); con [load] se piden al
/// abrir, con su carga, su error y "Reintentar" (los productos de una entidad).
Future<void> showReportDocuments(
  BuildContext context, {
  required String productName,
  List<SalesReportDocumentEntity>? docs,
  Future<Either<Failure, List<SalesReportDocumentEntity>>> Function()? load,
  required Future<void> Function(SalesReportDocumentEntity doc) onOpen,
}) {
  assert(docs != null || load != null, 'Pasa docs o load');
  return showAppModal(
    context,
    title: 'Documentos',
    subtitle: productName,
    icon: Icons.description_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: _DocumentsBody(docs: docs, load: load, onOpen: onOpen),
  );
}

class _DocumentsBody extends StatefulWidget {
  final List<SalesReportDocumentEntity>? docs;
  final Future<Either<Failure, List<SalesReportDocumentEntity>>> Function()? load;
  final Future<void> Function(SalesReportDocumentEntity doc) onOpen;

  const _DocumentsBody({required this.docs, required this.load, required this.onOpen});

  @override
  State<_DocumentsBody> createState() => _DocumentsBodyState();
}

class _DocumentsBodyState extends State<_DocumentsBody> {
  List<SalesReportDocumentEntity>? _docs;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _docs = widget.docs;
    if (_docs == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.load!();
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((failure) => _error = failure.message, (list) => _docs = list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ],
        ),
      );
    }
    final docs = _docs ?? const [];
    if (docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No hay documentos')),
      );
    }
    return Column(
      children: [
        for (final d in docs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${d.tipo} Nro: ${d.numero}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onOpen(d),
          ),
      ],
    );
  }
}

/// El modal "Productos vendidos" de una fila de un reporte por entidad: sus productos con las mismas
/// tarjetas de Productos y servicios, buscador por código o nombre y scroll infinito; tocar uno abre
/// sus documentos ([onOpenSale] abre el comprobante).
Future<void> showEntityProducts(
  BuildContext context, {
  required ReportKind kind,
  required RankingRow row,
  required Future<void> Function(SalesReportDocumentEntity doc) onOpenSale,
}) async {
  final reports = context.read<ReportsProvider>();
  unawaited(reports.openEntityProducts(kind, row));
  await showAppModal(
    context,
    title: 'Productos vendidos',
    subtitle: kind == ReportKind.vendedores ? 'Ejecutivo comercial: ${row.name}' : row.name,
    icon: Icons.inventory_2_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    fixedHeight: true,
    child: _EntityProductsBody(onOpenSale: onOpenSale),
  );
  reports.closeEntityProducts();
}

class _EntityProductsBody extends StatefulWidget {
  final Future<void> Function(SalesReportDocumentEntity doc) onOpenSale;

  const _EntityProductsBody({required this.onOpenSale});

  @override
  State<_EntityProductsBody> createState() => _EntityProductsBodyState();
}

class _EntityProductsBodyState extends State<_EntityProductsBody> {
  final _search = TextEditingController();
  String _query = '';

  /// El margen empieza oculto, como en el resto de Reportes.
  bool _marginVisible = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El scroll es el del modal: al acercarse al final se pide la página siguiente.
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_onScroll);
      _position = position?..addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _position;
    if (position != null && position.extentAfter < 400) context.read<ReportsProvider>().loadMoreEntityProducts();
  }

  /// Si la primera página no llena la ventana, se pide la siguiente sin esperar a que se deslice.
  void _fillScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = _position;
      if (position != null && position.hasContentDimensions && position.extentAfter < 400) _onScroll();
    });
  }

  /// Busca en toda la lista (como en Productos y servicios): el servidor pagina, así que al buscar se
  /// piden las páginas que faltan para no dejar fuera ningún producto.
  Future<void> _onSearch(String text) async {
    final reports = context.read<ReportsProvider>();
    setState(() => _query = text.trim());
    while (mounted && _query.isNotEmpty) {
      final state = reports.entityProducts;
      if (state == null || !state.hasMore || state.loading) break;
      if (state.loadingMore) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        continue;
      }
      final before = state.products.length;
      await reports.loadMoreEntityProducts();
      if (state.products.length <= before) break;
    }
  }

  Future<void> _showDocuments(ReportsProvider reports, RankingProduct product) => showReportDocuments(
        context,
        productName: product.name,
        load: () => reports.loadEntityProductDocuments(product),
        onOpen: widget.onOpenSale,
      );

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    final state = reports.entityProducts;
    final scheme = Theme.of(context).colorScheme;
    final importes = !reports.ocultarImportes;
    final showMargin = importes && !reports.ocultarMargen;

    if (state == null || state.loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator()));
    }
    if (state.error != null) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo cargar los productos',
        message: state.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: reports.retryEntityProducts),
      );
    }

    final q = _query.toLowerCase();
    final shown = q.isEmpty
        ? state.products
        : [
            for (final p in state.products)
              if (p.codigo.toLowerCase().contains(q) || p.name.toLowerCase().contains(q)) p,
          ];
    _fillScreen();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // El buscador de la web ("Buscar producto"): por código o nombre.
        AppSearchBar(
          hint: 'Buscar por código o nombre',
          controller: _search,
          onChanged: _onSearch,
          actions: [
            if (showMargin)
              IconButton(
                tooltip: _marginVisible ? 'Ocultar el margen' : 'Ver el margen',
                icon: Icon(
                  _marginVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: scheme.primary,
                ),
                onPressed: () => setState(() => _marginVisible = !_marginVisible),
              ),
          ],
        ),
        if (state.loadingMore && _query.isNotEmpty) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          state.products.isEmpty
              ? const AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No hay productos',
                  message: 'No se vendieron productos en el rango.',
                )
              : const AppEmptyState(
                  icon: Icons.search_off,
                  title: 'Sin resultados',
                  message: 'Ninguno coincide con la búsqueda.',
                )
        else
          for (final p in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ReportProductCard(
                title: p.name,
                detail: p.codigo,
                venta: p.venta,
                cantidad: p.cantidad,
                margen: p.margen,
                showAmounts: importes,
                showMargin: showMargin,
                marginVisible: _marginVisible,
                onTap: () => _showDocuments(reports, p),
              ),
            ),
        if (state.loadingMore)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}
