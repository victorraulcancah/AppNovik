import 'package:flutter/material.dart';
import 'empty_state.dart';

/// Lista de tarjetas numeradas. Con [items] vacío muestra un estado vacío.
///
/// [startNumber] permite continuar la numeración al paginar. Con
/// [onLoadMore] pide la página siguiente al acercarse al final.
class AppCardList<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return AppEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    final count = items.length + (loadingMore ? 1 : 0);
    final list = ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
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
        return itemBuilder(context, items[i], startNumber + i);
      },
    );

    Widget result = list;
    if (onLoadMore != null) {
      result = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
            onLoadMore!();
          }
          return false;
        },
        child: list,
      );
    }
    return onRefresh == null
        ? result
        : RefreshIndicator(onRefresh: onRefresh!, child: result);
  }
}
