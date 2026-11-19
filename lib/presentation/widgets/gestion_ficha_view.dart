import 'package:flutter/material.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/gestion_entity.dart';
import '../components/components.dart';
import '../utils/contact_launcher.dart';
import '../utils/gestion_copy.dart';
import '../utils/inicio_copy.dart' show soles;
import 'gestion_widgets.dart';

void _aviso(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// "¿Qué significa cada estado?": cada estado con su rango de % de caída y lo que quiere decir.
Future<void> showGestionAyudaEstados(BuildContext context, {required int anioActual}) {
  return showAppModal(
    context,
    title: '¿Qué significa cada estado?',
    subtitle: 'Se comparan las ventas de $anioActual con el mismo periodo de ${anioActual - 1}',
    icon: Icons.help_outline,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: Builder(
      builder: (modalContext) {
        final theme = Theme.of(modalContext);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final fila in gestionEstadosAyuda)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: gestionEstadoUi(fila.estado).color.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.18 : 0.08,
                      ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: gestionEstadoUi(fila.estado).color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gestionEstadoUi(fila.estado).etiqueta,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: gestionLegible(gestionEstadoUi(fila.estado).color, theme.brightness),
                            ),
                          ),
                        ),
                        GestionPill(label: fila.rango, color: gestionEstadoUi(fila.estado).color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(fila.significado, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// La tarjeta de estado de la cabecera: cuánto vendió de más o de menos el cliente del 1 de enero a hoy contra el
/// mismo tramo del año anterior, con el rango del estado (71 % o más, 26 - 70 %...). Sin ventas entonces no hay
/// comparación.
class GestionEstadoCard extends StatelessWidget {
  final GestionCliente cliente;
  final GestionPeriodo periodo;

  const GestionEstadoCard({super.key, required this.cliente, required this.periodo});

  @override
  Widget build(BuildContext context) {
    final ayuda = IconButton(
      tooltip: '¿Qué significa cada estado?',
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      icon: const Icon(Icons.help_outline),
      onPressed: () => showGestionAyudaEstados(context, anioActual: periodo.desde.year),
    );
    final caida = periodo.caidaPct;

    if (cliente.estado == GestionEstado.sinBase || caida == null) {
      return GestionStatCard(
        title: 'Sin comparación',
        titleTrailing: ayuda,
        value: '—',
        detail: 'No compró del ${periodo.etiquetaAnterior}',
        icon: Icons.help_outline,
        color: const Color(0xFF64748B),
      );
    }

    final ui = gestionEstadoUi(cliente.estado);
    final cayo = caida > 0;
    return GestionStatCard(
      title: ui.etiqueta,
      titleTrailing: ayuda,
      note: ui.rango,
      value: '${periodo.variacion < 0 ? '-' : '+'}${soles(periodo.variacion.abs())}',
      detail: '${cayo ? '-' : '+'}${caida.abs().toStringAsFixed(1)} % frente a ${periodo.etiquetaAnterior}',
      icon: ui.icono,
      color: ui.color,
    );
  }
}

/// La cabecera de la ficha: nombre y estado del cliente, sus datos de contacto (tocar el teléfono llama, tocar el
/// correo escribe) y la tarjeta de estado.
class GestionFichaHeader extends StatelessWidget {
  final GestionFicha ficha;

  const GestionFichaHeader({super.key, required this.ficha});

  Future<void> _abrir(BuildContext context, Future<bool> Function() abrir, String error) async {
    final ok = await abrir();
    if (!ok && context.mounted) _aviso(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cliente = ficha.cliente;
    final estado = gestionEstadoUi(cliente.estado);
    final etiquetaDocumento = cliente.documento != null && cliente.documento!.length == 11 ? 'RUC' : 'DNI';
    final datos = [
      ?cliente.codigo,
      if (cliente.documento != null) '$etiquetaDocumento ${cliente.documento}',
      ?cliente.categoria,
      ?cliente.ciudad,
    ];
    final whatsapp = ContactLauncher.whatsappNumber(cliente.telefono);

    Widget contacto({
      required IconData icon,
      required String text,
      VoidCallback? onTap,
      String? tooltip,
    }) {
      final fila = Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      );
      if (onTap == null) return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: fila);
      return Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44), child: Center(child: fila)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  cliente.esEmpresa ? Icons.business : Icons.person_outline,
                  size: 28,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nombre,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    GestionPill(label: cliente.estadoEtiqueta, color: estado.color),
                  ],
                ),
              ),
            ],
          ),
          if (datos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              datos.join('  |  '),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 4),
          if (cliente.telefono != null)
            Row(
              children: [
                Expanded(
                  child: contacto(
                    icon: Icons.phone_outlined,
                    text: cliente.telefono!,
                    tooltip: 'Llamar a ${cliente.telefono}',
                    onTap: () => _abrir(context, () => ContactLauncher.call(cliente.telefono!), 'No se pudo abrir el teléfono'),
                  ),
                ),
                if (whatsapp != null)
                  IconButton(
                    tooltip: 'Escribir por WhatsApp',
                    icon: const Icon(Icons.chat_outlined, color: Color(0xFF22C55E)),
                    onPressed: () => _abrir(context, () => ContactLauncher.whatsapp(whatsapp), 'No se pudo abrir WhatsApp'),
                  ),
              ],
            ),
          if (cliente.email != null)
            contacto(
              icon: Icons.mail_outline,
              text: cliente.email!,
              tooltip: 'Escribir a ${cliente.email}',
              onTap: () => _abrir(context, () => ContactLauncher.email(cliente.email!), 'No se pudo abrir el correo'),
            ),
          if (cliente.direccion != null) contacto(icon: Icons.place_outlined, text: cliente.direccion!),
          if (cliente.contactoOculto)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Algunos datos de contacto no se muestran con tu perfil.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 12),
          GestionEstadoCard(cliente: cliente, periodo: ficha.periodo),
        ],
      ),
    );
  }
}

