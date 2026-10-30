import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/document_entity.dart';
import '../components/components.dart';
import '../providers/documents_provider.dart';

const _months = ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sep.', 'oct.', 'nov.', 'dic.'];

/// `05 ene. 2026`, como la web.
String documentFilterDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

String _range(DocumentFilters f) => f.desde == null || f.hasta == null
    ? 'Todas las fechas'
    : '${documentFilterDate(f.desde!)} - ${documentFilterDate(f.hasta!)}';

/// Una etiqueta de la fila de filtros. [remove] devuelve los filtros sin ese valor; es
/// `null` en lo que ya es como al entrar (no hay nada que quitar).
class DocumentFilterTag {
  final String key;
  final String text;
  final DocumentFilters Function(DocumentFilters)? remove;

  const DocumentFilterTag(this.key, this.text, [this.remove]);
}

/// Las etiquetas de la fila de filtros, como las de la web: el rango de fechas y las
/// sucursales siempre ("Sucursal: Todas (3)" si no se eligió ninguna) y los demás filtros
/// puestos. Con uno solo elegido se ve su nombre; con varios, la cantidad.
List<DocumentFilterTag> documentFilterTags({
  required DocumentKind kind,
  required DocumentFilters filters,
  required DocumentFilterCatalogs catalogs,
  required DateTime now,
}) {
  final base = DocumentFilters.hoy(now);
  String names(List<int> ids, List<({int id, String name})> options) {
    if (ids.length != 1) return '${ids.length}';
    for (final o in options) {
      if (o.id == ids.first) return o.name;
    }
    return '#${ids.first}';
  }

  final datesAreDefault = filters.desde == base.desde && filters.hasta == base.hasta;
  final tags = <DocumentFilterTag>[
    DocumentFilterTag(
      'fechas',
      _range(filters),
      datesAreDefault ? null : (f) => f.copyWith(desde: base.desde, hasta: base.hasta),
    ),
    if (filters.vendedores.isNotEmpty)
      DocumentFilterTag(
        'vendedores',
        'Ejecutivo: ${names(filters.vendedores, catalogs.vendedores)}',
        (f) => f.copyWith(vendedores: const <int>[]),
      ),
    if (filters.clientes.isNotEmpty)
      DocumentFilterTag(
        'clientes',
        'Cliente: ${names(filters.clientes, catalogs.clientes)}',
        (f) => f.copyWith(clientes: const <int>[]),
      ),
    if (filters.sucursales.isNotEmpty)
      DocumentFilterTag(
        'sucursales',
        'Sucursal: ${names(filters.sucursales, catalogs.sucursales)}',
        (f) => f.copyWith(sucursales: const <int>[]),
      )
    else if (catalogs.sucursales.isNotEmpty)
      DocumentFilterTag('sucursales', 'Sucursal: Todas (${catalogs.sucursales.length})'),
  ];

  if (kind == DocumentKind.venta) {
    if (filters.tipo != null) {
      tags.add(DocumentFilterTag(
        'tipo',
        switch (filters.tipo!) {
          DocumentTipo.boleta => 'Boleta',
          DocumentTipo.factura => 'Factura',
          DocumentTipo.notaVenta => 'Nota de venta',
        },
        (f) => f.copyWith(tipo: null),
      ));
    }
    if (filters.estado != null) {
      tags.add(DocumentFilterTag(
        'estado',
        filters.estado == DocumentEstado.activos ? 'Activos' : 'Eliminados',
        (f) => f.copyWith(estado: null),
      ));
    }
  } else {
    if (filters.estadoCotizacion != DocumentQuoteState.todas) {
      tags.add(DocumentFilterTag(
        'estadoCotizacion',
        filters.estadoCotizacion == DocumentQuoteState.pendientes ? 'Pendientes' : 'Procesadas',
        (f) => f.copyWith(estadoCotizacion: DocumentQuoteState.todas),
      ));
    }
    if (filters.reserva != DocumentReserve.todas) {
      tags.add(DocumentFilterTag(
        'reserva',
        filters.reserva == DocumentReserve.reservadas ? 'Reservadas' : 'No reservadas',
        (f) => f.copyWith(reserva: DocumentReserve.todas),
      ));
    }
  }
  return tags;
}

/// Abre el panel de filtros avanzados y aplica lo elegido al pulsar "Aplicar filtros".
Future<void> showDocumentFilters(BuildContext context) async {
  final documents = context.read<DocumentsProvider>();
  documents.ensureCatalogs();

  final draft = ValueNotifier<DocumentFilters>(documents.filters);
  final applied = await showAppModal(
    context,
    title: 'Filtros avanzados',
    subtitle: documents.kind == DocumentKind.venta ? 'Ventas' : 'Cotizaciones',
    icon: Icons.filter_list,
    primaryLabel: 'Aplicar filtros',
    child: _FiltersBody(draft: draft),
  );
  final result = applied == true ? draft.value : null;
  draft.dispose();
  if (result != null) await documents.applyFilters(result);
}

class _FiltersBody extends StatelessWidget {
  final ValueNotifier<DocumentFilters> draft;

  const _FiltersBody({required this.draft});

