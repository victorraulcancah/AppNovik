import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/sale_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/sales_provider.dart';
import '../widgets/client_modals.dart';
import '../widgets/exchange_rate_badge.dart';
import '../widgets/sale_checkout.dart';
import '../widgets/sale_modals.dart';
import '../widgets/sale_product_entry.dart';

/// Módulo Ventas: registra una venta al contado en soles — comprobante, cliente,
/// productos con su precio y stock, y una forma de pago. Las ventas a crédito,
/// en dólares, con puntos y las cotizaciones llegan después.
class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _observaciones = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canSell) context.read<SalesProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _observaciones.dispose();
    super.dispose();
  }

  bool get _canSell =>
      context.read<AuthProvider>().session?.can('ventas.store') ?? false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickClient() async {
    final sales = context.read<SalesProvider>();
    await showAppSearchSheet<ClientEntity>(
      context,
      title: 'Cliente',
      subtitle: 'Busca por nombre, documento o código',
      icon: Icons.person_search_outlined,
      hint: 'Nombre, DNI/RUC o código',
      search: sales.searchClients,
      itemOf: (c) => AppSearchItem(
        title: c.name,
        subtitle: [
          if (c.documento != null) c.documento!,
          if (c.tipo != null) (c.esPersona ? 'Persona' : 'Empresa'),
        ].join(' · '),
      ),
      onSelect: (c) {
        sales.selectClient(c);
        return null;
      },
    );
  }

  Future<void> _createClient() async {
    final sales = context.read<SalesProvider>();
    final created = await showCreateClientForm(context);
    if (created != null && mounted) {
      sales.selectClient(created);
      _snack('Cliente creado');
    }
  }

  Future<void> _toggleSinDocumento(bool on) async {
    final problem = await context.read<SalesProvider>().toggleSinDocumento(on);
    if (problem != null && mounted) _snack(problem);
  }

  Future<void> _submit() async {
    final sales = context.read<SalesProvider>();
    final session = context.read<AuthProvider>().session;
    FocusScope.of(context).unfocus();
    if (!sales.prepare()) return;

    final client = sales.client!;
    final tipo = sales.tipoDocumento;
    // Igual que la web: vender a un cliente de la cartera de otro ejecutivo pide confirmación.
    final ejecutivoId = client.ejecutivoComercialId;
    if (!client.esVarios && ejecutivoId != null && ejecutivoId != session?.user.id) {
      final seguir = await showAppConfirm(
        context,
        title: tipo.esCotizacion ? '¿Deseas continuar con la cotización?' : '¿Deseas continuar con la venta?',
        subtitle: client.name,
        icon: Icons.groups_outlined,
        message: 'Este cliente no pertenece a tu cartera comercial. '
            '${client.ejecutivoComercial != null ? 'Actualmente está asignado a ${client.ejecutivoComercial}.' : 'Actualmente está asignado a otro ejecutivo.'}',
        confirmLabel: 'Sí, continuar',
        tone: AppModalTone.warning,
      );
      if (!seguir || !mounted) return;
    }

    var ok = false;
    if (tipo.esCotizacion) {
      // La cotización pregunta si reserva el stock y hasta cuándo.
      final options = await showQuoteOptions(
        context,
        now: DateTime.now(),
        client: client.name,
        total: formatMoney(sales.total),
      );
      if (options == null || !mounted) return;
      ok = await sales.submit(
        reservarStock: options.reservarStock,
        vencimientoStock: options.vencimientoStock,
      );
    } else {
      // La venta se arma y se crea en el modal "Crear venta" (fecha, entrega y pagos).
      ok = await showSaleCheckout(context, sales: sales);
    }
    if (!mounted) return;
    if (ok) {
      _observaciones.clear();
      await showSaleRegistered(context, sales.lastSale!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    final canSell = context.read<AuthProvider>().session?.can('ventas.store') ?? false;

    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.point_of_sale_outlined,
          title: 'Ventas',
          subtitle: 'Venta al contado en soles.',
          trailing: AppAccountMenu(),
        ),
        Expanded(child: _body(sales, canSell)),
      ],
    );
  }

  Widget _body(SalesProvider sales, bool canSell) {
    if (!canSell) {
      return const AppEmptyState(
        icon: Icons.lock_outline,
        title: 'Sin acceso',
        message: 'No tienes permiso para registrar ventas.',
      );
    }
    if (sales.loading && sales.warehouses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sales.error != null && sales.warehouses.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo preparar la venta',
        message: sales.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: sales.retry),
      );
    }
    if (sales.warehouses.isEmpty || sales.priceLists.isEmpty || sales.paymentMethods.isEmpty) {
      return AppEmptyState(
        icon: Icons.settings_outlined,
        title: 'Falta configuración',
        message: [
          if (sales.warehouses.isEmpty) 'No tienes almacenes asignados.',
          if (sales.priceLists.isEmpty) 'No hay listas de precios en soles.',
          if (sales.paymentMethods.isEmpty) 'No tienes formas de pago al contado.',
        ].join(' '),
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: sales.retry),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _comprobante(sales),
                    const SizedBox(height: 16),
                    _cliente(sales),
                    const SizedBox(height: 16),
                    _productos(sales),
                    // En una venta, la fecha, la entrega, los pagos y las observaciones van en el
                    // modal "Crear venta"; la cotización solo lleva observaciones.
                    if (sales.tipoDocumento.esCotizacion) ...[
                      const SizedBox(height: 16),
                      _pago(sales),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _bottomBar(sales),
      ],
    );
  }

  Widget _comprobante(SalesProvider sales) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppSection(
      title: 'Comprobante',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdownField<SaleDocumentType>(
            key: ValueKey('tipo-${sales.tipoDocumento}'),
            label: 'Tipo de documento',
            value: sales.tipoDocumento,
            items: [
              for (final t in sales.documentTypes)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => v == null ? null : sales.selectTipoDocumento(v),
          ),
          if (sales.facturaAPersona)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Text(
                'No se puede emitir Factura a un cliente de tipo Persona.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (sales.tipoDocumento.esCotizacion)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Text(
                'La cotización no cobra ni descuenta stock, salvo que reserves el stock.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          if (sales.puedeSinDocumento || sales.sinDocumento)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: sales.sinDocumento,
              onChanged: sales.sinDocumentoLoading ? null : (v) => _toggleSinDocumento(v ?? false),
              title: const Text('Emitir sin documento del cliente (venta menor a S/700)'),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ExchangeRateBadge(
              rate: sales.exchangeRate,
              loading: sales.exchangeRateLoading,
              onRefresh: sales.loadExchangeRate,
            ),
          ),
          const SizedBox(height: 12),
          AppDropdownField<int>(
            key: ValueKey('almacen-${sales.warehouseId}'),
            label: 'Almacén',
            value: sales.warehouseId,
            items: [
              for (final w in sales.warehouses)
                DropdownMenuItem(value: w.id, child: Text(w.name)),
            ],
            onChanged: sales.selectWarehouse,
          ),
          const SizedBox(height: 12),
          AppDropdownField<int>(
            key: ValueKey('lista-${sales.priceListId}'),
            label: 'Lista de precios',
            value: sales.priceListId,
            items: [
              for (final p in sales.priceLists)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: sales.selectPriceList,
          ),
        ],
      ),
    );
  }

  Widget _cliente(SalesProvider sales) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final client = sales.client;
    final canCreate = context.read<AuthProvider>().session?.can('clientes.store') ?? false;
    // Con "sin documento" el cliente es siempre "CLIENTE VARIOS": no se cambia ni se crea otro.
    final locked = sales.sinDocumento || sales.sinDocumentoLoading;

    return AppSection(
      title: 'Cliente',
      icon: Icons.person_outline,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: locked ? null : _pickClient,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Icon(client == null ? Icons.person_search_outlined : Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: client == null
                          ? Text(
                              'Elegir cliente',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (client.documento != null)
                                  Text(
                                    client.documento!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    if (!locked)
                      Text(
                        client == null ? 'Buscar' : 'Cambiar',
                        style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (canCreate && !locked) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Crear cliente',
              onPressed: _createClient,
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ],
        ],
      ),
    );
  }

  Widget _productos(SalesProvider sales) {
    return AppSection(
      title: sales.lines.isEmpty ? 'Productos' : 'Productos (${sales.lines.length})',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SaleProductEntry(),
          if (sales.lines.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
          ],
          for (var i = 0; i < sales.lines.length; i++) ...[
            _SaleLineTile(
              key: ObjectKey(sales.lines[i].product),
              line: sales.lines[i],
              problem: sales.lineProblem(sales.lines[i]),
              onQuantity: (n) {
                final aviso = sales.setCantidad(i, n);
                if (aviso != null) _snack(aviso);
              },
              onPrice: (v) => sales.setPrecio(i, v),
              onRemove: () => sales.removeLine(i),
            ),
            if (i < sales.lines.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  /// Observaciones de la cotización (la venta las pide en el modal "Crear venta").
  Widget _pago(SalesProvider sales) {
    return AppSection(
      title: 'Observaciones',
      icon: Icons.notes_outlined,
      child: AppTextField(
        controller: _observaciones,
        label: 'Observaciones (opcional)',
        maxLines: 2,
        keyboardType: TextInputType.multiline,
      ),
    );
  }

  Widget _bottomBar(SalesProvider sales) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sales.submitError != null) ...[
                    ErrorBanner(message: sales.submitError!),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              formatMoney(sales.total),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: AppButton(
                          label: sales.tipoDocumento.esCotizacion ? 'Crear cotización' : 'Registrar venta',
                          loading: sales.submitting,
                          onPressed: () {
                            sales.setObservaciones(_observaciones.text);
                            _submit();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una línea de la venta: producto, cantidad con − / +, precio editable y subtotal.
class _SaleLineTile extends StatefulWidget {
  final SaleLineEntity line;
  final String? problem;
  final ValueChanged<int> onQuantity;
  final ValueChanged<double> onPrice;
  final VoidCallback onRemove;

  const _SaleLineTile({
    super.key,
    required this.line,
    required this.problem,
    required this.onQuantity,
    required this.onPrice,
    required this.onRemove,
  });

  @override
  State<_SaleLineTile> createState() => _SaleLineTileState();
}

class _SaleLineTileState extends State<_SaleLineTile> {
  late final _quantity = TextEditingController(text: '${widget.line.cantidad}');
  late final _price = TextEditingController(text: _priceText(widget.line.precio));
  final _quantityFocus = FocusNode();
  final _priceFocus = FocusNode();

  static String _priceText(double v) => v == 0 ? '' : v.toStringAsFixed(2);

  @override
  void didUpdateWidget(_SaleLineTile old) {
    super.didUpdateWidget(old);
    // Lo cambió otra cosa (la lista de precios, el tope de stock): se refleja en el campo.
    if (!_quantityFocus.hasFocus && _quantity.text != '${widget.line.cantidad}') {
      _quantity.text = '${widget.line.cantidad}';
    }
    if (!_priceFocus.hasFocus && (double.tryParse(_price.text) ?? 0) != widget.line.precio) {
      _price.text = _priceText(widget.line.precio);
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _quantityFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = widget.line;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.problem == null ? scheme.outlineVariant : scheme.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Producto y botón para quitarlo.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [line.product.codigo, ?line.product.marca].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar',
                onPressed: widget.onRemove,
                icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Cantidad y precio, cada uno con todo el ancho que necesita.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _QuantityField(
                    controller: _quantity,
                    focusNode: _quantityFocus,
                    onMinus: () => widget.onQuantity(line.cantidad - 1),
                    onPlus: () => widget.onQuantity(line.cantidad + 1),
                    onChanged: (text) {
                      final n = int.tryParse(text);
                      if (n != null && n >= 1) widget.onQuantity(n);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _price,
                    focusNode: _priceFocus,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: const InputDecoration(labelText: 'Precio S/', hintText: '0'),
                    onChanged: (text) => widget.onPrice(double.tryParse(text) ?? 0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // El aviso (si lo hay) a la izquierda y el subtotal de la línea a la derecha.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: widget.problem == null
                      ? const SizedBox.shrink()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.problem!,
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Subtotal  ',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  formatMoney(line.subtotal),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cantidad: un campo numérico con los botones − y + dentro, para que ocupe el mismo
/// ancho y alto que el campo de precio.
class _QuantityField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onChanged;

  const _QuantityField({
    required this.controller,
    required this.focusNode,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const buttonSize = BoxConstraints(minWidth: 38, minHeight: 44);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Cantidad',
        prefixIcon: IconButton(
          tooltip: 'Menos',
          onPressed: onMinus,
          icon: const Icon(Icons.remove, size: 20),
        ),
        prefixIconConstraints: buttonSize,
        suffixIcon: IconButton(
          tooltip: 'Más',
          onPressed: onPlus,
          icon: const Icon(Icons.add, size: 20),
        ),
        suffixIconConstraints: buttonSize,
      ),
      onChanged: onChanged,
    );
  }
}
