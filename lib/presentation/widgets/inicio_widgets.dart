import 'package:flutter/material.dart';

import '../../domain/entities/inicio_entity.dart';
import '../../theme/app_theme.dart';
import '../components/components.dart';
import '../providers/inicio_provider.dart';
import '../utils/inicio_copy.dart';
import 'inicio_help.dart';

/// Piezas que comparten los tres resúmenes del Inicio (Ejecutivo, Jefe y CEO).

const _blue = Color(0xFF3B82F6);
const _tabular = [FontFeature.tabularFigures()];

/// Saludo según la hora y el texto del rol.
class InicioGreeting extends StatelessWidget {
  final ({String icon, String title, String text}) greeting;
  final String? subtitle;
  final bool loading;

  const InicioGreeting({super.key, required this.greeting, this.subtitle, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting.icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                subtitle == null ? greeting.text : '${greeting.text} · $subtitle',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 8),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
          ),
      ],
    );
  }
}

/// El switch de la web "CEO | Jefe | Ejecutivo".
class InicioViewSwitch extends StatelessWidget {
  final List<InicioView> views;
  final InicioView selected;
  final ValueChanged<InicioView> onChanged;

  const InicioViewSwitch({super.key, required this.views, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<InicioView>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [for (final v in views) ButtonSegment(value: v, label: Text(v.label))],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Tarjeta sin título (para lo que lleva su propio encabezado).
class InicioPanel extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const InicioPanel({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Barra de avance que se llena al aparecer.
class InicioProgressBar extends StatelessWidget {
  final double percent;
  final Color color;
  final double height;

  const InicioProgressBar({super.key, required this.percent, required this.color, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = (percent / 100).clamp(0.0, 1.0);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color,
          backgroundColor: scheme.surfaceContainerHigh,
        ),
      ),
    );
  }
}

/// Ventas del rango contra la meta: el monto y el % grandes, la barra, el mensaje motivador y,
/// debajo, lo que cada resumen quiera agregar ([footer]).
class InicioGoalCard extends StatelessWidget {
  final InicioView view;
  final String title;
  final double total;
  final int decimals;

  /// Variación contra el año pasado (`null`: sin base) y el texto de la comparación
  /// ("Año pasado: S/ 1,000"). Sin [variation] ni [comparison] no se muestra.
  final double? variation;
  final String? comparison;
  final bool showVariation;
  final GoalEntity meta;
  final String noGoalText;
  final String name;
  final List<Widget> footer;

  /// La ayuda (?) de la tarjeta, junto al título.
  final InicioHelp? help;

  const InicioGoalCard({
    super.key,
    required this.view,
    required this.title,
    required this.total,
    this.decimals = 2,
    this.variation,
    this.comparison,
    this.showVariation = true,
    required this.meta,
    required this.noGoalText,
    required this.name,
    this.footer = const [],
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final light = goalColor(meta.semaforo);
    final avance = meta.avance;
    final message = meta.hasGoal && avance != null ? goalMessage(view, avance, name) : null;

    return InicioPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                child: const Icon(Icons.track_changes, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              if (help != null) InicioHelpButton(help: help!),
              if (showVariation) AppVariationBadge(value: variation),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AppCountUp(
                    value: total,
                    format: (v) => soles(v, decimals),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
              ),
              if (meta.hasGoal && avance != null) ...[
                const SizedBox(width: 12),
                Text(
                  '${avance.toStringAsFixed(1)}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: light,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ],
          ),
          if (comparison != null)
            Text(comparison!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          if (meta.hasGoal)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Meta: ${soles(meta.monto)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                Text(
                  meta.falta > 0 ? 'Faltan ${soles(meta.falta, decimals)}' : '¡Meta cumplida!',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            )
          else
            Text(noGoalText, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          if (meta.hasGoal) ...[
            const SizedBox(height: 8),
            InicioProgressBar(percent: avance ?? 0, color: light),
          ],
          if (message != null) ...[
            const SizedBox(height: 12),
            _GoalMessage(view: view, message: message, avance: avance ?? 0, name: name),
          ],
          ...footer,
        ],
      ),
    );
  }
}

class _GoalMessage extends StatelessWidget {
  final InicioView view;
  final ({String icon, String title, String text}) message;
  final double avance;
  final String name;

  const _GoalMessage({required this.view, required this.message, required this.avance, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: dark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(message.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: message.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' ${message.text}'),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Mensajes según el avance',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.help_outline, size: 20, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () => showGoalTiers(context, view: view, avance: avance, name: name),
          ),
        ],
      ),
    );
  }
}

/// La ayuda (?) del mensaje motivador: todos los tramos de avance con su mensaje, y resaltado el
/// que toca ahora.
Future<void> showGoalTiers(
  BuildContext context, {
  required InicioView view,
  required double avance,
  required String name,
}) {
  final tiers = goalTiers(view);
  final current = goalTierIndex(tiers, avance);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mensajes según el avance de la meta',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < tiers.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: i == current ? const Color(0xFFF59E0B).withValues(alpha: 0.16) : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          tiers[i].rango,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${tiers[i].icon} '),
                              TextSpan(
                                text: tiers[i].title.replaceAll('{nombre}', name),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(text: ' ${tiers[i].text}'),
                            ],
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Dato chico de un recuadro: etiqueta, valor y su variación.
class InicioKpi extends StatelessWidget {
  final String label;
  final String value;
  final double? variation;
  final bool showVariation;
  final String? caption;

  const InicioKpi({
    super.key,
    required this.label,
    required this.value,
    this.variation,
    this.showVariation = true,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: muted),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: _tabular),
          ),
        ),
        if (showVariation) ...[const SizedBox(height: 4), AppVariationBadge(value: variation)],
        if (caption != null) ...[const SizedBox(height: 2), Text(caption!, style: muted)],
      ],
    );
  }
}

