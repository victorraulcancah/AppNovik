import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/account_statement_entity.dart';
import '../components/components.dart';

/// Rojo de los pagos y de las ventas anuladas (el de la web), legible en claro y oscuro.
Color statementRose(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);

/// La cabecera del estado de cuenta: deuda total en soles y dólares siempre a la vista; tocándola
/// se ven también la línea de crédito, el crédito disponible, la línea utilizada y la deuda anterior.
class StatementSummaryCard extends StatefulWidget {
  /// `null` mientras llega (la web muestra un indicador de carga).
  final StatementSummaryEntity? summary;

  const StatementSummaryCard({super.key, required this.summary});

  @override
  State<StatementSummaryCard> createState() => _StatementSummaryCardState();
}

class _StatementSummaryCardState extends State<StatementSummaryCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = widget.summary;
    final rose = statementRose(context);

    Widget metric(String label, String value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              s == null
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      value,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
            ],
          ),
        );

    Color? debtColor(double v) => v > 0 ? rose : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    metric('Deuda total soles', formatMoney(s?.deudaTotalSoles ?? 0, symbol: 'S/.'),
                        color: debtColor(s?.deudaTotalSoles ?? 0)),
                    metric('Deuda total dólares', formatMoney(s?.deudaTotalDolares ?? 0, symbol: r'$.'),
                        color: debtColor(s?.deudaTotalDolares ?? 0)),
                    Icon(_open ? Icons.expand_less : Icons.expand_more, color: scheme.onSurfaceVariant),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _open
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10, right: 6),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  metric('Línea de crédito', formatMoney(s?.credito ?? 0, symbol: 'S/.')),
                                  metric('Crédito disponible', formatMoney(s?.creditoDisponible ?? 0, symbol: 'S/.')),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  metric('Línea utilizada', formatMoney(s?.lineaUtilizada ?? 0, symbol: 'S/.')),
                                  const Spacer(),
                                ],
                              ),
                              if (s != null && s.hayDeudaAnterior) ...[
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    metric('Deuda anterior (S/.)', formatMoney(s.deudaAnteriorSoles, symbol: 'S/.'),
                                        color: rose),
                                    metric('Deuda anterior (\$)', formatMoney(s.deudaAnteriorDolares, symbol: r'$.'),
                                        color: rose),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una fila de cualquiera de las tres pestañas, como tarjeta: lo principal, fecha y documento,
/// producto, quién registró el pago, y el monto en soles o dólares. Los pagos y las ventas anuladas
/// salen en rojo, como en la web.
class StatementRowCard extends StatelessWidget {
  final StatementRowEntity row;

  /// Abre el comprobante de la venta (solo si la fila lo trae).
  final VoidCallback? onOpenDocument;

  const StatementRowCard({super.key, required this.row, this.onOpenDocument});

  static final _date = DateFormat(AppConstants.dateFormat);

  /// Cantidad sin decimales sobrantes: `2`, `1.5`.
  static String quantity(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final rose = statementRose(context);
    final r = row;
    final enDolares = r.dolares != 0 && r.soles == 0;
    final amount = enDolares ? formatMoney(r.dolares, symbol: r'$.') : formatMoney(r.soles, symbol: 'S/.');
    final who = r.registradoPor == null ? null : shortPersonName(r.registradoPor);

    return AppListCard(
      title: r.titulo,
      lines: [
        [if (r.fecha != null) _date.format(r.fecha!), r.documento].join(' · '),
        if (r.detalle != null && r.detalle!.isNotEmpty) r.detalle!,
        if (who != null && who.isNotEmpty) 'Registrado por $who',
      ],
      trailingTitle: amount,
      trailingTitleColor: r.enRojo ? rose : null,
      trailingCaption: r.cantidad == null ? null : 'Cant. ${quantity(r.cantidad!)}',
      footer: (r.origen != null || r.anulado || r.esPago)
          ? Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (r.esPago) AppStatusBadge(label: r.origen ?? 'Pago', tone: AppBadgeTone.danger),
                if (r.anulado) const AppStatusBadge(label: 'Anulada', tone: AppBadgeTone.danger),
              ],
            )
          : null,
      onTap: onOpenDocument,
      actions: [
        if (onOpenDocument != null)
          AppActionButton(type: AppActionType.view, label: 'Ver comprobante', onPressed: onOpenDocument),
      ],
    );
  }
}
