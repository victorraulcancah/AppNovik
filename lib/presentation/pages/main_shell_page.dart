import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';

/// Módulo que la app sabe mostrar. `slug` coincide con el nombre del módulo
/// en el backend (`Module.name` pasado por `convertToSlug`).
class _AppModulo {
  final String slug;
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;
  const _AppModulo(this.slug, this.titulo, this.icono, this.iconoActivo);

  AppDestination get destino =>
      AppDestination(label: titulo, icon: icono, selectedIcon: iconoActivo);
}

const _catalogo = [
  _AppModulo('ventas', 'Ventas', Icons.point_of_sale_outlined, Icons.point_of_sale),
  _AppModulo('reportes', 'Reportes', Icons.bar_chart_outlined, Icons.bar_chart),
  _AppModulo('stock', 'Stock', Icons.inventory_2_outlined, Icons.inventory_2),
  _AppModulo('documentos', 'Documentos', Icons.description_outlined, Icons.description),
  _AppModulo('productos', 'Productos', Icons.category_outlined, Icons.category),
];

/// Contenedor principal. Solo muestra los módulos que la empresa del usuario
/// tiene habilitados.
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    if (session == null) return const SizedBox.shrink();

    final modulos =
        _catalogo.where((m) => session.hasModule(m.slug)).toList();
    final index = modulos.isEmpty ? 0 : _index.clamp(0, modulos.length - 1);
    final actual = modulos.isEmpty ? null : modulos[index];

    return AdaptiveScaffold(
      appBar: AppTopBar(
        title: actual?.titulo ?? AppConstants.appName,
        subtitle: session.company.razonSocial,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      destinations: [for (final m in modulos) m.destino],
      selectedIndex: index,
      onDestinationSelected: (i) => setState(() => _index = i),
      body: actual == null
          ? const AppEmptyState(
              icon: Icons.apps_outlined,
              title: 'Sin módulos habilitados',
              message: 'Tu empresa no tiene módulos habilitados para la app.',
            )
          : AppEmptyState(
              icon: actual.iconoActivo,
              title: actual.titulo,
              message: 'Este módulo está en construcción.',
            ),
    );
  }
}
