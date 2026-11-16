import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/account_statement_entity.dart';
import '../../domain/entities/sale_entity.dart' show ClientEntity;
import '../components/components.dart';
import '../providers/account_statement_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/download_file.dart';
import '../widgets/account_statement_widgets.dart';
import 'account_statement_pdf_page.dart';
import 'receipt_page.dart';

/// Módulo Estado de cuenta: se elige un cliente y un rango de fechas y se ve su cabecera (crédito
/// y deuda), los movimientos de ventas y pagos intercalados por fecha (por producto o agrupados
/// por venta), sus pedidos y sus pagos. Se puede exportar el Excel de cada pestaña y el PDF.
/// Permisos: `estado-de-cuenta.index`.
class AccountStatementPage extends StatefulWidget {
  const AccountStatementPage({super.key});

  @override
  State<AccountStatementPage> createState() => _AccountStatementPageState();
}

class _AccountStatementPageState extends State<AccountStatementPage> {
  static final _day = DateFormat(AppConstants.dateFormat);

  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickClient() async {
    final provider = context.read<AccountStatementProvider>();
    await showAppSearchSheet<ClientEntity>(
      context,
      title: 'Cliente',
      subtitle: 'Busca por nombre, documento o código',
      icon: Icons.person_search_outlined,
      hint: 'Nombre, DNI/RUC o código',
      search: provider.searchClients,
      itemOf: (c) => AppSearchItem(
        title: c.name,
        subtitle: [
          if (c.documento != null) c.documento!,
          if (c.tipo != null) (c.esPersona ? 'Persona' : 'Empresa'),
        ].join(' · '),
      ),
      onSelect: (c) {
        _searchController.clear();
        provider.selectClient(c);
        return null;
      },
    );
  }

