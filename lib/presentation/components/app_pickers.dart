import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_modal.dart';

/// Campo que muestra un valor y abre un selector al tocarlo (rango de fechas, lista
/// con varias opciones...). Con [onClear] aparece una ✕ para quitar el valor.
class AppPickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.arrow_drop_down,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClear,
                )
              : Icon(icon),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Selector de varias opciones con búsqueda. Devuelve los ids elegidos al aplicar
/// (vacío = todos) o `null` si se cerró sin aplicar. Con [single] solo se puede elegir una (la
/// misma lista con casillas, pero marcar otra desmarca la anterior): para los filtros que el servidor
/// acepta de a uno.
Future<List<int>?> showAppMultiSelect(
  BuildContext context, {
  required String title,
  required List<({int id, String name})> options,
  required List<int> selected,
  String? subtitle,
  IconData icon = Icons.checklist,
  bool single = false,
}) async {
  final chosen = ValueNotifier<Set<int>>({...selected});
  final applied = await showAppModal(
    context,
    title: title,
    subtitle: subtitle ?? (single ? 'Elige uno; sin elegir se incluyen todos' : 'Sin elegir ninguno se incluyen todos'),
    icon: icon,
    primaryLabel: 'Aplicar',
    child: _MultiSelectBody(options: options, chosen: chosen, single: single),
  );
  final result = applied == true ? chosen.value.toList() : null;
  chosen.dispose();
  return result;
}

/// Elegir **uno** de una lista de vendedores, proveedores, clientes...: el mismo modal de los filtros
/// (casillas, "Buscar", "Quitar todos", Cancelar / Aplicar), con una sola casilla marcada. Es la base de
/// todos los selectores de esas personas. Devuelve `null` si se cerró sin aplicar; si se aplicó, un
/// registro con el id elegido o `id: null` si se dejó sin elegir.
Future<({int? id})?> showAppSelectOne(
  BuildContext context, {
  required String title,
  required List<({int id, String name})> options,
  int? selected,
  String? subtitle,
  IconData icon = Icons.checklist,
}) async {
  final chosen = await showAppMultiSelect(
    context,
    title: title,
    subtitle: subtitle ?? 'Elige uno',
    icon: icon,
    single: true,
    options: options,
    selected: [?selected],
  );
  if (chosen == null) return null;
  return (id: chosen.isEmpty ? null : chosen.first);
}

class _MultiSelectBody extends StatefulWidget {
  final List<({int id, String name})> options;
  final ValueNotifier<Set<int>> chosen;
  final bool single;

  const _MultiSelectBody({required this.options, required this.chosen, this.single = false});

  @override
  State<_MultiSelectBody> createState() => _MultiSelectBodyState();
}

class _MultiSelectBodyState extends State<_MultiSelectBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? widget.options
        : [for (final o in widget.options) if (o.name.toLowerCase().contains(q)) o];
    // Alto según las opciones (cada una mide ~48), con tope para que la lista haga scroll.
    final maxHeight = math.min(360.0, MediaQuery.sizeOf(context).height * 0.45);
    final height = math.min(maxHeight, math.max(96.0, visible.length * 48.0 + 8));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Set<int>>(
          valueListenable: widget.chosen,
          builder: (context, chosen, _) => Row(
            children: [
              Expanded(
                child: Text(
                  chosen.isEmpty ? 'Todos' : (widget.single ? '1 elegido' : '${chosen.length} elegidos'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: chosen.isEmpty ? null : () => widget.chosen.value = {},
                child: const Text('Quitar todos'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    widget.options.isEmpty ? 'No hay opciones' : 'Sin resultados',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              : ValueListenableBuilder<Set<int>>(
                  valueListenable: widget.chosen,
                  builder: (context, chosen, _) => ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final option = visible[i];
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(option.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        value: chosen.contains(option.id),
                        onChanged: (on) {
                          // Elegir uno: marcar otra opción reemplaza la anterior.
                          final next = widget.single ? <int>{} : {...chosen};
                          on == true ? next.add(option.id) : next.remove(option.id);
                          widget.chosen.value = next;
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
