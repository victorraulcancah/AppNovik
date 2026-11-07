import 'package:flutter/material.dart';

import '../../domain/entities/inicio_entity.dart';
import '../providers/inicio_provider.dart';
import '../utils/inicio_copy.dart';
import 'inicio_help.dart';
import 'inicio_widgets.dart';

/// Resumen Ejecutivo (rol Vendedor): sus ventas contra la meta, la evolución, sus tops, las
/// oportunidades comerciales, lo que tiene que hacer hoy, los clientes con caída, sus cotizaciones
/// pendientes y los cumpleaños de su cartera. Lo mismo que el Dashboard "Ejecutivo" de la web.
class InicioExecutiveView extends StatelessWidget {
  final ExecutiveSummaryEntity data;
  final DateTime now;

  /// Abre Documentos para ver las cotizaciones; `null` si el usuario no puede verlas.
  final VoidCallback? onOpenQuotes;

  const InicioExecutiveView({super.key, required this.data, required this.now, this.onOpenQuotes});

  @override
  Widget build(BuildContext context) {
    final name = firstName(data.vendedor);
    final sales = data.ventas;
    final oneMonth = data.desde.year == data.hasta.year && data.desde.month == data.hasta.month;
    final monthShort = monthsShort[data.desde.month - 1];
    final previousLabel = '$monthShort ${data.desde.year - 1}';
    final currentLabel = '$monthShort ${data.desde.year}';
    final comparison =
        'Año pasado (${shortRange(data.desdeAnterior, data.hastaAnterior)}): ${soles(sales.totalAnterior, 2)}';

    return inicioSections([
      InicioGoalCard(
        view: InicioView.ejecutivo,
        title: 'Ventas',
        help: inicioExecutiveSalesHelp(),
        total: sales.total,
        variation: sales.variacionPct,
        comparison: comparison,
        meta: data.meta,
        noGoalText: data.meta.aplica
            ? 'Sin meta cargada para este mes'
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
          // Con más de un almacén, cuánto se vendió en cada uno.
          if (data.porAlmacen.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final a in data.porAlmacen)
                  Text.rich(
                    TextSpan(
                      children: [
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.storefront, size: 14, color: Color(0xFF84CC16)),
                        ),
                        TextSpan(text: ' ${a.nombre} '),
                        TextSpan(
                          text: soles(a.monto, 2),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ],
      ),
      InicioEvolution(
        title: 'Evolución de mis ventas',
        evolution: data.evolucion,
        help: inicioExecutiveEvolutionHelp(),
      ),
      InicioSection(
        title: 'Ventas por cliente',
        icon: Icons.group_outlined,
        trailing: InicioHelpButton(help: inicioTopHelp('Ventas por cliente', 'clientes')),
        child: InicioTopBars(items: data.topClientes),
      ),
      InicioSection(
        title: 'Productos más vendidos',
        icon: Icons.inventory_2_outlined,
        trailing: InicioHelpButton(help: inicioTopHelp('Productos más vendidos', 'productos')),
        child: InicioTopBars(items: data.topProductos),
      ),
      InicioSection(
        title: 'Venta por departamento',
        icon: Icons.map_outlined,
        trailing: InicioHelpButton(help: inicioTopHelp('Venta por departamento', 'departamentos (del cliente)')),
        child: InicioTopBars(items: data.departamentos),
      ),
      _Opportunities(data: data, onOpenQuotes: onOpenQuotes),
      _TasksSection(tasks: data.tareas, now: now),
      InicioFallClients(
        fall: data.conCaida,
        previousLabel: previousLabel,
        currentLabel: currentLabel,
        help: inicioFallClientsHelpExecutive(),
      ),
      InicioPendingQuotes(
        title: 'Cotizaciones pendientes',
        quotes: data.cotizaciones,
        total: data.cotizacionesCantidad,
        help: inicioPriorityHelp(),
      ),
      _Birthdays(birthdays: data.cumpleanos, oneMonth: oneMonth, month: data.desde.month),
    ]);
  }
}

/// Oportunidades comerciales: lo que está en caída y las cotizaciones por cerrar.
class _Opportunities extends StatelessWidget {
  final ExecutiveSummaryEntity data;
  final VoidCallback? onOpenQuotes;

  const _Opportunities({required this.data, this.onOpenQuotes});

