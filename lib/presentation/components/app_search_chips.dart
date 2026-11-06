import 'package:flutter/material.dart';

/// Los términos de búsqueda ya confirmados, como chips que se pueden quitar uno a uno (como
/// los filtros activos de la web). Sin términos no ocupa lugar.
class AppSearchChips extends StatelessWidget {
  final List<String> terms;
  final ValueChanged<String> onRemove;
  final VoidCallback? onClear;

  const AppSearchChips({
    super.key,
    required this.terms,
    required this.onRemove,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final term in terms)
              InputChip(
                key: ValueKey('chip-$term'),
                label: Text(term),
                visualDensity: VisualDensity.compact,
                onDeleted: () => onRemove(term),
                deleteButtonTooltipMessage: 'Quitar "$term"',
              ),
            if (onClear != null && terms.length > 1)
              TextButton(onPressed: onClear, child: const Text('Limpiar todo')),
          ],
        ),
      ),
    );
  }
}
