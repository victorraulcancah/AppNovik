import 'package:flutter/material.dart';

import '../../domain/entities/inicio_entity.dart';
import '../components/components.dart';
import '../providers/inicio_provider.dart';
import '../utils/inicio_copy.dart';
import 'inicio_help.dart';
import 'inicio_widgets.dart';

/// Resumen del Jefe Comercial ("Mi equipo"): las ventas de todo el equipo contra la meta de la
/// empresa, la evolución, el cumplimiento por vendedor, los tops, las oportunidades, las
/// gestiones del equipo y las listas de clientes con caída, cotizaciones pendientes y productos
/// con mayor caída. Lo mismo que el Dashboard "Jefe" de la web.
class InicioTeamView extends StatelessWidget {
  final TeamSummaryEntity data;

  /// Abre Documentos para ver las cotizaciones; `null` si el usuario no puede verlas.
  final VoidCallback? onOpenQuotes;

  const InicioTeamView({super.key, required this.data, this.onOpenQuotes});

  @override
  Widget build(BuildContext context) {
    final name = firstName(data.jefe);
    final sales = data.ventas;
    final monthShort = monthsShort[data.desdeAnterior.month - 1];
    final previousLabel = '$monthShort ${data.desdeAnterior.year}';
    final currentLabel = '$monthShort ${data.desde.year}';
    final comparison =
        'Año pasado (${shortRange(data.desdeAnterior, data.hastaAnterior)}): ${soles(sales.totalAnterior, 2)}';
    final maxProduct = data.topProductos.fold<double>(1, (m, p) => p.monto > m ? p.monto : m);

    return inicioSections([
      InicioGoalCard(
        view: InicioView.jefe,
        title: 'Ventas del equipo',
        help: inicioTeamSalesHelp(),
        total: sales.total,
        variation: sales.variacionPct,
        comparison: comparison,
        meta: data.meta,
        noGoalText: data.meta.aplica
            ? 'Sin meta de la empresa para este mes'
            : 'La meta es mensual: elige un solo mes para verla',
        name: name,
        footer: [
          InicioKpiRow(
            children: [
              InicioKpi(
                label: 'N.º de ventas',
                value: thousands(sales.numero.toDouble()),
                variation: sales.numeroVariacionPct,
                caption: 'Año pasado: ${sales.numeroAnterior}',
              ),
              InicioKpi(
                label: 'Ticket promedio',
                value: soles(sales.ticket, 2),
                variation: sales.ticketVariacionPct,
                caption: 'Año pasado: ${soles(sales.ticketAnterior, 2)}',
              ),
            ],
          ),
        ],
      ),
      InicioEvolution(title: 'Evolución de ventas del equipo', evolution: data.evolucion),
      InicioSellerGoals(
        title: 'Cumplimiento de metas por vendedor',
        sellers: data.vendedores,
        help: inicioSellerGoalsHelp(),
      ),
      AppSection(
        title: 'Productos más vendidos del equipo',
        icon: Icons.inventory_2_outlined,
        trailing: InicioHelpButton(help: inicioTeamTopProductsHelp()),
        child: InicioTable(
          columns: const ['Producto', 'Ventas (S/)', 'Avance', 'Porcentaje'],
          emptyText: 'Sin ventas en el rango',
          firstFlex: 4,
          rows: [
            for (final p in data.topProductos)
              [
                InicioCell(p.codigo ?? p.nombre),
                InicioCell(thousands(p.monto)),
                SizedBox(
                  width: 44,
                  child: InicioProgressBar(percent: p.monto / maxProduct * 100, color: const Color(0xFF6366F1), height: 6),
                ),
                InicioCell('${sales.total > 0 ? (p.monto / sales.total * 100).toStringAsFixed(1) : '0.0'}%'),
              ],
          ],
        ),
      ),
      InicioDepartments(departments: data.departamentos, help: inicioTeamDepartmentsHelp()),
      _TeamOpportunities(data: data, onOpenQuotes: onOpenQuotes),
      _TeamManagements(data: data),
      InicioFallClients(
        fall: data.clientesCaida,
        previousLabel: previousLabel,
        currentLabel: currentLabel,
        help: inicioFallClientsHelpTeam(),
      ),
      InicioPendingQuotes(
        help: inicioPriorityHelp(),
        title: 'Cotizaciones pendientes del equipo (${data.cotizacionesCantidad})',
        quotes: data.cotizaciones,
        showSeller: true,
        total: data.cotizacionesCantidad,
        totals: data.cotizacionesCantidad > 0
            ? InicioTotalsBar(
                children: [
                  InicioTotal(
                    label: 'Total ·',
                    value:
                        '${data.cotizacionesCantidad} cotizaci${data.cotizacionesCantidad == 1 ? 'ón' : 'ones'}',
                  ),
                  InicioTotal(label: 'Soles:', value: soles(data.cotizacionesSoles, 2)),
                  InicioTotal(label: 'Dólares:', value: dolares(data.cotizacionesDolares, 2)),
                ],
              )
            : null,
      ),
      InicioFallProducts(
        products: data.productosMayorCaida,
        previousLabel: previousLabel,
        currentLabel: currentLabel,
        help: inicioFallProductsHelpTeam(),
      ),
    ]);
  }
}

