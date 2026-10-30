import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/document_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/documents_provider.dart';
import '../utils/share_file.dart';
import '../widgets/document_filters.dart';
import '../widgets/document_modals.dart';
import 'receipt_page.dart';

/// Módulo Documentos: ventas y cotizaciones de la empresa, con búsqueda por número,
/// filtros avanzados, totales, descarga en Excel y, en cada documento, ver el detalle,
/// el comprobante en PDF y eliminar o anular con nota de crédito. Las demás listas de la
/// web (traslados, guías de remisión, notas de crédito, entradas de stock) aún no están.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  /// Arranca en la primera lista a la que el usuario tiene acceso.
  void _start() {
    final documents = context.read<DocumentsProvider>();
    final kinds = _kinds();
    if (kinds.isNotEmpty && !kinds.contains(documents.kind)) {
      documents.selectKind(kinds.first);
    } else {
      documents.ensureLoaded();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool _can(String permission) =>
      context.read<AuthProvider>().session?.can(permission) ?? false;

  /// Listas permitidas, con los mismos permisos que la web.
  List<DocumentKind> _kinds() => [
        if (_can('documentos.ventas.index')) DocumentKind.venta,
        if (_can('documentos.cotizaciones.index')) DocumentKind.cotizacion,
      ];

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) context.read<DocumentsProvider>().setSearch(text);
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    final result = await context.read<DocumentsProvider>().exportCurrent();
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await shareDownloadedFile(result.right);
  }

  void _openReceipt(DocumentEntity d) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptPage(document: d)));
  }

  Future<void> _delete(DocumentEntity d) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Eliminar documento',
      subtitle: d.numero,
      icon: Icons.delete_outline,
      message: '¿Está seguro de eliminar este documento? '
          'No será considerado en los reportes ni podrá ser restaurado.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;

    final result = await context.read<DocumentsProvider>().deleteDocument(d);
    if (!mounted) return;
    _snack(result.isLeft
        ? result.left.message
        : (d.esCotizacion ? 'Cotización eliminada' : 'Venta eliminada'));
  }

  Future<void> _creditNote(DocumentEntity d) async {
    final done = await showCreditNoteForm(context, d);
    if (done == true && mounted) _snack('Nota de crédito creada con éxito');
  }

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentsProvider>();
    final kinds = _kinds();

    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.description_outlined,
          title: 'Documentos',
          subtitle: 'Ventas y cotizaciones de tu empresa.',
          trailing: AppAccountMenu(),
        ),
        if (kinds.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<DocumentKind>(
                showSelectedIcon: false,
                selected: {documents.kind},
                onSelectionChanged: (s) => documents.selectKind(s.first),
                segments: [
                  for (final k in kinds)
                    ButtonSegment(
                      value: k,
                      label: Text(k == DocumentKind.venta ? 'Ventas' : 'Cotizaciones'),
                    ),
                ],
              ),
            ),
          ),
        AppSearchBar(
          hint: 'Buscar por número de documento',
          onChanged: _onSearchChanged,
          onFilter: () => showDocumentFilters(context),
          filterActive: documents.filtersActive,
          actions: [
            if (kinds.isNotEmpty)
              IconButton(
                tooltip: 'Descargar Excel',
                onPressed: documents.exporting ? null : _export,
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: documents.exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
              ),
          ],
        ),
        if (kinds.isNotEmpty && documents.search.isEmpty) _tagsRow(documents),
        if (kinds.isNotEmpty) _summary(documents),
        Expanded(child: _body(documents, kinds)),
      ],
    );
  }

  /// Las etiquetas de los filtros puestos: cada una se quita con su ✕, y "Restablecer"
  /// vuelve a como se entra (los documentos de hoy).
  Widget _tagsRow(DocumentsProvider documents) {
    final tags = documentFilterTags(
      kind: documents.kind,
      filters: documents.filters,
      catalogs: documents.catalogs,
      now: documents.now,
    );
    final canReset = tags.any((t) => t.remove != null);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(tag.text),
                visualDensity: VisualDensity.compact,
                onDeleted: tag.remove == null
                    ? null
                    : () => documents.applyFilters(tag.remove!(documents.filters)),
              ),
            ),
          if (canReset)
            TextButton.icon(
              onPressed: documents.resetFilters,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Restablecer'),
            ),
        ],
      ),
    );
  }

  /// Cuántos documentos hay y la suma de todo lo filtrado (no solo lo cargado), cada moneda
  /// por separado; los eliminados no cuentan.
  Widget _summary(DocumentsProvider documents) {
    if (documents.total == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final label = documents.kind == DocumentKind.venta ? 'ventas' : 'cotizaciones';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 14,
          runSpacing: 2,
          children: [
            Text('${documents.total} $label', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Total Soles: ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: formatMoney(documents.totalSoles, symbol: 'S/.')),
              ]),
              style: theme.textTheme.bodySmall,
            ),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Total Dólares: ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: formatMoney(documents.totalDolares, symbol: r'$')),
              ]),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(DocumentsProvider documents, List<DocumentKind> kinds) {
    if (kinds.isEmpty) {
      return const AppEmptyState(
        icon: Icons.lock_outline,
        title: 'Sin acceso',
        message: 'No tienes permiso para ver ventas ni cotizaciones.',
      );
    }
    if (documents.loading && documents.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (documents.error != null && documents.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los documentos',
        message: documents.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: documents.refresh),
      );
    }

    return AppCardList<DocumentEntity>(
      items: documents.items,
      emptyIcon: Icons.description_outlined,
      emptyTitle: 'No hay documentos',
      emptyMessage: documents.search.isNotEmpty
          ? 'Revisa el número o prueba con otro.'
          : 'Prueba con otro rango de fechas en los filtros.',
      onRefresh: documents.refresh,
      onLoadMore: documents.loadMore,
      loadingMore: documents.loadingMore,
      itemBuilder: (context, d, number) => _card(context, d, number),
    );
  }

  Widget _card(BuildContext context, DocumentEntity d, int number) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = documentStatus(d);
    final statusColor = switch (status.tone) {
      AppBadgeTone.success => dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      AppBadgeTone.danger => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      AppBadgeTone.warning => dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      AppBadgeTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };

    final deletePermission = d.esCotizacion
        ? 'documentos.cotizaciones.destroy'
        : 'documentos.ventas.destroy';

    return AppListCard(
      number: number,
      title: d.numero,
      lines: [
        d.cliente,
        '${d.vendedor} · ${d.almacen}',
        d.creado == null ? '' : DateFormat(AppConstants.dateTimeFormat).format(d.creado!),
      ].where((l) => l.isNotEmpty).toList(),
      trailingTitle: formatMoney(d.monto, symbol: d.simboloMoneda),
      trailingCaption: status.label,
      trailingCaptionColor: statusColor,
      onTap: () => showDocumentDetail(context, d),
      actions: [
        AppActionButton(type: AppActionType.view, onPressed: () => showDocumentDetail(context, d)),
        AppActionButton(
          type: AppActionType.pdf,
          label: 'Ver comprobante PDF',
          onPressed: () => _openReceipt(d),
        ),
        if (d.sePuedeEliminar && _can(deletePermission))
          AppActionButton(type: AppActionType.delete, onPressed: () => _delete(d)),
        if (d.sePuedeAnularConNotaCredito && _can('documentos.ventas.destroy'))
          AppActionButton(
            type: AppActionType.annul,
            label: 'Anular con nota de crédito',
            onPressed: () => _creditNote(d),
          ),
      ],
    );
  }
}
