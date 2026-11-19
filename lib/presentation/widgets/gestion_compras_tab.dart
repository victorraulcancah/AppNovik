import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/gestion_entity.dart';
import '../../theme/app_theme.dart';
import '../components/components.dart';
import '../providers/gestion_provider.dart';
import '../utils/gestion_copy.dart';
import '../utils/inicio_copy.dart' show soles;
import 'gestion_abrir.dart';
import 'gestion_widgets.dart';
import 'inicio_widgets.dart' show inicioSegmentedStyle;

const _meses = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];

/// La pestaña Compras: las ventas del año contra el año anterior, la evolución mes a mes (mensual y acumulada) y, del
/// año que se elija, las últimas compras y el top 10 de productos, marcas y categorías. Tocar una compra abre su
/// comprobante.
class GestionComprasTab extends StatefulWidget {
  const GestionComprasTab({super.key});

  @override
  State<GestionComprasTab> createState() => _GestionComprasTabState();
}

class _GestionComprasTabState extends State<GestionComprasTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GestionProvider>().ensureCompras();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gestion = context.watch<GestionProvider>();
    final datos = gestion.compras;

    if (datos == null) {
      if (gestion.comprasError != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorBanner(message: gestion.comprasError!),
            TextButton(style: gestionEnlace(context), onPressed: gestion.loadCompras, child: const Text('Reintentar')),
          ],
        );
      }
      return const AppSkeletonDetail(rows: 6);
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final anioListas = datos.anioListas;
    final vacio = 'Sin compras en $anioListas';
    final corte = datos.acumulado.map((m) => m.corte).whereType<String>().firstOrNull;
    final anios = [datos.anioAnterior, datos.anioActual];

    String mes(GestionMes m) => _meses[(m.mes - 1).clamp(0, 11)];
    final etiquetas = [for (final m in datos.evolucion) mes(m)];
    final acumuladoActual = datos.acumulado.takeWhile((m) => m.actual != null).map((m) => m.actual!).toList();

    final anterior = scheme.outlineVariant;
    final actual = AppTheme.strongFill(theme.brightness);

    Widget leyenda(Color color, int anio) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(
              '$anio',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: anio == anioListas ? FontWeight.w800 : FontWeight.w400,
                color: anio == anioListas ? null : scheme.onSurfaceVariant,
              ),
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (gestion.comprasError != null) ...[
          ErrorBanner(message: gestion.comprasError!),
          const SizedBox(height: 12),
        ],
        _TarjetasPeriodo(periodo: datos.periodo),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Evolución de compras',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (gestion.comprasLoading)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            Text('Año', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            // El año solo cambia las listas de abajo: los gráficos ya muestran los dos.
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: inicioSegmentedStyle(context),
              segments: [for (final a in anios) ButtonSegment(value: a, label: Text('$a'))],
              selected: {gestion.anioCompras ?? anioListas},
              onSelectionChanged: (s) => gestion.setAnioCompras(s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppSection(
          title: 'Ventas al ${datos.hasta} | ${datos.anioAnterior} vs. ${datos.anioActual}',
          icon: Icons.bar_chart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 16, children: [leyenda(anterior, datos.anioAnterior), leyenda(actual, datos.anioActual)]),
              const SizedBox(height: 8),
              AppGroupedBarChart(
                labels: etiquetas,
                previous: [for (final m in datos.evolucion) m.anterior],
                current: [for (final m in datos.evolucion) m.actual ?? 0],
                height: 220,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSection(
          title: 'Ventas acumulada al ${datos.hasta} | ${datos.anioAnterior} vs. ${datos.anioActual}',
          icon: Icons.show_chart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 16,
                children: [
                  leyenda(const Color(0xFF64748B), datos.anioAnterior),
                  leyenda(const Color(0xFF2563EB), datos.anioActual),
                ],
              ),
              const SizedBox(height: 8),
              AppAreaChart(
                labels: etiquetas,
                series: [
                  AreaSeries(
                    name: '${datos.anioAnterior}',
                    color: const Color(0xFF64748B),
                    values: [for (final m in datos.acumulado) m.anterior],
                  ),
                  // Después del mes en curso el año actual todavía no tiene venta: la línea se corta, no cae a cero.
                  AreaSeries(name: '${datos.anioActual}', color: const Color(0xFF2563EB), values: acumuladoActual),
                ],
                format: (v) => soles(v, 2),
                height: 220,
              ),
              if (corte != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${datos.anioAnterior} se suma $corte, el mismo día que ${datos.anioActual}.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSection(
          title: 'Últimas compras',
          icon: Icons.receipt_long_outlined,
          trailing: Text('solo $anioListas', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          child: datos.ultimasCompras.isEmpty
              ? Text(vacio, style: theme.textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final c in datos.ultimasCompras) _CompraFila(compra: c),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _TopSeccion(titulo: 'Top 10 productos $anioListas', icono: Icons.inventory_2_outlined, filas: datos.topProductos, vacio: vacio),
        const SizedBox(height: 16),
        _TopSeccion(titulo: 'Top 10 marcas $anioListas', icono: Icons.sell_outlined, filas: datos.topMarcas, vacio: vacio),
        const SizedBox(height: 16),
        _TopSeccion(titulo: 'Top 10 categorías $anioListas', icono: Icons.category_outlined, filas: datos.topCategorias, vacio: vacio),
      ],
    );
  }
}

/// Las 4 tarjetas del periodo: lo vendido el año anterior y este año en el mismo tramo (del 1 de enero a hoy), el
/// número de compras con su ticket promedio y cuánto crece o cae contra el año anterior.
class _TarjetasPeriodo extends StatelessWidget {
  final GestionPeriodo periodo;

  const _TarjetasPeriodo({required this.periodo});

  @override
  Widget build(BuildContext context) {
    // Cuánto creció (+) o cayó (-) contra el mismo tramo del año anterior; sin ventas entonces no hay comparación.
    final caida = periodo.caidaPct;
    final variacion = caida == null ? null : -caida;
    final anioActual = periodo.hasta.year;
    final anioAnterior = anioActual - 1;
    // Las mismas fechas en los dos años: "01/01 - 22/10".
    final fechas = '${gestionDiaMes(periodo.desde)} - ${gestionDiaMes(periodo.hasta)}';

    return GestionStatGrid(
      children: [
        GestionStatCard(
          title: 'Ventas $anioAnterior',
          note: fechas,
          value: soles(periodo.ventasAnterior),
          detail: 'mismo tramo del año anterior',
          icon: Icons.bar_chart,
        ),
        GestionStatCard(
          title: 'Ventas $anioActual',
          note: fechas,
          value: soles(periodo.ventas),
          detail: 'del 1 de enero a hoy',
          icon: Icons.bar_chart,
        ),
        GestionStatCard(
          title: 'N.º de compras',
          note: fechas,
          value: '${periodo.compras}',
          detail: 'ticket promedio ${soles(periodo.ticketPromedio, 2)}',
          icon: Icons.shopping_cart_outlined,
        ),
        GestionStatCard(
          title: 'Contra el año anterior',
          note: periodo.etiquetaAnterior,
          value: variacion == null ? '—' : '${variacion > 0 ? '+' : ''}${variacion.toStringAsFixed(1)} %',
          detail: variacion == null ? 'no compró entonces' : 'antes: ${soles(periodo.ventasAnterior)}',
          icon: variacion != null && variacion < 0 ? Icons.trending_down : Icons.trending_up,
          color: variacion == null
              ? const Color(0xFF64748B)
              : (variacion < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
        ),
      ],
    );
  }
}

/// Una compra de la lista: tocar el documento abre su comprobante.
class _CompraFila extends StatelessWidget {
  final GestionUltimaCompra compra;

  const _CompraFila({required this.compra});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => abrirComprobanteGestion(context, cotizacion: false, id: compra.id),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestionDocumentoLink(texto: compra.documento),
                    Text(
                      gestionFecha(compra.fecha),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                soles(compra.monto, 2),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un top 10: el nombre (con su código en los productos), lo que compró y debajo qué parte del total del año
/// representa ("Otros" es el resto).
class _TopSeccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<GestionTop> filas;
  final String vacio;

  const _TopSeccion({required this.titulo, required this.icono, required this.filas, required this.vacio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppSection(
      title: titulo,
      icon: icono,
      child: filas.isEmpty
          ? Text(vacio, style: theme.textTheme.bodyMedium)
          : Column(
              children: [
                for (final f in filas)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: f.esOtros
                              ? Text(
                                  f.nombre,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                )
                              : Text.rich(
                                  TextSpan(
                                    children: [
                                      // En los productos, el código va delante de la descripción.
                                      if (f.codigo != null)
                                        TextSpan(text: '${f.codigo}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      TextSpan(text: f.nombre),
                                    ],
                                  ),
                                  style: theme.textTheme.bodyMedium,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              soles(f.monto),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            // Siempre con un decimal; menos de 0.1 % se escribe "<0.1", no "0.0".
                            Text(
                              '${f.porcentaje < 0.1 ? '<0.1' : f.porcentaje.toStringAsFixed(1)} %',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