class _TeamOpportunities extends StatelessWidget {
  final TeamSummaryEntity data;
  final VoidCallback? onOpenQuotes;

  const _TeamOpportunities({required this.data, this.onOpenQuotes});

  @override
  Widget build(BuildContext context) {
    final clients = data.clientesCaidaEstados;
    final products = data.productosSinVentasEstados;
    String detail(StatusCountsEntity s) =>
        '${s.critico} críticos · ${s.riesgo} en riesgo · ${s.seguimiento} en seguimiento';

    return AppSection(
      title: 'Oportunidades comerciales del equipo',
      icon: Icons.track_changes,
      trailing: InicioHelpButton(help: inicioTeamOpportunitiesHelp()),
      child: Column(
        children: [
          InicioOpportunity(
            icon: Icons.group_outlined,
            color: const Color(0xFFE11D48),
            count: clients.enCaida,
            title: 'Clientes con caída',
            detail: detail(clients),
          ),
          const SizedBox(height: 10),
          InicioOpportunity(
            icon: Icons.description_outlined,
            color: const Color(0xFF2563EB),
            count: data.cotizacionesCantidad,
            title: 'Cotizaciones pendientes',
            detail: soles(data.cotizacionesMonto, 2),
            onTap: onOpenQuotes,
          ),
          const SizedBox(height: 10),
          InicioOpportunity(
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFFD97706),
            count: products.enCaida,
            title: 'Productos sin ventas',
            detail: detail(products),
          ),
        ],
      ),
    );
  }
}

/// Gestiones del equipo programadas para hoy, la semana o el mes, por tipo: hechas / programadas.
class _TeamManagements extends StatefulWidget {
  final TeamSummaryEntity data;

  const _TeamManagements({required this.data});

  @override
  State<_TeamManagements> createState() => _TeamManagementsState();
}

class _TeamManagementsState extends State<_TeamManagements> {
  TaskPeriod _period = TaskPeriod.hoy;

  Color _pctColor(double? pct) => pct == null
      ? const Color(0xFF94A3B8)
      : pct >= 80
      ? const Color(0xFF16A34A)
      : pct >= 50
      ? const Color(0xFFD97706)
      : const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = [...?widget.data.gestiones[_period]]
      ..sort((a, b) => managementOrder.indexOf(a.tipo).compareTo(managementOrder.indexOf(b.tipo)));

    return AppSection(
      title: 'Gestiones del equipo (${_period.label.toLowerCase()})',
      icon: Icons.assignment_outlined,
      trailing: InicioHelpButton(help: inicioManagementsHelp()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TaskPeriod>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [for (final p in TaskPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const InicioEmpty(text: 'Sin gestiones programadas')
          else
            // De a dos por fila; cada fila toma la altura de su contenido (con letra grande una
            // proporción fija recortaba el texto).
            for (var i = 0; i < items.length; i += 2) ...[
              if (i > 0) const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _managementTile(items[i], theme, scheme)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: i + 1 < items.length
                          ? _managementTile(items[i + 1], theme, scheme)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _managementTile(ManagementEntity g, ThemeData theme, ColorScheme scheme) {
    final type = contactType(g.tipo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(type.icon, size: 24, color: type.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${g.hechas} / ${g.programadas}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  type.plural,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InicioChip(label: g.pct == null ? '—' : '${g.pct!.round()}%', color: _pctColor(g.pct)),
        ],
      ),
    );
  }
}
