import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'empty_state.dart';

/// Lista de tarjetas numeradas. Con [items] vacío muestra un estado vacío.
///
/// [startNumber] permite continuar la numeración al paginar. Con
/// [onLoadMore] pide la página siguiente al acercarse al final.
class AppCardList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int number) itemBuilder;
  final int startNumber;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final Future<void> Function()? onRefresh;

  /// Se llama al acercarse al final de la lista (el proveedor debe ignorar
  /// llamadas repetidas mientras carga).
  final VoidCallback? onLoadMore;

  /// Muestra un indicador de carga al final.
  final bool loadingMore;

  /// Espacio al final de la lista; súbelo (por ejemplo 96) si la vista tiene
  /// un [AppSpeedDial] para que no tape el último elemento.
  final double bottomPadding;

  /// Para usarla dentro de otro scroll.
  final bool shrinkWrap;

  const AppCardList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.startNumber = 1,
    this.emptyTitle = 'Sin resultados',
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.onRefresh,
    this.onLoadMore,
    this.loadingMore = false,
    this.bottomPadding = 16,
    this.shrinkWrap = false,
  });

  @override
  State<AppCardList<T>> createState() => _AppCardListState<T>();
}

class _AppCardListState<T> extends State<AppCardList<T>> {
  /// Posiciones que ya hicieron su animación de entrada: al volver a verlas con el
  /// scroll no se repite.
  final _entered = <int>{};

  /// Cambia con cada lista nueva para que las tarjetas se creen de cero y animen otra vez.
  var _generation = 0;

  @override
  void didUpdateWidget(AppCardList<T> old) {
    super.didUpdateWidget(old);
    final a = old.items;
    final b = widget.items;
    // Una lista distinta (otra búsqueda o filtro) vuelve a entrar con animación.
    if (!identical(a, b) && (a.isEmpty || b.isEmpty || a.first != b.first)) {
      _entered.clear();
      _generation++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final loadingMore = widget.loadingMore;
    final shrinkWrap = widget.shrinkWrap;
    if (items.isEmpty) {
      return AppEmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    }

    final count = items.length + (loadingMore ? 1 : 0);
    final list = ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        final card = widget.itemBuilder(
          context,
          items[i],
          widget.startNumber + i,
        );
        // Solo las primeras tarjetas entran escalonadas; el resto aparece normal.
        if (i >= _staggerLimit) return card;
        return _Staggered(
          key: ValueKey((_generation, i)),
          index: i,
          entered: _entered,
          child: card,
        );
      },
    );

    Widget result = list;
    if (widget.onLoadMore != null) {
      result = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
            widget.onLoadMore!();
          }
          return false;
        },
        child: list,
      );
    }
    return widget.onRefresh == null
        ? result
        : RefreshIndicator(onRefresh: widget.onRefresh!, child: result);
  }
}

const _staggerLimit = 10;

/// Anima la entrada de una tarjeta solo la primera vez que se construye su posición.
class _Staggered extends StatefulWidget {
  final int index;
  final Set<int> entered;
  final Widget child;

  const _Staggered({
    super.key,
    required this.index,
    required this.entered,
    required this.child,
  });

  @override
  State<_Staggered> createState() => _StaggeredState();
}

class _StaggeredState extends State<_Staggered> {
  late final bool _play = widget.entered.add(widget.index);

  @override
  Widget build(BuildContext context) {
    if (!_play) return widget.child;
    return AppEntrance(
      delay: Duration(milliseconds: 40 * widget.index),
      duration: const Duration(milliseconds: 320),
      offset: 12,
      child: widget.child,
    );
  }
}
