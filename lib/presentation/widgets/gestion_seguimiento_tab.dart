import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/gestion_entity.dart';
import '../components/components.dart';
import '../providers/gestion_provider.dart';
import '../utils/gestion_copy.dart';
import '../utils/success_snack.dart';
import 'gestion_form.dart';
import 'gestion_widgets.dart';

/// La pestaña Seguimiento: las respuestas rápidas (último contacto, resultado, próxima gestión y total del año),
/// el formulario "Registrar nueva gestión" (solo con `clientes.seguimiento.registrar`) y el historial de gestiones
/// con sus filtros. Todo el seguimiento de un cliente en un solo lugar.
class GestionSeguimientoTab extends StatefulWidget {
  const GestionSeguimientoTab({super.key});

  @override
  State<GestionSeguimientoTab> createState() => _GestionSeguimientoTabState();
}

class _GestionSeguimientoTabState extends State<GestionSeguimientoTab> {
  final _draft = GestionFormDraft();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GestionProvider>().loadCatalogo();
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_draft.listo) return;
    final gestion = context.read<GestionProvider>();
    final programa = _draft.programar;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await gestion.registrar(_draft.toNueva());
    if (!mounted) return;
    setState(() {
      _saving = false;
      // El formulario conserva lo escrito: solo se muestra el motivo.
      _error = result.isLeft ? result.left.message : null;
    });
    if (result.isRight) {
      _draft.reset();
      showSuccessSnack(context, programa ? 'Gestión guardada y seguimiento programado' : 'Gestión guardada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gestion = context.watch<GestionProvider>();
    final historial = gestion.historial;
    final ultima = historial.gestiones.isEmpty ? null : historial.gestiones.first;
    final proxima = historial.proxima;
    final catalogo = gestion.catalogo;
    final now = gestion.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestionStatGrid(
          children: [
            GestionStatCard(
              title: 'Último contacto',
              value: ultima == null ? '—' : gestionFecha(ultima.fecha),
              detail: ultima == null
                  ? 'sin gestiones'
                  : '${gestionHaceCuanto(ultima.fecha, now)} • ${ultima.tipo.corto}',
              icon: Icons.phone_outlined,
              color: const Color(0xFF16A34A),
            ),
            GestionStatCard(
              title: 'Resultado',
              value: ultima == null ? '—' : null,
              valueWidget: ultima == null ? null : GestionPill.resultado(ultima.tono, ultima.resultadoEtiqueta),
              detail: ultima == null ? 'sin gestiones' : catalogo?.resultado(ultima.resultado)?.cuando ?? ultima.tipoEtiqueta,
              icon: Icons.handshake_outlined,
              color: ultima == null ? const Color(0xFF64748B) : gestionTonoColor(ultima.tono),
            ),
            GestionStatCard(
              title: 'Próxima gestión',
              value: proxima?.proximoSeguimiento == null ? '—' : gestionFecha(proxima!.proximoSeguimiento!),
              detail: proxima?.proximoSeguimiento == null
                  ? 'sin contacto programado'
                  : '${proxima!.vencida ? 'Vencida · ' : ''}${gestionHora(proxima.proximoSeguimiento!)} · '
                      '${(proxima.proximoTipo ?? proxima.tipo).corto}'
                      '${proxima.proximaAccion != null ? ' · ${proxima.proximaAccion}' : ''}',
              icon: Icons.event_available_outlined,
              color: proxima?.vencida == true ? const Color(0xFFDC2626) : const Color(0xFF7C3AED),
            ),
            GestionStatCard(
              title: 'Total de gestiones',
              value: '${historial.totalAnio}',
              detail: historial.desdeAnio == null ? 'este año' : 'desde ${gestionFecha(historial.desdeAnio!)}',
              icon: Icons.description_outlined,
              color: const Color(0xFF2563EB),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppSection(
          title: 'Registrar nueva gestión',
          icon: Icons.edit_note,
          child: gestion.canRegister ? _form(context) : const Text('No tienes permiso para registrar gestiones.'),
        ),
        const SizedBox(height: 16),
        AppSection(
          title: 'Historial de gestiones',
          icon: Icons.history,
          child: _Historial(canRegister: gestion.canRegister),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestionFormFields(draft: _draft),
          const SizedBox(height: 12),
          if (!_draft.programar)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF16A34A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Se registra la gestión de hoy.',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Si no necesitas otro contacto por ahora, solo guardas.',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: _draft.programar ? 'Guardar gestión y programar' : 'Guardar gestión',
            loading: _saving,
            onPressed: _draft.listo ? _save : null,
          ),
        ],
      ),
    );
  }
}

/// El historial: filtros por tipo, resultado y fechas, y una tarjeta por gestión (la más reciente arriba).
class _Historial extends StatelessWidget {
  final bool canRegister;

  const _Historial({required this.canRegister});

  Future<void> _pickRango(BuildContext context, GestionProvider gestion) async {
    final hoy = gestion.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
      initialDateRange: gestion.rango,
      helpText: 'Elegir fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) gestion.setRango(picked);
  }

