import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/app_theme.dart';
import 'app_dropdown_field.dart';

class AppFilterOption {
  final String value;
  final String label;
  const AppFilterOption(this.value, this.label);
}

/// Un filtro de la hoja: un desplegable con una opción "todas" (valor `null`).
class AppFilterField {
  final String id;
  final String label;
  final List<AppFilterOption> options;

  /// Valor aplicado actualmente; `null` es "todas".
  final String? value;

  /// Texto de la opción sin filtro ("Todas", "Todos").
  final String allLabel;

  const AppFilterField({
    required this.id,
    required this.label,
    required this.options,
    this.value,
    this.allLabel = 'Todas',
  });
}

/// Abre la hoja de filtros. Devuelve un mapa `id -> valor` (con `null` para
/// "todas") al pulsar el botón de aplicar, o `null` si se cerró sin aplicar.
///
/// En celular sube como hoja inferior; en tablet es un diálogo centrado.
Future<Map<String, String?>?> showAppFilterSheet(
  BuildContext context, {
  String title = 'Filtros',
  required List<AppFilterField> fields,
  String applyLabel = 'Ver resultados',
}) {
  Widget content(BuildContext ctx, {required bool handle}) => _FilterContent(
        title: title,
        fields: fields,
        applyLabel: applyLabel,
        showHandle: handle,
      );

  final isTablet =
      MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

  if (isTablet) {
    return showDialog<Map<String, String?>>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: content(ctx, handle: false),
        ),
      ),
    );
  }

  return showModalBottomSheet<Map<String, String?>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => content(ctx, handle: true),
  );
}

class _FilterContent extends StatefulWidget {
  final String title;
  final List<AppFilterField> fields;
  final String applyLabel;
  final bool showHandle;

  const _FilterContent({
    required this.title,
    required this.fields,
    required this.applyLabel,
    required this.showHandle,
  });

  @override
  State<_FilterContent> createState() => _FilterContentState();
}

class _FilterContentState extends State<_FilterContent> {
  late final Map<String, String?> _values = {
    for (final f in widget.fields) f.id: f.value,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHandle)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(Icons.filter_list, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final f in widget.fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AppDropdownField<String?>(
                        label: f.label,
                        value: _values[f.id],
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(f.allLabel),
                          ),
                          for (final o in f.options)
                            DropdownMenuItem<String?>(
                              value: o.value,
                              child: Text(o.label),
                            ),
                        ],
                        onChanged: (v) => setState(() => _values[f.id] = v),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.strongFill(theme.brightness),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(_values),
                child: Text(widget.applyLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
