import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/sale_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/sales_provider.dart';
import '../utils/success_snack.dart';
import '../widgets/client_modals.dart';
import '../widgets/exchange_rate_badge.dart';
import '../widgets/sale_checkout.dart';
import '../widgets/sale_line_card.dart';
import '../widgets/sale_free_item.dart';
import '../widgets/sale_modals.dart';
import '../widgets/sale_product_entry.dart';

/// Módulo Ventas: registra una venta o una cotización — comprobante, cliente, productos con su
/// precio y stock, y en el modal "Crear venta" las formas de pago (al contado, a crédito con
/// cuotas, con puntos), en soles o en dólares según la lista de precios. También culmina una
/// cotización como venta o la edita.
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

  /// Cambia la descripción y el código de un ítem libre ya agregado.
  Future<void> _editFree(SaleLineEntity line) async {
    final info = await showFreeItemEdit(context, line);
    if (info != null && mounted) _snack(info);
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
      showSuccessSnack(context, 'Cliente creado');
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
    // Igual que la web: vender a un cliente de la cartera de otro ejecutivo pide confirmación. El
    // vendedor de la venta es el de la cotización que se culmina, o quien la registra.
    final ejecutivoId = client.ejecutivoComercialId;
    final vendedorId = sales.vendedorDeCotizacion ?? session?.user.id;
    final esMiVenta = vendedorId == session?.user.id;
    if (!client.esVarios && ejecutivoId != null && vendedorId != null && ejecutivoId != vendedorId) {
      final seguir = await showAppConfirm(
        context,
        title: tipo.esCotizacion ? '¿Deseas continuar con la cotización?' : '¿Deseas continuar con la venta?',
        subtitle: client.name,
        icon: Icons.groups_outlined,
        message: 'Este cliente no pertenece a ${esMiVenta ? 'tu' : 'la'} cartera comercial. '
            '${client.ejecutivoComercial != null ? 'Actualmente está asignado a ${client.ejecutivoComercial}.' : 'Actualmente está asignado a otro ejecutivo.'}',
        confirmLabel: 'Sí, continuar',
        tone: AppModalTone.warning,
      );
      if (!seguir || !mounted) return;
    }

    var ok = false;
    if (tipo.esCotizacion) {
      // La cotización pregunta si reserva el stock y hasta cuándo, y quién es el vendedor encargado.
      await sales.ensureSellers();
      if (!mounted) return;
      final options = await showQuoteOptions(
        context,
        now: DateTime.now(),
        client: client.name,
        total: formatMoney(sales.total, symbol: sales.moneySymbol),
        sellers: sales.sellers,
        initialSellerId: sales.vendedorDeCotizacion,
        excludeSellerId: session?.user.id,
        editing: sales.fromQuote != null,
      );
      if (options == null || !mounted) return;
      ok = await sales.submit(
        reservarStock: options.reservarStock,
        vencimientoStock: options.vencimientoStock,
        vendedorId: options.vendedorId,
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
          subtitle: 'Ventas y cotizaciones.',
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
                    if (sales.fromQuote != null || sales.quoteLoading || sales.quoteError != null) ...[
                      _quoteBanner(sales),
                      const SizedBox(height: 16),
                    ],
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

  /// Aviso de que se está culminando o editando una cotización, con "Cancelar" (como en la web).
  Widget _quoteBanner(SalesProvider sales) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quote = sales.fromQuote;

    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: quote == null && sales.quoteError != null
                  ? Text(
                      sales.quoteError!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
                    )
                  : quote == null
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cargando la cotización…',
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onTertiaryContainer),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Está trabajando con la Cotización Nro: ${quote.numero}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            if (quote != null || sales.quoteError != null)
              TextButton(
                onPressed: () {
                  sales.cancelQuote();
                  _observaciones.clear();
                },
                child: Text(quote != null ? 'Cancelar' : 'Cerrar'),
              ),
          ],
        ),
      ),
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
          // Quitar una línea (y deshacerlo) y el resumen de líneas e ítems.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sales.lines.length; i++) ...[
                  SaleLineCard(
                    key: ObjectKey(sales.lines[i].product),
                    line: sales.lines[i],
                    problem: sales.lineProblem(sales.lines[i]),
                    symbol: sales.moneySymbol,
                    maxQuantity: sales.warehouseId == null
                        ? null
                        : sales.lines[i].product.maximoEn(sales.warehouseId!),
                    listPrice: sales.lines[i].esLibre || sales.priceListId == null
                        ? null
                        : sales.lines[i].product.precioEn(sales.priceListId!),
                    onQuantity: (n) {
                      final aviso = sales.setCantidad(i, n);
                      if (aviso != null) _snack(aviso);
                    },
                    onPrice: (v) => sales.setPrecio(i, v),
                    onDto: (v) => sales.setDto(i, v),
                    onToggleDto: () => sales.toggleDtoFijo(i),
                    onRemove: () => _removeLine(sales, i),
                    onEditFree: sales.lines[i].esLibre ? () => _editFree(sales.lines[i]) : null,
                  ),
                  if (i < sales.lines.length - 1) const SizedBox(height: 12),
                ],
                if (sales.lines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _linesSummary(sales),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Quita la línea y avisa con "Deshacer" (si se tocó el basurero sin querer, vuelve a su lugar).
  void _removeLine(SalesProvider sales, int index) {
    final removed = sales.lines[index];
    sales.removeLine(index);
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Quitaste "${removed.product.name}"', maxLines: 1, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => sales.restoreLine(index, removed),
          ),
        ),
      );
  }

  /// "3 líneas · 5 ítems" (en la web: "Nr. Líneas: 3 / Tot. Ítems: 5").
  Widget _linesSummary(SalesProvider sales) {
    final theme = Theme.of(context);
    final lines = sales.lines.length;
    final items = sales.lines.fold<int>(0, (sum, l) => sum + l.cantidad);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.shopping_bag_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$lines ${lines == 1 ? 'línea' : 'líneas'} · $items ${items == 1 ? 'ítem' : 'ítems'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
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
                              formatMoney(sales.total, symbol: sales.moneySymbol),
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