  @override
  Widget build(BuildContext context) {
    final gestion = context.watch<GestionProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final catalogo = gestion.catalogo;
    final visibles = gestion.gestionesVisibles;

    Widget chips<T>({
      required List<({T? value, String label})> options,
      required T? selected,
      required ValueChanged<T?> onSelected,
    }) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              ChoiceChip(
                label: Text(options[i].label),
                selected: options[i].value == selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(options[i].value),
              ),
            ],
          ],
        ),
      );
    }

    final Widget lista;
    if (gestion.historialLoading && !gestion.historialLoaded) {
      lista = const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: AppSkeletonDetail(rows: 4));
    } else if (gestion.historialError != null && !gestion.historialLoaded) {
      lista = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErrorBanner(message: gestion.historialError!),
          TextButton(style: gestionEnlace(context), onPressed: gestion.retryClient, child: const Text('Reintentar')),
        ],
      );
    } else if (visibles.isEmpty) {
      lista = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          gestion.historial.gestiones.isEmpty
              ? 'Todavía no hay gestiones con este cliente'
              : 'No hay gestiones con esos filtros',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      lista = Column(
        children: [
          for (final g in visibles) ...[
            _GestionCard(gestion: g, canRegister: canRegister, now: gestion.now()),
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chips<GestionContacto>(
          options: [
            (value: null, label: 'Todos los tipos'),
            for (final t in GestionContacto.values) (value: t, label: t.corto),
          ],
          selected: gestion.filtroTipo,
          onSelected: gestion.setFiltroTipo,
        ),
        chips<String>(
          options: [
            (value: null, label: 'Todos los resultados'),
            for (final r in catalogo?.resultados ?? const <GestionResultado>[]) (value: r.clave, label: r.etiqueta),
          ],
          selected: gestion.filtroResultado,
          onSelected: gestion.setFiltroResultado,
        ),
        const SizedBox(height: 8),
        AppPickerField(
          label: 'Fechas',
          value: '${gestionDia(gestion.rango.start)} – ${gestionDia(gestion.rango.end)}',
          icon: Icons.date_range,
          onTap: () => _pickRango(context, gestion),
        ),
        if (gestion.filtrando)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: gestionEnlace(context),
              onPressed: gestion.clearFiltros,
              child: const Text('Quitar filtros'),
            ),
          ),
        const SizedBox(height: 8),
        lista,
      ],
    );
  }
}

/// El detalle de una gestión.
Future<void> showGestionDetalle(BuildContext context, GestionRegistro g) {
  return showAppModal(
    context,
    title: 'Detalle de la gestión',
    subtitle: gestionDiaHora(g.fecha),
    icon: Icons.description_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestionInfoRow(label: 'Fecha y hora', value: gestionDiaHora(g.fecha)),
        GestionInfoRow(label: 'Tipo de contacto', value: g.tipoEtiqueta),
        GestionInfoRow(label: 'Resultado', valueWidget: GestionPill.resultado(g.tono, g.resultadoEtiqueta)),
        GestionInfoRow(label: 'Comentario', value: g.comentario),
        GestionInfoRow(
          label: 'Próxima gestión',
          value: g.proximoSeguimiento == null ? null : gestionDiaHora(g.proximoSeguimiento!),
        ),
        GestionInfoRow(label: 'Tipo del próximo contacto', value: g.proximoTipoEtiqueta),
        GestionInfoRow(label: 'Próxima acción', value: g.proximaAccion),
        GestionInfoRow(label: 'Registrado por', value: g.registradoPor),
      ],
    ),
  );
}

enum _Accion { editar, reprogramar }

/// Una gestión del historial: tipo, fecha, resultado, comentario, el siguiente contacto y quién la registró. Tocarla
/// abre su detalle; con permiso de registrar, su menú edita o reprograma.
class _GestionCard extends StatelessWidget {
  final GestionRegistro gestion;
  final bool canRegister;
  final DateTime now;

  const _GestionCard({required this.gestion, required this.canRegister, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = gestion;
    final proximo = g.proximoSeguimiento;
    final vencido = proximo != null && proximo.isBefore(now);
    final programada = g.seguimientoEstado == GestionSeguimiento.programado && proximo != null;

    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => showGestionDetalle(context, g),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestionContactoIcon(tipo: g.tipo, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${g.tipo.corto} · ${gestionDia(g.fecha)} ${gestionHora(g.fecha)}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    GestionPill.resultado(g.tono, g.resultadoEtiqueta),
                    if (g.comentario != null) ...[
                      const SizedBox(height: 4),
                      Text(g.comentario!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    ],
                    if (proximo != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Próxima: ${gestionDia(proximo)} · ${[
                              gestionHora(proximo),
                              if (g.proximoTipo != null) g.proximoTipo!.corto,
                              ?g.proximaAccion,
                            ].join(' · ')}',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if (programada)
                            GestionPill(
                              label: vencido ? 'Vencido' : 'Programado',
                              color: vencido ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Por: ${g.registradoPor == null ? '—' : shortPersonName(g.registradoPor)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (canRegister)
                PopupMenuButton<_Accion>(
                  tooltip: 'Acciones',
                  onSelected: (accion) => switch (accion) {
                    _Accion.editar => showGestionEditar(context, g),
                    _Accion.reprogramar => showGestionReprogramar(context, g),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: _Accion.editar, child: Text('Editar')),
                    // Solo el contacto que quedó programado se puede reprogramar.
                    if (programada) const PopupMenuItem(value: _Accion.reprogramar, child: Text('Reprogramar')),
                  ],
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
