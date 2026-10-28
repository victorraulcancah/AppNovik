import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import 'app_modal.dart';
import 'error_banner.dart';

/// Un resultado de [showAppSearchSheet]: lo que se muestra de cada elemento.
class AppSearchItem {
  final String title;
  final String? subtitle;

  /// Texto destacado a la derecha (un precio, un stock).
  final String? trailing;

  /// Cantidad ya elegida de este elemento; se muestra como una insignia.
  final int selectedCount;

  const AppSearchItem({
    required this.title,
    this.subtitle,
    this.trailing,
    this.selectedCount = 0,
  });
}

/// Selector con búsqueda en el servidor: el usuario escribe, se consulta [search]
/// (con una pausa para no llamar en cada tecla) y elige un resultado.
///
/// Usa el modal estándar de la app. Con [closeOnSelect] en `false` el selector
/// sigue abierto para elegir varios; pasa [refresh] (por ejemplo el provider)
/// para que las insignias de [AppSearchItem.selectedCount] se actualicen.
///
/// [onSelect] puede devolver un mensaje para mostrar sobre la lista (por
/// ejemplo "sin stock"); si devuelve `null` la selección se aceptó.
Future<void> showAppSearchSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.search,
  required String hint,
  required Future<Either<Failure, List<T>>> Function(String query) search,
  required AppSearchItem Function(T item) itemOf,
  required String? Function(T item) onSelect,
  bool closeOnSelect = true,
  Listenable? refresh,
  String emptyHint = 'Escribe para buscar',
  String closeLabel = 'Cerrar',
}) {
  return showAppModal(
    context,
    title: title,
    subtitle: subtitle,
    icon: icon,
    primaryLabel: null,
    secondaryLabel: closeLabel,
    child: _SearchBody<T>(
      hint: hint,
      emptyHint: emptyHint,
      search: search,
      itemOf: itemOf,
      onSelect: onSelect,
      closeOnSelect: closeOnSelect,
      refresh: refresh,
    ),
  );
}

class _SearchBody<T> extends StatefulWidget {
  final String hint;
  final String emptyHint;
  final Future<Either<Failure, List<T>>> Function(String query) search;
  final AppSearchItem Function(T item) itemOf;
  final String? Function(T item) onSelect;
  final bool closeOnSelect;
  final Listenable? refresh;

  const _SearchBody({
    required this.hint,
    required this.emptyHint,
    required this.search,
    required this.itemOf,
    required this.onSelect,
    required this.closeOnSelect,
    required this.refresh,
  });

  @override
  State<_SearchBody<T>> createState() => _SearchBodyState<T>();
}

class _SearchBodyState<T> extends State<_SearchBody<T>> {
  Timer? _debounce;
  int _request = 0;
  String _query = '';
  bool _loading = false;
  String? _error;
  String? _notice;
  List<T> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      _request++;
      setState(() {
        _query = '';
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(query));
  }

  Future<void> _run(String query) async {
    final request = ++_request;
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
      _notice = null;
    });
    final result = await widget.search(query);
    if (!mounted || request != _request) return;
    setState(() {
      _loading = false;
      result.fold(
        (failure) {
          _results = [];
          _error = failure.message;
        },
        (items) => _results = items,
      );
    });
  }

  void _select(T item) {
    final problem = widget.onSelect(item);
    if (problem != null) {
      setState(() => _notice = problem);
      return;
    }
    if (widget.closeOnSelect) {
      Navigator.of(context).pop();
    } else {
      setState(() => _notice = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget list() {
      final refresh = widget.refresh;
      Widget tiles(BuildContext context) => Column(
            children: [
              for (final item in _results) _tile(context, item),
            ],
          );
      return refresh == null
          ? tiles(context)
          : ListenableBuilder(listenable: refresh, builder: (c, _) => tiles(c));
    }

    final Widget results;
    if (_error != null) {
      results = ErrorBanner(message: _error!);
    } else if (_loading && _results.isEmpty) {
      results = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_query.isEmpty) {
      results = _Message(icon: Icons.search, text: widget.emptyHint);
    } else if (_results.isEmpty && !_loading) {
      results = const _Message(icon: Icons.search_off, text: 'Sin resultados');
    } else {
      results = list();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(hint: widget.hint, onChanged: _onChanged),
        if (_notice != null) ...[
          const SizedBox(height: 8),
          ErrorBanner(message: _notice!),
        ],
        const SizedBox(height: 8),
        if (_loading && _results.isNotEmpty)
          LinearProgressIndicator(minHeight: 2, color: scheme.outline),
        results,
      ],
    );
  }

  Widget _tile(BuildContext context, T item) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = widget.itemOf(item);

    return InkWell(
      onTap: () => _select(item),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (view.subtitle != null)
                    Text(
                      view.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (view.trailing != null) ...[
              const SizedBox(width: 12),
              Text(
                view.trailing!,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
            if (view.selectedCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '×${view.selectedCount}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Campo de búsqueda del selector, ya enfocado para escribir de inmediato.
class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      hintText: hint,
      autoFocus: true,
      elevation: const WidgetStatePropertyAll(0),
      leading: const Icon(Icons.search),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
      onChanged: onChanged,
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 36, color: scheme.outline),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
