import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/app_theme.dart';
import 'app_tabs.dart';
import 'error_banner.dart';

/// Tono del modal: define el color de la franja de cabecera y del botón principal.
enum AppModalTone {
  /// Acciones normales (crear, editar, ver detalle): azul pizarra de la marca.
  normal,

  /// Acciones destructivas (eliminar).
  danger,

  /// Acciones delicadas pero reversibles o de cierre (anular).
  warning,
}

extension on AppModalTone {
  List<Color> get headerColors => switch (this) {
        AppModalTone.normal => const [AppTheme.brandDark, AppTheme.brandDarkAlt],
        AppModalTone.danger => const [Color(0xFF7F1D1D), Color(0xFF991B1B)],
        AppModalTone.warning => const [Color(0xFF78350F), Color(0xFF92400E)],
      };

  /// Color del botón principal; en oscuro se aclara para que se distinga del fondo.
  Color buttonColor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      AppModalTone.normal => AppTheme.strongFill(brightness),
      AppModalTone.danger =>
        dark ? const Color(0xFFDC2626) : const Color(0xFFB91C1C),
      AppModalTone.warning =>
        dark ? const Color(0xFFD97706) : const Color(0xFFB45309),
    };
  }
}

/// Modal estándar de la app (ver detalle, crear, editar, anular, importar...).
///
/// Cabecera con fondo de color: ícono, título y subtítulo (una línea cada uno).
/// Cuerpo con scroll y pie con dos botones: el secundario (Cancelar, Cerrar...)
/// y el principal. No tiene botón de cerrar: en celular sube como hoja inferior
/// con asa y se cierra deslizando hacia abajo; en tablet es un diálogo
/// centrado que también se cierra tocando fuera.
///
/// Devuelve `true` si se confirmó la acción principal, `null` si se cerró.
///
/// - [onPrimary] puede ser asíncrono: mientras corre, el botón muestra carga.
///   Si lanza una excepción, el modal sigue abierto; si termina bien, se cierra.
/// - [formKey]: si se pasa, el cuerpo se envuelve en un `Form` y la acción
///   principal solo corre si el formulario es válido.
/// - [primaryEnabled]: habilita o deshabilita el botón principal desde dentro
///   del cuerpo (por ejemplo, hasta elegir un archivo).
/// - Con [primaryLabel] `null` no hay botón principal (solo se puede cerrar).
/// - [tabs]: cuando hay muchos campos, en lugar de [child] se pasan pestañas;
///   la barra queda fija bajo la cabecera. Pasa un [tabsController] para
///   validar formularios por pestaña (`AppTabsController.validate`).
/// - [error]: mensaje de error que se muestra fijo sobre el cuerpo (por
///   ejemplo, la respuesta del servidor al guardar).
Future<bool?> showAppModal(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData? icon,
  AppModalTone tone = AppModalTone.normal,
  Widget? child,
  List<AppTabItem>? tabs,
  AppTabsController? tabsController,
  String? primaryLabel = 'Guardar',
  String secondaryLabel = 'Cancelar',
  FutureOr<void> Function()? onPrimary,
  GlobalKey<FormState>? formKey,
  ValueListenable<bool>? primaryEnabled,
  ValueListenable<String?>? error,
}) {
  assert(child != null || (tabs != null && tabs.isNotEmpty), 'Pasa child o tabs');
  final isTablet =
      MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

  Widget build(BuildContext ctx, {required bool handle}) => _AppModalContent(
        title: title,
        subtitle: subtitle,
        icon: icon,
        tone: tone,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        onPrimary: onPrimary,
        formKey: formKey,
        primaryEnabled: primaryEnabled,
        error: error,
        tabs: tabs,
        tabsController: tabsController,
        showHandle: handle,
        child: child,
      );

  if (isTablet) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: build(ctx, handle: false),
        ),
      ),
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: build(ctx, handle: true),
    ),
  );
}

/// Confirmación sencilla (eliminar, anular): mismo modal, con un mensaje.
/// Devuelve `true` solo si el usuario confirma.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String? subtitle,
  IconData? icon,
  String confirmLabel = 'Confirmar',
  AppModalTone tone = AppModalTone.danger,
}) async {
  final result = await showAppModal(
    context,
    title: title,
    subtitle: subtitle,
    icon: icon,
    tone: tone,
    primaryLabel: confirmLabel,
    child: Text(message),
  );
  return result ?? false;
}

class _AppModalContent extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final AppModalTone tone;
  final String? primaryLabel;
  final String secondaryLabel;
  final FutureOr<void> Function()? onPrimary;
  final GlobalKey<FormState>? formKey;
  final ValueListenable<bool>? primaryEnabled;
  final ValueListenable<String?>? error;
  final List<AppTabItem>? tabs;
  final AppTabsController? tabsController;
  final bool showHandle;
  final Widget? child;

  const _AppModalContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.formKey,
    required this.primaryEnabled,
    required this.error,
    required this.tabs,
    required this.tabsController,
    required this.showHandle,
    required this.child,
  });

  @override
  State<_AppModalContent> createState() => _AppModalContentState();
}

class _AppModalContentState extends State<_AppModalContent> {
  bool _busy = false;
  AppTabsController? _ownTabs;

  AppTabsController? get _tabs {
    if (widget.tabs == null) return null;
    return widget.tabsController ?? (_ownTabs ??= AppTabsController());
  }

  @override
  void dispose() {
    _ownTabs?.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final form = widget.formKey?.currentState;
    if (form != null && !form.validate()) return;

    setState(() => _busy = true);
    try {
      await widget.onPrimary?.call();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      // El modal sigue abierto; quien llama muestra el error.
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _primaryButton(Brightness brightness, bool enabled) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: widget.tone.buttonColor(brightness),
        foregroundColor: Colors.white,
      ),
      onPressed: (_busy || !enabled) ? null : _confirm,
      child: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          : Text(widget.primaryLabel!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPrimary = widget.primaryLabel != null;

    final tabs = _tabs;
    Widget body = tabs != null
        ? AppTabsView(tabs: widget.tabs!, controller: tabs)
        : widget.child!;
    if (widget.formKey != null) {
      body = Form(key: widget.formKey, child: body);
    }

    return Material(
      color: scheme.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera con fondo: asa, ícono, título, subtítulo y cierre.
          Container(
            padding: EdgeInsets.fromLTRB(16, widget.showHandle ? 8 : 14, 8, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: widget.tone.headerColors,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showHandle)
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.icon, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Una línea: los nombres largos se cortan con "…".
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
          if (tabs != null) AppTabBar(tabs: widget.tabs!, controller: tabs),
          if (widget.error != null)
            ValueListenableBuilder<String?>(
              valueListenable: widget.error!,
              builder: (context, message, _) => message == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: ErrorBanner(message: message),
                    ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: body,
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outline),
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                        ),
                      ),
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: Text(widget.secondaryLabel),
                    ),
                  ),
                  if (hasPrimary) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: widget.primaryEnabled == null
                          ? _primaryButton(theme.brightness, true)
                          : ValueListenableBuilder<bool>(
                              valueListenable: widget.primaryEnabled!,
                              builder: (context, enabled, _) =>
                                  _primaryButton(theme.brightness, enabled),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
