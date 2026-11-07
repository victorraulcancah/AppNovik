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

/// Saludo según la hora y el texto del rol: la cabecera de Inicio, con el degradado de la marca
/// (azul marino con destellos naranjas), legible en claro y oscuro.
class InicioGreeting extends StatelessWidget {
  final ({String icon, String title, String text}) greeting;
  final String? subtitle;
  final bool loading;

  const InicioGreeting({super.key, required this.greeting, this.subtitle, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget blob(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary.withValues(alpha: alpha)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.brandDark, AppTheme.brandDarkAlt],
          ),
        ),
        child: Stack(
          children: [
            Positioned(right: -34, top: -46, child: blob(130, 0.38)),
            Positioned(right: 46, bottom: -56, child: blob(96, 0.16)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)),
                    child: Text(greeting.icon, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting.title,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle == null ? greeting.text : '${greeting.text} · $subtitle',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      style: inicioSegmentedStyle(context),
      segments: [for (final v in views) ButtonSegment(value: v, label: Text(v.label))],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Estilo de los segmentos de Inicio: compactos, con el segmento elegido bien marcado (azul marino de
/// la marca, o pizarra en oscuro, con texto blanco) y los demás en gris suave.
ButtonStyle inicioSegmentedStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final dark = scheme.brightness == Brightness.dark;
  final selectedBackground = dark ? AppTheme.navIndicator : AppTheme.brandDark;
  const selectedForeground = Colors.white;
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? selectedBackground : scheme.surfaceContainerHigh,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? selectedForeground : scheme.onSurface,
    ),
    side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
  );
}

/// Tarjeta sin título (para lo que lleva su propio encabezado).
class InicioPanel extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const InicioPanel({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Bloque de un resumen: título con su ícono en un círculo de color y el contenido en una tarjeta
/// aireada. Es el `AppSection` de siempre con el aire y los colores de Inicio.
class InicioSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  /// Algo a la derecha del título (una leyenda, la ayuda, un contador).
  final Widget? trailing;

  const InicioSection({super.key, required this.title, required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              ?trailing,
            ],
          ),
        ),
        InicioPanel(child: child),
      ],
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

/// Ventas del rango contra la meta: el anillo de avance como protagonista (con el color del
/// semáforo), el monto grande, cuánto falta, el mensaje motivador y, debajo, lo que cada resumen
/// quiera agregar ([footer]).
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
    final hasGoal = meta.hasGoal && avance != null;
    final message = hasGoal ? goalMessage(view, avance, name) : null;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    final amount = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: AppCountUp(
        value: total,
        format: (v) => soles(v, decimals),
        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: _tabular),
      ),
    );

    final figures = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        amount,
        if (comparison != null) ...[const SizedBox(height: 2), Text(comparison!, style: muted)],
        const SizedBox(height: 6),
        if (meta.hasGoal) ...[
          Text('Meta: ${soles(meta.monto)}', style: muted),
          Text(
            meta.falta > 0 ? 'Faltan ${soles(meta.falta, decimals)}' : '¡Meta cumplida!',
            style: muted?.copyWith(fontWeight: FontWeight.w700),
          ),
        ] else
          Text(noGoalText, style: muted),
      ],
    );

    return InicioPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFB7832), Color(0xFFD64A06)],
                  ),
                ),
                child: const Icon(Icons.track_changes, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (help != null) InicioHelpButton(help: help!),
              if (showVariation) AppVariationBadge(value: variation),
            ],
          ),
          const SizedBox(height: 16),
          if (hasGoal)
            Row(
              children: [
                InicioGoalRing(percent: avance, color: light),
                const SizedBox(width: 18),
                Expanded(child: figures),
              ],
            )
          else
            figures,
          if (message != null) ...[
            const SizedBox(height: 16),
            _GoalMessage(view: view, message: message, avance: avance ?? 0, name: name),
          ],
          ...footer,
        ],
      ),
    );
  }
}

/// Anillo de avance de la meta: el arco se dibuja al aparecer, con el color del semáforo, y el
/// porcentaje va al centro. Con "quitar animaciones" sale completo de entrada.
class InicioGoalRing extends StatelessWidget {
  final double percent;
  final Color color;
  final double size;

  const InicioGoalRing({super.key, required this.percent, required this.color, this.size = 116});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = (percent / 100).clamp(0.0, 1.0);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final label = Padding(
      padding: EdgeInsets.all(size * 0.2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${percent.toStringAsFixed(1)}%',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: _tabular,
          ),
        ),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? target : 0, end: target),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(progress: value, color: color, track: theme.colorScheme.surfaceContainerHigh),
          child: child,
        ),
        child: Center(child: label),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _RingPainter({required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.283185307179586, false, base..color = track);
    if (progress > 0) {
      canvas.drawArc(rect, -1.5707963267948966, 6.283185307179586 * progress, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
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

/// Dos datos lado a lado, cada uno en su ficha de color suave.
class InicioKpiRow extends StatelessWidget {
  final List<Widget> children;

  const InicioKpiRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: children[i],
                ),
              ),
            ],
          ],
        ),
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

    return InicioSection(
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
/// Con más de [collapsedRows] filas muestra las primeras y un botón "Ver más".
class InicioTable extends StatefulWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final String emptyText;

  /// Cuánto ancho se lleva la primera columna frente a cada una de las demás.
  final int firstFlex;

  /// Al tocar una fila (con su posición); `null`: filas sin acción.
  final ValueChanged<int>? onTap;

  /// Cuántas filas se ven antes de "Ver más".
  final int collapsedRows;

  const InicioTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyText,
    this.firstFlex = 4,
    this.onTap,
    this.collapsedRows = 6,
  });

  @override
  State<InicioTable> createState() => _InicioTableState();
}

class _InicioTableState extends State<InicioTable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = widget.rows;
    if (rows.isEmpty) return InicioEmpty(text: widget.emptyText);

    Widget line(List<Widget> cells, {int? index}) {
      final row = Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? widget.firstFlex : 3,
              child: Align(alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight, child: cells[i]),
            ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: index != null && widget.onTap != null ? InkWell(onTap: () => widget.onTap!(index), child: row) : row,
      );
    }

    final headStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    final collapsible = rows.length > widget.collapsedRows;
    final visible = collapsible && !_expanded ? widget.collapsedRows : rows.length;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          line([for (final c in widget.columns) Text(c, style: headStyle, maxLines: 1, overflow: TextOverflow.ellipsis)]),
          for (var i = 0; i < visible; i++) ...[
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.7)),
            line(rows[i], index: i),
          ],
          if (collapsible)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                label: Text(_expanded ? 'Ver menos' : 'Ver más (${rows.length - widget.collapsedRows})'),
              ),
            ),
        ],
      ),
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
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: dark ? 0.26 : 0.16)),
                child: Icon(icon, size: 28, color: color),
              ),
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
    return InicioSection(
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
    return InicioSection(
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
    return InicioSection(
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
    return InicioSection(
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
    return InicioSection(
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
      if (i > 0) const SizedBox(height: 18),
      AppEntrance(delay: Duration(milliseconds: 50 * (i < 8 ? i : 8)), offset: 12, child: sections[i]),
    ],
  ],
);
