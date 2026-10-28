import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Avatar con la inicial del usuario. Al tocarlo muestra el usuario y su
/// empresa, y permite cerrar sesión. Va en `AppPageHeader.trailing`.
class AppAccountMenu extends StatelessWidget {
  const AppAccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final company = auth.session?.company.razonSocial;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initial =
        (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'logout') context.read<AuthProvider>().logout();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? '',
                style: textTheme.titleSmall?.copyWith(color: scheme.onSurface),
              ),
              if (company != null)
                Text(
                  company,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 12),
              Text('Cerrar sesión'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: Text(
            initial,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
