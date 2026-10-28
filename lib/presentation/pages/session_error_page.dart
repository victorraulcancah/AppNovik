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
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'No se pudo cargar tu sesión',
          message: auth.errorMessage,
          action: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
    );
  }
}
