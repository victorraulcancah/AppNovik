import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/seller_payment_entity.dart';
import '../components/components.dart';
import '../providers/seller_payments_provider.dart';
import 'document_filters.dart' show documentFilterDate;

/// El rango de fechas de los filtros: `01 nov. 2026 - 30 nov. 2026`, o `Todas las fechas`.
String sellerPaymentRange(SellerPaymentFilters f) => f.desde == null || f.hasta == null
    ? 'Todas las fechas'
    : '${documentFilterDate(f.desde!)} - ${documentFilterDate(f.hasta!)}';

/// Un monto como lo escribe la web en las etiquetas: miles con coma y hasta dos decimales.
String _amount(double v) => NumberFormat('#,##0.##', 'en_US').format(v);

/// Los filtros avanzados que están puestos, como chips que se quitan uno a uno. "Los pagos del mes" es
/// cómo se entra a la lista, así que el rango sale como chip solo si es distinto del mes (y quitarlo
/// vuelve al mes).
List<AppActiveFilter> sellerPaymentActiveFilters(SellerPaymentsProvider payments) {
  final f = payments.filters;
  final base = payments.baseFilters;

  String names(String single, String plural, List<int> ids, String? Function(int id) nameOf) {
    if (ids.length == 1) return '$single: ${nameOf(ids.first) ?? '#${ids.first}'}';
    return '$plural: ${ids.length} elegidos';
  }

  String? find(List<SellerPaymentOption>? list, int id) {
    for (final o in list ?? const <SellerPaymentOption>[]) {
      if (o.id == id) return o.name;
    }
    return null;
  }

  void change(SellerPaymentFilters value) => payments.applyFilters(value);

  return [
    if (!f.sameDates(base))
      AppActiveFilter(
        id: 'fechas',
        label: sellerPaymentRange(f),
        onRemove: () => change(f.copyWith(desde: base.desde, hasta: base.hasta)),
      ),
    if (f.clientes.isNotEmpty)
      AppActiveFilter(
        id: 'clientes',
        label: names('Cliente', 'Clientes', f.clientes, (id) => find(payments.filterClients, id)),
        onRemove: () => change(f.copyWith(clientes: const <int>[])),
      ),
    if (f.ejecutivos.isNotEmpty)
      AppActiveFilter(
        id: 'ejecutivos',
        label: names(
          'Ejecutivo comercial',
          'Ejecutivos comerciales',
          f.ejecutivos,
          (id) => find(payments.sellers, id),
        ),
        onRemove: () => change(f.copyWith(ejecutivos: const <int>[])),
      ),
    if (f.montoMin != null || f.montoMax != null)
      AppActiveFilter(
        id: 'monto',
        label: f.montoMin != null && f.montoMax != null
            ? 'Monto: ${_amount(f.montoMin!)} - ${_amount(f.montoMax!)}'
            : f.montoMin != null
                ? 'Monto: desde ${_amount(f.montoMin!)}'
                : 'Monto: hasta ${_amount(f.montoMax!)}',
        onRemove: () => change(f.copyWith(montoMin: null, montoMax: null)),
      ),
    if (f.metodos.isNotEmpty)
      AppActiveFilter(
        id: 'metodos',
        label: names('Método', 'Métodos', f.metodos, payments.methodName),
        onRemove: () => change(f.copyWith(metodos: const <int>[])),
      ),
    if (f.estado != null)
      AppActiveFilter(
        id: 'estado',
        label: 'Estado: ${f.estado!.pluralLabel}',
        onRemove: () => change(f.copyWith(estado: null)),
      ),
  ];
}

/// Abre el panel de filtros avanzados y aplica lo elegido al pulsar "Aplicar filtros".
Future<void> showSellerPaymentFilters(BuildContext context) async {
  final payments = context.read<SellerPaymentsProvider>();
  final draft = ValueNotifier<SellerPaymentFilters>(payments.filters);
  final applied = await showAppModal(
    context,
    title: 'Filtros avanzados',
    subtitle: 'Pagos vendedores',
    icon: Icons.filter_list,
    primaryLabel: 'Aplicar filtros',
    child: _FiltersBody(draft: draft, payments: payments),
  );
  var result = applied == true ? draft.value : null;
  draft.dispose();
  if (result != null) {
    // Si los montos quedaron al revés, se ordenan.
    final min = result.montoMin;
    final max = result.montoMax;
    if (min != null && max != null && min > max) {
      result = result.copyWith(montoMin: max, montoMax: min);
    }
    await payments.applyFilters(result);
  }
}

class _FiltersBody extends StatefulWidget {
  final ValueNotifier<SellerPaymentFilters> draft;
  final SellerPaymentsProvider payments;

  const _FiltersBody({required this.draft, required this.payments});

  @override
  State<_FiltersBody> createState() => _FiltersBodyState();
}

class _FiltersBodyState extends State<_FiltersBody> {
  late final TextEditingController _min;
  late final TextEditingController _max;

  SellerPaymentsProvider get _payments => widget.payments;
  ValueNotifier<SellerPaymentFilters> get _draft => widget.draft;