/// Dos datos lado a lado, separados de lo de arriba por una línea.
class InicioKpiRow extends StatelessWidget {
  final List<Widget> children;

  const InicioKpiRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// Barras de un año contra el anterior, mes por mes (la "Evolución" de la web).
class InicioEvolution extends StatelessWidget {
  final String title;
  final EvolutionEntity evolution;
  final InicioHelp? help;

  const InicioEvolution({super.key, required this.title, required this.evolution, this.help});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = AppTheme.strongFill(theme.brightness);

    Widget legend(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );

    return AppSection(
      title: title,
      icon: Icons.bar_chart,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            children: [
              legend(scheme.outlineVariant, '${evolution.anioAnterior}'),
              legend(current, '${evolution.anioActual}'),
            ],
          ),
          if (help != null) InicioHelpButton(help: help!),
        ],
      ),
      child: AppGroupedBarChart(
        labels: [for (final m in evolution.meses) monthsShort[(m.mes - 1).clamp(0, 11)]],
        previous: [for (final m in evolution.meses) m.anterior],
        current: [for (final m in evolution.meses) m.actual],
      ),
    );
  }
}

/// Tabla compacta: encabezado y filas; la primera columna a la izquierda y el resto a la derecha.
class InicioTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final String emptyText;

  /// Cuánto ancho se lleva la primera columna frente a cada una de las demás.
  final int firstFlex;

  /// Al tocar una fila (con su posición); `null`: filas sin acción.
  final ValueChanged<int>? onTap;

  const InicioTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyText,
    this.firstFlex = 4,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (rows.isEmpty) return InicioEmpty(text: emptyText);

    Widget line(List<Widget> cells, {int? index}) {
      final row = Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? firstFlex : 3,
              child: Align(alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight, child: cells[i]),
            ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: index != null && onTap != null ? InkWell(onTap: () => onTap!(index), child: row) : row,
      );
    }

    final headStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Column(
      children: [
        line([for (final c in columns) Text(c, style: headStyle, maxLines: 1, overflow: TextOverflow.ellipsis)]),
        for (var i = 0; i < rows.length; i++) ...[
          Divider(height: 1, color: scheme.outlineVariant),
          line(rows[i], index: i),
        ],
      ],
    );
  }
}

/// Texto de una celda de [InicioTable].
class InicioCell extends StatelessWidget {
  final String text;
  final Color? color;
  final bool bold;
  final bool muted;

  const InicioCell(this.text, {super.key, this.color, this.bold = false, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color ?? (muted ? theme.colorScheme.onSurfaceVariant : null),
        fontWeight: bold ? FontWeight.w700 : null,
        fontFeatures: _tabular,
      ),
    );
  }
}

class InicioEmpty extends StatelessWidget {
  final String text;

  const InicioEmpty({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Pie gris de las listas: los totales de todo lo que cuenta la lista.
class InicioTotalsBar extends StatelessWidget {
  final List<Widget> children;

  const InicioTotalsBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(10)),
      child: Wrap(spacing: 14, runSpacing: 2, alignment: WrapAlignment.spaceBetween, children: children),
    );
  }
}

/// "Etiqueta: **valor**" para los pies de lista.
class InicioTotal extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const InicioTotal({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: TextStyle(fontWeight: FontWeight.w800, color: color ?? theme.colorScheme.onSurface),
          ),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: _tabular,
      ),
    );
  }
}

