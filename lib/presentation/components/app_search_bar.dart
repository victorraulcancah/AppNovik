import 'package:flutter/material.dart';

/// Campo de búsqueda Material 3 para listas, con botón de filtros opcional a la
/// derecha. [filterActive] marca el botón cuando hay filtros aplicados.
class AppSearchBar extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilter;
  final bool filterActive;

  /// Otros botones junto al de filtros (por ejemplo, descargar el Excel).
  final List<Widget> actions;

  const AppSearchBar({
    super.key,
    this.hint = 'Buscar',
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onFilter,
    this.filterActive = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SearchBar(
              controller: controller,
              hintText: hint,
              elevation: const WidgetStatePropertyAll(0),
              leading: const Icon(Icons.search),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          if (onFilter != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Filtros',
              onPressed: onFilter,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Badge(
                isLabelVisible: filterActive,
                smallSize: 8,
                child: const Icon(Icons.filter_list),
              ),
            ),
          ],
          ...actions,
        ],
      ),
    );
  }
}