  @override
  void initState() {
    super.initState();
    final f = _draft.value;
    _min = TextEditingController(text: f.montoMin == null ? '' : _amountText(f.montoMin!));
    _max = TextEditingController(text: f.montoMax == null ? '' : _amountText(f.montoMax!));
    // Los clientes y los ejecutivos se piden al abrir el panel (una vez por empresa) para que las
    // etiquetas de los chips muestren sus nombres.
    _payments.loadFilterClients().then((_) {
      if (mounted) setState(() {});
    }, onError: (_) {});
    if (_payments.canSeeOthers) {
      _payments.loadSellers().then((_) {
        if (mounted) setState(() {});
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  static String _amountText(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  double? _parse(String text) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    return v == null || v < 0 ? null : v;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickIds({
    required String title,
    required IconData icon,
    required Future<List<SellerPaymentOption>> Function() load,
    required List<int> current,
    required SellerPaymentFilters Function(SellerPaymentFilters, List<int>) apply,
  }) async {
    final List<SellerPaymentOption> options;
    try {
      options = await load();
    } catch (e) {
      if (mounted) _snack('$e'.replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    final chosen = await showAppMultiSelect(
      context,
      title: title,
      icon: icon,
      options: [for (final o in options) (id: o.id, name: o.name)],
      selected: current,
    );
    if (chosen != null) _draft.value = apply(_draft.value, chosen);
  }

  Future<void> _pickDates(SellerPaymentFilters f) async {
    final now = _payments.now;
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: f.desde != null && f.hasta != null
          ? DateTimeRange(start: f.desde!, end: f.hasta!)
          : DateTimeRange(start: today, end: today),
      helpText: 'Rango de fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) {
      _draft.value = _draft.value.copyWith(desde: picked.start, hasta: picked.end);
    }
  }

  String _summary(List<int> ids, String all, String? Function(int id) nameOf) {
    if (ids.isEmpty) return all;
    if (ids.length > 1) return '${ids.length} elegidos';
    return nameOf(ids.first) ?? '#${ids.first}';
  }

  String? _find(List<SellerPaymentOption>? list, int id) {
    for (final o in list ?? const <SellerPaymentOption>[]) {
      if (o.id == id) return o.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = _payments.now;
    final today = DateTime(now.year, now.month, now.day);

    return ValueListenableBuilder<SellerPaymentFilters>(
      valueListenable: _draft,
      builder: (context, f, _) {
        void setDates(DateTime from, DateTime to) => _draft.value = f.copyWith(desde: from, hasta: to);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _draft.value = _payments.baseFilters;
                  _min.clear();
                  _max.clear();
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Restablecer'),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(label: const Text('Hoy'), onPressed: () => setDates(today, today)),
                ActionChip(
                  label: const Text('Ayer'),
                  onPressed: () {
                    final y = today.subtract(const Duration(days: 1));
                    setDates(y, y);
                  },
                ),
                ActionChip(
                  label: const Text('Últimos 7 días'),
                  onPressed: () => setDates(today.subtract(const Duration(days: 6)), today),
                ),
                ActionChip(
                  label: const Text('Este mes'),
                  onPressed: () => setDates(DateTime(today.year, today.month), DateTime(today.year, today.month + 1, 0)),
                ),
                ActionChip(
                  label: const Text('Mes pasado'),
                  onPressed: () => setDates(DateTime(today.year, today.month - 1), DateTime(today.year, today.month, 0)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppPickerField(
              label: 'Rango de fechas',
              value: sellerPaymentRange(f),
              icon: Icons.date_range,
              onTap: () => _pickDates(f),
              onClear: f.desde == null ? null : () => _draft.value = f.copyWith(desde: null, hasta: null),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: Text('Vacío: todas las fechas.', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Clientes',
              value: _summary(f.clientes, 'Todos', (id) => _find(_payments.filterClients, id)),
              icon: Icons.person_outline,
              onTap: () => _pickIds(
                title: 'Clientes',
                icon: Icons.groups_outlined,
                load: _payments.loadFilterClients,
                current: f.clientes,
                apply: (d, ids) => d.copyWith(clientes: ids),
              ),
            ),
            // Solo quien ve los pagos de todos elige ejecutivo.
            if (_payments.canSeeOthers) ...[
              const SizedBox(height: 16),
              AppPickerField(
                label: 'Ejecutivo comercial',
                value: _summary(f.ejecutivos, 'Todos', (id) => _find(_payments.sellers, id)),
                icon: Icons.badge_outlined,
                onTap: () => _pickIds(
                  title: 'Ejecutivo comercial',
                  icon: Icons.badge_outlined,
                  load: _payments.loadSellers,
                  current: f.ejecutivos,
                  apply: (d, ids) => d.copyWith(ejecutivos: ids),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Monto desde'),
                    onChanged: (v) => _draft.value = _draft.value.copyWith(montoMin: _parse(v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Monto hasta'),
                    onChanged: (v) => _draft.value = _draft.value.copyWith(montoMax: _parse(v)),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: Text('El monto del pago, en su moneda.', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Métodos de pago',
              value: _summary(f.metodos, 'Todos', (id) => _payments.methodName(id)),
              icon: Icons.payments_outlined,
              onTap: () => _pickIds(
                title: 'Métodos de pago',
                icon: Icons.payments_outlined,
                // Solo los que aparecen en la lista, como la web.
                load: () async => _payments.availableMethods,
                current: f.metodos,
                apply: (d, ids) => d.copyWith(metodos: ids),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: Text('Solo los que aparecen en la lista.', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 16),
            AppDropdownField<SellerPaymentStatus?>(
              key: ValueKey('estado-${f.estado}'),
              label: 'Estado',
              value: f.estado,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final s in [SellerPaymentStatus.aprobado, SellerPaymentStatus.pendiente, SellerPaymentStatus.cancelado])
                  DropdownMenuItem(value: s, child: Text(s.pluralLabel)),
              ],
              onChanged: (v) => _draft.value = f.copyWith(estado: v),
            ),
          ],
        );
      },
    );
  }
}

/// El texto de un monto con su símbolo: `S/. 1,500.00`.
String sellerPaymentMoney(double value, String moneda) =>
    formatMoney(value, symbol: moneda == 'dolares' ? r'$.' : 'S/.');
