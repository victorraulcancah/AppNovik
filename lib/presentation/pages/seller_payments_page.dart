import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/seller_payment_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/seller_payments_provider.dart';
import '../utils/download_file.dart';
import '../utils/success_snack.dart';
import '../widgets/seller_payment_filters.dart';
import '../widgets/seller_payment_modals.dart';

/// Módulo Pagos vendedores ("Registro de Pagos" de la web): los pagos que los ejecutivos registran de
/// sus clientes, con búsqueda por términos, filtros avanzados (fechas, cliente, ejecutivo, monto,
/// método de pago y estado), totales en soles y dólares y Excel. Permite realizar un pago de cuota y, en
/// cada pago, aprobarlo, editarlo o eliminarlo, con los mismos permisos que la web
/// (`pagos-vendedores.*`).
class SellerPaymentsPage extends StatefulWidget {
  const SellerPaymentsPage({super.key});

  @override
  State<SellerPaymentsPage> createState() => _SellerPaymentsPageState();
}

class _SellerPaymentsPageState extends State<SellerPaymentsPage> {
  Timer? _debounce;
  final _searchController = TextEditingController();

  /// Panel de detalle (tablet).
  final _pane = AppPaneController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final payments = context.read<SellerPaymentsProvider>();
      if (payments.canIndex) payments.ensureLoaded();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _pane.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<SellerPaymentsProvider>().setSearch(text);
    });
  }

  /// "Buscar" en el teclado: lo escrito pasa a ser un chip y el campo queda libre para otro término,
  /// como en la web.
  void _onSearchSubmitted(String text) {
    _debounce?.cancel();
    _searchController.clear();
    context.read<SellerPaymentsProvider>().addSearchTerm(text);
  }

  void _reset() {
    _debounce?.cancel();
    _searchController.clear();
    context.read<SellerPaymentsProvider>().resetFilters();
  }

  Future<void> _export() async {
    final result = await context.read<SellerPaymentsProvider>().exportAll();
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await downloadFile(context, result.right);
  }

  Future<void> _create() async {
    final done = await showSellerPaymentCreate(context);
    if (done == true && mounted) showSuccessSnack(context, 'Depósito aplicado a la deuda');
  }

  Future<void> _edit(SellerPaymentEntity p) async {
    final done = await showSellerPaymentEdit(context, p);
    if (done == true && mounted) showSuccessSnack(context, 'Pago editado');
  }

  Future<void> _approve(SellerPaymentEntity p) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Confirmar pago',
      subtitle: p.cliente,
      icon: Icons.check_circle_outline,
      message: '¿Estás seguro de confirmar el pago?',
      confirmLabel: 'Confirmar',
      tone: AppModalTone.normal,
    );
    if (!confirmed || !mounted) return;
    final result = await context.read<SellerPaymentsProvider>().approvePayment(p);
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    showSuccessSnack(context, 'Pago confirmado');
  }

  Future<void> _delete(SellerPaymentEntity p) async {
    final approved = p.status == SellerPaymentStatus.aprobado;
    final confirmed = await showAppConfirm(
      context,
      title: 'Eliminar pago',
      subtitle: p.cliente,
      icon: Icons.delete_outline,
      message: approved
          ? '¿Está seguro de eliminar este Pago Confirmado? (Se mantendrá visible pero marcado como eliminado)'
          : '¿Está seguro de eliminar este Pago?',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    final result = await context.read<SellerPaymentsProvider>().deletePayment(p);
    if (!mounted) return;
    if (result.isRight && _pane.selectedId == p.id) _pane.close();
    if (result.isLeft) return _snack(result.left.message);
    showSuccessSnack(context, 'Pago eliminado');
  }

  Future<void> _showDetail(SellerPaymentEntity p) => showSellerPaymentDetail(
        context,
        p,
        showExecutive: context.read<SellerPaymentsProvider>().canSeeOthers,
        pane: _pane,
      );

  /// "Total Soles" y "Total Dólares" de la cabecera de la web, en el modal de totales: son los del
  /// servidor para la búsqueda y los filtros puestos, y los pagos cancelados no cuentan.
  void _showTotals(SellerPaymentsProvider payments) {
    showAppSummary(
      context,
      title: 'Totales',
      subtitle: 'Pagos vendedores',
      metrics: [
        AppSummaryMetric(label: 'Periodo', value: sellerPaymentRange(payments.filters)),
        AppSummaryMetric(label: 'Pagos', value: '${payments.total}'),
        AppSummaryMetric(
          label: 'Total Soles',
          value: sellerPaymentMoney(payments.totalSoles, 'soles'),
          color: const Color(0xFF16A34A),
        ),
        AppSummaryMetric(
          label: 'Total Dólares',
          value: sellerPaymentMoney(payments.totalDolares, 'dolares'),
          color: const Color(0xFFD97706),
        ),
      ],
      note: 'Según la búsqueda y los filtros que están puestos. Los pagos cancelados no cuentan.',
    );
  }

  List<AppSpeedDialAction> _actions(SellerPaymentsProvider payments) => [
        if (payments.canStore)
          AppSpeedDialAction(
            label: 'Realizar pago',
            icon: Icons.add_card_outlined,
            color: const Color(0xFF16A34A),
            onPressed: _create,
          ),
        AppSpeedDialAction(
          label: 'Totales',
          icon: Icons.functions,
          color: const Color(0xFF0E90C7),
          onPressed: () => _showTotals(payments),
        ),
        AppSpeedDialAction(
          label: payments.exporting ? 'Exportando…' : 'Exportar Excel',
          icon: Icons.description_outlined,
          color: const Color(0xFF0D9488),
          onPressed: payments.exporting ? null : _export,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final payments = context.watch<SellerPaymentsProvider>();
    final session = context.watch<AuthProvider>().session;

    if (session != null && !payments.canIndex) {
      return Column(
        children: const [
          AppPageHeader(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Pagos vendedores',
            trailing: AppAccountMenu(),
          ),
          Expanded(
            child: AppEmptyState(
              icon: Icons.lock_outline,
              title: 'Sin acceso',
              message: 'No tienes permiso para ver los pagos de los vendedores.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Pagos vendedores',
          subtitle: 'Registro de pagos de tus clientes.',
          trailing: AppAccountMenu(),
        ),
        Expanded(
          // En tablet, la lista a la izquierda y el detalle del pago a la derecha.
          child: AppMasterDetail(
            controller: _pane,
            emptyIcon: Icons.account_balance_wallet_outlined,
            emptyTitle: 'Selecciona un pago',
            emptyMessage: 'Toca un pago para ver su detalle.',
            listBuilder: (context) => _listPane(payments),
          ),
        ),
      ],
    );
  }

  Widget _listPane(SellerPaymentsProvider payments) {
    final filters = sellerPaymentActiveFilters(payments);
    return Stack(
      children: [
        Column(
          children: [
            AppSearchBar(
              hint: 'Buscar',
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
              onFilter: () => showSellerPaymentFilters(context),
              filterCount: filters.length,
            ),
            AppSearchChips(
              terms: payments.searchTerms,
              onRemove: payments.removeSearchTerm,
              onClear: payments.clearSearchTerms,
            ),
            AppActiveFilters(filters: filters, onClear: _reset),
            if (payments.total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${payments.total} ${payments.total == 1 ? 'pago' : 'pagos'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            Expanded(child: _body(payments)),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: AppSpeedDial(actions: _actions(payments)),
        ),
      ],
    );
  }

  Widget _body(SellerPaymentsProvider payments) {
    if (payments.loading && payments.items.isEmpty) {
      return const AppSkeletonList();
    }
    if (payments.error != null && payments.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los pagos',
        message: payments.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: payments.refresh),
      );
    }

    return AppCardList<SellerPaymentEntity>(
      items: payments.items,
      emptyIcon: Icons.account_balance_wallet_outlined,
      emptyTitle: 'No hay pagos',
      emptyMessage: payments.hasAnyFilter ? 'Prueba con otra búsqueda o quita los filtros.' : 'No hay pagos en este periodo.',
      onRefresh: payments.refresh,
      onLoadMore: payments.loadMore,
      loadingMore: payments.loadingMore,
      bottomPadding: 96,
      itemBuilder: (context, p, number) => _card(context, payments, p),
    );
  }

  /// Las acciones de la fila, con las mismas reglas y permisos que la tabla de la web: un pago
  /// cancelado no tiene acciones; uno aprobado se edita (`update` o `post-confirm.update`) o se elimina
  /// (`post-confirm.destroy`); uno pendiente se aprueba (`confirmarPago`), se edita (`update`) o se
  /// elimina (`destroy`).
  List<Widget> _rowActions(SellerPaymentsProvider payments, SellerPaymentEntity p) {
    switch (p.status) {
      case SellerPaymentStatus.cancelado:
        return const [];
      case SellerPaymentStatus.aprobado:
        return [
          if (payments.canUpdate || payments.canPostConfirmUpdate)
            AppActionButton(type: AppActionType.edit, onPressed: () => _edit(p)),
          if (payments.canPostConfirmDestroy)
            AppActionButton(type: AppActionType.delete, label: 'Eliminar pago', onPressed: () => _delete(p)),
        ];
      case SellerPaymentStatus.pendiente:
        return [
          if (payments.canApprove) _ApproveButton(onPressed: () => _approve(p)),
          if (payments.canUpdate) AppActionButton(type: AppActionType.edit, onPressed: () => _edit(p)),
          if (payments.canDestroy)
            AppActionButton(type: AppActionType.delete, label: 'Eliminar pago', onPressed: () => _delete(p)),
        ];
    }
  }

  Widget _card(BuildContext context, SellerPaymentsProvider payments, SellerPaymentEntity p) {
    final status = p.status;
    return AppListCard(
      title: p.cliente.isEmpty ? 'Sin cliente' : p.cliente,
      lines: [
        if (p.creado != null) DateFormat(AppConstants.dateFormat).format(p.creado!),
        // La columna "Ejecutivo" solo la ve quien ve los pagos de todos.
        if (payments.canSeeOthers && p.ejecutivo != null) 'Ejecutivo comercial: ${p.ejecutivo}',
        if (p.metodos.isNotEmpty) 'Método: ${p.metodos.join(' / ')}',
        // La columna "Descripción Adicional" de la web: la última nota y, con más de una, cuántas hay.
        if (p.ultimaNota != null)
          'Nota: ${p.ultimaNota!.texto}${p.notasCount > 1 ? ' (${p.notasCount} notas)' : ''}',
      ],
      trailingTitle: sellerPaymentMoney(p.montoTotal, p.moneda),
      footer: AppStatusBadge(label: status.label, tone: sellerPaymentTone(status)),
      actions: _rowActions(payments, p),
      selected: _pane.selectedId == p.id,
      onTap: () => _showDetail(p),
    );
  }
}

/// El botón "Confirmar pago" de una fila: la misma píldora de las demás acciones, en verde.
class _ApproveButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ApproveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Confirmar pago',
      onPressed: onPressed,
      icon: const Icon(Icons.check_circle_outline),
      iconSize: 18,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        fixedSize: const Size(38, 28),
        minimumSize: const Size(38, 28),
        padding: EdgeInsets.zero,
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
