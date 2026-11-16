import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/report_ranking_entity.dart';
import '../components/components.dart';
import '../providers/reports_provider.dart';

String _soles(double v) => formatMoney(v, symbol: 'S/.');

/// El porcentaje como se muestra: `12.5 %`; lo que es más que cero pero menos de 0.1 se escribe
/// `<0.1 %` para que no parezca que no vendió.
String rankingPercent(double value) {
  if (value > 0 && value < 0.05) return '<0.1 %';
  return '${value.toStringAsFixed(1)} %';
}

/// El color de la barra de cada reporte (el mismo en la tarjeta y en la lista completa).
Color rankingColor(ReportKind kind) => switch (kind) {
  ReportKind.departamentos => const Color(0xFF14B8A6),
  ReportKind.vendedores => const Color(0xFF4F6BED),
  ReportKind.marcas => const Color(0xFF8B5CF6),
  ReportKind.categorias => const Color(0xFFEC4899),
  ReportKind.clientes => const Color(0xFF22A55E),
  ReportKind.general => const Color(0xFF84CC16),
};

/// Los reportes disponibles, en fichas que se deslizan: "Venta general", "Departamentos", ...
class ReportKindSelector extends StatelessWidget {
  final List<ReportKind> kinds;
  final ReportKind selected;
  final ValueChanged<ReportKind> onSelect;

  const ReportKindSelector({
    super.key,
    required this.kinds,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        itemCount: kinds.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final kind = kinds[i];
          return ChoiceChip(
            label: Text(kind.chip),
            selected: kind == selected,
            showCheckmark: false,
            onSelected: (_) => onSelect(kind),
          );
        },
      ),
    );
  }
}

/// Barra proporcional fina; crece al aparecer (sin animación con "quitar animaciones").
class RankingBar extends StatelessWidget {
  /// De 0 a 1.
  final double fraction;
  final Color color;
  final double height;

  const RankingBar({super.key, required this.fraction, required this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHigh;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final value = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? value : 0, end: value),
      duration: still ? Duration.zero : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: track)),
              FractionallySizedBox(
                widthFactor: t,
                child: ColoredBox(color: color, child: SizedBox(height: height)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta del resumen de Venta general: el top 3 de un reporte (posición, nombre, monto, barra y %)
/// con una flecha que abre la lista completa.
class RankingSummaryCard extends StatelessWidget {
  final ReportKind kind;
  final RankingState? state;

  /// `false` cuando el rol no ve importes: solo se muestra el %.
  final bool showAmounts;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  const RankingSummaryCard({
    super.key,
    required this.kind,
    required this.state,
    required this.showAmounts,
    required this.onOpen,
    required this.onRetry,
  });

  static const top = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = this.state;

    final Widget body;
    if (state == null || state.loading) {
      body = const _SummarySkeleton();
    } else if (state.error != null) {
      body = Row(
        children: [
          Expanded(
            child: Text(
              'No se pudo cargar',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      );
    } else if (state.rows.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Sin ventas en el rango',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      final rows = state.rows.take(top).toList();
      final max = rows.first.venta;
      body = Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _SummaryRow(
              position: i + 1,
              row: rows[i],
              share: state.share(rows[i]),
              fraction: max > 0 ? rows[i].venta / max : 0,
              color: rankingColor(kind),
              showAmount: showAmounts,
            ),
          ],
        ],
      );
    }

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      kind.cardTitle,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 20, color: scheme.primary, semanticLabel: 'Ver todos'),
                ],
              ),
              const SizedBox(height: 10),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int position;
  final RankingRow row;
  final double share;
  final double fraction;
  final Color color;
  final bool showAmount;

  const _SummaryRow({
    required this.position,
    required this.row,
    required this.share,
    required this.fraction,
    required this.color,
    required this.showAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const tabular = [FontFeature.tabularFigures()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '$position. ${row.name}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (showAmount) ...[
              const SizedBox(width: 12),
              Text(
                _soles(row.venta),
                style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: tabular),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: RankingBar(fraction: fraction, color: color)),
            const SizedBox(width: 10),
            SizedBox(
              width: 58,
              child: Text(
                rankingPercent(share),
                textAlign: TextAlign.end,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabular,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: const AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeletonBox(height: 12, width: 180),
            SizedBox(height: 6),
            AppSkeletonBox(height: 8),
            SizedBox(height: 12),
            AppSkeletonBox(height: 12, width: 150),
            SizedBox(height: 6),
            AppSkeletonBox(height: 8),
            SizedBox(height: 12),
            AppSkeletonBox(height: 12, width: 120),
            SizedBox(height: 6),
            AppSkeletonBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// La lista completa de un reporte por entidad: título, total, buscador por nombre y, de mayor a
/// menor, nombre, monto y % del total con su barra. Nunca muestra unidades.
class RankingView extends StatefulWidget {
  final ReportKind kind;
  final RankingState? state;
  final bool showAmounts;
  final ValueChanged<String> onSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  const RankingView({
    super.key,
    required this.kind,
    required this.state,
    required this.showAmounts,
    required this.onSearch,
    required this.onRefresh,
    required this.onRetry,
    required this.onLoadMore,
  });

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = widget.state;
    final kind = widget.kind;

    if (state == null || state.loading) return const AppSkeletonList();
    if (state.error != null) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo cargar el reporte',
        message: state.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: widget.onRetry),
      );
    }

    final rows = state.visible;
    final max = state.rows.isEmpty ? 0.0 : state.rows.first.venta;
    final count = '${state.totalRows} ${kind.plural}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kind.cardTitle,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                widget.showAmounts ? 'Total ${_soles(state.total)} · $count' : count,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        AppSearchBar(
          hint: 'Buscar por nombre',
          controller: _search,
          onChanged: widget.onSearch,
        ),
        if (state.searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: AppCardList<RankingRow>(
            items: rows,
            emptyIcon: Icons.search_off,
            emptyTitle: state.rows.isEmpty ? 'No hay ventas' : 'Sin resultados',
            emptyMessage: state.rows.isEmpty
                ? 'Prueba con otro rango de fechas o quita los filtros.'
                : 'Ninguno coincide con la búsqueda.',
            onRefresh: widget.onRefresh,
            onLoadMore: widget.onLoadMore,
            loadingMore: state.loadingMore,
            itemBuilder: (context, row, _) {
              final share = state.share(row);
              return AppListCard(
                title: row.name,
                trailingTitle: widget.showAmounts ? _soles(row.venta) : rankingPercent(share),
                trailingCaption: widget.showAmounts ? rankingPercent(share) : null,
                footer: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  child: RankingBar(
                    fraction: max > 0 ? row.venta / max : 0,
                    color: rankingColor(kind),
                    height: 6,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
