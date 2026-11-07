import 'dart:async';

import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'empty_state.dart';

/// Maneja el panel de detalle de una pantalla con dos paneles (lista + detalle).
///
/// La pantalla crea uno, se lo pasa a [AppMasterDetail] y a las funciones `show...Detail`
/// (`pane:`). Cuando hay espacio para dos paneles el detalle se dibuja a la derecha, en lugar
/// de abrirse como modal; cuando no (celular), esas funciones abren el modal de siempre. Así el
/// código que pide el detalle y espera su resultado (`true` si se pulsó la acción principal) es
/// el mismo en los dos casos.
class AppPaneController extends ChangeNotifier {
  bool _wide = false;
  Widget? _content;
  Object? _selectedId;
  int _generation = 0;
  Completer<bool?>? _completer;

  /// Si ahora mismo se dibujan los dos paneles.
  bool get isWide => _wide;

  /// El `id` del elemento que se está viendo a la derecha (para resaltarlo en la lista).
  Object? get selectedId => _selectedId;

  bool get hasContent => _content != null;

  /// Para el contenido: cambia con cada detalle nuevo.
  int get generation => _generation;

  Widget? get content => _content;

  /// Muestra un detalle en el panel y devuelve lo que se decida en él (`true` = acción principal,
  /// `null` = se cerró o se eligió otro elemento). [builder] recibe la función que cierra el panel.
  ///
  /// Con [keepOnPrimary] la acción principal (por ejemplo "Editar") responde `true` pero deja el
  /// detalle a la vista: el formulario se abre encima y, si se cancela, el panel sigue como estaba.
  /// Quien pidió el detalle lo vuelve a presentar (con `present`) si guardó cambios.
  Future<bool?> present({
    required Object? id,
    bool keepOnPrimary = false,
    required Widget Function(void Function([bool? result]) close) builder,
  }) {
    // Elegir otro elemento deja sin respuesta al anterior.
    final previous = _completer;
    if (previous != null && !previous.isCompleted) previous.complete(null);

    final completer = Completer<bool?>();
    _completer = completer;
    _generation++;
    _selectedId = id;

    void close([bool? result]) {
      if (keepOnPrimary && result == true) {
        if (!completer.isCompleted) completer.complete(result);
        return;
      }
      if (identical(_completer, completer)) {
        _content = null;
        _selectedId = null;
        _completer = null;
        notifyListeners();
      }
      if (!completer.isCompleted) completer.complete(result);
    }

    _content = builder(close);
    notifyListeners();
    return completer.future;
  }

  /// Vacía el panel (queda el estado "Selecciona…").
  void close() {
    final completer = _completer;
    if (_content == null && completer == null) return;
    _content = null;
    _selectedId = null;
    _completer = null;
    if (completer != null && !completer.isCompleted) completer.complete(null);
    notifyListeners();
  }

  void _syncWide(bool wide) {
    if (_wide == wide) return;
    _wide = wide;
    // Al pasar a un solo panel (por ejemplo al girar el equipo) el detalle abierto se descarta.
    if (!wide && _content != null) scheduleMicrotask(close);
  }

  @override
  void dispose() {
    final completer = _completer;
    if (completer != null && !completer.isCompleted) completer.complete(null);
    super.dispose();
  }
}

/// Pantalla en dos paneles cuando hay ancho de sobra: la lista a la izquierda y, a la derecha,
/// el detalle del elemento elegido (o un estado vacío). Con menos ancho muestra solo la lista y
/// el detalle sigue abriéndose como modal.
class AppMasterDetail extends StatelessWidget {
  /// Ancho disponible desde el que se usan dos paneles (el riel de navegación ya se descontó):
  /// la lista de 400 y al menos 440 para el detalle. Una tablet en vertical queda con un panel.
  static const minWidth = 840.0;

  final AppPaneController controller;

  /// La lista completa (búsqueda, filtros y tarjetas). Se vuelve a armar al elegir un elemento
  /// para poder resaltarlo.
  final WidgetBuilder listBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final double listWidth;

  const AppMasterDetail({
    super.key,
    required this.controller,
    required this.listBuilder,
    this.emptyIcon = Icons.touch_app_outlined,
    this.emptyTitle = 'Selecciona un elemento',
    this.emptyMessage,
    this.listWidth = 400,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= minWidth;
        controller._syncWide(wide);
        if (!wide) return listBuilder(context);

        return Row(
          children: [
            SizedBox(
              width: listWidth,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => listBuilder(context),
              ),
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final content = controller.content;
                  return AppFadeSwitcher(
                    child: KeyedSubtree(
                      key: ValueKey(content == null ? 'vacio' : controller.generation),
                      child:
                          content ??
                          AppEmptyState(
                            icon: emptyIcon,
                            title: emptyTitle,
                            message: emptyMessage,
                          ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Espera a que [busy] deje de ser verdadero cuando [source] avise un cambio (por ejemplo a que un
/// provider termine de recargar su lista después de guardar). Sale de todos modos pasado [timeout].
Future<void> whenIdle(
  Listenable source,
  bool Function() busy, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  // Deja que quien guardó alcance a marcar "cargando".
  await Future<void>.delayed(Duration.zero);
  if (!busy()) return;
  final done = Completer<void>();
  void listener() {
    if (!busy() && !done.isCompleted) done.complete();
  }

  source.addListener(listener);
  try {
    await done.future.timeout(timeout, onTimeout: () {});
  } finally {
    source.removeListener(listener);
  }
}
