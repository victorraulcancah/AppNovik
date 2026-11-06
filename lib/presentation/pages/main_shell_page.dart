import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../components/components.dart';
import '../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/shell_navigation.dart';
import 'clients_page.dart';
import 'documents_page.dart';
import 'inicio_page.dart';
import 'products_page.dart';
import 'reports_page.dart';
import 'sales_page.dart';
import 'stock_page.dart';

/// Módulo que la app sabe mostrar. `slug` coincide con el nombre del módulo
/// en el backend (`Module.name` pasado por `convertToSlug`).
class _AppModulo {
  final String slug;
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;

  /// Sin módulo contratado de por medio: lo ven todos los usuarios (como el Dashboard de la web).
  final bool siempre;

  const _AppModulo(
    this.slug,
    this.titulo,
    this.icono,
    this.iconoActivo, {
    this.siempre = false,
  });

  AppDestination get destino =>
      AppDestination(label: titulo, icon: icono, selectedIcon: iconoActivo);
}

/// Módulos ya construidos que no se muestran por ahora (para mostrarlos, quitar su slug de acá).
const _ocultos = {'clientes'};

const _catalogo = [
  _AppModulo('inicio', 'Inicio', Icons.home_outlined, Icons.home, siempre: true),
  _AppModulo(
    'ventas',
    'Ventas',
    Icons.point_of_sale_outlined,
    Icons.point_of_sale,
  ),
  _AppModulo('reportes', 'Reportes', Icons.bar_chart_outlined, Icons.bar_chart),
  _AppModulo('stock', 'Stock', Icons.inventory_2_outlined, Icons.inventory_2),
  _AppModulo(
    'documentos',
    'Documentos',
    Icons.description_outlined,
    Icons.description,
  ),
  _AppModulo('productos', 'Productos', Icons.category_outlined, Icons.category),
  _AppModulo('clientes', 'Clientes', Icons.people_alt_outlined, Icons.people_alt),
];

/// Contenedor principal. Solo muestra los módulos que la empresa del usuario
/// tiene habilitados. No tiene barra superior: cada módulo pone su propio
/// encabezado (`AppPageHeader`) en lo más alto de la pantalla.
class MainShellPage extends StatefulWidget {
  /// Solo para pruebas: arma la pantalla de cada módulo (por su slug) en vez de las reales.
  final Widget Function(String slug)? pageBuilder;

  const MainShellPage({super.key, this.pageBuilder});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

/// Cuántos módulos caben en la barra inferior del celular; si hay más, el último lugar es "Más".
const _maxEnBarra = 5;

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;

  /// Muestra la lista "Más" (los módulos que no caben en la barra) en vez de un módulo.
  bool _mostrandoMas = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    if (session == null) return const SizedBox.shrink();

    final modulos = _catalogo
        .where(
          (m) =>
              !_ocultos.contains(m.slug) &&
              (m.siempre || session.hasModule(m.slug)),
        )
        .toList();
    // Otra pantalla pidió pasar a un módulo (por ejemplo, Documentos → Ventas al culminar una
    // cotización): se atiende en cuanto termina de dibujarse este cuadro.
    final navigation = context.watch<ShellNavigation>();
    final requested = navigation.requested;
    if (requested != null) {
      final target = modulos.indexWhere((m) => m.slug == requested);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigation.take();
        if (mounted && target >= 0 && (target != _index || _mostrandoMas)) {
          setState(() {
            _index = target;
            _mostrandoMas = false;
          });
        }
      });
    }

    final index = modulos.isEmpty ? 0 : _index.clamp(0, modulos.length - 1);
    final actual = modulos.isEmpty ? null : modulos[index];

    // En celular, con más de cinco módulos la barra muestra los primeros y un "Más" con el resto.
    // En tablet el riel lateral los muestra todos.
    final esTablet =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;
    final conMas = !esTablet && modulos.length > _maxEnBarra;
    final enBarra = conMas ? _maxEnBarra - 1 : modulos.length;
    final mostrandoMas = conMas && _mostrandoMas;

    return AdaptiveScaffold(
      destinations: [
        for (final m in modulos.take(enBarra)) m.destino,
        if (conMas)
          const AppDestination(
            label: 'Más',
            icon: Icons.more_horiz,
            selectedIcon: Icons.more_horiz,
          ),
      ],
      selectedIndex: mostrandoMas || (conMas && index >= enBarra)
          ? enBarra
          : index,
      onDestinationSelected: (i) {
        HapticFeedback.selectionClick();
        setState(() {
          if (conMas && i == enBarra) {
            _mostrandoMas = true;
          } else {
            _index = i;
            _mostrandoMas = false;
          }
        });
      },
      body: AppFadeSwitcher(
        child: KeyedSubtree(
          key: ValueKey(mostrandoMas ? 'mas' : actual?.slug ?? 'vacio'),
          child: mostrandoMas
              ? _MasModulos(
                  modulos: modulos.skip(enBarra).toList(),
                  actual: actual,
                  onSelect: (m) => setState(() {
                    _index = modulos.indexOf(m);
                    _mostrandoMas = false;
                  }),
                )
              : _contenido(actual),
        ),
      ),
    );
  }

  Widget _contenido(_AppModulo? actual) {
    final custom = actual == null ? null : widget.pageBuilder;
    if (custom != null) return custom(actual!.slug);
    return actual == null
        ? const _ModuloVacio(
            icono: Icons.apps_outlined,
            titulo: 'Novik',
            mensaje: 'Tu empresa no tiene módulos habilitados para la app.',
          )
        : switch (actual.slug) {
            'inicio' => const InicioPage(),
            'ventas' => const SalesPage(),
            'reportes' => const ReportsPage(),
            'productos' => const ProductsPage(),
            'clientes' => const ClientsPage(),
            'stock' => const StockPage(),
            'documentos' => const DocumentsPage(),
            _ => _ModuloVacio(
              icono: actual.iconoActivo,
              titulo: actual.titulo,
              mensaje: 'Este módulo está en construcción.',
            ),
          };
  }
}

/// Lista de los módulos que no caben en la barra inferior.
class _MasModulos extends StatelessWidget {
  final List<_AppModulo> modulos;
  final _AppModulo? actual;
  final ValueChanged<_AppModulo> onSelect;

  const _MasModulos({
    required this.modulos,
    required this.actual,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.apps_outlined,
          title: 'Más',
          trailing: AppAccountMenu(),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: modulos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final m = modulos[i];
              final activo = m.slug == actual?.slug;
              return AppEntrance(
                delay: Duration(milliseconds: 40 * i),
                offset: 12,
                child: Material(
                  color: scheme.surfaceContainerLowest,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: activo ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      activo ? m.iconoActivo : m.icono,
                      color: activo ? scheme.primary : null,
                    ),
                    title: Text(
                      m.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelect(m),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Módulo sin pantalla todavía: encabezado estándar y un estado vacío.
class _ModuloVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;

  const _ModuloVacio({
    required this.icono,
    required this.titulo,
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppPageHeader(
          icon: icono,
          title: titulo,
          trailing: const AppAccountMenu(),
        ),
        Expanded(
          child: AppEmptyState(icon: icono, title: titulo, message: mensaje),
        ),
      ],
    );
  }
}
