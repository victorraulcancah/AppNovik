import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/report_entity.dart';
import '../components/components.dart';
import '../providers/reports_provider.dart';
import 'document_filters.dart';

/// Abre los filtros avanzados del reporte (fechas, sucursales, clientes, vendedores, marcas,
/// categoría y departamentos) y los aplica al pulsar "Aplicar filtros".
Future<void> showReportFilters(BuildContext context) async {
  final reports = context.read<ReportsProvider>();
  reports.ensureCatalogs();

  final draft = ValueNotifier<SalesReportFilters>(reports.filters);
  final applied = await showAppModal(
    context,
    title: 'Filtros avanzados',
    subtitle: 'Ventas General',
    icon: Icons.filter_list,
    primaryLabel: 'Aplicar filtros',
    child: AppDisposer(
      onDispose: [draft.dispose],
      child: _FiltersBody(draft: draft),
    ),
  );
  if (applied == true) await reports.applyFilters(draft.value);
}

class _FiltersBody extends StatelessWidget {
  final ValueNotifier<SalesReportFilters> draft;

  const _FiltersBody({required this.draft});

  /// Resumen de lo elegido: "Todos", el nombre si es uno, o cuántos hay.
  String _summary(List<String> ids, List<ReportOption> options, String all) {
    if (ids.isEmpty) return all;
    if (ids.length > 1) return '${ids.length} elegidos';
    for (final o in options) {
      if (o.id == ids.first) return o.name;
    }
    return '#${ids.first}';
  }

  /// Elige entre las [options] (sus ids son texto; el selector usa números, así que se pasan por su
  /// posición). Devuelve los ids elegidos o `null` si se cerró sin aplicar.
  Future<List<String>?> _pick(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<ReportOption> options,
    required List<String> current,
  }) async {
    final chosen = await showAppMultiSelect(
      context,
      title: title,
      icon: icon,
      options: [for (var i = 0; i < options.length; i++) (id: i, name: options[i].name)],
      selected: [
        for (var i = 0; i < options.length; i++)
          if (current.contains(options[i].id)) i,
      ],
    );
    return chosen == null ? null : [for (final i in chosen) options[i].id];
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>();
    final catalogs = reports.catalogs;
    final now = DateUtils.dateOnly(reports.now);

    return ValueListenableBuilder<SalesReportFilters>(
      valueListenable: draft,
      builder: (context, f, _) {
        void setDates(DateTime from, DateTime to) => draft.value = f.copyWith(desde: from, hasta: to);

        Future<void> pickDates() async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: now,
            initialDateRange: DateTimeRange(start: f.desde, end: f.hasta),
            helpText: 'Rango de fechas',
            saveText: 'Aplicar',
          );
          if (picked != null) setDates(picked.start, picked.end);
        }

        Widget field({
          required String label,
          required IconData icon,
          required List<String> ids,
          required List<ReportOption> options,
          required String all,
          required SalesReportFilters Function(List<String>) apply,
        }) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppPickerField(
              label: label,
              value: _summary(ids, options, all),
              icon: icon,
              onTap: () async {
                final result = await _pick(
                  context,
                  title: label,
                  icon: icon,
                  options: options,
                  current: ids,
                );
                if (result != null) draft.value = apply(result);
              },
              onClear: ids.isEmpty ? null : () => draft.value = apply(const []),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  final month = DateTimeRange(start: DateTime(now.year, now.month), end: now);
                  draft.value = SalesReportFilters(desde: month.start, hasta: month.end);
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Restablecer'),
              ),
            ),
            if (reports.catalogsLoading && !reports.catalogsLoaded)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (reports.catalogsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: ErrorBanner(message: reports.catalogsError!)),
                    IconButton(
                      tooltip: 'Reintentar',
                      onPressed: reports.ensureCatalogs,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(label: const Text('Hoy'), onPressed: () => setDates(now, now)),
                ActionChip(
                  label: const Text('Esta semana'),
                  onPressed: () => setDates(now.subtract(Duration(days: now.weekday - 1)), now),
                ),
                ActionChip(
                  label: const Text('Este mes'),
                  onPressed: () => setDates(DateTime(now.year, now.month), now),
                ),
                ActionChip(
                  label: const Text('Mes pasado'),
                  onPressed: () => setDates(
                    DateTime(now.year, now.month - 1),
                    DateTime(now.year, now.month, 0),
                  ),
                ),
                ActionChip(
                  label: const Text('Este año'),
                  onPressed: () => setDates(DateTime(now.year), now),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppPickerField(
              label: 'Fechas',
              value: '${documentFilterDate(f.desde)} - ${documentFilterDate(f.hasta)}',
              icon: Icons.date_range_outlined,
              onTap: pickDates,
            ),
            const SizedBox(height: 12),
            field(
              label: 'Sucursales',
              icon: Icons.store_mall_directory_outlined,
              ids: f.sucursales,
              options: catalogs.sucursales,
              all: 'Todas',
              apply: (v) => f.copyWith(sucursales: v),
            ),
            field(
              label: 'Clientes',
              icon: Icons.groups_outlined,
              ids: f.clientes,
              options: catalogs.clientes,
              all: 'Todos',
              apply: (v) => f.copyWith(clientes: v),
            ),
            field(
              label: 'Vendedores',
              icon: Icons.badge_outlined,
              ids: f.vendedores,
              options: catalogs.vendedores,
              all: 'Todos',
              apply: (v) => f.copyWith(vendedores: v),
            ),
            field(
              label: 'Marcas',
              icon: Icons.sell_outlined,
              ids: f.marcas,
              options: catalogs.marcas,
              all: 'Todas',
              apply: (v) => f.copyWith(marcas: v),
            ),
            field(
              label: 'Categoría',
              icon: Icons.account_tree_outlined,
              ids: f.categorias,
              options: catalogs.categorias,
              all: 'Todas',
              apply: (v) => f.copyWith(categorias: v),
            ),
            field(
              label: 'Departamentos',
              icon: Icons.map_outlined,
              ids: f.departamentos,
              options: catalogs.departamentos,
              all: 'Todos',
              apply: (v) => f.copyWith(departamentos: v),
            ),
          ],
        );
      },
    );
  }
}
