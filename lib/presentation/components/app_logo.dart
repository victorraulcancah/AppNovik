import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Marca provisional de Novik (inicial + nombre) hasta tener el logo real.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showName;

  const AppLogo({super.key, this.size = 64, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: AppConstants.appName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
            child: Text(
              AppConstants.appName.substring(0, 1),
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: size * 0.55,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (showName) ...[
            const SizedBox(height: 12),
            Text(
              AppConstants.appName,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
