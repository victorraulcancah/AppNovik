import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/sale_entity.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../components/components.dart';
import '../providers/sales_provider.dart';

/// Modal "Crear venta" (como el de la web): fecha de emisión, método de entrega, el tipo de cambio
/// si la venta es en dólares, una o más formas de pago que sumen el total (con cuotas si es a
/// crédito o a plazo, y puntos si el cliente los tiene) y observaciones. Al tocar Crear registra la
/// venta; si el servidor la rechaza el modal sigue abierto con el motivo. Devuelve `true` si la
/// venta quedó registrada.
Future<bool> showSaleCheckout(
  BuildContext context, {
  required SalesProvider sales,
  DateTime Function() now = DateTime.now,
}) async {
  final today = now();
  final rate = sales.exchangeRate?.valorFinal;
  final draft = _CheckoutDraft(
    total: sales.total,
    tipo: sales.tipoDocumento,
    today: DateTime(today.year, today.month, today.day),
    delivery: sales.defaultDelivery,
    method: _defaultMethod(sales),
    dolares: sales.esDolares,
    symbol: sales.moneySymbol,
    tipoCambio: rate,
    client: sales.client,
    minimoCanjePuntos: sales.minimoCanjePuntos,
  );
  final error = ValueNotifier<String?>(null);

  final created = await showAppModal(
    context,
    title: 'Crear venta',
    subtitle: '${sales.tipoDocumento.label} · Total ${formatMoney(sales.total, symbol: sales.moneySymbol)}',
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

PaymentMethodEntity? _defaultMethod(SalesProvider sales) {
  final id = sales.defaultPaymentMethodId;
  for (final m in sales.paymentMethods) {
    if (m.id == id) return m;
  }
  return null;
}

/// Una cuota de un crédito: monto y fecha de vencimiento.
class _Cuota {
  final TextEditingController monto;
  DateTime fecha;

  _Cuota(double amount, this.fecha) : monto = TextEditingController(text: amount.toStringAsFixed(2));

  double get amount => double.tryParse(monto.text.trim()) ?? 0;
}

/// Una forma de pago con su monto y, si es a crédito o a plazo, sus cuotas.
class _PayRow {
  PaymentMethodEntity? method;
  final TextEditingController monto;
  SalePlazo plazo = SalePlazo.month;
  final cuotas = <_Cuota>[];

  _PayRow(this.method, double amount) : monto = TextEditingController(text: amount.toStringAsFixed(2));

  double get amount => double.tryParse(monto.text.trim()) ?? 0;

  PaymentKind get kind => method?.kind ?? PaymentKind.normal;
}

/// Lo que va llenando el usuario en el modal.
class _CheckoutDraft extends ChangeNotifier {
  final double total;
  final SaleDocumentType tipo;
  final DateTime today;
  final bool dolares;
  final String symbol;
  final ClientEntity? client;
  final double minimoCanjePuntos;

  DateTime date;
  SaleDelivery delivery;
  final rows = <_PayRow>[];
  final observaciones = TextEditingController();

  /// Tipo de cambio de la venta en dólares (el oficial al abrir, editable).
  final tipoCambio = TextEditingController();

  /// Se puede crear: los pagos cumplen todas las reglas.
  final canCreate = ValueNotifier<bool>(true);

  // Los campos quitados siguen dibujados hasta el siguiente cuadro: se liberan al cerrar.
  final _removedRows = <_PayRow>[];
  final _removedCuotas = <_Cuota>[];

  _CheckoutDraft({
    required this.total,
    required this.tipo,
    required this.today,
    required this.delivery,
    required PaymentMethodEntity? method,
    required this.dolares,
    required this.symbol,
    required double? tipoCambio,
    required this.client,
    required this.minimoCanjePuntos,
  }) : date = today {
    if (tipoCambio != null) this.tipoCambio.text = tipoCambio.toStringAsFixed(3);
    final row = _PayRow(null, total);
    rows.add(row);
    if (method != null) setMethod(row, method, notify: false);
    canCreate.value = problem == null;
  }

  double? get tc => double.tryParse(tipoCambio.text.trim());

  /// Lo que se cobra en la moneda de la venta (los puntos se canjean en soles).
  double _effective(_PayRow r) => dolares && r.kind == PaymentKind.puntos ? r.amount / (tc ?? 1) : r.amount;

  double get paid => roundMoney(rows.fold<double>(0, (sum, r) => sum + _effective(r)));

  /// Lo que falta cobrar (negativo si se pasó).
  double get remaining => roundMoney(total - paid);

  bool get tcOutOfRange => dolares && (tc == null || tc! < saleExchangeRateMin || tc! > saleExchangeRateMax);

  List<SalePaymentEntity> get payments => [
        for (final r in rows)
          if (r.method != null)
            SalePaymentEntity(
              paymentMethodId: r.method!.id,
              monto: r.amount,
              kind: r.kind,
              plazo: r.kind == PaymentKind.credito || r.kind == PaymentKind.plazo ? r.plazo : null,
              installments: [
                if (r.kind == PaymentKind.credito || r.kind == PaymentKind.plazo)
                  for (final c in r.cuotas) SaleInstallmentEntity(monto: c.amount, fechaVencimiento: c.fecha),
              ],
            ),
      ];

  /// El primer problema de los pagos (`null` si todo está bien).
  String? get problem {
    if (rows.any((r) => r.method == null)) return 'Elige la forma de pago';
    return CreateSaleUseCase.checkPayments(
      payments: payments,
      total: total,
      dolares: dolares,
      tipoCambio: tc,
      client: client,
      minimoCanjePuntos: minimoCanjePuntos,
    );
  }

  void refresh() {
    canCreate.value = problem == null;
    notifyListeners();
  }

  void pickDate(DateTime value) {
    date = value;
    refresh();
  }

  // --- Formas de pago ---

  void setMethod(_PayRow row, PaymentMethodEntity? method, {bool notify = true}) {
    row.method = method;
    if (method != null && method.conCuotas) {
      row.plazo = method.esPlazo ? SalePlazo.day : SalePlazo.month;
      _rebuildCuotas(row, count: 1);
    } else {
      _clearCuotas(row);
    }
    if (notify) refresh();
  }

  void addRow(PaymentMethodEntity? method) {
    final row = _PayRow(null, remaining > 0 ? remaining : 0);
    rows.add(row);
    if (method != null) setMethod(row, method, notify: false);
    refresh();
  }

  void removeRow(int index) {
    final row = rows.removeAt(index);
    _clearCuotas(row);
    _removedRows.add(row);
    if (rows.length == 1) {
      rows.first.monto.text = total.toStringAsFixed(2);
      _rebuildCuotas(rows.first);
    }
    refresh();
  }

  /// El monto de una forma de pago cambió: las cuotas del crédito se reparten de nuevo.
  void amountChanged(_PayRow row) {
    if (row.method?.conCuotas ?? false) _rebuildCuotas(row);
    refresh();
  }

  // --- Cuotas ---

  void _clearCuotas(_PayRow row) {
    _removedCuotas.addAll(row.cuotas);
    row.cuotas.clear();
  }

  /// Reparte el monto en [count] cuotas iguales y las fecha cada [SalePlazo] desde hoy. Con
  /// [datesOnly] solo se vuelven a calcular las fechas.
  void _rebuildCuotas(_PayRow row, {int? count, bool datesOnly = false}) {
    if (!(row.method?.conCuotas ?? false)) return;
    var n = row.plazo == SalePlazo.day ? 1 : (count ?? row.cuotas.length);
    if (n < 1) n = 1;

    final amounts = splitInstallments(row.amount, n);
    if (datesOnly && n == row.cuotas.length) {
      for (var i = 0; i < n; i++) {
        row.cuotas[i].fecha = row.plazo.after(today, i + 1);
      }
      return;
    }
    _clearCuotas(row);
    for (var i = 0; i < n; i++) {
      row.cuotas.add(_Cuota(amounts[i], row.plazo.after(today, i + 1)));
    }
  }

  void setPlazo(_PayRow row, SalePlazo plazo) {
    row.plazo = plazo;
    _rebuildCuotas(row, datesOnly: true);
    refresh();
  }

  void addCuota(_PayRow row) {
    _rebuildCuotas(row, count: row.cuotas.length + 1);
    refresh();
  }

  void removeCuota(_PayRow row, int index) {
    if (row.cuotas.length <= 1) return;
    final removed = row.cuotas.removeAt(index);
    _removedCuotas.add(removed);
    _rebuildCuotas(row, count: row.cuotas.length);
    refresh();
  }

  void pickCuotaDate(_Cuota cuota, DateTime value) {
    cuota.fecha = value;
    refresh();
  }

  SaleCheckoutEntity toCheckout(DateTime now) => SaleCheckoutEntity(
        // La web solo manda la fecha si se eligió otro día; la hora es la actual.
        fechaEmision: date == today ? null : DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second),
        delivery: delivery,
        payments: payments,
        observaciones: observaciones.text.trim(),
        tipoCambio: dolares ? tc : null,
      );

  @override
  void dispose() {
    for (final r in [...rows, ..._removedRows]) {
      r.monto.dispose();
      for (final c in r.cuotas) {
        c.monto.dispose();
      }
    }
    for (final c in _removedCuotas) {
      c.monto.dispose();
    }
    observaciones.dispose();
    tipoCambio.dispose();
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
    final client = sales.client;
    final points = client?.creditoAFavor ?? 0;

    return ListenableBuilder(
      listenable: draft,
      // El alto cambia con suavidad cuando se agrega o quita un pago o aparece el tipo de cambio.
      builder: (context, _) => AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sales.offeredPaymentMethods.any((m) => m.esPuntos) && points > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'El cliente tiene S/. ${points.toStringAsFixed(2)} en PUNTOS'
                '${sales.minimoCanjePuntos > 0 ? ' (mínimo para canjear: ${formatQuantity(sales.minimoCanjePuntos)})' : ''}.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w700),
              ),
            ),
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
          if (draft.dolares) ...[
            const SizedBox(height: 12),
            TextField(
              controller: draft.tipoCambio,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'Tipo de cambio',
                prefixText: 'S/ ',
                helperText: sales.exchangeRate == null
                    ? 'Entre 3.000 y 4.300'
                    : 'Oficial ${sales.exchangeRate!.valorFinal.toStringAsFixed(3)} · editable entre 3.000 y 4.300',
                errorText: draft.tcOutOfRange ? 'El tipo de cambio debe estar entre 3.000 y 4.300' : null,
              ),
              onChanged: (_) => draft.refresh(),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < draft.rows.length; i++) ...[
            // El primer pago ya está al abrir; los que se agregan llegan deslizándose desde la derecha.
            if (i == 0)
              _PaymentCard(
                key: ObjectKey(draft.rows[i]),
                index: i,
                row: draft.rows[i],
                draft: draft,
                sales: sales,
                onRemove: null,
              )
            else
              AppEntrance(
                key: ObjectKey(draft.rows[i]),
                from: const Offset(28, 0),
                duration: const Duration(milliseconds: 300),
                child: _PaymentCard(
                  index: i,
                  row: draft.rows[i],
                  draft: draft,
                  sales: sales,
                  onRemove: () => draft.removeRow(i),
                ),
              ),
            const SizedBox(height: 10),
          ],
          _PaymentsSummary(draft: draft),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              PaymentMethodEntity? method;
              for (final m in sales.offeredPaymentMethods) {
                if (m.id == sales.defaultPaymentMethodId) method = m;
              }
              // Un segundo pago no repite el crédito ni los puntos.
              if (method != null && (method.conCuotas || method.esPuntos)) {
                method = sales.offeredPaymentMethods
                    .where((m) => !m.conCuotas && !m.esPuntos)
                    .firstOrNull;
              }
              draft.addRow(method);
            },
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
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final int index;
  final _PayRow row;
  final _CheckoutDraft draft;
  final SalesProvider sales;
  final VoidCallback? onRemove;

  const _PaymentCard({
    super.key,
    required this.index,
    required this.row,
    required this.draft,
    required this.sales,
    required this.onRemove,
  });

  String _money(double v, {bool soles = false}) =>
      formatMoney(v, symbol: soles || !draft.dolares ? 'S/.' : r'$.');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final client = sales.client;
    final method = row.method;
    final isPoints = row.kind == PaymentKind.puntos;
    final tc = draft.tc ?? 1;

    // Cada tarjeta ofrece las formas de pago que el cliente puede usar; el crédito y los puntos
    // no se repiten en otra tarjeta.
    bool usedElsewhere(PaymentMethodEntity m) => draft.rows.any(
          (r) => !identical(r, row) && r.method != null && ((m.conCuotas && r.method!.conCuotas) || (m.esPuntos && r.method!.esPuntos)),
        );
    final methods = [
      for (final m in sales.offeredPaymentMethods)
        if (!usedElsewhere(m)) m,
    ];

    final montoHelper = !draft.dolares || row.amount <= 0
        ? null
        : isPoints
            ? '≈ ${_money(row.amount / tc)}'
            : '≈ ${_money(row.amount * tc, soles: true)}';

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
                  key: ValueKey('metodo-${method?.id}'),
                  label: 'Forma de pago',
                  value: method?.id,
                  items: [
                    for (final m in methods)
                      DropdownMenuItem(
                        value: m.id,
                        enabled: sales.canUsePayment(m),
                        child: Text(
                          sales.canUsePayment(m) ? m.name : '${m.name} (no disponible)',
                          style: sales.canUsePayment(m) ? null : TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    PaymentMethodEntity? chosen;
                    for (final m in methods) {
                      if (m.id == id) chosen = m;
                    }
                    draft.setMethod(row, chosen);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: row.monto,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(
                    labelText: isPoints ? 'Puntos a canjear' : 'Monto',
                    prefixText: isPoints ? 'S/ ' : '${draft.symbol} ',
                    helperText: montoHelper,
                  ),
                  onChanged: (_) => draft.amountChanged(row),
                ),
                if (method != null && method.conCuotas) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Crédito en soles: ${_money(client?.creditoDisponible ?? 0, soles: true)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                  ),
                  if (draft.dolares)
                    Text(
                      'Se le descontará: ${_money(row.amount * tc, soles: true)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w700),
                    ),
                  const SizedBox(height: 8),
                  _Cuotas(row: row, draft: draft),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Las cuotas de un crédito: cada cuánto vencen, y el monto y la fecha de cada una.
class _Cuotas extends StatelessWidget {
  final _PayRow row;
  final _CheckoutDraft draft;

  const _Cuotas({required this.row, required this.draft});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sum = roundMoney(row.cuotas.fold<double>(0, (s, c) => s + c.amount));
    final mismatch = sum != roundMoney(row.amount);
    final day = row.plazo == SalePlazo.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cuotas del crédito', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        AppDropdownField<SalePlazo>(
          key: ValueKey('plazo-${row.plazo}'),
          label: 'Plazo de pago',
          value: row.plazo,
          items: [for (final p in SalePlazo.values) DropdownMenuItem(value: p, child: Text(p.label))],
          onChanged: (p) {
            if (p != null) draft.setPlazo(row, p);
          },
        ),
        if (mismatch)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 6),
            child: Text(
              'La suma de las cuotas debe ser igual al monto del crédito',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 8),
        for (var i = 0; i < row.cuotas.length; i++)
          Padding(
            key: ObjectKey(row.cuotas[i]),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: row.cuotas[i].monto,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: InputDecoration(labelText: 'Cuota ${i + 1}', prefixText: '${draft.symbol} '),
                    onChanged: (_) => draft.refresh(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: AppPickerField(
                    label: 'Vence',
                    value: DateFormat(AppConstants.dateFormat).format(row.cuotas[i].fecha),
                    icon: Icons.event_outlined,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: row.cuotas[i].fecha,
                        firstDate: draft.today,
                        lastDate: DateTime(draft.today.year + 10),
                        helpText: 'Fecha de vencimiento',
                      );
                      if (picked != null) draft.pickCuotaDate(row.cuotas[i], picked);
                    },
                  ),
                ),
                if (!day && row.cuotas.length > 1)
                  IconButton(
                    tooltip: 'Quitar cuota',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    onPressed: () => draft.removeCuota(row, i),
                  ),
              ],
            ),
          ),
        if (!day)
          OutlinedButton.icon(
            onPressed: () => draft.addCuota(row),
            icon: const Icon(Icons.add),
            label: const Text('Agregar cuota'),
          ),
      ],
    );
  }
}

/// Cuánto se cobra frente al total: en verde cuando cuadra, en rojo cuando falta, sobra o algo de
/// las formas de pago no cumple las reglas.
class _PaymentsSummary extends StatelessWidget {
  final _CheckoutDraft draft;

  const _PaymentsSummary({required this.draft});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = draft.remaining;
    final problem = draft.problem;
    final ok = problem == null;
    final color = ok ? const Color(0xFF16A34A) : scheme.error;
    final symbol = draft.symbol;

    final String text;
    if (ok) {
      text = 'Los pagos suman el total';
    } else if (draft.rows.every((r) => r.method != null) && remaining > 0) {
      text = 'Faltan ${formatMoney(remaining, symbol: symbol)} para completar el total';
    } else if (draft.rows.every((r) => r.method != null) && remaining < 0) {
      text = 'Sobran ${formatMoney(-remaining, symbol: symbol)} sobre el total';
    } else {
      text = problem;
    }

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
