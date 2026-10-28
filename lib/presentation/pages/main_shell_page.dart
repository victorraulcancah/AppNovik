import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import 'modulo_placeholder_page.dart';

class _Modulo {
  final String titulo;
  final IconData icono;
  const _Modulo(this.titulo, this.icono);
}

const _modulos = [
  _Modulo('Ventas', Icons.point_of_sale),
  _Modulo('Reportes', Icons.bar_chart),
  _Modulo('Stock', Icons.inventory_2),
  _Modulo('Documentos', Icons.description),
  _Modulo('Producto', Icons.category),
];

/// Contenedor principal: barra inferior en celular y riel lateral en tablet.
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final modulo = _modulos[_index];
    final isTablet =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

    final body = ModuloPlaceholderPage(
      titulo: modulo.titulo,
      icono: modulo.icono,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(modulo.titulo),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: isTablet
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final m in _modulos)
                      NavigationRailDestination(
                        icon: Icon(m.icono),
                        label: Text(m.titulo),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isTablet
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final m in _modulos)
                  NavigationDestination(icon: Icon(m.icono), label: m.titulo),
              ],
            ),
    );
  }
}
