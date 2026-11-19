import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/gestion_entity.dart';
import '../components/components.dart';
import '../providers/gestion_provider.dart';
import '../utils/gestion_copy.dart';
import '../utils/inicio_copy.dart' show soles;
import 'gestion_abrir.dart';
import 'gestion_widgets.dart';

/// La pestaña Documentos: las cotizaciones y las ventas (facturas, boletas y tickets) del cliente en un rango de
/// fechas (por defecto, el año actual), con el ejecutivo, el almacén, el monto y la fecha. Tocar un documento lo abre.
class GestionDocumentosTab extends StatefulWidget {
  const GestionDocumentosTab({super.key});

  @override
  State<GestionDocumentosTab> createState() => _GestionDocumentosTabState();
}

class _GestionDocumentosTabState extends State<GestionDocumentosTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GestionProvider>().ensureDocumentos();
    });
  }

  Future<void> _pickRango(GestionProvider gestion) async {
    final hoy = gestion.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
      initialDateRange: gestion.rangoDocumentos,
      helpText: 'Elegir fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) await gestion.setRangoDocumentos(picked);
  }

  Future<void> _pickVista(GestionProvider gestion, Map<String, String> vistas) async {
    final claves = vistas.keys.toList();
    final chosen = await showAppSelectOne(
      context,
      title: 'Tipo de documento',
      subtitle: 'Elige uno',
      icon: Icons.description_outlined,
      options: [
        for (var i = 0; i < claves.length; i++)
          (id: i, name: '${vistas[claves[i]]} (${gestion.conteoDocumentos(claves[i])})'),
      ],
      selected: claves.indexOf(gestion.vistaDocumentos),
    );
    if (chosen?.id != null) gestion.setVistaDocumentos(claves[chosen!.id!]);
  }

  @override
  Widget build(BuildContext context) {
    final gestion = context.watch<GestionProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hoy = gestion.now();
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    final rango = gestion.rangoDocumentos;

    const vistas = {'todos': 'Todos', 'cotizaciones': 'Cotizaciones', 'ventas': 'Ventas'};
    final presets = {
      'Este año': DateTimeRange(start: DateTime(hoy.year), end: dia),
      'Año pasado': DateTimeRange(start: DateTime(hoy.year - 1), end: DateTime(hoy.year - 1, 12, 31)),
      'Últimos 12 meses': DateTimeRange(start: DateTime(hoy.year - 1, hoy.month, hoy.day + 1), end: dia),
    };

    final Widget lista;
    final documentos = gestion.documentos;
    if (documentos == null && gestion.documentosError != null) {
      lista = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorBanner(message: gestion.documentosError!),
          TextButton(style: gestionEnlace(context), onPressed: gestion.loadDocumentos, child: const Text('Reintentar')),
        ],
      );
    } else if (documentos == null || gestion.documentosLoading) {
      lista = const AppSkeletonDetail(rows: 5);
    } else if (gestion.documentosVisibles.isEmpty) {
      lista = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No hay documentos en este rango de fechas',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      final visibles = gestion.documentosVisibles;
      lista = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visibles.length; i++) ...[
            _DocumentoCard(numero: i + 1, documento: visibles[i], abriendo: gestion.abriendoDocumento),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${visibles.length} documentos',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Un selector (no una fila de botones que se corta): Todos, Cotizaciones o Ventas, cada uno con su conteo.
        AppPickerField(
          label: 'Tipo de documento',
          value: '${vistas[gestion.vistaDocumentos]} (${gestion.conteoDocumentos(gestion.vistaDocumentos)})',
          icon: Icons.description_outlined,
          onTap: () => _pickVista(gestion, vistas),
        ),
        const SizedBox(height: 8),
        AppPickerField(
          label: 'Fecha',
          value: '${gestionDia(rango.start)} – ${gestionDia(rango.end)}',
          icon: Icons.date_range,
          onTap: () => _pickRango(gestion),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              for (final p in presets.entries) ...[
                if (p.key != presets.keys.first) const SizedBox(width: 8),
                ActionChip(label: Text(p.key), onPressed: () => gestion.setRangoDocumentos(p.value)),
              ],
            ],
          ),
        ),
        if (gestion.abriendoDocumento) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2)),
        const SizedBox(height: 12),
        lista,
      ],
    );
  }
}

/// Un documento: su número (en rojo si está anulado), el ejecutivo, el almacén, el monto y la fecha. Tocarlo lo abre.
class _DocumentoCard extends StatelessWidget {
  final int numero;
  final GestionDocumento documento;
  final bool abriendo;

  const _DocumentoCard({required this.numero, required this.documento, required this.abriendo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = documento;
    final estado = d.anulado
        ? const Color(0xFFDC2626)
        : switch (d.estado) {
            'Pendiente' => const Color(0xFFD97706),
            'Convertida' => const Color(0xFF2563EB),
            _ => const Color(0xFF16A34A),
          };

    Widget dato(IconData icon, Color color, String text) => Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
          ],
        );

    return Semantics(
      button: true,
      label: 'Abrir el documento ${d.numero}',
      child: Material(
        color: scheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: abriendo
              ? null
              : () => abrirComprobanteGestion(context, cotizacion: d.esCotizacion, id: d.id, nroDocumento: d.nroDocumento),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$numero', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Expanded(child: GestionDocumentoLink(texto: d.numero, anulado: d.anulado)),
                    const SizedBox(width: 8),
                    Text(
                      soles(d.monto, 2),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (d.ejecutivo != null) dato(Icons.person_outline, const Color(0xFF0EA5E9), 'Ejecutivo: ${shortPersonName(d.ejecutivo)}'),
                if (d.almacen != null) dato(Icons.warehouse_outlined, const Color(0xFF65A30D), d.almacen!),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestionPill(label: d.estado.isEmpty ? '—' : d.estado, color: estado),
                    const Spacer(),
                    Text(
                      gestionDia(d.fecha),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