  @override
  Widget build(BuildContext context) {
    final clients = data.clientesSinCompra;
    final products = data.productosSinVenta;
    String detail(StatusCountsEntity s) =>
        '${s.critico} críticos · ${s.riesgo} en riesgo · ${s.seguimiento} en seguimiento';

    return InicioSection(
      title: 'Oportunidades comerciales',
      icon: Icons.track_changes,
      trailing: InicioHelpButton(help: inicioExecutiveOpportunitiesHelp()),
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

/// Mis tareas: las gestiones programadas (hoy, la semana o el mes) y las vencidas, con filtro por
/// tipo de contacto. No dependen del rango de fechas.
class _TasksSection extends StatefulWidget {
  final List<TaskEntity> tasks;
  final DateTime now;

  const _TasksSection({required this.tasks, required this.now});

  @override
  State<_TasksSection> createState() => _TasksSectionState();
}

class _TasksSectionState extends State<_TasksSection> {
  TaskPeriod _period = TaskPeriod.hoy;
  String _type = 'todas';

  static const _types = ['todas', 'llamada', 'visita', 'whatsapp', 'correo'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Las tareas llegan hasta fin de mes: el periodo deja las que vencen hasta su último día (y las vencidas).
    final end = periodEnd(_period, widget.now);
    final tasks = [for (final t in widget.tasks) if (!t.fecha.isAfter(end)) t];
    int count(String type) => type == 'todas' ? tasks.length : tasks.where((t) => t.tipo == type).length;
    final visible = _type == 'todas' ? tasks : [for (final t in tasks) if (t.tipo == _type) t];

    String typeLabel(String type) => switch (type) {
      'todas' => 'Todas',
      _ => contactType(type).plural,
    };

    final periodText = switch (_period) {
      TaskPeriod.hoy => 'para hoy',
      TaskPeriod.semana => 'para la semana',
      TaskPeriod.mes => 'para el mes',
    };

    return InicioSection(
      title: 'Mis tareas (${tasks.length})',
      icon: Icons.assignment_outlined,
      trailing: InicioHelpButton(help: inicioTasksHelp()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TaskPeriod>(
            showSelectedIcon: false,
            style: inicioSegmentedStyle(context),
            segments: [for (final p in TaskPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _types.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ChoiceChip(
                label: Text('${typeLabel(_types[i])} (${count(_types[i])})'),
                selected: _type == _types[i],
                showCheckmark: false,
                labelStyle: TextStyle(color: scheme.onSurface),
                onSelected: (_) => setState(() => _type = _types[i]),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined, size: 40, color: scheme.outlineVariant),
                  const SizedBox(height: 8),
                  Text('No tienes gestiones pendientes $periodText.', textAlign: TextAlign.center),
                  Text(
                    '¡Aprovecha para contactar clientes en seguimiento o con caída!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            for (final t in visible) _TaskRow(task: t, now: widget.now),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskEntity task;
  final DateTime now;

  const _TaskRow({required this.task, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = contactType(task.tipo);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(type.icon, size: 18, color: type.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${type.short} – ${task.cliente}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            taskWhen(task, now),
            style: theme.textTheme.bodySmall?.copyWith(
              color: task.vencida ? const Color(0xFFEF4444) : theme.colorScheme.onSurfaceVariant,
              fontWeight: task.vencida ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cumpleaños de los clientes de la cartera en el periodo (con un solo mes, todo el mes).
class _Birthdays extends StatelessWidget {
  final List<BirthdayEntity> birthdays;
  final bool oneMonth;
  final int month;

  const _Birthdays({required this.birthdays, required this.oneMonth, required this.month});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InicioSection(
      title: oneMonth ? 'Cumpleaños de ${monthsLong[month - 1]}' : 'Cumpleaños del periodo',
      icon: Icons.cake_outlined,
      trailing: InicioHelpButton(help: inicioBirthdaysHelp()),
      child: birthdays.isEmpty
          ? const InicioEmpty(text: 'Ningún cliente de tu cartera cumple años en este periodo')
          : Column(
              children: [
                for (final b in birthdays)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: b.esHoy ? const Color(0xFFEC4899).withValues(alpha: 0.12) : null,
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: b.esHoy
                                ? const Color(0xFFEC4899)
                                : b.yaPaso
                                ? scheme.surfaceContainerHigh
                                : const Color(0xFFEC4899).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${b.dia}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: b.esHoy
                                      ? Colors.white
                                      : b.yaPaso
                                      ? scheme.onSurfaceVariant
                                      : const Color(0xFFDB2777),
                                ),
                              ),
                              if (!oneMonth)
                                Text(
                                  monthsShort[b.mes - 1].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: b.esHoy ? Colors.white : scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: b.yaPaso ? scheme.onSurfaceVariant : null,
                                ),
                              ),
                              if (b.telefono != null)
                                Text(
                                  b.telefono!,
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.cake,
                          size: 18,
                          color: b.yaPaso ? scheme.outlineVariant : const Color(0xFFF43F5E),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
