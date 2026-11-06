import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/client_record_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/client_list_provider.dart';
import '../utils/download_file.dart';
import '../utils/success_snack.dart';
import '../widgets/client_record_form.dart';
import '../widgets/client_record_modals.dart';

/// Módulo Clientes: lista paginada con búsqueda y filtros (tipo, estado, categoría, ejecutivo y
/// departamento), detalle, crear y editar con las pestañas de la web, categorías de cliente y
/// exportar a Excel, según los permisos del usuario (`clientes.*`).
class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _can('clientes.index')) context.read<ClientListProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool _can(String permission) => context.read<AuthProvider>().session?.can(permission) ?? false;

  bool _hasRole(String role) => context.read<AuthProvider>().session?.hasRole(role) ?? false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<ClientListProvider>().setSearch(text);
    });
  }

  Future<void> _openFilters() async {
    final provider = context.read<ClientListProvider>();
    final result = await showClientFilters(
      context,
      current: provider.filters,
      loadCatalogs: provider.loadFilterCatalogs,
    );
    if (result != null) provider.setFilters(result);
  }

  /// Qué pestañas del formulario puede usar el usuario (los mismos permisos de la web).
  ClientFormAccess _access({required bool editing}) {
    final provider = context.read<ClientListProvider>();
    final canBeExecutive = _hasRole('Vendedor') || _hasRole('Ceo Empresa');
    return ClientFormAccess(
      basic: editing ? _can('clientes.update.informacion-basica') : _can('clientes.store'),
      addresses: editing ? _can('clientes.update.direcciones') : _can('clientes.store'),
      contacts: editing ? _can('clientes.update.contactos') : _can('clientes.store'),
      conditions: _can('clientes.condiciones-de-venta') || _hasRole('Ceo Empresa'),
      onlySeller: provider.isOnlySeller,
      defaultExecutiveId: canBeExecutive ? provider.userId : null,
    );
  }

  Future<void> _create() {
    final provider = context.read<ClientListProvider>();
    return showClientForm(
      context,
      access: _access(editing: false),
      loadCatalogs: provider.loadFormCatalogs,
      onSubmit: (form) async {
        final error = await provider.saveClient(form);
        if (error == null && mounted) showSuccessSnack(context, 'Cliente creado');
        return error;
      },
    );
  }

  Future<void> _edit(ClientRecordEntity client) {
    final provider = context.read<ClientListProvider>();
    return showClientForm(
      context,
      client: client,
      access: _access(editing: true),
      loadCatalogs: provider.loadFormCatalogs,
      onSubmit: (form) async {
        final error = await provider.saveClient(form, id: client.id, originalEmail: client.email);
        if (error == null && mounted) showSuccessSnack(context, 'Cliente editado');
        return error;
      },
    );
  }

  bool get _canEdit => _can('clientes.update');

  Future<void> _detail(ClientRecordEntity client) async {
    final edit = await showClientDetail(
      context,
      client,
      canEdit: _canEdit,
      canSeePhone: _can('clientes.show-telefono'),
    );
    if (edit == true && mounted) _edit(client);
  }

  Future<void> _export() async {
    final result = await context.read<ClientListProvider>().exportAll();
    if (!mounted) return;
    if (result.isLeft) return _snack(result.left.message);
    await downloadFile(context, result.right);
  }

  Future<void> _categories() async {
    final provider = context.read<ClientListProvider>();
    if (_can('clientes.categorizar')) {
      await showClientCategoriesConfig(
        context,
        load: provider.loadCategories,
        onSave: (categorias, ciclo, {required calculate}) =>
            provider.saveCategories(categorias: categorias, ciclo: ciclo, calculate: calculate),
      );
    } else {
      await showClientCategories(context, load: provider.loadCategories);
    }
  }

  List<AppSpeedDialAction> _actions(ClientListProvider provider) {
    return [
      if (_can('clientes.store'))
        AppSpeedDialAction(
          label: 'Crear cliente',
          icon: Icons.add,
          color: const Color(0xFF16A34A),
          onPressed: _create,
        ),
      if (_can('clientes.categorizar'))
        AppSpeedDialAction(
          label: 'Configurar categorías',
          icon: Icons.tune,
          color: const Color(0xFF7C3AED),
          onPressed: _categories,
        )
      else if (_hasRole('Vendedor'))
        AppSpeedDialAction(
          label: 'Ver categorías',
          icon: Icons.workspace_premium_outlined,
          color: const Color(0xFF0E90C7),
          onPressed: _categories,
        ),
      if (_can('clientes.export'))
        AppSpeedDialAction(
          label: provider.exporting ? 'Exportando…' : 'Exportar',
          icon: Icons.description_outlined,
          color: const Color(0xFF0D9488),
          onPressed: provider.exporting ? null : _export,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientListProvider>();
    final session = context.watch<AuthProvider>().session;

    if (session != null && !session.can('clientes.index')) {
      return Column(
        children: const [
          AppPageHeader(
            icon: Icons.people_alt_outlined,
            title: 'Clientes',
            trailing: AppAccountMenu(),
          ),
          Expanded(
            child: AppEmptyState(
              icon: Icons.lock_outline,
              title: 'Sin acceso',
              message: 'No tienes permiso para ver clientes.',
            ),
          ),
        ],
      );
    }

    final actions = _actions(provider);
    return Stack(
      children: [
        Column(
          children: [
            const AppPageHeader(
              icon: Icons.people_alt_outlined,
              title: 'Clientes',
              subtitle: 'Personas y empresas a las que les vendes.',
              trailing: AppAccountMenu(),
            ),
            AppSearchBar(
              hint: 'Buscar por nombre, DNI/RUC, teléfono…',
              onChanged: _onSearchChanged,
              onFilter: _openFilters,
              filterActive: provider.filters.panelActive,
            ),
            _TypeCounters(provider: provider),
            Expanded(child: _body(provider)),
          ],
        ),
        if (actions.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: AppSpeedDial(actions: actions),
          ),
      ],
    );
  }

  Widget _body(ClientListProvider provider) {
    if (provider.loading && provider.items.isEmpty) {
      return const AppSkeletonList();
    }
    if (provider.error != null && provider.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los clientes',
        message: provider.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: provider.refresh),
      );
    }

    return AppCardList<ClientRecordEntity>(
      items: provider.items,
      emptyIcon: Icons.people_outline,
      emptyTitle: 'No hay clientes',
      emptyMessage: provider.filters.active ? 'Prueba con otra búsqueda o quita los filtros.' : null,
      onRefresh: provider.refresh,
      onLoadMore: provider.loadMore,
      loadingMore: provider.loadingMore,
      bottomPadding: 96,
      itemBuilder: (context, c, number) => _card(context, c, number),
    );
  }

  Widget _card(BuildContext context, ClientRecordEntity c, int number) {
    final scheme = Theme.of(context).colorScheme;
    final canSeePhone = _can('clientes.show-telefono');

    // Los mismos datos que la tabla de la web: código, tipo, documento, nombre, categoría,
    // teléfono, departamento, línea de crédito, ejecutivo y estado.
    final id = '${c.esEmpresa ? 'RUC' : 'DNI'} ${c.dniRuc}';
    final lines = [
      [c.esEmpresa ? 'Empresa' : 'Persona', id].join(' · '),
      [
        if (c.codigo != null) c.codigo!,
        if (canSeePhone && c.telefono != null) c.telefono!,
        if (c.departmentName != null) c.departmentName!,
      ].join(' · '),
      c.ejecutivoNombre == null ? 'Sin ejecutivo asignado' : 'Ejecutivo: ${c.ejecutivoNombre}',
    ].where((t) => t.isNotEmpty).toList();

    return AppListCard(
      number: number,
      title: c.displayName,
      lines: lines,
      trailingTitle: formatMoney(c.credito, symbol: 'S/.'),
      trailingCaption: c.lineaUtilizada > 0 ? 'Usado ${formatMoney(c.lineaUtilizada, symbol: 'S/.')}' : 'Crédito',
      trailingCaptionColor: scheme.onSurfaceVariant,
      footer: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (c.categoriaNombre != null) ClientCategoryBadge(name: c.categoriaNombre!, code: c.categoriaCodigo),
          AppStatusBadge(
            label: c.estado ? 'Activo' : 'Inactivo',
            tone: c.estado ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
        ],
      ),
      onTap: () => _detail(c),
      actions: [
        AppActionButton(type: AppActionType.view, onPressed: () => _detail(c)),
        if (_canEdit) AppActionButton(type: AppActionType.edit, onPressed: () => _edit(c)),
      ],
    );
  }
}

/// "Todos / Personas / Empresas" con su cantidad, que también filtran la lista (como los
/// contadores de la cabecera de la web).
class _TypeCounters extends StatelessWidget {
  final ClientListProvider provider;

  const _TypeCounters({required this.provider});

  @override
  Widget build(BuildContext context) {
    final tipo = provider.filters.tipo;
    Widget chip(String label, int count, String? value) => ChoiceChip(
          label: Text('$label: $count'),
          selected: tipo == value,
          onSelected: (_) => provider.setTipo(value),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          chip('Todos', provider.allCount, null),
          const SizedBox(width: 8),
          chip('Personas', provider.totalPersonas, 'p'),
          const SizedBox(width: 8),
          chip('Empresas', provider.totalEmpresas, 'e'),
        ],
      ),
    );
  }
}