  @override
  Widget build(BuildContext context) {
    final documents = context.watch<DocumentsProvider>();
    final catalogs = documents.catalogs;
    final isSale = documents.kind == DocumentKind.venta;
    final now = documents.now;

    String summary(List<int> ids, List<({int id, String name})> options, String all) {
      if (ids.isEmpty) return all;
      if (ids.length > 1) return '${ids.length} elegidos';
      for (final o in options) {
        if (o.id == ids.first) return o.name;
      }
      return '#${ids.first}';
    }

    Future<void> pickIds({
      required String title,
      required IconData icon,
      required List<({int id, String name})> options,
      required List<int> current,
      required DocumentFilters Function(DocumentFilters, List<int>) apply,
    }) async {
      final chosen = await showAppMultiSelect(
        context,
        title: title,
        icon: icon,
        options: options,
        selected: current,
      );
      if (chosen != null) draft.value = apply(draft.value, chosen);
    }

    Future<void> pickDates(DocumentFilters f) async {
      final today = DateTime(now.year, now.month, now.day);
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: today,
        initialDateRange: f.desde != null && f.hasta != null
            ? DateTimeRange(start: f.desde!, end: f.hasta!)
            : DateTimeRange(start: today, end: today),
        helpText: 'Rango de fechas',
        saveText: 'Aplicar',
      );
      if (picked != null) {
        draft.value = draft.value.copyWith(desde: picked.start, hasta: picked.end);
      }
    }

    return ValueListenableBuilder<DocumentFilters>(
      valueListenable: draft,
      builder: (context, f, _) {
        final today = DateTime(now.year, now.month, now.day);
        void setDates(DateTime from, DateTime to) =>
            draft.value = f.copyWith(desde: from, hasta: to);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => draft.value = DocumentFilters.hoy(now),
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
              label: 'Rango de fechas',
              value: _range(f),
              icon: Icons.date_range,
              onTap: () => pickDates(f),
              onClear: f.desde == null ? null : () => draft.value = f.copyWith(desde: null, hasta: null),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: Text('Vacío: todas las fechas.', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Sucursales',
              value: catalogs.sucursales.isEmpty && documents.catalogsLoading
                  ? 'Cargando…'
                  : summary(f.sucursales, catalogs.sucursales, 'Todas'),
              onTap: () => pickIds(
                title: 'Sucursales',
                icon: Icons.store_outlined,
                options: catalogs.sucursales,
                current: f.sucursales,
                apply: (d, ids) => d.copyWith(sucursales: ids),
              ),
            ),
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Ejecutivos',
              value: catalogs.vendedores.isEmpty && documents.catalogsLoading
                  ? 'Cargando…'
                  : summary(f.vendedores, catalogs.vendedores, 'Todos'),
              onTap: () => pickIds(
                title: 'Ejecutivos',
                icon: Icons.badge_outlined,
                options: catalogs.vendedores,
                current: f.vendedores,
                apply: (d, ids) => d.copyWith(vendedores: ids),
              ),
            ),
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Clientes',
              value: catalogs.clientes.isEmpty && documents.catalogsLoading
                  ? 'Cargando…'
                  : summary(f.clientes, catalogs.clientes, 'Todos'),
              onTap: () => pickIds(
                title: 'Clientes',
                icon: Icons.groups_outlined,
                options: catalogs.clientes,
                current: f.clientes,
                apply: (d, ids) => d.copyWith(clientes: ids),
              ),
            ),
            const SizedBox(height: 16),
            if (isSale) ...[
              AppDropdownField<DocumentTipo?>(
                key: ValueKey('tipo-${f.tipo}'),
                label: 'Tipo de documento',
                value: f.tipo,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(value: DocumentTipo.boleta, child: Text('Boleta')),
                  DropdownMenuItem(value: DocumentTipo.factura, child: Text('Factura')),
                  DropdownMenuItem(value: DocumentTipo.notaVenta, child: Text('Nota de venta')),
                ],
                onChanged: (v) => draft.value = f.copyWith(tipo: v),
              ),
              const SizedBox(height: 16),
              AppDropdownField<DocumentEstado?>(
                key: ValueKey('estado-${f.estado}'),
                label: 'Estado del documento',
                value: f.estado,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todas')),
                  DropdownMenuItem(value: DocumentEstado.activos, child: Text('Activos')),
                  DropdownMenuItem(value: DocumentEstado.eliminados, child: Text('Eliminados')),
                ],
                onChanged: (v) => draft.value = f.copyWith(estado: v),
              ),
            ] else ...[
              AppDropdownField<DocumentQuoteState>(
                key: ValueKey('cot-${f.estadoCotizacion}'),
                label: 'Estado de cotización',
                value: f.estadoCotizacion,
                items: const [
                  DropdownMenuItem(value: DocumentQuoteState.todas, child: Text('Todas')),
                  DropdownMenuItem(value: DocumentQuoteState.pendientes, child: Text('Pendientes')),
                  DropdownMenuItem(value: DocumentQuoteState.procesadas, child: Text('Procesadas')),
                ],
                onChanged: (v) => draft.value = f.copyWith(estadoCotizacion: v),
              ),
              const SizedBox(height: 16),
              AppDropdownField<DocumentReserve>(
                key: ValueKey('res-${f.reserva}'),
                label: 'Estado de reserva',
                value: f.reserva,
                items: const [
                  DropdownMenuItem(value: DocumentReserve.todas, child: Text('Todas')),
                  DropdownMenuItem(value: DocumentReserve.reservadas, child: Text('Reservadas')),
                  DropdownMenuItem(value: DocumentReserve.noReservadas, child: Text('No reservadas')),
                ],
                onChanged: (v) => draft.value = f.copyWith(reserva: v),
              ),
            ],
          ],
        );
      },
    );
  }
}
