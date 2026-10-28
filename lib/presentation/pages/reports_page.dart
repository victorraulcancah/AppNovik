import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/report_entity.dart';
import '../../theme/app_theme.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

/// Módulo Reportes: el resumen ejecutivo del usuario para el rango elegido —
/// sus ventas contra el año pasado y su meta, la evolución del año, sus mejores
/// clientes, productos y departamentos, y sus cotizaciones pendientes. Los demás
/// reportes de la web (por producto, sucursal, marca, categoría, tracking...) aún no están.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static final _day = DateFormat(AppConstants.dateFormat);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canView) context.read<ReportsProvider>().ensureLoaded();
    });
  }

  bool get _canView =>
      context.read<AuthProvider>().session?.can('reportes.index') ?? false;

  Future<void> _pickCustom() async {
    final reports = context.read<ReportsProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: reports.dates,
      helpText: 'Elegir fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) reports.selectCustom(picked);
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    final canView = context.read<AuthProvider>().session?.can('reportes.index') ?? false;

    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.bar_chart_outlined,
          title: 'Reportes',
          subtitle: 'Resumen de tus ventas.',
          trailing: AppAccountMenu(),
        ),
        if (canView) _rangeChips(reports),
        if (canView && reports.loading && reports.summary != null)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _body(reports, canView)),
      ],
    );
  }

  Widget _rangeChips(ReportsProvider reports) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        itemCount: ReportRange.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final range = ReportRange.values[i];
          final custom = range == ReportRange.personalizado;
          final selected = reports.range == range;
          return ChoiceChip(
            label: Text(
              custom && selected
                  ? '${_day.format(reports.dates.start)} – ${_day.format(reports.dates.end)}'
                  : range.label,
            ),
            avatar: custom ? const Icon(Icons.date_range, size: 18) : null,
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => custom ? _pickCustom() : reports.selectRange(range),
          );
        },
      ),
    );
  }

  Widget _body(ReportsProvider reports, bool canView) {
    if (!canView) {
      return const AppEmptyState(
        icon: Icons.lock_outline,
        title: 'Sin acceso',
        message: 'No tienes permiso para ver reportes.',
      );
    }
    final summary = reports.summary;
    if (summary == null) {
      if (reports.error != null) {
        return AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'No se pudo cargar el reporte',
          message: reports.error,
          action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: reports.refresh),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: reports.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (reports.error != null) ...[
                  ErrorBanner(message: reports.error!),
                  const SizedBox(height: 12),
                ],
                _sales(summary),
                const SizedBox(height: 16),
                _evolution(summary.evolucion),
                const SizedBox(height: 16),
                _ranking('Mejores clientes', Icons.groups_outlined, summary.topClientes),
                const SizedBox(height: 16),
                _ranking('Productos más vendidos', Icons.inventory_2_outlined, summary.topProductos),
                const SizedBox(height: 16),
                _ranking('Venta por departamento', Icons.map_outlined, summary.departamentos),
                const SizedBox(height: 16),
                _quotes(summary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sales(ExecutiveSummaryEntity s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = s.ventas;

    final rangoAnterior = '${_day.format(s.desdeAnterior)} - ${_day.format(s.hastaAnterior)}';

    return AppSection(
      title: 'Ventas',
      icon: Icons.payments_outlined,
      trailing: Text(
        s.desde == s.hasta ? _day.format(s.desde) : '${_day.format(s.desde)} – ${_day.format(s.hasta)}',
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatMoney(v.total),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppVariationBadge(value: v.totalVariacion),
              Text(
                'vs ${formatMoney(v.totalAnterior)} el año pasado',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          Text(
            rangoAnterior,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppMetric(
                  label: 'N.º de ventas',
                  value: '${v.numero}',
                  variation: v.numeroVariacion,
                ),
              ),
              Expanded(
                child: AppMetric(
                  label: 'Ticket promedio',
                  value: formatMoney(v.ticket),
                  variation: v.ticketVariacion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _goal(s.meta),
          if (s.porAlmacen.length > 1) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 8),
            for (final a in s.porAlmacen)
              AppDetailRow(label: a.nombre, value: formatMoney(a.monto)),
          ],
        ],
      ),
    );
  }

  Widget _goal(GoalEntity meta) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    if (!meta.conMeta) {
      return Row(
        children: [
          Icon(Icons.flag_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              meta.aplica
                  ? 'Sin meta cargada para este mes'
                  : 'La meta es mensual: elige un solo mes para verla',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    final color = switch (meta.semaforo) {
      GoalLight.rojo => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      GoalLight.ambar => dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
      GoalLight.verde => dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
      GoalLight.gris => scheme.onSurfaceVariant,
    };
    final avance = meta.avance ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Meta del mes: ${formatMoney(meta.monto)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              '${avance.toStringAsFixed(1)} %',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (avance / 100).clamp(0.0, 1.0),
            minHeight: 10,
            color: color,
            backgroundColor: scheme.surfaceContainer,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          meta.falta > 0 ? 'Faltan ${formatMoney(meta.falta)}' : '¡Meta cumplida!',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _evolution(EvolutionEntity e) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const initials = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    // Siempre 12 meses, aunque el backend omita alguno.
    final previous = List<double>.filled(12, 0);
    final current = List<double>.filled(12, 0);
    for (final m in e.meses) {
      if (m.mes >= 1 && m.mes <= 12) {
        previous[m.mes - 1] = m.anterior;
        current[m.mes - 1] = m.actual;
      }
    }

    Widget legend(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 4),
            Text(text, style: theme.textTheme.labelSmall),
          ],
        );

    return AppSection(
      title: 'Evolución de mis ventas',
      icon: Icons.show_chart,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          legend(scheme.outlineVariant, '${e.anioAnterior}'),
          const SizedBox(width: 10),
          legend(AppTheme.strongFill(theme.brightness), '${e.anioActual}'),
        ],
      ),
      child: AppGroupedBarChart(
        labels: initials,
        previous: previous,
        current: current,
      ),
    );
  }

  Widget _ranking(String title, IconData icon, List<RankedItemEntity> items) {
    return AppSection(
      title: title,
      icon: icon,
      child: AppBarList(
        emptyText: 'Sin ventas en el rango',
        items: [
          for (final i in items)
            (label: i.codigo != null ? '${i.codigo} · ${i.nombre}' : i.nombre, value: i.monto),
        ],
      ),
    );
  }

  Widget _quotes(ExecutiveSummaryEntity s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppSection(
      title: 'Cotizaciones pendientes',
      icon: Icons.request_quote_outlined,
      trailing: Text(
        '${s.cotizacionesCantidad} · ${formatMoney(s.cotizacionesMonto)}',
        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: s.cotizaciones.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No tienes cotizaciones pendientes en el rango',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < s.cotizaciones.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                  _quoteRow(s.cotizaciones[i]),
                ],
              ],
            ),
    );
  }

  Widget _quoteRow(PendingQuoteEntity q) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (label, tone) = switch (q.prioridad) {
      QuotePriority.alta => ('Alta', AppBadgeTone.danger),
      QuotePriority.media => ('Media', AppBadgeTone.warning),
      QuotePriority.baja => ('Baja', AppBadgeTone.success),
    };
    final number = int.tryParse(q.documento);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.cliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${number == null ? q.documento : 'C001-${number.toString().padLeft(4, '0')}'}'
                  ' · ${q.dias} ${q.dias == 1 ? 'día' : 'días'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(q.monto),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              AppStatusBadge(label: label, tone: tone),
            ],
          ),
        ],
      ),
    );
  }
}
