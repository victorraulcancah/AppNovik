import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Una pestaña: su nombre, un ícono y contador opcionales, y su contenido.
class AppTabItem {
  final String label;
  final IconData? icon;

  /// Número que se muestra junto al nombre (por ejemplo, cuántos ítems tiene).
  final int? badge;
  final Widget child;

  const AppTabItem({
    required this.label,
    required this.child,
    this.icon,
    this.badge,
  });
}

/// Pestaña activa y pestañas con errores. Une la barra ([AppTabBar]) con el
/// contenido ([AppTabsView]) y permite validar formularios repartidos en
/// varias pestañas.
class AppTabsController extends ChangeNotifier {
  int _index = 0;
  Set<int> _errors = {};

  int get index => _index;

  /// Pestañas con campos inválidos tras el último [validate].
  Set<int> get errors => _errors;

  void select(int value) {
    if (value == _index) return;
    _index = value;
    notifyListeners();
  }

  /// Valida un `Form` por pestaña (en el mismo orden que las pestañas). Marca
  /// las que tienen errores y salta a la primera. Devuelve `true` si todas
  /// son válidas.
  bool validate(List<GlobalKey<FormState>> forms) {
    final invalid = <int>{};
    for (var i = 0; i < forms.length; i++) {
      final state = forms[i].currentState;
      if (state != null && !state.validate()) invalid.add(i);
    }
    _errors = invalid;
    if (invalid.isNotEmpty) _index = invalid.reduce(math.min);
    notifyListeners();
    return invalid.isEmpty;
  }
}

/// Barra de pestañas: nombre con ícono, subrayado en la activa, contador y un
/// punto rojo si la pestaña tiene errores. Se desplaza si no caben.
class AppTabBar extends StatelessWidget {
  final List<AppTabItem> tabs;
  final AppTabsController controller;

  const AppTabBar({super.key, required this.tabs, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final underline = AppTheme.strongFill(theme.brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                _Tab(
                  item: tabs[i],
                  selected: i == controller.index,
                  hasError: controller.errors.contains(i),
                  underline: underline,
                  onTap: () => controller.select(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final AppTabItem item;
  final bool selected;
  final bool hasError;
  final Color underline;
  final VoidCallback onTap;

  const _Tab({
    required this.item,
    required this.selected,
    required this.hasError,
    required this.underline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? underline : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                item.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (item.badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${item.badge}', style: theme.textTheme.labelSmall),
                ),
              ],
              if (hasError) ...[
                const SizedBox(width: 6),
                Icon(Icons.error, size: 14, color: scheme.error),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenido de las pestañas. Todas se mantienen montadas (solo se ve la
/// activa), así los campos conservan lo escrito y se validan aunque estén
/// ocultas.
///
/// Al cambiar de pestaña, la nueva entra con un fundido y un deslizamiento horizontal desde el
/// lado hacia el que se avanza (si se pasa a una pestaña de la derecha, llega desde la derecha).
/// Con "quitar animaciones" del sistema el cambio es directo.
class AppTabsView extends StatefulWidget {
  final List<AppTabItem> tabs;
  final AppTabsController controller;

  const AppTabsView({super.key, required this.tabs, required this.controller});

  @override
  State<AppTabsView> createState() => _AppTabsViewState();
}

class _AppTabsViewState extends State<AppTabsView> with SingleTickerProviderStateMixin {
  // Arranca en 1: la pestaña inicial se ve de entrada, sin animación.
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _curved = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);

  // La pestaña que se está mostrando (se fija al crearse, antes de que nadie la cambie).
  late int _shown;

  /// 1 si se avanzó hacia una pestaña de la derecha, -1 hacia la izquierda.
  int _dir = 1;

  @override
  void initState() {
    super.initState();
    _shown = widget.controller.index;
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(AppTabsView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _shown = widget.controller.index;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _anim.dispose();
    super.dispose();
  }

  void _onChange() {
    final next = widget.controller.index;
    if (next == _shown) return;
    _dir = next > _shown ? 1 : -1;
    _shown = next;
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            Visibility(
              visible: i == widget.controller.index,
              maintainState: true,
              // La estructura es la misma para todas (así los formularios no pierden su estado);
              // solo la pestaña activa recibe la animación.
              child: _TabSlide(
                animation: i == widget.controller.index ? _curved : kAlwaysCompleteAnimation,
                direction: _dir,
                still: still,
                child: widget.tabs[i].child,
              ),
            ),
        ],
      ),
    );
  }
}

class _TabSlide extends StatelessWidget {
  final Animation<double> animation;
  final int direction;
  final bool still;
  final Widget child;

  const _TabSlide({
    required this.animation,
    required this.direction,
    required this.still,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = still ? 1.0 : animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(direction * 28.0 * (1 - t), 0),
            child: child,
          ),
        );
      },
    );
  }
}