/// Mosaico de "Oportunidades comerciales": ícono, cantidad grande, qué es y el detalle.
class InicioOpportunity extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  const InicioOpportunity({
    super.key,
    required this.icon,
    required this.color,
    required this.count,
    required this.title,
    required this.detail,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: color.withValues(alpha: dark ? 0.18 : 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 34, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCountUp(
                      value: count.toDouble(),
                      format: (v) => thousands(v),
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
                    ),
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de color (estado de un cliente o prioridad de una cotización).
class InicioChip extends StatelessWidget {
  final String label;
  final Color color;

  const InicioChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// El avance de un vendedor: barra y % con el color del semáforo.
class InicioGoalProgress extends StatelessWidget {
  final double percent;
  final GoalLight light;

  const InicioGoalProgress({super.key, required this.percent, required this.light});

  @override
  Widget build(BuildContext context) {
    final color = goalColor(light);
    // Si la celda no alcanza (letra grande, pantalla angosta) se achica en vez de desbordar.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 38, child: InicioProgressBar(percent: percent, color: color, height: 6)),
          const SizedBox(width: 6),
          Text(
            '${percent.round()}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: _tabular),
          ),
        ],
      ),
    );
  }
}

/// Cumplimiento de metas por vendedor: ventas, meta y avance.
class InicioSellerGoals extends StatelessWidget {
  final String title;
  final List<SellerGoalEntity> sellers;

  /// Con un almacén elegido las metas (de toda la empresa) no se comparan con lo vendido allí.
  final bool hideGoals;
  final InicioHelp? help;

  const InicioSellerGoals({super.key, required this.title, required this.sellers, this.hideGoals = false, this.help});

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: title,
      icon: Icons.track_changes,
      trailing: help == null ? null : InicioHelpButton(help: help!),
      child: InicioTable(
        columns: const ['Vendedor', 'Ventas (S/)', 'Meta (S/)', 'Avance'],
        emptyText: 'Sin ventas en el rango',
        firstFlex: 4,
        rows: [
          for (var i = 0; i < sellers.length; i++)
            [
              InicioCell('${i + 1}. ${firstName(sellers[i].nombre)}'),
              InicioCell(thousands(sellers[i].venta)),
              InicioCell(!hideGoals && sellers[i].meta != null && sellers[i].meta! > 0 ? thousands(sellers[i].meta!) : '—'),
              !hideGoals && sellers[i].avance != null
                  ? InicioGoalProgress(percent: sellers[i].avance!, light: sellers[i].semaforo)
                  : const InicioCell('—'),
            ],
        ],
      ),
    );
  }
}

/// Ventas por departamento: monto y participación con su barra.
class InicioDepartments extends StatelessWidget {
  final List<DepartmentEntity> departments;
  final InicioHelp? help;

