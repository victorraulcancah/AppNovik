import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Destino de la navegación principal.
class AppDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Scaffold con navegación Material 3 según el ancho: barra inferior en
/// celular y riel lateral en tablet. Con menos de 2 destinos no muestra
/// navegación (Material pide mínimo 2).
class AdaptiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  const AdaptiveScaffold({
    super.key,
    this.appBar,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final showNav = destinations.length >= 2;
    final isTablet =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      appBar: appBar,
      body: isTablet && showNav
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: onDestinationSelected,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: !isTablet && showNav
          ? MediaQuery.withClampedTextScaling(
              // Las etiquetas de la barra inferior son de una sola palabra y no
              // deben partirse: crecen con la letra del sistema hasta 1.2x.
              maxScaleFactor: 1.2,
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelPadding: EdgeInsets.zero,
                destinations: [
                  for (final d in destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                ],
              ),
            )
          : null,
    );
  }
}
