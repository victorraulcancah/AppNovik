import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/app_theme.dart';

/// Marca provisional de Novik (inicial + nombre) hasta tener el logo real.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final Color nameColor;

  const AppLogo({
    super.key,
    this.size = 64,
    this.showName = true,
    this.nameColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(size * 0.3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            AppConstants.appName.substring(0, 1),
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.55,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 14),
          Text(
            AppConstants.appName,
            style: TextStyle(
              color: nameColor,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
