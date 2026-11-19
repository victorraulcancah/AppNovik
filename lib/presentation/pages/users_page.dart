import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/user_record_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/users_provider.dart';
import '../utils/success_snack.dart';
import '../widgets/user_record_form.dart';
import '../widgets/user_record_modals.dart';

/// Módulo Usuarios: lista paginada con búsqueda y filtros (estado y rol), detalle, crear y editar
/// con las pestañas de la web (datos personales, accesos y permisos adicionales) y la gestión de
/// roles, según los permisos del usuario (`usuarios.*`).
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  Timer? _debounce;

  /// Panel de detalle (tablet).
  final _pane = AppPaneController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _can('usuarios.index')) context.read<UsersProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pane.dispose();
    super.dispose();
  }

  bool _can(String permission) => context.read<AuthProvider>().session?.can(permission) ?? false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) context.read<UsersProvider>().setSearch(text);
    });
  }

  Future<void> _openFilters() async {
    final provider = context.read<UsersProvider>();
    final result = await showUserFilters(
      context,
      current: provider.filters,
      loadRoles: provider.loadRoles,
    );
    if (result != null) provider.setFilters(result);
  }

  /// Los filtros del panel que están puestos (sin contar la búsqueda), como chips que se quitan.
  List<AppActiveFilter> _activeFilters(UsersProvider provider) {
    final f = provider.filters;
    return [
      if (f.estado != null)
        AppActiveFilter(
          id: 'estado',
          label: 'Estado: ${f.estado! ? 'Activos' : 'Inactivos'}',
          onRemove: () => provider.setFilters(f.copyWith(clearEstado: true)),
        ),
      if (f.role != null)
        AppActiveFilter(
          id: 'rol',
          label: 'Rol: ${UserRoles.display(f.role!)}',
          onRemove: () => provider.setFilters(f.copyWith(clearRole: true)),
        ),
    ];
  }

  /// Muestra el aviso que sigue a guardar: el éxito, o el aviso de que la foto no se pudo subir.
  void _saved(({String? error, String? warning}) result, String success) {
    if (result.error != null || !mounted) return;
    if (result.warning != null) {
      _snack(result.warning!);
    } else {
      showSuccessSnack(context, success);
    }
  }

  Future<void> _create() {
    final provider = context.read<UsersProvider>();
    return showUserForm(
      context,
      loadCatalogs: provider.loadCatalogs,
      assignableRoles: provider.assignableRoles,
      onSubmit: (form, photo) async {
        final result = await provider.saveUser(form, photo: photo);
        _saved(result, 'Usuario creado');
        return result.error;
      },
    );
  }

  Future<void> _edit(UserRecordEntity user) async {
    final provider = context.read<UsersProvider>();
    final saved = await showUserForm(
      context,
      user: user,
      loadCatalogs: provider.loadCatalogs,
      assignableRoles: provider.assignableRoles,
      onSubmit: (form, photo) async {
        final result = await provider.saveUser(form, id: user.id, photo: photo);
        _saved(result, 'Usuario editado');
        return result.error;
      },
    );
    // En tablet el detalle seguía a la vista: si se guardó, vuelve con los datos nuevos (si se
    // canceló, queda como estaba).
    if (saved != true || !mounted || !_pane.isWide || _pane.selectedId != user.id) return;
    final updated = provider.items.where((u) => u.id == user.id).firstOrNull;
    if (updated == null) {
      _pane.close();
    } else {
      unawaited(_detail(updated));
    }
  }

  bool get _canEdit => _can('usuarios.update');

  Future<void> _detail(UserRecordEntity user) async {
    final edit = await showUserDetail(context, user, canEdit: _canEdit, pane: _pane);
    if (edit == true && mounted) _edit(user);
  }

  Future<void> _roles() => showUserRoles(
        context,
        canCreate: _can('usuarios.store'),
        canEdit: _can('usuarios.update'),
        canDelete: _can('usuarios.destroy'),
      );

  List<AppSpeedDialAction> _actions() {
    return [
      if (_can('usuarios.store'))
        AppSpeedDialAction(
          label: 'Crear usuario',
          icon: Icons.person_add_alt_outlined,
          color: const Color(0xFF16A34A),
          onPressed: _create,
        ),
      if (_can('usuarios.index'))
        AppSpeedDialAction(
          label: 'Roles',
          icon: Icons.shield_outlined,
          color: const Color(0xFF0E90C7),
          onPressed: _roles,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsersProvider>();
    final session = context.watch<AuthProvider>().session;

    if (session != null && !session.can('usuarios.index')) {
      return Column(
        children: const [
          AppPageHeader(
            icon: Icons.manage_accounts_outlined,
            title: 'Usuarios',
            trailing: AppAccountMenu(),
          ),
          Expanded(
            child: AppEmptyState(
              icon: Icons.lock_outline,
              title: 'Sin acceso',
              message: 'No tienes permiso para ver usuarios.',
            ),
          ),
        ],
      );
    }

    final actions = _actions();
    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.manage_accounts_outlined,
          title: 'Usuarios',
          subtitle: 'Quién usa el sistema, con qué rol y accesos.',
          trailing: AppAccountMenu(),
        ),
        // En tablet, la lista a la izquierda y el detalle del usuario a la derecha.
        Expanded(
          child: AppMasterDetail(
            controller: _pane,
            emptyIcon: Icons.manage_accounts_outlined,
            emptyTitle: 'Selecciona un usuario',
            emptyMessage: 'Toca un usuario para ver su detalle.',
            listBuilder: (context) => _listPane(provider, actions),
          ),
        ),
      ],
    );
  }

  Widget _listPane(UsersProvider provider, List<AppSpeedDialAction> actions) {
    return Stack(
      children: [
        Column(
          children: [
            AppSearchBar(
              hint: 'Buscar por usuario, nombre, rol, correo…',
              onChanged: _onSearchChanged,
              onFilter: _openFilters,
              filterCount: _activeFilters(provider).length,
            ),
            AppActiveFilters(
              filters: _activeFilters(provider),
              onClear: () => provider.setFilters(provider.filters.copyWith(clearEstado: true, clearRole: true)),
            ),
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

  Widget _body(UsersProvider provider) {
    if (provider.loading && provider.items.isEmpty) {
      return const AppSkeletonList();
    }
    if (provider.error != null && provider.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los usuarios',
        message: provider.error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: provider.refresh),
      );
    }

    return AppCardList<UserRecordEntity>(
      items: provider.items,
      emptyIcon: Icons.person_search_outlined,
      emptyTitle: 'No hay usuarios',
      emptyMessage: provider.filters.active ? 'Prueba con otra búsqueda o quita los filtros.' : null,
      onRefresh: provider.refresh,
      onLoadMore: provider.loadMore,
      loadingMore: provider.loadingMore,
      bottomPadding: 96,
      itemBuilder: (context, u, number) => _card(context, u),
    );
  }

  Widget _card(BuildContext context, UserRecordEntity u) {
    // Los mismos datos que la tabla de la web: código, nombre, roles, correo, teléfono, estado y,
    // en la fila de abajo, las sucursales asignadas (el Ceo y el Admin de la empresa, todas).
    final warehouses = u.seesEverything ? 'Todos los Almacenes' : u.warehouses.map((w) => w.name).join(', ');
    final lines = [
      if (u.codigo != null) 'Código: ${u.codigo}',
      if (u.roles.isNotEmpty) 'Roles: ${u.rolesLabel}',
      if (u.email != null) 'Correo: ${u.email}',
      if (u.telefono != null) 'Teléfono: ${u.telefono}',
      if (warehouses.isNotEmpty) 'Sucursales: $warehouses',
    ];

    return AppListCard(
      title: u.name,
      lines: lines,
      // El correo y las sucursales van cada uno en una sola línea.
      oneLinePrefixes: const ['Correo:', 'Sucursales:'],
      leading: UserAvatar(user: u, size: 44),
      footerOnRight: true,
      footer: Row(
        children: [
          const Spacer(),
          AppStatusBadge(
            label: u.estado ? 'Activo' : 'Inactivo',
            tone: u.estado ? AppBadgeTone.success : AppBadgeTone.neutral,
          ),
        ],
      ),
      selected: _pane.selectedId == u.id,
      onTap: () => _detail(u),
      actions: [
        AppActionButton(type: AppActionType.view, onPressed: () => _detail(u)),
        if (_canEdit) AppActionButton(type: AppActionType.edit, onPressed: () => _edit(u)),
      ],
    );
  }
}
