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
import '../widgets/document_modals.dart';

/// Módulo Documentos: ventas y cotizaciones de la empresa (solo lectura), con
/// búsqueda por número, filtros y detalle. Las demás listas de la web (traslados,
/// guías, notas de crédito, entradas de stock) aún no están.
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

  Future<void> _openFilters() async {
    final documents = context.read<DocumentsProvider>();
    final isQuote = documents.kind == DocumentKind.cotizacion;

    final result = await showAppFilterSheet(
      context,
      fields: [
        AppFilterField(
          id: 'fecha',
          label: 'Fecha',
          allLabel: DocumentDateRange.hoy.label,
          value: documents.range == DocumentDateRange.hoy ? null : documents.range.name,
          options: [
            for (final r in DocumentDateRange.values.skip(1))
              AppFilterOption(r.name, r.label),
          ],
        ),
        if (!isQuote) ...[
          AppFilterField(
            id: 'tipo',
            label: 'Comprobante',
            allLabel: 'Todos',
            value: documents.tipo?.name,
            options: const [
              AppFilterOption('boleta', 'Boleta'),
              AppFilterOption('factura', 'Factura'),
              AppFilterOption('notaVenta', 'Nota de venta'),
            ],
          ),
          AppFilterField(
            id: 'estado',
            label: 'Estado',
            allLabel: 'Todos',
            value: documents.estado?.name,
            options: const [
              AppFilterOption('activos', 'Activos'),
              AppFilterOption('eliminados', 'Eliminados'),
            ],
          ),
        ],
        if (isQuote)
          AppFilterField(
            id: 'pendientes',
            label: 'Cotizaciones',
            allLabel: 'Todas',
            value: documents.soloPendientes ? 'pendientes' : null,
            options: const [AppFilterOption('pendientes', 'Pendientes (sin procesar)')],
          ),
      ],
    );
    if (result == null) return;

    T? byName<T extends Enum>(List<T> values, String? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    documents.applyFilters(
      range: byName(DocumentDateRange.values, result['fecha']) ?? DocumentDateRange.hoy,
      tipo: byName(DocumentTipo.values, result['tipo']),
      estado: byName(DocumentEstado.values, result['estado']),
      soloPendientes: result['pendientes'] != null,
    );
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
          onFilter: _openFilters,
          filterActive: documents.filtersActive,
        ),
        if (documents.total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${documents.total} ${documents.kind == DocumentKind.venta ? 'ventas' : 'cotizaciones'}'
                '${documents.search.isEmpty ? ' · ${documents.range.label.toLowerCase()}' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        Expanded(child: _body(documents, kinds)),
      ],
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
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final status = documentStatus(d);
    final statusColor = switch (status.tone) {
      AppBadgeTone.success => dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      AppBadgeTone.danger => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      AppBadgeTone.warning => dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      AppBadgeTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };

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
      ],
    );
  }
}