/// La pestaña Resumen: ventas del año, información general, última gestión, próximo contacto, última compra y
/// principales productos.
class GestionResumenTab extends StatelessWidget {
  final GestionFicha ficha;

  /// Con permiso de registrar, la última gestión vacía ofrece registrar la primera.
  final bool canRegister;
  final VoidCallback onRegistrarPrimera;

  const GestionResumenTab({
    super.key,
    required this.ficha,
    required this.canRegister,
    required this.onRegistrarPrimera,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cliente = ficha.cliente;
    final kpis = ficha.kpis;
    final periodo = ficha.periodo;
    final ultima = ficha.ultimaGestion;
    final proxima = ficha.proximaGestion;
    final compra = kpis.ultimaCompra;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestionStatGrid(
          children: [
            GestionStatCard(
              title: 'Sin comprar',
              value: kpis.diasSinComprar == null ? 'Sin compras' : '${kpis.diasSinComprar} días',
              detail: compra == null
                  ? 'aún no compró'
                  : 'desde el ${gestionFecha(compra.fecha)}\nÚltima compra ${compra.documento} · ${soles(compra.monto, 2)}',
              icon: Icons.calendar_month_outlined,
              color: kpis.diasSinComprar == null ? const Color(0xFF64748B) : gestionColorDeDias(kpis.diasSinComprar),
            ),
            GestionStatCard(
              title: 'Ventas',
              note: periodo.etiqueta,
              value: soles(periodo.ventas),
              detail: '${periodo.etiquetaAnterior}: ${soles(periodo.ventasAnterior)}',
              icon: Icons.bar_chart,
            ),
            GestionStatCard(
              title: 'N.º de compras',
              note: periodo.etiqueta,
              value: '${periodo.compras}',
              detail: 'solo el año actual',
              icon: Icons.shopping_cart_outlined,
            ),
            GestionStatCard(
              title: 'Ticket promedio',
              note: periodo.etiqueta,
              value: soles(periodo.ticketPromedio, 2),
              detail: 'ventas entre N.º de compras',
              icon: Icons.confirmation_number_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppSection(
          title: 'Información general',
          icon: Icons.badge_outlined,
          child: Column(
            children: [
              GestionInfoRow(label: cliente.esEmpresa ? 'Razón social' : 'Nombre', value: cliente.nombre),
              GestionInfoRow(
                label: cliente.documento != null && cliente.documento!.length == 11 ? 'RUC' : 'DNI / documento',
                value: cliente.documento,
              ),
              GestionInfoRow(label: 'Tipo de cliente', value: cliente.esEmpresa ? 'Empresa' : 'Persona'),
              GestionInfoRow(label: 'Ejecutivo comercial', value: cliente.vendedor == null ? null : shortPersonName(cliente.vendedor)),
              GestionInfoRow(label: 'Teléfono', value: cliente.telefono),
              GestionInfoRow(label: 'Correo', value: cliente.email),
              GestionInfoRow(label: 'Dirección', value: cliente.direccion),
              GestionInfoRow(label: 'Ciudad', value: cliente.ciudad),
              GestionInfoRow(label: 'Condición de pago', value: cliente.condicionPago ?? 'Contado'),
              GestionInfoRow(
                label: 'Límite de crédito',
                value: cliente.limiteCredito > 0 ? soles(cliente.limiteCredito) : null,
              ),
              GestionInfoRow(label: 'Clasificación', value: cliente.categoria),
              GestionInfoRow(
                label: 'Estado',
                value: '${cliente.activo ? 'Activo' : 'Inactivo'} · ${cliente.estadoEtiqueta}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSection(
          title: 'Última gestión',
          icon: Icons.history,
          child: ultima == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Todavía no hay gestiones con este cliente',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (canRegister) ...[
                      const SizedBox(height: 12),
                      AppButton(label: 'Registrar la primera gestión', onPressed: onRegistrarPrimera),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestionContactoIcon(tipo: ultima.tipo, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ultima.tipoEtiqueta, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            '${gestionFecha(ultima.fecha)} · ${gestionHora(ultima.fecha)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          GestionPill.resultado(ultima.tono, ultima.resultadoEtiqueta),
                          if (ultima.comentario != null) ...[
                            const SizedBox(height: 6),
                            Text(ultima.comentario!, style: theme.textTheme.bodyMedium),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Por: ${ultima.registradoPor ?? '—'}',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        AppSection(
          title: 'Próximo contacto',
          icon: Icons.event_outlined,
          child: proxima != null && proxima.proximoSeguimiento != null
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF3B82F6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${gestionFecha(proxima.proximoSeguimiento!)} · ${gestionHora(proxima.proximoSeguimiento!)}',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${proxima.proximoTipoEtiqueta ?? proxima.tipoEtiqueta}'
                            '${proxima.proximaAccion != null ? ' · ${proxima.proximaAccion}' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          GestionPill(
                            label: proxima.vencida ? 'Vencido' : 'Programado',
                            color: proxima.vencida ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Text('No hay un contacto programado.', style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(height: 16),
        AppSection(
          title: 'Última compra',
          icon: Icons.shopping_cart_outlined,
          child: compra == null
              ? Text('Sin compras registradas.', style: theme.textTheme.bodyMedium)
              : Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(gestionFecha(compra.fecha), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            compra.documento,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
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
                  ],
                ),
        ),
        const SizedBox(height: 16),
        AppSection(
          title: 'Principales productos (año actual)',
          icon: Icons.inventory_2_outlined,
          child: ficha.productos.isEmpty
              ? Text('Sin compras este año.', style: theme.textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final p in ficha.productos) _ProductoBarra(producto: p),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Un producto de los principales: su código y nombre, lo que compró con su parte del total del año, y una barra.
class _ProductoBarra extends StatelessWidget {
  final GestionProducto producto;

  const _ProductoBarra({required this.producto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      // El código va delante de la descripción, como en el reporte de Productos y Servicios.
                      if (producto.codigo != null)
                        TextSpan(text: '${producto.codigo}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: producto.producto),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              // Lo que compró y qué parte del total del año es, con un decimal ("Otros" es el resto).
              Text(
                '${soles(producto.monto)} · ${producto.porcentaje.toStringAsFixed(1)} %',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (producto.porcentaje / 100).clamp(0.0, 1.0),
              minHeight: 6,
              color: const Color(0xFF0EA5E9),
              backgroundColor: scheme.surfaceContainer,
            ),
          ),
        ],
      ),
    );
  }
}
