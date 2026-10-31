import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/document_entity.dart';
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

/// Lo que se decide al crear una cotización.
typedef QuoteOptions = ({bool reservarStock, DateTime? vencimientoStock});

/// Último día en que se puede reservar el stock: el siguiente al de hoy, y como mucho el
/// final del mes (igual que la web).
DateTime quoteDefaultExpiry(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final endOfMonth = DateTime(now.year, now.month + 1, 0);
  return tomorrow.isAfter(endOfMonth) ? endOfMonth : tomorrow;
}

/// Pregunta si la cotización reserva el stock y hasta qué día, y confirma su creación.
/// Devuelve `null` si se cancela.
Future<QuoteOptions?> showQuoteOptions(
  BuildContext context, {
  required DateTime now,
  required String client,
  required String total,
}) async {
  final today = DateTime(now.year, now.month, now.day);
  final endOfMonth = DateTime(now.year, now.month + 1, 0);
  final reserve = ValueNotifier<bool>(false);
  final expiry = ValueNotifier<DateTime>(quoteDefaultExpiry(now));

  final confirmed = await showAppModal(
    context,
    title: 'Crear cotización',
    subtitle: '$client · $total',
    icon: Icons.request_quote_outlined,
    primaryLabel: 'Crear',
    child: AppDisposer(
      onDispose: [reserve.dispose, expiry.dispose],
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
          ],
        ),
      ),
    ),
  );

  return confirmed == true
      ? (
          reservarStock: reserve.value,
          vencimientoStock: reserve.value ? expiry.value : null,
        )
      : null;
}