  Future<void> _pickCustom() async {
    final provider = context.read<AccountStatementProvider>();
    final current = provider.dates;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
      helpText: 'Elegir fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) provider.selectCustom((start: picked.start, end: picked.end));
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) context.read<AccountStatementProvider>().setSearch(text);
    });
  }

  Future<void> _exportExcel() async {
    final result = await context.read<AccountStatementProvider>().exportExcel();
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await downloadFile(context, result.right);
  }

  Future<void> _exportPdf() async {
    final provider = context.read<AccountStatementProvider>();
    final navigator = Navigator.of(context);
    final name = provider.client?.name ?? '';
    final result = await provider.exportPdf();
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AccountStatementPdfPage(pdf: result.right, fileName: provider.pdfFileName, clientName: name),
      ),
    );
  }

  void _openReceipt(StatementRowEntity row) {
    final document = row.document;
    if (document == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptPage(document: document)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountStatementProvider>();
    final session = context.watch<AuthProvider>().session;

    const header = AppPageHeader(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Estado de cuenta',
      subtitle: 'Movimientos, pedidos y pagos de un cliente.',
      trailing: AppAccountMenu(),
    );

    if (session != null && !session.can('estado-de-cuenta.index')) {
      return const Column(
        children: [
          header,
          Expanded(
            child: AppEmptyState(
              icon: Icons.lock_outline,
              title: 'Sin acceso',
              message: 'No tienes permiso para ver el estado de cuenta.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        header,
        Expanded(
          child: Stack(
            children: [
              // Lo de arriba (cliente, fechas, cabecera, pestañas) no pasa de poco más de la mitad de la
              // pantalla: si no cabe (letra grande, cabecera abierta) se desliza, y la lista conserva su lugar.
              LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: box.maxHeight * 0.55),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _controls(provider),
                            if (provider.hasClient) StatementSummaryCard(summary: provider.summary, loading: provider.summaryLoading),
                            if (provider.hasClient) _tabs(provider),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: provider.hasClient ? _list(provider) : _noClient()),
                  ],
                ),
              ),
              if (provider.hasClient)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: AppSpeedDial(actions: _actions(provider)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<AppSpeedDialAction> _actions(AccountStatementProvider provider) {
    final busy = provider.exporting;
    return [
      AppSpeedDialAction(
        label: busy ? 'Exportando…' : 'Exportar Excel',
        icon: Icons.description_outlined,
        color: const Color(0xFF0D9488),
        onPressed: busy ? null : _exportExcel,
      ),
      AppSpeedDialAction(
        label: busy ? 'Exportando…' : 'Exportar PDF',
        icon: Icons.picture_as_pdf_outlined,
        color: const Color(0xFFA31238),
        onPressed: busy ? null : _exportPdf,
      ),
    ];
  }

  Widget _controls(AccountStatementProvider provider) {
    final client = provider.client;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AppPickerField(
            label: 'Cliente',
            value: client?.name ?? 'Lista de clientes',
            icon: Icons.person_search_outlined,
            onTap: _pickClient,
            onClear: client == null ? null : () {
              _searchController.clear();
              provider.selectClient(null);
            },
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            itemCount: StatementRange.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final range = StatementRange.values[i];
              final custom = range == StatementRange.personalizado;
              final selected = provider.range == range;
              final dates = provider.dates;
              return ChoiceChip(
                label: Text(
                  custom && selected ? '${_day.format(dates.start)} – ${_day.format(dates.end)}' : range.label,
                ),
                avatar: custom ? const Icon(Icons.date_range, size: 18) : null,
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => custom ? _pickCustom() : provider.selectRange(range),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _noClient() {
    return AppEmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Elige un cliente',
      message: 'Busca un cliente para ver su estado de cuenta.',
      action: AppButton(label: 'Elegir cliente', icon: Icons.person_search_outlined, onPressed: _pickClient),
    );
  }

  /// Las tres pestañas y, en la principal, el buscador de producto y el botón de agrupar.
  Widget _tabs(AccountStatementProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              for (final tab in StatementTab.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(tab.label)),
                      ),
                      selected: provider.tab == tab,
                      showCheckmark: false,
                      onSelected: (_) => provider.selectTab(tab),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              _groupButton(provider),
            ],
          ),
        ),
        if (provider.tab == StatementTab.estadoDeCuenta) _mainTools(provider),
      ],
    );
  }

  /// El botón de agrupar de la web, en la fila de las pestañas: verde para agrupar los pedidos por
  /// venta (una fila por venta) y naranja para volver a verlos por producto. Desde Pedidos o Pagos
  /// lleva a Estado de Cuenta ya agrupado.
  Widget _groupButton(AccountStatementProvider provider) {
    final grouped = provider.agrupado;
    return Tooltip(
      message: grouped ? 'Ver por producto' : 'Agrupar por venta',
      child: Semantics(
        button: true,
        label: grouped ? 'Ver por producto' : 'Agrupar por venta',
        child: Material(
          color: grouped ? const Color(0xFFF97316) : const Color(0xFF84CC16),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.selectionClick();
              if (provider.tab != StatementTab.estadoDeCuenta) {
                provider.selectTab(StatementTab.estadoDeCuenta);
                provider.setAgrupado(true);
              } else {
                provider.setAgrupado(!grouped);
              }
            },
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                grouped ? Icons.layers_clear_outlined : Icons.layers_outlined,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Buscador de producto (solo en la pestaña principal y en la vista por producto, porque la
  /// agrupada tiene una fila por venta, sin productos).
  Widget _mainTools(AccountStatementProvider provider) {
    if (provider.agrupado) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Una fila por venta',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    }
    return AppSearchBar(
      hint: 'Buscar por código o descripción',
      controller: _searchController,
      onChanged: _onSearchChanged,
    );
  }

  Widget _list(AccountStatementProvider provider) {
    final list = provider.current;
    final tab = provider.tab;
    if (list.loading && list.rows.isEmpty) return const AppSkeletonList();
    if (list.error != null && list.rows.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo cargar el estado de cuenta',
        message: list.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: provider.refresh),
      );
    }
    final searching = tab == StatementTab.estadoDeCuenta && !provider.agrupado && provider.search.isNotEmpty;
    return AppCardList<StatementRowEntity>(
      // Al cambiar de cliente, de fechas o de pestaña la lista se crea de cero.
      key: ValueKey('${tab.name}-${provider.client?.id}-${provider.range.name}-${provider.agrupado}-${provider.search}'),
      items: list.rows,
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: switch (tab) {
        StatementTab.estadoDeCuenta => 'Sin movimientos',
        StatementTab.pedidos => 'Sin pedidos',
        StatementTab.pagos => 'Sin pagos',
      },
      emptyMessage: searching ? 'Prueba con otra búsqueda.' : 'No hay registros en estas fechas.',
      onRefresh: provider.refresh,
      onLoadMore: provider.loadMore,
      loadingMore: list.loadingMore,
      bottomPadding: 96,
      itemBuilder: (context, row, _) => StatementRowCard(
        row: row,
        onOpenDocument: row.document == null ? null : () => _openReceipt(row),
      ),
    );
  }
}
