import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/app_theme.dart';

/// Tono del modal: define el color de la franja de cabecera y del botón principal.
enum AppModalTone {
  /// Acciones normales (crear, editar): azul pizarra de la marca.
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

/// Abre un modal con cabecera de color (título y subtítulo), cuerpo
/// desplazable y pie con Cancelar y la acción principal.
///
/// En celular sube como hoja inferior; en tablet es un diálogo centrado.
/// Devuelve `true` si se confirmó la acción principal, `null` si se cerró.
///
/// [onPrimary] puede ser asíncrono: mientras corre, el botón muestra carga.
/// Si lanza una excepción, el modal sigue abierto; si termina bien, se cierra.
Future<bool?> showAppModal(
  BuildContext context, {
  required String title,
  String? subtitle,
  AppModalTone tone = AppModalTone.normal,
  required Widget child,
  String primaryLabel = 'Guardar',
  String cancelLabel = 'Cancelar',
  FutureOr<void> Function()? onPrimary,
}) {
  Widget build(BuildContext ctx) => _AppModalContent(
        title: title,
        subtitle: subtitle,
        tone: tone,
        primaryLabel: primaryLabel,
        cancelLabel: cancelLabel,
        onPrimary: onPrimary,
        child: child,
      );

  final isTablet =
      MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

  if (isTablet) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: build(ctx),
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
      child: build(ctx),
    ),
  );
}

/// Confirmación sencilla (eliminar, anular): mismo modal, sin cuerpo propio.
/// Devuelve `true` solo si el usuario confirma.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String? subtitle,
  String confirmLabel = 'Confirmar',
  AppModalTone tone = AppModalTone.danger,
}) async {
  final result = await showAppModal(
    context,
    title: title,
    subtitle: subtitle,
    tone: tone,
    primaryLabel: confirmLabel,
    child: Text(message),
  );
  return result ?? false;
}

class _AppModalContent extends StatefulWidget {
  final String title;
  final String? subtitle;
  final AppModalTone tone;
  final String primaryLabel;
  final String cancelLabel;
  final FutureOr<void> Function()? onPrimary;
  final Widget child;

  const _AppModalContent({
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.primaryLabel,
    required this.cancelLabel,
    required this.onPrimary,
    required this.child,
  });

  @override
  State<_AppModalContent> createState() => _AppModalContentState();
}

class _AppModalContentState extends State<_AppModalContent> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await widget.onPrimary?.call();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      // El modal sigue abierto; quien llama muestra el error.
      if (mounted) setState(() => _busy = false);
    }
  }

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
          // Franja de cabecera: título, subtítulo y cierre.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: widget.tone.headerColors,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: widget.child,
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    side: BorderSide(color: scheme.outline),
                    minimumSize: const Size(96, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(widget.cancelLabel),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                    backgroundColor: widget.tone.buttonColor(theme.brightness),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _busy ? null : _confirm,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.primaryLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
