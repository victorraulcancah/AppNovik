import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/other_document_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/other_documents_provider.dart';
import '../widgets/other_document_modals.dart';
import '../pdf/other_document_pdf.dart';
import 'other_document_pdf_page.dart';
import 'receipt_page.dart';

/// Una de las otras listas de Documentos: traslados de stock, guías de remisión, notas de
/// crédito o entradas de stock. Búsqueda por número, rango de fechas ("Creado", por defecto hoy),
/// detalle y, según el documento, el PDF de su comprobante o eliminar el traslado.
class OtherDocumentsView extends StatefulWidget {
  final OtherDocumentKind kind;

  const OtherDocumentsView({super.key, required this.kind});

  @override
  State<OtherDocumentsView> createState() => _OtherDocumentsViewState();
}

class _OtherDocumentsViewState extends State<OtherDocumentsView> {
  Timer? _debounce;
  late final TextEditingController _search;

  OtherDocumentKind get _kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<OtherDocumentsProvider>().stateOf(_kind).search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OtherDocumentsProvider>().ensureLoaded(_kind);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool _can(String permission) => context.read<AuthProvider>().session?.can(permission) ?? false;

  /// El Jefe de Almacén ve los documentos pero no los importes, como en la web.
  bool get _showAmounts {
    final roles = context.read<AuthProvider>().session?.roles ?? const [];
    return !roles.any((r) => r.toLowerCase() == 'jefe de almacén');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) context.read<OtherDocumentsProvider>().setSearch(_kind, text);
    });
  }

  Future<void> _openFilters() async {
    final provider = context.read<OtherDocumentsProvider>();
    final result = await showOtherDocumentFilters(
      context,
      kind: _kind,
      current: provider.stateOf(_kind).filters,
      now: provider.now(),
    );
    if (result != null) await provider.applyFilters(_kind, result);
  }

  Future<void> _delete(OtherDocumentEntity d) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Eliminar documento',
      subtitle: d.numero,
      icon: Icons.delete_outline,
      message: '¿Está seguro de eliminar este documento? '
          'Este documento no será considerado en los reportes ni podrá ser restaurado.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;

    final result = await context.read<OtherDocumentsProvider>().deleteTransfer(d);
    if (!mounted) return;
    _snack(result.isLeft ? result.left.message : 'Transferencia eliminada');
  }

  void _openPdf(OtherDocumentEntity d) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OtherDocumentPdfPage(document: d, showAmounts: _showAmounts),
      ),
    );
  }

  void _openReceipt(OtherDocumentEntity d) {
    final receipt = d.comprobante;
    if (receipt == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptPage(document: receipt)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OtherDocumentsProvider>();
    final state = provider.stateOf(_kind);

    return Column(
      children: [
        AppSearchBar(
          hint: 'Buscar por número de documento',
          controller: _search,
          onChanged: _onSearchChanged,
          onFilter: _openFilters,
          filterActive: provider.filtersActive(_kind),
        ),
        if (state.total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${state.total} ${_kind.plural}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        Expanded(child: _body(provider, state)),
      ],
    );
  }

  Widget _body(OtherDocumentsProvider provider, OtherDocumentsState state) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los documentos',
        message: state.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: () => provider.refresh(_kind)),
      );
    }

    return AppCardList<OtherDocumentEntity>(
      items: state.items,
      emptyIcon: Icons.description_outlined,
      emptyTitle: 'No hay documentos',
      emptyMessage: state.search.isNotEmpty
          ? 'Revisa el número o prueba con otro.'
          : 'Prueba con otro rango de fechas en los filtros.',
      onRefresh: () => provider.refresh(_kind),
      onLoadMore: () => provider.loadMore(_kind),
      loadingMore: state.loadingMore,
      itemBuilder: (context, d, number) => _card(context, d, number),
    );
  }

  Widget _card(BuildContext context, OtherDocumentEntity d, int number) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final success = dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    final warning = dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final danger = dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    final created = d.creado == null ? '' : DateFormat(AppConstants.dateTimeFormat).format(d.creado!);
    final amounts = _showAmounts;

    final lines = <String>[];
    String? trailingTitle, trailingCaption;
    Color? trailingColor;

    switch (d.kind) {
      case OtherDocumentKind.traslado:
        lines.addAll([
          d.usuario ?? '',
          '${d.desde ?? '-'} → ${d.hacia ?? '-'}',
          created,
        ]);
        trailingCaption = !d.activo ? 'Eliminado' : (d.pendienteRecepcion ? 'Falta recibir' : 'Recibido');
        trailingColor = !d.activo ? danger : (d.pendienteRecepcion ? warning : success);
      case OtherDocumentKind.guia:
        lines.addAll([
          if (d.comprobanteNumero != null) 'Comprobante ${d.comprobanteNumero}',
          d.guia?.direccionLlegada ?? '',
          created,
        ]);
        trailingTitle = '${formatQuantity(d.guia?.pesoTotal ?? 0)} KG.';
      case OtherDocumentKind.notaCredito:
        lines.addAll([
          if (d.comprobanteNumero != null) 'Comprobante ${d.comprobanteNumero}',
          d.nota?.descripcion ?? '',
          created,
        ]);
      case OtherDocumentKind.entradaStock:
        lines.addAll([d.usuario ?? '', d.almacen ?? '', created]);
        if (amounts) trailingTitle = formatMoney(d.monto, symbol: 'S/.');
    }

    return AppListCard(
      number: number,
      title: d.numero,
      lines: lines.where((l) => l.isNotEmpty).toList(),
      trailingTitle: trailingTitle,
      trailingCaption: trailingCaption,
      trailingCaptionColor: trailingColor,
      onTap: () => showOtherDocumentDetail(context, d, showAmounts: amounts),
      actions: [
        AppActionButton(
          type: AppActionType.view,
          onPressed: () => showOtherDocumentDetail(context, d, showAmounts: amounts),
        ),
        if (d.comprobante != null)
          AppActionButton(
            type: AppActionType.pdf,
            label: 'Ver comprobante PDF',
            onPressed: () => _openReceipt(d),
          ),
        if (hasOtherDocumentPdf(d.kind))
          AppActionButton(type: AppActionType.pdf, label: 'Ver PDF', onPressed: () => _openPdf(d)),
        if (d.sePuedeEliminar && _can('transferir-stock.destroy'))
          AppActionButton(type: AppActionType.delete, onPressed: () => _delete(d)),
      ],
    );
  }
}
