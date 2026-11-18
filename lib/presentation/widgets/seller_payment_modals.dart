import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/seller_payment_entity.dart';
import '../components/components.dart';
import '../providers/seller_payments_provider.dart';
import 'seller_payment_filters.dart' show sellerPaymentMoney;

/// La insignia de estado de un pago (Aprobado, Pendiente, Cancelado).
AppBadgeTone sellerPaymentTone(SellerPaymentStatus status) => switch (status) {
      SellerPaymentStatus.aprobado => AppBadgeTone.success,
      SellerPaymentStatus.pendiente => AppBadgeTone.warning,
      SellerPaymentStatus.cancelado => AppBadgeTone.danger,
    };

double? _parseMoney(String? text) => double.tryParse((text ?? '').trim().replaceAll(',', '.'));

String? _text(String? text) {
  final t = (text ?? '').trim();
  return t.isEmpty ? null : t;
}

final _moneyFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

String? _validateAmount(String? v) {
  final amount = _parseMoney(v);
  if (amount == null) return 'Escribe el monto';
  if (amount <= 0) return 'El monto debe ser mayor a 0';
  return null;
}

// ---------------------------------------------------------------------------------------------
// Detalle
// ---------------------------------------------------------------------------------------------

/// Todo lo que muestra la fila de la tabla de la web: cliente, ejecutivo, descripción, fecha, monto,
/// método de pago y estado.
Future<bool?> showSellerPaymentDetail(
  BuildContext context,
  SellerPaymentEntity p, {
  required bool showExecutive,
  AppPaneController? pane,
}) {
  final status = p.status;
  return showAppModal(
    context,
    pane: pane,
    paneId: p.id,
    title: p.cliente.isEmpty ? 'Pago' : p.cliente,
    subtitle: 'Pago ${p.id}',
    icon: Icons.payments_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDetailRow(label: 'Cliente', value: p.cliente.isEmpty ? null : p.cliente),
        if (showExecutive) AppDetailRow(label: 'Ejecutivo comercial', value: p.ejecutivo),
        AppDetailRow(
          label: 'Fecha',
          value: p.creado == null ? null : DateFormat(AppConstants.dateFormat).format(p.creado!),
        ),
        AppDetailRow(label: 'Monto', value: sellerPaymentMoney(p.montoTotal, p.moneda)),
        AppDetailRow(label: 'Método de pago', value: p.metodos.isEmpty ? null : p.metodos.join(' / ')),
        AppDetailRow(label: 'Descripción adicional', value: p.descripcion),
        AppDetailRow(
          label: 'Estado',
          valueWidget: AppStatusBadge(label: status.label, tone: sellerPaymentTone(status)),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------------------------
// Realizar pago
// ---------------------------------------------------------------------------------------------

class _LineDraft {
  static int _next = 0;

  final int id = _next++;
  int? methodId;
  final monto = TextEditingController();
  final descripcion = TextEditingController();

  void dispose() {
    monto.dispose();
    descripcion.dispose();
  }
}

/// Lo que se va llenando en "Realizar Pago de Cuota": el cliente, su deuda, la moneda, la fecha y una o
/// varias líneas de método de pago.
class _CreateDraft extends ChangeNotifier {
  SellerPaymentOption? client;
  String moneda = 'soles';
  DateTime? date;
  SellerClientDebt debt = const SellerClientDebt();
  bool loadingDebt = false;
  bool loadingClients = false;
  final lines = <_LineDraft>[_LineDraft()];

  /// Se puede realizar el pago cuando ya se eligió el cliente (como la web).
  final canSubmit = ValueNotifier<bool>(false);
  bool _disposed = false;

  void change(VoidCallback fn) {
    fn();
    canSubmit.value = client != null;
    if (!_disposed) notifyListeners();
  }

  /// Sin monto por defecto (se permite cualquier cantidad): una sola línea vacía.
  void resetLines() {
    for (final l in lines) {
      l.dispose();
    }
    lines
      ..clear()
      ..add(_LineDraft());
  }

  @override
  void dispose() {
    _disposed = true;
    for (final l in lines) {
      l.dispose();
    }
    canSubmit.dispose();
    super.dispose();
  }
}

/// "Realizar Pago de Cuota": cliente, su deuda en soles y dólares, la moneda, la fecha de pago y uno o
/// varios métodos de pago con su monto y descripción. El depósito se distribuye entre las cuotas más
/// antiguas del cliente en esa moneda; si no debe nada, queda como anticipo. Devuelve `true` si se
/// registró.
Future<bool?> showSellerPaymentCreate(BuildContext context) async {
  final payments = context.read<SellerPaymentsProvider>();
  final List<SellerPaymentOption> methods;
  try {
    methods = await payments.loadPaymentMethods();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
    return null;
  }
  if (!context.mounted) return null;

  final formKey = GlobalKey<FormState>();
  final draft = _CreateDraft();
  final error = ValueNotifier<String?>(null);

  return showAppModal(
    context,
    title: 'Realizar Pago de Cuota',
    subtitle: 'Pagos vendedores',
    icon: Icons.add_card_outlined,
    primaryLabel: 'Realizar',
    formKey: formKey,
    error: error,
    primaryEnabled: draft.canSubmit,
    // El cuerpo cambia (la deuda del cliente, más métodos de pago): la ventana mide siempre lo mismo.
    fixedHeight: true,
    child: AppDisposer(
      onDispose: [draft.dispose, error.dispose],
      child: _CreateBody(draft: draft, payments: payments, methods: methods),
    ),
    onPrimary: () async {
      error.value = null;
      final client = draft.client;
      if (client == null) return;
      final result = await payments.createPayment(
        clientId: client.id,
        moneda: draft.moneda,
        date: draft.date,
        lines: [
          for (final l in draft.lines)
            SellerPaymentLine(
              paymentMethodId: l.methodId!,
              monto: _parseMoney(l.monto.text)!,
              descripcionAdicional: _text(l.descripcion.text),
            ),
        ],
      );
      if (result.isLeft) {
        // El modal sigue abierto con el mensaje del servidor.
        error.value = result.left.message;
        throw StateError(result.left.message);
      }
    },
  );
}

class _CreateBody extends StatelessWidget {
  final _CreateDraft draft;
  final SellerPaymentsProvider payments;
  final List<SellerPaymentOption> methods;

  const _CreateBody({required this.draft, required this.payments, required this.methods});

  Future<void> _pickClient(BuildContext context) async {
    if (draft.loadingClients) return;
    draft.change(() => draft.loadingClients = true);
    final List<SellerPaymentOption> clients;
    try {
      clients = await payments.loadAllClients();
    } catch (e) {
      draft.change(() => draft.loadingClients = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
      }
      return;
    }
    draft.change(() => draft.loadingClients = false);
    if (!context.mounted) return;
    final chosen = await showAppSelectOne(
      context,
      title: 'Clientes',
      subtitle: 'Elige el cliente que paga',
      icon: Icons.groups_outlined,
      options: [for (final c in clients) (id: c.id, name: c.name)],
      selected: draft.client?.id,
    );
    if (chosen == null || !context.mounted) return;
    final id = chosen.id;
    if (id == null) {
      draft.change(() {
        draft.client = null;
        draft.debt = const SellerClientDebt();
        draft.moneda = 'soles';
        draft.resetLines();
      });
      return;
    }
    if (id == draft.client?.id) return;
    final client = clients.firstWhere((c) => c.id == id);
    draft.change(() {
      draft.client = client;
      draft.debt = const SellerClientDebt();
      draft.loadingDebt = true;
      draft.resetLines();
    });
    final result = await payments.loadClientDebt(id);
    if (draft.client?.id != id) return;
    result.fold(
      (failure) {
        draft.change(() => draft.loadingDebt = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (debt) => draft.change(() {
        draft.debt = debt;
        // Como la web: en dólares si solo debe dólares; en soles en cualquier otro caso.
        draft.moneda = debt.dolares > 0 && debt.soles == 0 ? 'dolares' : 'soles';
        draft.loadingDebt = false;
      }),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = payments.now;
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.date ?? today,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year + 1, 12, 31),
      helpText: 'Fecha de pago',
    );
    if (picked != null) draft.change(() => draft.date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final dolares = draft.moneda == 'dolares';
        final symbol = dolares ? r'$.' : 'S/.';
        final debtInMoneda = dolares ? draft.debt.dolares : draft.debt.soles;
        final monedaLabel = dolares ? 'dólares' : 'soles';

        Widget debtFigure(String label, double value, String currency, bool selected) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(
                    sellerPaymentMoney(value, currency),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPickerField(
              label: 'Cliente',
              value: draft.loadingClients ? 'Cargando…' : (draft.client?.name ?? 'Buscar cliente'),
              icon: Icons.person_outline,
              onTap: () => _pickClient(context),
              onClear: draft.client == null
                  ? null
                  : () => draft.change(() {
                        draft.client = null;
                        draft.debt = const SellerClientDebt();
                        draft.moneda = 'soles';
                        draft.resetLines();
                      }),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Deudas del cliente', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  AppDropdownField<String>(
                    key: ValueKey('moneda-${draft.moneda}'),
                    label: 'Moneda',
                    value: draft.moneda,
                    items: const [
                      DropdownMenuItem(value: 'soles', child: Text('Soles')),
                      DropdownMenuItem(value: 'dolares', child: Text('Dólares')),
                    ],
                    onChanged: (v) {
                      if (v == null || v == draft.moneda) return;
                      // Sin monto por defecto: al cambiar de moneda se vuelve a empezar.
                      draft.change(() {
                        draft.moneda = v;
                        draft.resetLines();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      debtFigure('Deuda en soles', draft.debt.soles, 'soles', !dolares),
                      debtFigure('Deuda en dólares', draft.debt.dolares, 'dolares', dolares),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (draft.loadingDebt)
                    Text('Consultando la deuda…', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
                  else
                    Text(
                      debtInMoneda > 0
                          ? 'Se distribuirá el depósito sobre las cuotas más antiguas en $monedaLabel.'
                          : 'El cliente no tiene deuda en $monedaLabel: el monto ingresado se guardará como anticipo.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(labelText: 'Deuda total ${dolares ? 'dólares' : 'soles'}'),
              child: Text(sellerPaymentMoney(debtInMoneda, draft.moneda)),
            ),
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Fecha de pago',
              value: draft.date == null ? 'Hoy' : DateFormat(AppConstants.dateFormat).format(draft.date!),
              icon: Icons.event_outlined,
              onTap: () => _pickDate(context),
              onClear: draft.date == null ? null : () => draft.change(() => draft.date = null),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < draft.lines.length; i++) ...[
              _LineCard(
                key: ValueKey('linea-${draft.lines[i].id}'),
                index: i,
                line: draft.lines[i],
                methods: methods,
                symbol: symbol,
                onRemove: i == 0 ? null : () => draft.change(() => draft.lines.removeAt(i).dispose()),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () => draft.change(() => draft.lines.add(_LineDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar método de pago'),
            ),
          ],
        );
      },
    );
  }
}

class _LineCard extends StatelessWidget {
  final int index;
  final _LineDraft line;
  final List<SellerPaymentOption> methods;
  final String symbol;
  final VoidCallback? onRemove;

  const _LineCard({
    super.key,
    required this.index,
    required this.line,
    required this.methods,
    required this.symbol,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
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
                  tooltip: 'Quitar método de pago',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppDropdownField<int>(
            label: 'Método de pago',
            value: line.methodId,
            items: [for (final m in methods) DropdownMenuItem(value: m.id, child: Text(m.name))],
            validator: (v) => v == null ? 'Elige el método de pago' : null,
            onChanged: (v) => line.methodId = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: line.monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _moneyFormatters,
            decoration: InputDecoration(labelText: 'Monto', prefixText: '$symbol '),
            validator: _validateAmount,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: line.descripcion,
            maxLines: 2,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(labelText: 'Descripción adicional'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Editar pago
// ---------------------------------------------------------------------------------------------

/// "Editar Pago de Cuota" (o "Editar Pago (Saldo a Favor)"): el método de pago, el monto y la
/// descripción. Un saldo a favor solo deja editar el método y la descripción; un pago ya confirmado,
/// todo menos el monto. Devuelve `true` si se guardó.
Future<bool?> showSellerPaymentEdit(BuildContext context, SellerPaymentEntity payment) async {
  final payments = context.read<SellerPaymentsProvider>();
  final List<SellerPaymentOption> methods;
  try {
    methods = await payments.loadPaymentMethods();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
    return null;
  }
  if (!context.mounted) return null;

  final allocation = payment.editAllocation;
  final saldoAFavor = allocation == null;
  final confirmed = allocation?.confirmed ?? false;

  // Como la web: el monto de un pago agrupado es el total del pago; el método y la descripción, los de
  // la parte que se edita (o los del propio pago si es un saldo a favor).
  final currentAmount = saldoAFavor ? payment.montoTotal : (allocation.paymentTotal ?? allocation.monto);
  final currentMethod = saldoAFavor ? payment.paymentMethodId : allocation.paymentMethodId;
  final currentDescription = saldoAFavor ? payment.descripcion : allocation.descripcionAdicional;

  final formKey = GlobalKey<FormState>();
  final monto = TextEditingController(
    text: currentAmount == currentAmount.roundToDouble() ? '${currentAmount.toInt()}' : '$currentAmount',
  );
  final descripcion = TextEditingController(text: currentDescription ?? '');
  final error = ValueNotifier<String?>(null);
  // El método actual puede no estar en la lista (Crédito, Contraentrega y Puntos no se ofrecen).
  int? methodId = methods.any((m) => m.id == currentMethod) ? currentMethod : null;

  final theme = Theme.of(context);

  return showAppModal(
    context,
    title: saldoAFavor ? 'Editar Pago (Saldo a Favor)' : 'Editar Pago de Cuota',
    subtitle: payment.cliente,
    icon: Icons.edit_outlined,
    primaryLabel: 'Editar',
    formKey: formKey,
    error: error,
    child: AppDisposer(
      onDispose: [monto.dispose, descripcion.dispose, error.dispose],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (saldoAFavor) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este es un pago de saldo a favor. Solo puedes editar el método de pago y la descripción.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppDropdownField<int>(
            label: 'Método de pago',
            value: methodId,
            items: [for (final m in methods) DropdownMenuItem(value: m.id, child: Text(m.name))],
            validator: (v) => v == null ? 'Elige el método de pago' : null,
            onChanged: (v) => methodId = v,
          ),
          const SizedBox(height: 16),
          if (saldoAFavor)
            AppDetailRow(label: 'Monto', value: sellerPaymentMoney(currentAmount, payment.moneda))
          else
            TextFormField(
              controller: monto,
              // Un pago confirmado no cambia de monto.
              enabled: !confirmed,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _moneyFormatters,
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: '${payment.simbolo} ',
              ),
              validator: confirmed ? null : _validateAmount,
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: descripcion,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(labelText: 'Descripción adicional'),
            // El servidor limita la descripción de un saldo a favor a 255 caracteres.
            validator: (v) => saldoAFavor && (v ?? '').trim().length > 255 ? 'Máximo 255 caracteres' : null,
          ),
        ],
      ),
    ),
    onPrimary: () async {
      error.value = null;
      final result = await payments.editPayment(
        payment,
        paymentMethodId: methodId!,
        monto: saldoAFavor || confirmed ? null : _parseMoney(monto.text),
        descripcion: _text(descripcion.text),
      );
      if (result.isLeft) {
        error.value = result.left.message;
        throw StateError(result.left.message);
      }
    },
  );
}
