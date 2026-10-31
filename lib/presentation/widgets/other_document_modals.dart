import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/other_document_entity.dart';
import '../components/components.dart';
import '../pages/receipt_page.dart';
import 'document_filters.dart';

final _dateTime = DateFormat(AppConstants.dateTimeFormat);

String _date(DateTime? d) => d == null ? '—' : _dateTime.format(d);

String _day(DateTime? d) => d == null ? '—' : documentFilterDate(d);

String _kg(double v) => '${formatQuantity(v)} KG.';

/// El detalle de un traslado, guía, nota de crédito o entrada de stock, con lo mismo que
/// muestra el documento de la web. Con [showAmounts] en `false` (Jefe de Almacén) no se ven
/// los importes. Las guías y notas de crédito pueden abrir el PDF de su comprobante.
Future<void> showOtherDocumentDetail(
  BuildContext context,
  OtherDocumentEntity d, {
  bool showAmounts = true,
}) async {
  final canOpenReceipt = d.comprobante != null;

  final verComprobante = await showAppModal(
    context,
    title: d.numero,
    subtitle: d.kind.label,
    icon: switch (d.kind) {
      OtherDocumentKind.traslado => Icons.local_shipping_outlined,
      OtherDocumentKind.guia => Icons.route_outlined,
      OtherDocumentKind.notaCredito => Icons.receipt_long_outlined,
      OtherDocumentKind.entradaStock => Icons.move_to_inbox_outlined,
    },
    primaryLabel: canOpenReceipt ? 'Ver comprobante' : null,
    secondaryLabel: 'Cerrar',
    child: _DetailBody(document: d, showAmounts: showAmounts),
  );

  if (verComprobante == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReceiptPage(document: d.comprobante!)),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final OtherDocumentEntity document;
  final bool showAmounts;

  const _DetailBody({required this.document, required this.showAmounts});

  @override
  Widget build(BuildContext context) {
    final d = document;
    final g = d.guia;
    final n = d.nota;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (d.kind) {
          OtherDocumentKind.traslado => _info([
              AppDetailRow(label: 'Fecha de emisión', value: _date(d.creado)),
              AppDetailRow(label: 'Usuario', value: d.usuario),
              AppDetailRow(label: 'Desde', value: d.desde),
              AppDetailRow(label: 'Hacia', value: d.hacia),
              AppDetailRow(
                label: 'Estado',
                valueWidget: !d.activo
                    ? const AppStatusBadge(label: 'Eliminado', tone: AppBadgeTone.danger)
                    : d.pendienteRecepcion
                        ? const AppStatusBadge(label: 'Falta recibir', tone: AppBadgeTone.warning)
                        : const AppStatusBadge(label: 'Recibido', tone: AppBadgeTone.success),
              ),
            ]),
          OtherDocumentKind.entradaStock => _info([
              AppDetailRow(label: 'Fecha de emisión', value: _date(d.creado)),
              AppDetailRow(label: 'Sucursal', value: d.almacen),
              AppDetailRow(label: 'Usuario', value: d.usuario),
            ]),
          OtherDocumentKind.guia => _info([
              AppDetailRow(label: 'Comprobante', value: d.comprobanteNumero),
              AppDetailRow(label: 'Fecha de emisión', value: _day(g?.fechaEmision)),
              AppDetailRow(label: 'Fecha de traslado', value: _day(g?.fechaTraslado)),
              AppDetailRow(label: 'Peso total', value: _kg(g?.pesoTotal ?? 0)),
              if (g?.tipoGuia != null)
                AppDetailRow(
                  label: 'Tipo de guía',
                  value: g!.tipoGuia == '02' ? 'Transportista' : 'Remitente',
                ),
              AppDetailRow(label: 'Salida', value: _address(g?.direccionSalida, g?.ubigeoSalida)),
              AppDetailRow(label: 'Llegada', value: _address(g?.direccionLlegada, g?.ubigeoLlegada)),
              if (g?.transportista != null)
                AppDetailRow(label: 'Transportista', value: g!.transportista),
              if (g?.documentoTransportista != null)
                AppDetailRow(label: 'Documento transportista', value: g!.documentoTransportista),
              if (g?.matricula != null) AppDetailRow(label: 'Matrícula', value: g!.matricula),
              if (g?.dniChofer != null) AppDetailRow(label: 'DNI del chofer', value: g!.dniChofer),
              if (g?.placaChofer != null) AppDetailRow(label: 'Placa', value: g!.placaChofer),
              if (g?.observaciones != null)
                AppDetailRow(label: 'Observaciones', value: g!.observaciones),
              AppDetailRow(label: 'Creado', value: _date(d.creado)),
            ]),
          OtherDocumentKind.notaCredito => _info([
              AppDetailRow(label: 'Comprobante', value: d.comprobanteNumero),
              AppDetailRow(label: 'Fecha de emisión', value: _day(n?.fechaEmision)),
              AppDetailRow(label: 'Motivo', value: n?.descripcion),
              AppDetailRow(label: 'Creado', value: _date(d.creado)),
            ]),
        },
        if (d.lines.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Productos', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final line in d.lines) _LineTile(kind: d.kind, line: line, showAmounts: showAmounts),
          const Divider(height: 24),
          AppDetailRow(label: 'Nro. de ítems', value: formatQuantity(d.unidades)),
          if (d.kind == OtherDocumentKind.entradaStock && showAmounts)
            AppDetailRow(label: 'Total', value: formatMoney(d.monto, symbol: 'S/.')),
        ],
      ],
    );
  }

  Widget _info(List<Widget> rows) => Column(children: rows);

  static String? _address(String? address, String? ubigeo) {
    final parts = [address, ubigeo].whereType<String>();
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _LineTile extends StatelessWidget {
  final OtherDocumentKind kind;
  final OtherDocumentLine line;
  final bool showAmounts;

  const _LineTile({required this.kind, required this.line, required this.showAmounts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detail = [if (line.codigo != null) line.codigo!, if (line.marca != null) line.marca!].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              formatQuantity(line.cantidad),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (detail.isNotEmpty)
                  Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (kind == OtherDocumentKind.traslado)
            line.aceptado
                ? const AppStatusBadge(label: 'Recibido', tone: AppBadgeTone.success)
                : const AppStatusBadge(label: 'Pendiente', tone: AppBadgeTone.warning)
          else if (kind == OtherDocumentKind.entradaStock && showAmounts)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(line.total, symbol: 'S/.'),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Costo ${formatMoney(line.costo, symbol: 'S/.')}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// El rango de "Creado" de una lista, con atajos (hoy, ayer, últimos 7 días...). Devuelve los
/// filtros elegidos o `null` si se cierra sin aplicar.
Future<OtherDocumentFilters?> showOtherDocumentFilters(
  BuildContext context, {
  required OtherDocumentKind kind,
  required OtherDocumentFilters current,
  required DateTime now,
}) async {
  final draft = ValueNotifier<OtherDocumentFilters>(current);
  final today = DateTime(now.year, now.month, now.day);

  final applied = await showAppModal(
    context,
    title: 'Filtros',
    subtitle: kind.label,
    icon: Icons.filter_list,
    primaryLabel: 'Aplicar filtros',
    child: AppDisposer(
      onDispose: [draft.dispose],
      child: ValueListenableBuilder<OtherDocumentFilters>(
        valueListenable: draft,
        builder: (context, f, _) {
          void setDates(DateTime from, DateTime to) =>
              draft.value = OtherDocumentFilters(desde: from, hasta: to);

          Future<void> pickDates() async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: today,
              initialDateRange: f.hasRange
                  ? DateTimeRange(start: f.desde!, end: f.hasta!)
                  : DateTimeRange(start: today, end: today),
              helpText: 'Rango de fechas',
              saveText: 'Aplicar',
            );
            if (picked != null) setDates(picked.start, picked.end);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => draft.value = OtherDocumentFilters.hoy(now),
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
                    onPressed: () => setDates(DateTime(today.year, today.month), today),
                  ),
                  ActionChip(
                    label: const Text('Mes pasado'),
                    onPressed: () => setDates(
                      DateTime(today.year, today.month - 1),
                      DateTime(today.year, today.month, 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppPickerField(
                label: 'Creado',
                value: f.hasRange ? '${documentFilterDate(f.desde!)} - ${documentFilterDate(f.hasta!)}' : 'Todas las fechas',
                icon: Icons.date_range_outlined,
                onTap: pickDates,
                onClear: f.hasRange ? () => draft.value = const OtherDocumentFilters() : null,
              ),
            ],
          );
        },
      ),
    ),
  );

  return applied == true ? draft.value : null;
}
