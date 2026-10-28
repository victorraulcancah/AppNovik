import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import 'modulo_placeholder_page.dart';

/// Módulo que la app sabe mostrar. `slug` coincide con el nombre del módulo
/// en el backend (`Module.name` pasado por `convertToSlug`).
class _AppModulo {
  final String slug;
  final String titulo;
  final IconData icono;
  const _AppModulo(this.slug, this.titulo, this.icono);
}

const _catalogo = [
  _AppModulo('ventas', 'Ventas', Icons.point_of_sale),
  _AppModulo('reportes', 'Reportes', Icons.bar_chart),
  _AppModulo('stock', 'Stock', Icons.inventory_2),
  _AppModulo('documentos', 'Documentos', Icons.description),
  _AppModulo('productos', 'Productos', Icons.category),
];

/// Contenedor principal: barra inferior en celular y riel lateral en tablet.
/// Solo muestra los módulos que la empresa del usuario tiene habilitados.
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final session = auth.session;
    if (session == null) return const SizedBox.shrink();

    final modulos =
        _catalogo.where((m) => session.hasModule(m.slug)).toList();
    final index = modulos.isEmpty ? 0 : _index.clamp(0, modulos.length - 1);
    final isTablet =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;
    final showNav = modulos.length >= 2;

    final Widget body = modulos.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tu empresa no tiene módulos habilitados para la app.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ModuloPlaceholderPage(
            titulo: modulos[index].titulo,
            icono: modulos[index].icono,
          );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(modulos.isEmpty ? AppConstants.appName : modulos[index].titulo),
            Text(
              session.company.razonSocial,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: isTablet && showNav
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final m in modulos)
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
      bottomNavigationBar: !isTablet && showNav
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final m in modulos)
                  NavigationDestination(icon: Icon(m.icono), label: m.titulo),
              ],
            )
          : null,
    );
  }
}
