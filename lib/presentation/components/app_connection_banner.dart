import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../core/network/connection_monitor.dart';

/// Pone un aviso "Sin conexión a internet" arriba de toda la app mientras la última petición
/// haya fallado por la red. Se quita solo cuando el servidor vuelve a responder.
class AppConnectionBanner extends StatelessWidget {
  final Widget child;

  /// Para pruebas; por defecto es el monitor global.
  final ValueListenable<bool>? offline;

  const AppConnectionBanner({super.key, required this.child, this.offline});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: offline ?? ConnectionMonitor.offline,
      builder: (context, isOffline, child) {
        final scheme = Theme.of(context).colorScheme;
        final topInset = MediaQuery.paddingOf(context).top;
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: isOffline
                  ? Material(
                      color: scheme.errorContainer,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 18,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Sin conexión a internet. Se reintentará al volver la señal.',
                                style: TextStyle(
                                  color: scheme.onErrorContainer,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              // Con el aviso visible ya cubrió la barra de estado: el resto no la repite.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: isOffline,
                child: child!,
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