  const InicioDepartments({super.key, required this.departments, this.help});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSection(
      title: 'Ventas por departamento',
      icon: Icons.map_outlined,
      trailing: help == null ? null : InicioHelpButton(help: help!),
      child: InicioTable(
        columns: const ['Departamento', 'Ventas (S/)', 'Participación'],
        emptyText: 'Sin ventas en el rango',
        rows: [
          for (final d in departments)
            [
              InicioCell(d.nombre),
              InicioCell(thousands(d.monto)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 30, child: InicioProgressBar(percent: d.participacion, color: _blue, height: 6)),
                    const SizedBox(width: 6),
                    Text('${d.participacion}%', style: theme.textTheme.bodySmall?.copyWith(fontFeatures: _tabular)),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

/// Clientes con mayor caída: lo del año pasado, lo de este año y la variación en soles.
class InicioFallClients extends StatelessWidget {
  final FallClientsEntity fall;
  final String previousLabel;
  final String currentLabel;
  final InicioHelp? help;

  const InicioFallClients({
    super.key,
    required this.fall,
    required this.previousLabel,
    required this.currentLabel,
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: 'Clientes con mayor caída',
      icon: Icons.group_outlined,
      trailing: help == null ? null : InicioHelpButton(help: help!),
      child: Column(
        children: [
          InicioTable(
            columns: ['Cliente', previousLabel, currentLabel, 'Variación'],
            emptyText: 'Ningún cliente con caída en el rango',
            firstFlex: 5,
            rows: [
              for (final f in fall.filas)
                [
                  InicioCell(f.cliente),
                  InicioCell(thousands(f.anterior)),
                  InicioCell(thousands(f.actual)),
                  InicioCell(thousands(f.variacion), color: fallState(f.estado).color, bold: true),
                ],
            ],
          ),
          if (fall.total > 0)
            InicioTotalsBar(
              children: [
                InicioTotal(label: 'Total ·', value: '${fall.total} cliente${fall.total == 1 ? '' : 's'}'),
                InicioTotal(label: '$previousLabel:', value: soles(fall.totales.anterior)),
                InicioTotal(label: '$currentLabel:', value: soles(fall.totales.actual)),
                InicioTotal(label: 'Variación:', value: soles(fall.totales.variacion), color: const Color(0xFFEF4444)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Productos con mayor caída: el rango contra el mismo rango del año pasado.
class InicioFallProducts extends StatelessWidget {
  final List<FallProductEntity> products;
  final String previousLabel;
  final String currentLabel;
  final InicioHelp? help;

  const InicioFallProducts({
    super.key,
    required this.products,
    required this.previousLabel,
    required this.currentLabel,
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    var before = 0.0;
    var now = 0.0;
    for (final p in products) {
      before += p.anterior;
      now += p.actual;
    }
    return AppSection(
      title: 'Productos con mayor caída',
      icon: Icons.inventory_2_outlined,
      trailing: help == null ? null : InicioHelpButton(help: help!),
      child: Column(
        children: [
          InicioTable(
            columns: ['Producto', previousLabel, currentLabel, 'Variación'],
            emptyText: 'Ningún producto con caída en el rango',
            firstFlex: 5,
            rows: [
              for (final p in products)
                [
                  InicioCell(p.codigo ?? p.producto),
                  InicioCell(thousands(p.anterior)),
                  InicioCell(thousands(p.actual)),
                  InicioCell(thousands(p.variacion), color: const Color(0xFFEF4444), bold: true),
                ],
            ],
          ),
          if (products.isNotEmpty)
            InicioTotalsBar(
              children: [
                InicioTotal(label: 'Total ·', value: '${products.length} producto${products.length == 1 ? '' : 's'}'),
                InicioTotal(label: '$previousLabel:', value: soles(before)),
                InicioTotal(label: '$currentLabel:', value: soles(now)),
                InicioTotal(label: 'Variación:', value: soles(now - before), color: const Color(0xFFEF4444)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Cotizaciones pendientes con sus días desde la emisión y su prioridad.
class InicioPendingQuotes extends StatelessWidget {
  final String title;
  final List<PendingQuoteEntity> quotes;
  final bool showSeller;
  final int total;
  final Widget? totals;
  final InicioHelp? help;

  const InicioPendingQuotes({
    super.key,
    required this.title,
    required this.quotes,
    this.showSeller = false,
    required this.total,
    this.totals,
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: title,
      icon: Icons.description_outlined,
      trailing: help == null ? null : InicioHelpButton(help: help!),
      child: Column(
        children: [
          InicioTable(
            columns: ['Cliente', if (showSeller) 'Vendedor', 'Monto', 'Días'],
            emptyText: showSeller
                ? 'No hay cotizaciones pendientes en el rango'
                : 'No tienes cotizaciones pendientes en el rango',
            firstFlex: 5,
            rows: [
              for (final q in quotes)
                [
                  InicioCell(q.cliente),
                  if (showSeller) InicioCell(q.vendedor == null ? '—' : firstName(q.vendedor!)),
                  InicioCell(
                    '${q.enDolares ? '\$' : 'S/'} ${_moneyText(q.montoMoneda)}',
                    color: priorityStyle(q.prioridad).color,
                    bold: true,
                  ),
                  showSeller
                      ? InicioCell('${q.dias}')
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InicioCell('${q.dias}'),
                            const SizedBox(width: 6),
                            InicioChip(
                              label: priorityStyle(q.prioridad).label,
                              color: priorityStyle(q.prioridad).color,
                            ),
                          ],
                        ),
                ],
            ],
          ),
          ?totals,
        ],
      ),
    );
  }
}

String _moneyText(double v) => soles(v, 2).replaceFirst('S/ ', '');

/// Barra de color fija de las listas de top (clientes, productos, departamentos).
class InicioTopBars extends StatelessWidget {
  final List<RankedAmountEntity> items;
  final String emptyText;

  const InicioTopBars({super.key, required this.items, this.emptyText = 'Sin ventas en el rango'});

  @override
  Widget build(BuildContext context) => AppBarList(
    items: [for (final i in items) (label: i.codigo ?? i.nombre, value: i.monto)],
    emptyText: emptyText,
    symbol: 'S/',
  );
}

/// Un color suelto para las barras de la dona de canales, por categoría de cliente.
Color channelColor(String? code) => switch (code) {
  'A' => const Color(0xFF0EA5E9),
  'B' => const Color(0xFF10B981),
  'C' => const Color(0xFFF59E0B),
  'D' => const Color(0xFFF97316),
  'E' => const Color(0xFF8B5CF6),
  'F' => const Color(0xFF9CA3AF),
  _ => const Color(0xFF94A3B8),
};

/// Las secciones de un resumen, una debajo de otra y entrando escalonadas.
Widget inicioSections(List<Widget> sections) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < sections.length; i++) ...[
      if (i > 0) const SizedBox(height: 14),
      AppEntrance(delay: Duration(milliseconds: 50 * (i < 8 ? i : 8)), offset: 12, child: sections[i]),
    ],
  ],
);
