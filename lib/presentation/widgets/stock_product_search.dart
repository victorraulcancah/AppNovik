import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/stock_manage_entity.dart';

/// Buscador de productos para armar un aumento de stock o una transferencia: se escribe, se
/// espera un momento y salen los productos; al tocar uno se agrega.
///
/// [search] hace la consulta (el texto ya viene sin espacios sobrantes); [detail] arma la línea
/// pequeña de cada resultado (por ejemplo, lo que tiene en el almacén); [onPick] recibe el
/// producto tocado.
///
/// Como en la web, cuando una búsqueda devuelve **exactamente un** producto se agrega solo (sirve
/// con el lector de código de barras, que escribe el código y pulsa Enter). Solo ocurre cuando la
/// búsqueda termina y el texto sigue siendo el mismo que se buscó: si se siguió escribiendo, no
/// se agrega nada a medias. Se puede apagar con [autoPickSingle].
class StockProductSearch extends StatefulWidget {
  final Future<Either<Failure, List<StockProductEntity>>> Function(String text)
  search;
  final String Function(StockProductEntity product) detail;
  final ValueChanged<StockProductEntity> onPick;
  final String hint;
  final bool enabled;

  /// Agrega solo el producto cuando la búsqueda devuelve exactamente uno.
  final bool autoPickSingle;

  /// Cuánto espera a que termine de escribir antes de buscar.
  final Duration delay;

  const StockProductSearch({
    super.key,
    required this.search,
    required this.detail,
    required this.onPick,
    this.hint = 'Buscar producto por nombre, código, marca…',
    this.enabled = true,
    this.autoPickSingle = true,
    this.delay = const Duration(milliseconds: 400),
  });

  @override
  State<StockProductSearch> createState() => _StockProductSearchState();
}

class _StockProductSearchState extends State<StockProductSearch> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  bool _loading = false;
  String? _error;
  String _query = '';
  List<StockProductEntity> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      // Sin texto no hay resultados; una respuesta que llegue tarde se descarta.
      _request++;
      setState(() {
        _query = '';
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(widget.delay, () => _run(query));
  }

  Future<void> _run(String query) async {
    final request = ++_request;
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    final result = await widget.search(query);
    if (!mounted || request != _request) return;
    setState(() {
      _loading = false;
      if (result.isLeft) {
        _results = const [];
        _error = result.left.message;
      } else {
        _results = result.right;
      }
    });
    // Un solo resultado: se agrega solo, pero únicamente si no se siguió escribiendo.
    if (widget.autoPickSingle &&
        widget.enabled &&
        result.isRight &&
        result.right.length == 1 &&
        _controller.text.trim() == query) {
      widget.onPick(result.right.single);
    }
  }

  void _pick(StockProductEntity product) {
    widget.onPick(product);
    // Se queda el texto y los resultados para agregar otro producto de la misma búsqueda.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchBar(
          controller: _controller,
          enabled: widget.enabled,
          hintText: widget.hint,
          elevation: const WidgetStatePropertyAll(0),
          leading: const Icon(Icons.search),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          trailing: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            else if (_controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Borrar',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  _onChanged('');
                },
              ),
          ],
          onChanged: _onChanged,
          onSubmitted: (text) {
            _debounce?.cancel();
            final query = text.trim();
            if (query.isNotEmpty) _run(query);
          },
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          )
        else if (_query.isNotEmpty && !_loading && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No se encontraron productos',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            // Un Material propio (y no un fondo de Container) para que los toques se vean.
            child: Material(
              color: scheme.surfaceContainerLowest,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: scheme.outlineVariant),
                  itemBuilder: (context, i) {
                    final p = _results[i];
                    return ListTile(
                      key: ValueKey('resultado-${p.id}'),
                      dense: true,
                      title: Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (p.codigo.isNotEmpty) p.codigo,
                          if (p.marca != null && p.marca!.isNotEmpty) p.marca!,
                          widget.detail(p),
                        ].where((t) => t.isNotEmpty).join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        Icons.add_circle_outline,
                        color: scheme.primary,
                      ),
                      onTap: widget.enabled ? () => _pick(p) : null,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
