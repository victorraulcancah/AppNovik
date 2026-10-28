import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';

/// Se muestra cuando hay sesión guardada pero no se pudo cargar la empresa
/// y los módulos (sin conexión, servidor caído).
class SessionErrorPage extends StatelessWidget {
  const SessionErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cloud_off, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'No se pudo cargar tu sesión',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(auth.errorMessage!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Reintentar',
                    icon: Icons.refresh,
                    onPressed: () => auth.retryContext(),
                  ),
                  TextButton(
                    onPressed: () => auth.logout(),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
