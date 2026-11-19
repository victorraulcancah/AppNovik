import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/gestion_entity.dart';
import '../../domain/entities/inicio_entity.dart' show TaskPeriod;
import '../components/components.dart';
import '../providers/gestion_provider.dart';
import '../utils/gestion_copy.dart';
import '../utils/inicio_copy.dart' show contactType;
import 'inicio_widgets.dart' show inicioSegmentedStyle;

/// Las tareas pendientes (la pantalla de Gestión sin cliente elegido): las gestiones programadas que siguen sin
/// hacerse, con el mismo filtro de "Mis tareas" del Inicio (Hoy, Semana, Mes y tipo de contacto) y, para quien ve a
/// todo el equipo (Jefe Comercial, CEO), el Ejecutivo comercial de cada una y un filtro por ejecutivo. Tocar una
/// tarea abre a ese cliente en su pestaña Seguimiento.
class GestionTareasView extends StatelessWidget {
  final void Function(GestionTarea tarea) onOpen;

  const GestionTareasView({super.key, required this.onOpen});

  Future<void> _elegirEjecutivo(BuildContext context, GestionProvider gestion) async {
    final chosen = await showAppSelectOne(
      context,
      title: 'Ejecutivo comercial',
      subtitle: 'Elige uno; sin elegir se ven todos',
      icon: Icons.badge_outlined,
      options: [
        for (final e in gestion.ejecutivos)
          (id: e.id, name: '${e.id == GestionProvider.sinEjecutivo ? e.nombre : shortPersonName(e.nombre)} (${e.tareas})'),
      ],
      selected: gestion.ejecutivo,
    );
    if (chosen != null) gestion.setEjecutivo(chosen.id);
  }

  @override
  Widget build(BuildContext context) {
    final gestion = context.watch<GestionProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (gestion.tareasLoading && !gestion.tareasLoaded) return const AppSkeletonList(count: 4);
    if (gestion.tareasError != null && !gestion.tareasLoaded) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar las tareas',
        message: gestion.tareasError,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: gestion.loadTareas),
      );
    }

    final now = gestion.now();
    final delPeriodo = gestion.tareasDelPeriodo;
    final visibles = gestion.tareasVisibles;
    final equipo = gestion.equipo;
    // El mismo orden y nombres de la web.
    const nombres = {'todas': 'Todas', 'llamada': 'Llamadas', 'visita': 'Visitas', 'whatsapp': 'WhatsApp', 'correo': 'Correo'};
    final tipos = nombres.keys.toList();
    final periodText = switch (gestion.periodo) {
      TaskPeriod.hoy => 'para hoy',
      TaskPeriod.semana => 'para la semana',
      TaskPeriod.mes => 'para el mes',
    };
    final ejecutivoElegido = gestion.ejecutivos.where((e) => e.id == gestion.ejecutivo).firstOrNull;

    return RefreshIndicator(
      onRefresh: gestion.loadTareas,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${equipo ? 'Tareas pendientes del equipo' : 'Mis tareas pendientes'} (${delPeriodo.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<TaskPeriod>(
            showSelectedIcon: false,
            style: inicioSegmentedStyle(context),
            segments: [for (final p in TaskPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {gestion.periodo},
            onSelectionChanged: (s) => gestion.setPeriodo(s.first),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (final tipo in tipos) ...[
                  if (tipo != tipos.first) const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('${nombres[tipo]} (${gestion.conteoTareas(tipo)})'),
                    selected: gestion.tipoTareas == tipo,
                    showCheckmark: false,
                    labelStyle: TextStyle(color: scheme.onSurface),
                    onSelected: (_) => gestion.setTipoTareas(tipo),
                  ),
                ],
              ],
            ),
          ),
          if (equipo) ...[
            const SizedBox(height: 6),
            AppPickerField(
              label: 'Ejecutivo comercial',
              value: ejecutivoElegido == null
                  ? 'Todos los ejecutivos'
                  : '${ejecutivoElegido.id == GestionProvider.sinEjecutivo ? ejecutivoElegido.nombre : shortPersonName(ejecutivoElegido.nombre)} (${ejecutivoElegido.tareas})',
              icon: Icons.badge_outlined,
              onTap: () => _elegirEjecutivo(context, gestion),
              onClear: gestion.ejecutivo == null ? null : () => gestion.setEjecutivo(null),
            ),
          ],
          const SizedBox(height: 10),
          if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined, size: 40, color: scheme.outlineVariant),
                  const SizedBox(height: 8),
                  Text(
                    'No hay gestiones pendientes $periodText.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            for (final t in visibles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TareaCard(tarea: t, equipo: equipo, now: now, onTap: () => onOpen(t)),
              ),
          const SizedBox(height: 8),
          _OtroCliente(),
        ],
      ),
    );
  }
}

/// "Cada tarea": "Llamar – Cliente", el ejecutivo y la acción, y cuándo toca.
class _TareaCard extends StatelessWidget {
  final GestionTarea tarea;
  final bool equipo;
  final DateTime now;
  final VoidCallback onTap;

  const _TareaCard({required this.tarea, required this.equipo, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = contactType(tarea.tipo);
    final detalle = [
      if (equipo) tarea.ejecutivo == null ? 'Sin ejecutivo' : shortPersonName(tarea.ejecutivo),
      ?tarea.accion,
    ].join(' · ');
    return AppListCard(
      title: '${type.short} – ${tarea.cliente}',
      lines: [if (detalle.isNotEmpty) detalle],
      leading: Icon(type.icon, color: type.color),
      trailingTitle: gestionTareaCuando(tarea, now),
      trailingTitleColor: tarea.vencida ? const Color(0xFFEF4444) : null,
      onTap: onTap,
    );
  }
}

/// "O elige cualquier cliente": cómo buscar a otro cliente.
class _OtroCliente extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.manage_search, size: 32, color: Color(0xFF8B5CF6)),
          const SizedBox(height: 6),
          Text('O elige cualquier cliente', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Búscalo arriba por nombre, documento o código para ver su ficha, registrar una gestión y dejar '
            'programado el siguiente contacto.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
