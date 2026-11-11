import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/inicio_entity.dart';
import '../components/app_motion.dart' show AppCountUpScope;
import '../providers/inicio_provider.dart';
import '../utils/inicio_copy.dart';
import 'inicio_help.dart';
import 'inicio_widgets.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Resumen del CEO: el panorama de toda la empresa. Responde al rango y al almacén elegidos (salvo
/// las cuentas por cobrar, que son el saldo de hoy). Lo mismo que el Dashboard "CEO" de la web.
class InicioCeoView extends StatefulWidget {
  final CeoSummaryEntity data;

  const InicioCeoView({super.key, required this.data});

  @override
  State<InicioCeoView> createState() => _InicioCeoViewState();
}

class _InicioCeoViewState extends State<InicioCeoView> {
  /// La utilidad arranca oculta, como en el diseño: se muestra con el ojo.
  bool _showProfit = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final name = firstName(data.ceo);
    final sales = data.ventas;
    final monthShort = monthsShort[data.desdeAnterior.month - 1];
    final previousLabel = '$monthShort ${data.desdeAnterior.year}';
    final currentLabel = '$monthShort ${data.desde.year}';

    return inicioSections([
      InicioGoalCard(
        view: InicioView.ceo,
        title: 'Ventas (${rangeLabel(data.desde, data.hasta)})',
        total: sales.total,
        decimals: 0,
        showVariation: false,
        meta: data.meta,
        noGoalText: data.meta.aplica
            ? 'Sin meta de la empresa para este mes'
            : data.sucursal != null
            ? 'La meta es de toda la empresa'
            : 'La meta es mensual: elige un solo mes para verla',
        name: name,
        footer: [
          const SizedBox(height: 12),
          _Indicator(
            title: 'vs. ${shortRange(data.desdeAnterior, data.hastaAnterior)}',
            value: _Pct(value: sales.variacionPct),
            detail: Text(soles(sales.totalAnterior)),
          ),
          const SizedBox(height: 8),
          _Indicator(
            title: 'vs. ${shortRange(sales.mesAnteriorDesde, sales.mesAnteriorHasta)}',
            value: _Pct(value: sales.mesAnteriorPct),
            detail: Text(soles(sales.mesAnterior)),
          ),
          const SizedBox(height: 8),
          _Indicator(
            title: 'Proyección de cierre',
            value: Text(
              sales.proyeccion != null ? soles(sales.proyeccion!) : '—',
              style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: _tabular),
            ),
            detail: Text(sales.proyeccion != null ? 'al ritmo actual del mes' : 'solo con el mes en curso'),
          ),
        ],
      ),
      InicioEvolution(title: 'Evolución de ventas mensuales', evolution: data.evolucion),
      _Indicators(
        data: data,
        showProfit: _showProfit,
        onToggleProfit: () => setState(() => _showProfit = !_showProfit),
      ),
      InicioSellerGoals(
        title: 'Cumplimiento por vendedor',
        sellers: data.vendedores,
        hideGoals: data.sucursal != null,
        help: inicioCeoSellerGoalsHelp(),
      ),
      InicioDepartments(departments: data.departamentos, help: inicioCeoDepartmentsHelp()),
      _Channels(channels: data.canales),
      _Receivables(data: data.cuentasPorCobrar),
      _Collections(sellers: data.cobroPorVendedor),
      _Incomes(incomes: data.ingresos),
      InicioFallProducts(
        products: data.productosMayorCaida,
        previousLabel: previousLabel,
        currentLabel: currentLabel,
        help: inicioFallProductsHelpCeo(),
      ),
      InicioFallClients(
        fall: data.clientesCaida,
        previousLabel: previousLabel,
        currentLabel: currentLabel,
        help: inicioFallClientsHelpCeo(),
      ),
      _NewClients(data: data.nuevosClientes, comparedWith: '$monthShort ${data.desdeAnterior.year}'),
    ]);
  }
}

/// "+15 %" en verde o "-8 %" en rojo; sin base, "—".
class _Pct extends StatelessWidget {
  final double? value;
  final bool arrow;

  const _Pct({required this.value, this.arrow = false});

  @override
  Widget build(BuildContext context) {
    final pct = value;
    if (pct == null) {
      return Text('—', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    final up = pct >= 0;
    return Text(
      '${arrow ? (up ? '↑ ' : '↓ ') : (up ? '+' : '')}${pct.toStringAsFixed(1)}%',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: up ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
        fontFeatures: _tabular,
      ),
    );
  }
}

/// Recuadro chico de un indicador: título, valor y detalle.
class _Indicator extends StatelessWidget {
  final String title;
  final Widget value;
  final Widget? detail;
  final IconData? icon;
  final Color? tone;

