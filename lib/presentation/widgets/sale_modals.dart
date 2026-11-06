import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/sale_entity.dart';
import '../components/components.dart';
import '../pages/receipt_page.dart';
import 'document_modals.dart';

/// Confirmación de una venta o cotización recién registrada: número, cliente, total y pagos.
/// Desde aquí se abre el comprobante en PDF (para descargarlo, compartirlo o imprimirlo) o el
/// detalle completo del documento.
Future<void> showSaleRegistered(
  BuildContext context,
  DocumentEntity sale,
) async {
  HapticFeedback.mediumImpact();
  final verPdf = await showAppModal(
    context,
    title: sale.esCotizacion ? 'Cotización registrada' : 'Venta registrada',
    subtitle: sale.numero,
    icon: Icons.check_circle_outline,
    primaryLabel: 'Descargar PDF',
    secondaryLabel: sale.esCotizacion ? 'Nueva cotización' : 'Nueva venta',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Center(child: AppSuccessCheck(size: 64)),
        ),
        AppDetailRow(label: 'Comprobante', value: sale.comprobante),
        AppDetailRow(label: 'Cliente', value: sale.cliente),
        AppDetailRow(label: 'Almacén', value: sale.almacen),
        AppDetailRow(
          label: 'Total',
          value: formatMoney(sale.monto, symbol: sale.simboloMoneda),
        ),
        if (sale.esCotizacion)
          AppDetailRow(
            label: 'Stock',
            value: sale.reservado == true && sale.vencimientoStock != null
                ? 'Reservado hasta ${DateFormat(AppConstants.dateFormat).format(sale.vencimientoStock!)}'
                : 'Sin reserva',
          ),
        for (final p in sale.pagos)
          AppDetailRow(
            label: p.metodo,
            value: formatMoney(p.monto, symbol: sale.simboloMoneda),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showDocumentDetail(context, sale),
            icon: const Icon(Icons.list_alt_outlined, size: 18),
            label: const Text('Ver detalle'),
          ),
        ),
      ],
    ),
  );
  if (verPdf == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReceiptPage(document: sale)),
    );
  }
}

/// Lo que se decide al crear una cotización: si reserva el stock (y hasta cuándo) y el vendedor
/// encargado (opcional).
typedef QuoteOptions = ({bool reservarStock, DateTime? vencimientoStock, int? vendedorId});

/// Último día en que se puede reservar el stock: el siguiente al de hoy, y como mucho el
/// final del mes (igual que la web).
DateTime quoteDefaultExpiry(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final endOfMonth = DateTime(now.year, now.month + 1, 0);
  return tomorrow.isAfter(endOfMonth) ? endOfMonth : tomorrow;
}

/// Pregunta si la cotización reserva el stock y hasta qué día, quién es el vendedor encargado, y
/// confirma su creación (o su edición con [editing]). Devuelve `null` si se cancela.
///
/// El vendedor encargado es opcional: [sellers] son los que se pueden elegir (sin [excludeSellerId],
/// que es el propio usuario) y [initialSellerId] el que ya tenía la cotización que se edita.
Future<QuoteOptions?> showQuoteOptions(
  BuildContext context, {
  required DateTime now,
  required String client,
  required String total,
  List<SellerEntity> sellers = const [],
  int? initialSellerId,
  int? excludeSellerId,
  bool editing = false,
}) async {
  final today = DateTime(now.year, now.month, now.day);
  final endOfMonth = DateTime(now.year, now.month + 1, 0);
  final reserve = ValueNotifier<bool>(false);
  final expiry = ValueNotifier<DateTime>(quoteDefaultExpiry(now));
  final options = [for (final s in sellers) if (s.id != excludeSellerId) s];
  // El de la cotización puede ser el propio usuario o alguien que ya no está en la lista: se
  // conserva solo si se puede elegir.
  final seller = ValueNotifier<int?>(options.any((s) => s.id == initialSellerId) ? initialSellerId : null);

  final confirmed = await showAppModal(
    context,
    title: editing ? 'Editar cotización' : 'Crear cotización',
    subtitle: '$client · $total',
    icon: Icons.request_quote_outlined,
    primaryLabel: editing ? 'Editar' : 'Crear',
    child: AppDisposer(
      onDispose: [reserve.dispose, expiry.dispose, seller.dispose],
      child: ValueListenableBuilder<bool>(
        valueListenable: reserve,
        builder: (context, reserving, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: reserving,
              onChanged: (v) => reserve.value = v,
              title: const Text('Reservar stock'),
              subtitle: const Text(
                'Aparta los productos para este cliente hasta la fecha que elijas.',
              ),
            ),
            if (reserving) ...[
              const SizedBox(height: 8),
              ValueListenableBuilder<DateTime>(
                valueListenable: expiry,
                builder: (context, date, _) => AppPickerField(
                  label: 'Límite para reservar stock',
                  value: DateFormat(AppConstants.dateFormat).format(date),
                  icon: Icons.event_outlined,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: today,
                      lastDate: endOfMonth,
                      helpText: 'Límite para reservar stock',
                    );
                    if (picked != null) expiry.value = picked;
                  },
                ),
              ),
            ],
            if (options.isNotEmpty) ...[
              const SizedBox(height: 12),
              ValueListenableBuilder<int?>(
                valueListenable: seller,
                builder: (context, selected, _) => AppDropdownField<int?>(
                  key: ValueKey('vendedor-$selected'),
                  label: 'Vendedor encargado (opcional)',
                  value: selected,
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Sin vendedor encargado')),
                    for (final s in options) DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => seller.value = v,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  return confirmed == true
      ? (
          reservarStock: reserve.value,
          vencimientoStock: reserve.value ? expiry.value : null,
          vendedorId: seller.value,
        )
      : null;
}
