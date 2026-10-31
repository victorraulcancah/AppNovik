import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/sale_entity.dart';
import '../components/components.dart';
import '../providers/sales_provider.dart';

/// Modal "Crear venta" (como el de la web): fecha de emisión, método de entrega, una o más formas
/// de pago que sumen el total, y observaciones. Al tocar Crear registra la venta; si el servidor
/// la rechaza el modal sigue abierto con el motivo. Devuelve `true` si la venta quedó registrada.
Future<bool> showSaleCheckout(
  BuildContext context, {
  required SalesProvider sales,
  DateTime Function() now = DateTime.now,
}) async {
  final today = now();
  final draft = _CheckoutDraft(
    total: sales.total,
    tipo: sales.tipoDocumento,
    today: DateTime(today.year, today.month, today.day),
    delivery: sales.defaultDelivery,
    method: sales.defaultPaymentMethodId,
  );
  final error = ValueNotifier<String?>(null);

  final created = await showAppModal(
    context,
    title: 'Crear venta',
    subtitle: '${sales.tipoDocumento.label} · Total ${formatMoney(sales.total)}',
    icon: Icons.point_of_sale,
    primaryLabel: 'Crear',
    primaryEnabled: draft.canCreate,
    error: error,
    onPrimary: () async {
      error.value = null;
      final ok = await sales.submit(checkout: draft.toCheckout(now()));
      if (!ok) {
        error.value = sales.submitError ?? 'No se pudo registrar la venta';
        // Mantiene el modal abierto para corregir o reintentar.
        throw StateError('venta rechazada');
      }
    },
    child: AppDisposer(
      onDispose: [draft.dispose, error.dispose],
      child: _CheckoutBody(draft: draft, sales: sales),
    ),
  );
  return created == true;
}

/// Una forma de pago con su monto.
class _PayRow {
  int? methodId;
  final TextEditingController monto;

  _PayRow(this.methodId, double amount) : monto = TextEditingController(text: amount.toStringAsFixed(2));

  double get amount => double.tryParse(monto.text.trim()) ?? 0;
}

/// Lo que va llenando el usuario en el modal.
class _CheckoutDraft extends ChangeNotifier {
  final double total;
  final SaleDocumentType tipo;
  final DateTime today;

  DateTime date;
  SaleDelivery delivery;
  final rows = <_PayRow>[];
  final observaciones = TextEditingController();

  /// Se puede crear: todas las formas de pago tienen método y monto, y suman el total.
  final canCreate = ValueNotifier<bool>(true);

  // Los campos de un pago quitado siguen dibujados hasta el siguiente cuadro: se liberan al cerrar.
  final _removed = <_PayRow>[];

  _CheckoutDraft({
    required this.total,
    required this.tipo,
    required this.today,
    required this.delivery,
    required int? method,
  }) : date = today {
    rows.add(_PayRow(method, total));
  }

  double get paid => roundMoney(rows.fold<double>(0, (sum, r) => sum + r.amount));

  /// Lo que falta cobrar (negativo si se pasó).
  double get remaining => roundMoney(total - paid);

  bool get valid => rows.every((r) => r.methodId != null && r.amount > 0) && remaining == 0;

  void refresh() {
    canCreate.value = valid;
    notifyListeners();
  }

  void pickDate(DateTime value) {
    date = value;
    refresh();
  }

  void addRow(int? method) {
    rows.add(_PayRow(method, remaining > 0 ? remaining : 0));
    refresh();
  }

  void removeRow(int index) {
    _removed.add(rows.removeAt(index));
    if (rows.length == 1) rows.first.monto.text = total.toStringAsFixed(2);
    refresh();
  }

  SaleCheckoutEntity toCheckout(DateTime now) => SaleCheckoutEntity(
        // La web solo manda la fecha si se eligió otro día; la hora es la actual.
        fechaEmision: date == today ? null : DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second),
        delivery: delivery,
        payments: [
          for (final r in rows) SalePaymentEntity(paymentMethodId: r.methodId!, monto: r.amount),
        ],
        observaciones: observaciones.text.trim(),
      );

  @override
  void dispose() {
    for (final r in [...rows, ..._removed]) {
      r.monto.dispose();
    }
    observaciones.dispose();
    canCreate.dispose();
    super.dispose();
  }
}

class _CheckoutBody extends StatelessWidget {
  final _CheckoutDraft draft;
  final SalesProvider sales;

  const _CheckoutBody({required this.draft, required this.sales});

  Future<void> _pickDate(BuildContext context) async {
    final range = saleIssueDateRange(draft.tipo, draft.today);
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.date,
      firstDate: range.first,
      lastDate: range.last,
      helpText: 'Fecha de emisión',
    );
    if (picked != null) draft.pickDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hint = draft.tipo == SaleDocumentType.ticket
        ? 'Hasta 30 días atrás.'
        : 'Hoy o los dos días anteriores.';

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPickerField(
            label: 'Fecha de emisión',
            value: DateFormat(AppConstants.dateFormat).format(draft.date),
            icon: Icons.event_outlined,
            onTap: () => _pickDate(context),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 4),
            child: Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 12),
          AppDropdownField<SaleDelivery>(
            label: 'Método de entrega',
            value: draft.delivery,
            items: [
              for (final d in SaleDelivery.values) DropdownMenuItem(value: d, child: Text(d.label)),
            ],
            onChanged: (v) {
              if (v == null) return;
              draft.delivery = v;
              draft.refresh();
            },
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < draft.rows.length; i++) ...[
            _PaymentCard(
              key: ObjectKey(draft.rows[i]),
              index: i,
              row: draft.rows[i],
              methods: sales.paymentMethods,
              onChanged: draft.refresh,
              onRemove: i == 0 ? null : () => draft.removeRow(i),
            ),
            const SizedBox(height: 10),
          ],
          _PaymentsSummary(draft: draft),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => draft.addRow(sales.defaultPaymentMethodId),
            icon: const Icon(Icons.add),
            label: const Text('Agregar método de pago'),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: draft.observaciones,
            label: 'Observaciones (opcional)',
            maxLines: 3,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final int index;
  final _PayRow row;
  final List<PaymentMethodEntity> methods;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _PaymentCard({
    super.key,
    required this.index,
    required this.row,
    required this.methods,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Método de pago ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Quitar',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: onRemove,
                )
              else
                const SizedBox(height: 40),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppDropdownField<int>(
                  label: 'Forma de pago',
                  value: row.methodId,
                  items: [
                    for (final m in methods) DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: (v) {
                    row.methodId = v;
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: row.monto,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Monto', prefixText: 'S/ '),
                  onChanged: (_) => onChanged(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuánto se cobra frente al total: en verde cuando cuadra, en rojo cuando falta o sobra.
class _PaymentsSummary extends StatelessWidget {
  final _CheckoutDraft draft;

  const _PaymentsSummary({required this.draft});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = draft.remaining;
    final ok = remaining == 0;
    final color = ok ? const Color(0xFF16A34A) : scheme.error;
    final text = ok
        ? 'Los pagos suman el total'
        : remaining > 0
            ? 'Faltan ${formatMoney(remaining)} para completar el total'
            : 'Sobran ${formatMoney(-remaining)} sobre el total';

    return Row(
      children: [
        Icon(ok ? Icons.check_circle_outline : Icons.info_outline, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
