import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/document_entity.dart';
import '../components/components.dart';
import '../providers/documents_provider.dart';

String _dateTime(DateTime? d) =>
    d == null ? '-' : DateFormat(AppConstants.dateTimeFormat).format(d);

/// Estado del documento como badge: en ventas, activo o eliminado; en
/// cotizaciones, usada, reservada o sin reserva.
({String label, AppBadgeTone tone}) documentStatus(DocumentEntity d) {
  if (d.kind == DocumentKind.cotizacion) {
    if (!d.activo) return (label: 'Usada', tone: AppBadgeTone.neutral);
    return d.reservado == true
        ? (label: 'Reservada', tone: AppBadgeTone.success)
        : (label: 'Sin reserva', tone: AppBadgeTone.warning);
  }
  return d.activo
      ? (label: 'Activo', tone: AppBadgeTone.success)
      : (label: 'Eliminado', tone: AppBadgeTone.danger);
}

/// Modal "ver detalle" de una venta o cotización: general, productos y pagos.
Future<bool?> showDocumentDetail(BuildContext context, DocumentEntity d) {
  final status = documentStatus(d);

  return showAppModal(
    context,
    title: d.numero,
    subtitle: d.cliente,
    icon: d.kind == DocumentKind.cotizacion
        ? Icons.request_quote_outlined
        : Icons.receipt_long_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    tabs: [
      AppTabItem(
        label: 'General',
        icon: Icons.info_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailRow(label: 'Comprobante', value: d.comprobante),
            AppDetailRow(label: 'Cliente', value: d.cliente),
            AppDetailRow(label: 'Fecha', value: _dateTime(d.creado)),
            AppDetailRow(
              label: 'Total',
              value: formatMoney(d.monto, symbol: d.simboloMoneda),
            ),
            AppDetailRow(label: 'Registrado por', value: d.usuario),
            AppDetailRow(label: 'Ejecutivo', value: d.vendedor),
            AppDetailRow(label: 'Almacén', value: d.almacen),
            if (d.descuento > 0)
              AppDetailRow(
                label: 'Descuento',
                value: formatMoney(d.descuento, symbol: d.simboloMoneda),
              ),
            if (d.esDolares && d.tipoCambio != null)
              AppDetailRow(label: 'Tipo de cambio', value: 'S/ ${d.tipoCambio}'),
            AppDetailRow(
              label: 'Estado',
              valueWidget: AppStatusBadge(label: status.label, tone: status.tone),
            ),
            if (d.esCotizacion && d.reservado == true && d.vencimientoStock != null)
              AppDetailRow(
                label: 'Stock reservado hasta',
                value: DateFormat(AppConstants.dateFormat).format(d.vencimientoStock!),
              ),
            if (d.boleta?.tieneNotaCredito == true)
              const AppDetailRow(label: 'Nota de crédito', value: 'Emitida'),
            if (d.boleta?.tieneGuia == true)
              const AppDetailRow(label: 'Guía de remisión', value: 'Creada'),
            if (!d.activo && d.kind == DocumentKind.venta) ...[
              AppDetailRow(label: 'Anulado por', value: d.anuladoPor ?? 'Sin registro'),
              if (d.anuladoAt != null)
                AppDetailRow(label: 'Anulado el', value: _dateTime(d.anuladoAt)),
            ],
            if (d.observaciones != null && d.observaciones!.isNotEmpty)
              AppDetailRow(label: 'Observaciones', value: d.observaciones),
          ],
        ),
      ),
      AppTabItem(
        label: 'Productos',
        icon: Icons.shopping_bag_outlined,
        badge: d.items.length,
        child: d.items.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Sin productos')),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final i in d.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppItemCard(
                        title: i.name,
                        subtitle: [
                          if (i.codigo != null && i.codigo!.isNotEmpty) i.codigo!,
                          if (i.marca != null && i.marca!.isNotEmpty) i.marca!,
                        ].join(' · '),
                        columns: [
                          AppItemColumn('Cant.', formatQuantity(i.cantidad)),
                          AppItemColumn(
                            'Precio',
                            formatMoney(i.precio, symbol: i.dolares ? r'$' : 'S/'),
                          ),
                          AppItemColumn(
                            'Subtotal',
                            formatMoney(i.subtotal, symbol: i.dolares ? r'$' : 'S/'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      if (d.pagos.isNotEmpty)
        AppTabItem(
          label: 'Pagos',
          icon: Icons.payments_outlined,
          badge: d.pagos.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in d.pagos)
                AppDetailRow(
                  label: p.metodo,
                  value: formatMoney(p.monto, symbol: d.simboloMoneda),
                ),
            ],
          ),
        ),
    ],
  );
}

/// Formulario de la nota de crédito de una boleta o factura (igual que la web: fecha de
/// emisión de hoy o de los dos días anteriores y una descripción obligatoria). Devuelve
/// `true` si se creó.
Future<bool?> showCreditNoteForm(BuildContext context, DocumentEntity d) {
  final documents = context.read<DocumentsProvider>();
  final formKey = GlobalKey<FormState>();
  final description = TextEditingController();
  final error = ValueNotifier<String?>(null);
  final today = DateUtils.dateOnly(documents.now);
  final date = ValueNotifier<DateTime>(today);

  final result = showAppModal(
    context,
    title: 'Nota de crédito',
    subtitle: d.numero,
    icon: Icons.block,
    tone: AppModalTone.danger,
    primaryLabel: 'Crear',
    formKey: formKey,
    error: error,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Se emitirá una nota de crédito sobre ${d.comprobante.toLowerCase()} ${d.numero} '
          'y se enviará a SUNAT. No se puede deshacer.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text('Fecha de emisión', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        ValueListenableBuilder<DateTime>(
          valueListenable: date,
          builder: (context, selected, _) => Wrap(
            spacing: 8,
            children: [
              for (final (label, days) in const [('Hoy', 0), ('Ayer', 1), ('Anteayer', 2)])
                ChoiceChip(
                  label: Text(label),
                  selected: selected == today.subtract(Duration(days: days)),
                  onSelected: (_) => date.value = today.subtract(Duration(days: days)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: description,
          label: 'Descripción (razón para anular)',
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'La descripción es obligatoria' : null,
        ),
      ],
    ),
    onPrimary: () async {
      error.value = null;
      final outcome = await documents.createCreditNote(
        document: d,
        descripcion: description.text,
        fechaEmision: date.value,
      );
      if (outcome.isLeft) {
        // El modal sigue abierto con el mensaje del servidor.
        error.value = outcome.left.message;
        throw StateError(outcome.left.message);
      }
    },
  );

  return result.whenComplete(() {
    description.dispose();
    error.dispose();
    date.dispose();
  });
}
