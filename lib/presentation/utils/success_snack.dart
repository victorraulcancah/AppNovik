import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/app_success.dart';

/// Aviso de que algo salió bien: un check que se dibuja, el mensaje y una vibración corta.
void showSuccessSnack(BuildContext context, String message) {
  HapticFeedback.mediumImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const AppSuccessCheck(size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
