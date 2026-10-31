import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/other_document_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/documents_provider.dart';
import '../utils/download_file.dart';
import '../widgets/document_filters.dart';
import '../widgets/document_modals.dart';
import 'other_documents_view.dart';
import 'receipt_page.dart';

/// Módulo Documentos, con las mismas listas que la web según los permisos del usuario: ventas,
/// cotizaciones, traslados de stock, guías de remisión, notas de crédito y entradas de stock.
/// Ventas y cotizaciones tienen búsqueda por número, filtros avanzados, totales, descarga en
/// Excel y, en cada documento, el detalle, el comprobante en PDF y eliminar o anular con nota de
/// crédito. Las demás listas tienen búsqueda por número, rango de fechas y el detalle.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  Timer? _debounce;

  /// La lista elegida: `venta`, `cotizacion` o el nombre de una [OtherDocumentKind].
  String? _selected;

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
    final options = _options();
    if (options.isEmpty) return;
    final first = options.first.id;
    setState(() => _selected = first);

    final kind = _documentKindOf(first);
    if (kind == null) return; // la lista de otros documentos se carga sola
    if (kind != documents.kind) {
      documents.selectKind(kind);
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

  /// Listas permitidas, con los mismos permisos y el mismo orden que la web.
  List<({String id, String label})> _options() => [
    if (_can('documentos.ventas.index')) (id: 'venta', label: 'Ventas'),
    if (_can('documentos.cotizaciones.index'))
      (id: 'cotizacion', label: 'Cotizaciones'),
    for (final k in OtherDocumentKind.values)
      if (_can(k.permission)) (id: k.name, label: k.label),
  ];

  DocumentKind? _documentKindOf(String? id) => switch (id) {
    'venta' => DocumentKind.venta,
    'cotizacion' => DocumentKind.cotizacion,
    _ => null,
  };

  OtherDocumentKind? _otherKindOf(String? id) {
    for (final k in OtherDocumentKind.values) {
      if (k.name == id) return k;
    }
    return null;
  }

  void _select(String id) {
    setState(() => _selected = id);
    final kind = _documentKindOf(id);
    if (kind != null) context.read<DocumentsProvider>().selectKind(kind);
  }

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
    await downloadFile(context, result.right);
  }

  void _openReceipt(DocumentEntity d) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ReceiptPage(document: d)));
  }

  Future<void> _delete(DocumentEntity d) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Eliminar documento',
      subtitle: d.numero,
      icon: Icons.delete_outline,
      message:
          '¿Está seguro de eliminar este documento? '
          'No será considerado en los reportes ni podrá ser restaurado.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;

    final result = await context.read<DocumentsProvider>().deleteDocument(d);
    if (!mounted) return;
    _snack(
      result.isLeft
          ? result.left.message
          : (d.esCotizacion ? 'Cotización eliminada' : 'Venta eliminada'),
    );
  }

  Future<void> _creditNote(DocumentEntity d) async {
    final done = await showCreditNoteForm(context, d);
    if (done == true && mounted) _snack('Nota de crédito creada con éxito');
  }

  /// Las acciones del botón flotante: descargar el Excel de lo que se ve y ver los totales.
  List<AppSpeedDialAction> _actions(DocumentsProvider documents) => [
    AppSpeedDialAction(
      label: 'Descargar Excel',
      icon: Icons.download_outlined,
      color: const Color(0xFF0D9488),
      onPressed: documents.exporting ? () {} : _export,
    ),
    AppSpeedDialAction(
      label: 'Totales',
      icon: Icons.functions,
      color: const Color(0xFF0E90C7),
      onPressed: () => showDocumentTotals(
        context,
        kind: documents.kind,
        filters: documents.filters,
        total: documents.total,
        totalSoles: documents.totalSoles,
        totalDolares: documents.totalDolares,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentsProvider>();
    final options = _options();
    final selected = options.any((o) => o.id == _selected)
        ? _selected
        : (options.isEmpty ? null : options.first.id);
    final otherKind = _otherKindOf(selected);

    return Stack(
      children: [
        Column(
          children: [
            const AppPageHeader(
              icon: Icons.description_outlined,
              title: 'Documentos',
              subtitle:
                  'Ventas, cotizaciones y demás documentos de tu empresa.',
              trailing: AppAccountMenu(),
            ),
            // Como en la web: un selector con todas las listas a las que se tiene acceso.
            if (options.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AppDropdownField<String>(
                  key: ValueKey('lista-$selected'),
                  label: 'Documentos',
                  value: selected,
                  items: [
                    for (final o in options)
                      DropdownMenuItem(value: o.id, child: Text(o.label)),
                  ],
                  onChanged: (id) {
                    if (id != null) _select(id);
                  },
                ),
              ),
            if (otherKind != null)
              Expanded(
                child: OtherDocumentsView(
                  key: ValueKey(otherKind),
                  kind: otherKind,
                ),
              )
            else ...[
              AppSearchBar(
                hint: 'Buscar por número de documento',
                onChanged: _onSearchChanged,
                onFilter: () => showDocumentFilters(context),
                filterActive: documents.filtersActive,
              ),
              if (documents.total > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${documents.total} ${documents.kind == DocumentKind.venta ? 'ventas' : 'cotizaciones'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Expanded(child: _body(documents, options.isEmpty)),
            ],
          ],
        ),
        // Botón "Acciones": abajo a la derecha, sobre la lista, como en Productos.
        if (otherKind == null && options.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: AppSpeedDial(actions: _actions(documents)),
          ),
      ],
    );
  }

  Widget _body(DocumentsProvider documents, bool noAccess) {
    if (noAccess) {
      return const AppEmptyState(
        icon: Icons.lock_outline,
        title: 'Sin acceso',
        message: 'No tienes permiso para ver documentos.',
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
        action: AppButton(
          label: 'Reintentar',
          icon: Icons.refresh,
          onPressed: documents.refresh,
        ),
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
      bottomPadding: 96,
      itemBuilder: (context, d, number) => _card(context, d, number),
    );
  }

  Widget _card(BuildContext context, DocumentEntity d, int number) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = documentStatus(d);
    final statusColor = switch (status.tone) {
      AppBadgeTone.success =>
        dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      AppBadgeTone.danger =>
        dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      AppBadgeTone.warning =>
        dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
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
        d.creado == null
            ? ''
            : DateFormat(AppConstants.dateTimeFormat).format(d.creado!),
      ].where((l) => l.isNotEmpty).toList(),
      trailingTitle: formatMoney(d.monto, symbol: d.simboloMoneda),
      trailingCaption: status.label,
      trailingCaptionColor: statusColor,
      onTap: () => showDocumentDetail(context, d),
      actions: [
        AppActionButton(
          type: AppActionType.view,
          onPressed: () => showDocumentDetail(context, d),
        ),
        AppActionButton(
          type: AppActionType.pdf,
          label: 'Ver comprobante PDF',
          onPressed: () => _openReceipt(d),
        ),
        if (d.sePuedeEliminar && _can(deletePermission))
          AppActionButton(
            type: AppActionType.delete,
            onPressed: () => _delete(d),
          ),
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