  const _Indicator({
    required this.title,
    required this.value,
    this.detail,
    this.icon,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone?.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.09),
        border: Border.all(color: tone?.withValues(alpha: 0.3) ?? scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: muted),
                const SizedBox(height: 2),
                DefaultTextStyle.merge(
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  child: value,
                ),
                if (detail != null)
                  DefaultTextStyle.merge(style: muted ?? const TextStyle(), child: detail!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicadores estratégicos del año (YTD): ventas acumuladas, utilidad estimada (oculta con el
/// ojo), cotizaciones pendientes y clientes activos del mes.
class _Indicators extends StatelessWidget {
  final CeoSummaryEntity data;
  final bool showProfit;
  final VoidCallback onToggleProfit;

  const _Indicators({required this.data, required this.showProfit, required this.onToggleProfit});

  @override
  Widget build(BuildContext context) {
    final ind = data.indicadores;
    final prevYear = data.desdeAnterior.year;
    return InicioSection(
      title: 'Indicadores estratégicos (YTD)',
      icon: Icons.insights_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: showProfit ? 'Ocultar utilidad' : 'Mostrar utilidad',
            visualDensity: VisualDensity.compact,
            icon: Icon(showProfit ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: onToggleProfit,
          ),
          InicioHelpButton(help: inicioIndicatorsHelp()),
        ],
      ),
      child: Column(
        children: [
          _Indicator(
            icon: Icons.bar_chart,
            title: 'Ventas acumuladas',
            value: Text(soles(ind.ventasAcumuladas)),
            detail: Row(
              children: [
                _Pct(value: ind.ventasAcumuladasPct, arrow: true),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'vs. $prevYear: ${soles(ind.ventasAcumuladasAnterior)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Indicator(
            icon: Icons.savings_outlined,
            title: 'Utilidad estimada',
            value: Text(showProfit ? soles(ind.utilidadEstimada) : '••••••'),
            detail: showProfit && ind.margenPct != null ? Text('Margen ${ind.margenPct}%') : null,
          ),
          const SizedBox(height: 8),
          _Indicator(
            icon: Icons.description_outlined,
            title: 'Cotizaciones pendientes',
            value: Text(soles(ind.cotizacionesMonto)),
            detail: Text('${ind.cotizacionesCantidad} oportunidades'),
          ),
          const SizedBox(height: 8),
          _Indicator(
            icon: Icons.group_outlined,
            title: 'Clientes activos (mes)',
            value: Text(thousands(ind.clientesActivos.toDouble())),
            detail: Row(
              children: [
                _Pct(value: ind.clientesActivosPct, arrow: true),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'vs. $prevYear: ${ind.clientesActivosAnterior}',
                    overflow: TextOverflow.ellipsis,
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

/// Ventas por canal: los clientes de cada categoría y lo vendido a ellos, en una dona con el total
/// de clientes al centro.
class _Channels extends StatelessWidget {
  final List<ChannelEntity> channels;

  const _Channels({required this.channels});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = channels.fold<int>(0, (s, c) => s + c.clientes);

    return InicioSection(
      title: 'Ventas por canal',
      icon: Icons.donut_large,
      trailing: InicioHelpButton(help: inicioChannelsHelp()),
      child: channels.isEmpty
          ? const InicioEmpty(text: 'Sin categorías de clientes')
          : Column(
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: AppCountUpScope.fromZeroOf(context) ? 0 : 1, end: 1),
                    duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                        ? Duration.zero
                        : const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => CustomPaint(
                      painter: _DonutPainter(
                        values: [for (final c in channels) c.clientes.toDouble()],
                        colors: [for (final c in channels) channelColor(c.codigo)],
                        track: scheme.surfaceContainerHigh,
                        progress: t,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              thousands(total.toDouble()),
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'clientes',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InicioTable(
                  columns: const ['Canal', '%', 'Clientes', 'Ventas'],
                  emptyText: '',
                  firstFlex: 4,
                  rows: [
                    for (final c in channels)
                      [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: channelColor(c.codigo), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Flexible(child: InicioCell(c.nombre)),
                          ],
                        ),
                        InicioCell(total > 0 ? '${(c.clientes / total * 100).toStringAsFixed(1)}%' : '0.0%'),
                        InicioCell('${c.clientes}'),
                        InicioCell(soles(c.monto)),
                      ],
                  ],
                ),
              ],
            ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color track;
  final double progress;

  const _DonutPainter({required this.values, required this.colors, required this.track, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);

    final total = values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * math.pi * 2 * progress;
      canvas.drawArc(rect, start, math.max(sweep - 0.02, 0.001), false, paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.values != values || old.colors != colors || old.track != track;
}

/// Cuentas por cobrar de hoy: el total, lo que está por vencer y lo vencido.
class _Receivables extends StatelessWidget {
  final ReceivablesEntity data;

  const _Receivables({required this.data});

  @override
  Widget build(BuildContext context) {
    return InicioSection(
      title: 'Cuentas por cobrar',
      icon: Icons.request_quote_outlined,
      trailing: InicioHelpButton(help: inicioReceivablesHelp()),
      child: Column(
        children: [
          _Indicator(
            tone: const Color(0xFF2563EB),
            title: 'Total por cobrar',
            value: Text(soles(data.total)),
            detail: const Text('saldo de hoy'),
          ),
          const SizedBox(height: 8),
          _Indicator(
            tone: const Color(0xFFD97706),
            title: 'Por vencer',
            value: Text(soles(data.porVencer)),
            detail: Text('${data.porVencerPct}%', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          _Indicator(
            tone: const Color(0xFFEF4444),
            title: 'Vencido',
            value: Text(soles(data.vencido)),
            detail: Text('${data.vencidoPct}%', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Cobro por vendedor: los depósitos que registró cada uno en Pagos de Vendedores.
class _Collections extends StatelessWidget {
  final List<SellerCollectionEntity> sellers;

  const _Collections({required this.sellers});

  @override
  Widget build(BuildContext context) {
    final totalSoles = sellers.fold<double>(0, (s, c) => s + c.soles);
    final totalDolares = sellers.fold<double>(0, (s, c) => s + c.dolares);

    return InicioSection(
      title: 'Cobro por vendedor',
      icon: Icons.payments_outlined,
      trailing: InicioHelpButton(help: inicioCollectionsHelp()),
      child: Column(
        children: [
          InicioTable(
            columns: const ['Vendedor', 'Soles (S/)', 'Dólares (\$)'],
            emptyText: 'Sin cobros en el rango',
            rows: [
              for (final c in sellers)
                [
                  InicioCell(firstName(c.nombre)),
                  InicioCell(thousands(c.soles)),
                  InicioCell(c.dolares > 0 ? thousands(c.dolares) : '—'),
                ],
            ],
          ),
          if (sellers.any((c) => c.pendiente > 0))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Por aprobar: ${soles(sellers.fold<double>(0, (s, c) => s + c.pendiente))}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFD97706)),
              ),
            ),
          if (sellers.isNotEmpty)
            InicioTotalsBar(
              children: [
                InicioTotal(label: 'Total Soles:', value: soles(totalSoles, 2)),
                InicioTotal(label: 'Total Dólares:', value: dolares(totalDolares, 2)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Ingresos por entidad bancaria: cada método de pago con ingresos en el rango, en soles o en
/// dólares, con su participación. El filtro deja ver solo algunos métodos: el total, los
/// porcentajes y la comparación con el mes anterior pasan a ser de los elegidos.
class _Incomes extends StatefulWidget {
  final IncomesEntity incomes;

  const _Incomes({required this.incomes});

  @override
  State<_Incomes> createState() => _IncomesState();
}

class _IncomesState extends State<_Incomes> {
  List<String> _chosen = [];
  bool _dollars = false;

  Future<void> _pickMethods() async {
    final all = [for (final m in widget.incomes.metodos) m.metodo];
    final selected = {..._chosen.where(all.contains)};
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar métodos de pago',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in all)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(m),
                          value: selected.contains(m),
                          onChanged: (v) => setSheet(() => v == true ? selected.add(m) : selected.remove(m)),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context, <String>[]), child: const Text('Restablecer')),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, selected.toList()),
                      child: const Text('Aceptar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _chosen = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final incomes = widget.incomes;
    // Al cambiar el rango, los métodos elegidos que ya no tienen ingresos salen del filtro.
    final available = [for (final m in incomes.metodos) m.metodo];
    final filter = _chosen.where(available.contains).toList();
    final filtering = filter.isNotEmpty;
    final rows = filtering ? [for (final m in incomes.metodos) if (filter.contains(m.metodo)) m] : incomes.metodos;

    double sum(double Function(PaymentIncomeEntity) pick) => rows.fold(0, (s, m) => s + pick(m));
    double? variation(double now, double before) => before > 0 ? (now - before) / before * 100 : null;

    final totalSoles = filtering ? sum((m) => m.soles) : incomes.totalSoles;
    final totalDolares = filtering ? sum((m) => m.dolares) : incomes.totalDolares;
    final solesBefore = filtering ? sum((m) => m.solesAnterior) : incomes.totalSolesAnterior;
    final dolaresBefore = filtering ? sum((m) => m.dolaresAnterior) : incomes.totalDolaresAnterior;
    final solesVariation = filtering ? variation(totalSoles, solesBefore) : incomes.variacionSolesPct;
    final dolaresVariation = filtering ? variation(totalDolares, dolaresBefore) : incomes.variacionDolaresPct;

    final total = _dollars ? totalDolares : totalSoles;
    double pick(PaymentIncomeEntity m) => _dollars ? m.dolares : m.soles;
    final shown = [for (final m in rows) if (pick(m) > 0) m]..sort((a, b) => pick(b).compareTo(pick(a)));
    String money(double v) => _dollars ? dolares(v) : soles(v);

    final desde = incomes.desdeAnterior;
    final hasta = incomes.hastaAnterior;
    final compared = desde != null && hasta != null ? 'vs. ${shortRange(desde, hasta)}' : '';

    return InicioSection(
      title: 'Ingresos por entidad bancaria',
      icon: Icons.account_balance_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (incomes.metodos.isNotEmpty)
            IconButton(
              tooltip: filtering ? '${filter.length} de ${available.length} métodos' : 'Filtrar métodos de pago',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.filter_alt, color: filtering ? scheme.primary : scheme.outline),
              onPressed: _pickMethods,
            ),
          InicioHelpButton(help: inicioIncomesHelp()),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (incomes.metodos.isNotEmpty) ...[
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: inicioSegmentedStyle(context),
              segments: const [
                ButtonSegment(value: false, label: Text('Soles')),
                ButtonSegment(value: true, label: Text('Dólares')),
              ],
              selected: {_dollars},
              onSelectionChanged: (s) => setState(() => _dollars = s.first),
            ),
            const SizedBox(height: 8),
          ],
          InicioTable(
            columns: const ['Método', 'Monto', 'Participación'],
            emptyText: _dollars ? 'Sin ingresos en dólares en el rango' : 'Sin ingresos en soles en el rango',
            rows: [
              for (final m in shown)
                [
                  InicioCell(m.metodo),
                  InicioCell(money(pick(m))),
                  // Si la celda no alcanza (letra grande, pantalla angosta) se achica en vez de desbordar.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          child: InicioProgressBar(
                            percent: total > 0 ? pick(m) / total * 100 : 0,
                            color: const Color(0xFF2563EB),
                            height: 6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(total > 0 ? pick(m) / total * 100 : 0).toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(fontFeatures: _tabular),
                        ),
                      ],
                    ),
                  ),
                ],
            ],
          ),
          if (incomes.metodos.isNotEmpty)
            InicioTotalsBar(
              children: [
                _TotalWithVariation(label: 'Total Soles:', value: solesText(totalSoles), variation: solesVariation),
                _TotalWithVariation(
                  label: 'Total Dólares:',
                  value: dolares(totalDolares, 2),
                  variation: dolaresVariation,
                ),
                if (compared.isNotEmpty)
                  Text(
                    compared,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String solesText(double v) => soles(v, 2);
}

class _TotalWithVariation extends StatelessWidget {
  final String label;
  final String value;
  final double? variation;

  const _TotalWithVariation({required this.label, required this.value, required this.variation});

  @override
  Widget build(BuildContext context) {
    // Si no cabe (letra grande, pantalla angosta) se achica en vez de desbordar.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InicioTotal(label: label, value: value),
          const SizedBox(width: 6),
          _Pct(value: variation, arrow: true),
        ],
      ),
    );
  }
}

/// Nuevos clientes del rango: cuántos hicieron su primera compra y lo que vendieron, contra el
/// mismo rango del año pasado, y los 5 que más compraron.
class _NewClients extends StatelessWidget {
  final NewClientsEntity data;
  final String comparedWith;

  const _NewClients({required this.data, required this.comparedWith});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxAmount = data.top.fold<double>(1, (m, t) => t.monto > m ? t.monto : m);

    Widget vs(double? pct) => Row(
      children: [
        _Pct(value: pct),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'vs. $comparedWith',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );

    return InicioSection(
      title: 'Nuevos clientes',
      icon: Icons.person_add_alt_1_outlined,
      trailing: InicioHelpButton(help: inicioNewClientsHelp()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Indicator(title: 'Clientes nuevos', value: Text('${data.cantidad}'), detail: vs(data.cantidadPct)),
          const SizedBox(height: 8),
          _Indicator(title: 'Ventas de clientes nuevos', value: Text(soles(data.ventas)), detail: vs(data.ventasPct)),
          const SizedBox(height: 12),
          Text('Top 5 nuevos clientes', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          InicioTable(
            columns: const ['Cliente', 'Ventas (S/)', ''],
            emptyText: 'Sin clientes nuevos en el rango',
            firstFlex: 5,
            rows: [
              for (final t in data.top)
                [
                  InicioCell(t.nombre),
                  InicioCell(thousands(t.monto)),
                  SizedBox(
                    width: 44,
                    child: InicioProgressBar(percent: t.monto / maxAmount * 100, color: const Color(0xFF2563EB), height: 6),
                  ),
                ],
            ],
          ),
        ],
      ),
    );
  }
}
