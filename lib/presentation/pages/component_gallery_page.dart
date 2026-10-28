import 'package:flutter/material.dart';
import '../components/components.dart';

/// Vista de ejemplo con los componentes reutilizables, con la misma lógica que
/// la web (`/productos`): encabezado con un solo botón de acciones adicionales,
/// búsqueda con filtros, lista de tarjetas y un botón flotante para crear.
/// Solo desarrollo, con datos de ejemplo:
///   flutter run --dart-define=GALLERY=true
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  static const _productos = [
    ('SUB-1200', 'Subwoofer 12" 1200 W', 'PIONEER', '24 und.', 'S/ 389.00'),
    ('PAR-65', 'Parlantes 6.5" 2 vías', 'JBL', '112 und.', 'S/ 129.90'),
    ('AMP-4C', 'Amplificador 4 canales', 'KICKER', '7 und.', 'S/ 459.00'),
    ('RAD-DEH', 'Radio Bluetooth 1 DIN', 'PIONEER', 'Agotado', 'S/ 299.00'),
  ];

  Map<String, String?> _filters = {};

  bool get _filtersActive => _filters.values.any((v) => v != null);

  Future<void> _openFilters() async {
    final result = await showAppFilterSheet(
      context,
      fields: [
        AppFilterField(
          id: 'estado',
          label: 'Estado',
          allLabel: 'Todos',
          value: _filters['estado'],
          options: const [
            AppFilterOption('activos', 'Activos'),
            AppFilterOption('inactivos', 'Inactivos'),
          ],
        ),
        AppFilterField(
          id: 'categoria',
          label: 'Categoría',
          value: _filters['categoria'],
          options: const [
            AppFilterOption('parlantes', 'Parlantes'),
            AppFilterOption('amplificadores', 'Amplificadores'),
          ],
        ),
        AppFilterField(
          id: 'marca',
          label: 'Marca',
          value: _filters['marca'],
          options: const [
            AppFilterOption('pioneer', 'Pioneer'),
            AppFilterOption('jbl', 'JBL'),
            AppFilterOption('kicker', 'Kicker'),
          ],
        ),
      ],
    );
    if (result != null) setState(() => _filters = result);
  }

  Future<void> _crear() {
    final codigo = TextEditingController();
    final nombre = TextEditingController();
    return showAppModal(
      context,
      title: 'Nuevo producto',
      subtitle: 'Completa los datos del producto',
      primaryLabel: 'Crear producto',
      onPrimary: () => Future<void>.delayed(const Duration(milliseconds: 600)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(controller: codigo, label: 'Código'),
          const SizedBox(height: 16),
          AppTextField(controller: nombre, label: 'Nombre'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: AppSpeedDial(
        actions: [
          AppSpeedDialAction(
            label: 'Crear',
            icon: Icons.add,
            color: const Color(0xFF16A34A),
            onPressed: _crear,
          ),
          AppSpeedDialAction(
            label: 'Descargar plantilla',
            icon: Icons.download_outlined,
            color: const Color(0xFF0E90C7),
            onPressed: () {},
          ),
          AppSpeedDialAction(
            label: 'Subir productos',
            icon: Icons.upload_outlined,
            color: const Color(0xFFE8891D),
            onPressed: () {},
          ),
          AppSpeedDialAction(
            label: 'Exportar',
            icon: Icons.description_outlined,
            color: const Color(0xFF0D9488),
            onPressed: () {},
          ),
          AppSpeedDialAction(
            label: 'Importar marcas',
            icon: Icons.sell_outlined,
            color: const Color(0xFF7C3AED),
            onPressed: () {},
          ),
          AppSpeedDialAction(
            label: 'Importar categorías',
            icon: Icons.account_tree_outlined,
            color: const Color(0xFFDB2777),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const AppPageHeader(
            icon: Icons.category_outlined,
            title: 'Productos',
            subtitle: 'Qué se compra y se vende, y en qué presentaciones.',
            trailing: AppAccountMenu(),
          ),
          AppSearchBar(
            hint: 'Buscar por nombre, código…',
            onFilter: _openFilters,
            filterActive: _filtersActive,
          ),
          Expanded(
            child: AppCardList<(String, String, String, String, String)>(
              items: _productos,
              bottomPadding: 96,
              itemBuilder: (context, p, number) => AppListCard(
                number: number,
                title: p.$2,
                lines: [p.$1, p.$3],
                trailingTitle: p.$5,
                trailingCaption: p.$4,
                actions: [
                  AppActionButton(type: AppActionType.edit, onPressed: () {}),
                  AppActionButton(
                    type: AppActionType.annul,
                    onPressed: () => showAppConfirm(
                      context,
                      title: 'Anular producto',
                      subtitle: '${p.$1} · ${p.$2}',
                      message: 'El producto quedará anulado y no podrá venderse.',
                      confirmLabel: 'Anular',
                      tone: AppModalTone.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
