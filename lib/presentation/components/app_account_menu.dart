import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

/// Avatar con la inicial del usuario. Al tocarlo muestra el usuario y su
/// empresa, el selector de tema (claro, oscuro, a modo del sistema) y permite
/// cerrar sesión. Va en `AppPageHeader.trailing`.
class AppAccountMenu extends StatelessWidget {
  const AppAccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final user = auth.user;
    final company = auth.session?.company.razonSocial;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initial =
        (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?';

    return MenuAnchor(
      style: const MenuStyle(
        minimumSize: WidgetStatePropertyAll(Size(260, 0)),
        alignment: AlignmentDirectional.bottomStart,
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user?.name ?? '', style: textTheme.titleSmall),
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
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tema',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                selected: {theme.mode},
                onSelectionChanged: (s) =>
                    context.read<ThemeProvider>().setMode(s.first),
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    tooltip: 'Claro',
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    tooltip: 'Oscuro',
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.desktop_windows_outlined),
                    tooltip: 'A modo del sistema',
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout),
          onPressed: () => context.read<AuthProvider>().logout(),
          child: const Text('Cerrar sesión'),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Cuenta',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Padding(
            padding: const EdgeInsets.all(6),
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
        ),
      ),
    );
  }
}
