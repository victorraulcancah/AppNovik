import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/user_permissions.dart';
import '../../domain/entities/user_record_entity.dart';
import '../components/components.dart';
import '../providers/users_provider.dart';

String _date(DateTime? value) => value == null ? '—' : DateFormat(AppConstants.dateFormat).format(value);

/// `yyyy-MM-dd` → `dd/MM/yyyy`.
String userDateLabel(String? iso) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  return date == null ? '—' : DateFormat(AppConstants.dateFormat).format(date);
}

/// Las iniciales del nombre para el círculo cuando el usuario no tiene foto.
String userInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}

/// El círculo de un usuario: su foto (se pide al servidor al abrirse) o, sin ella, sus iniciales.
class UserAvatar extends StatefulWidget {
  final UserRecordEntity user;
  final double size;

  const UserAvatar({super.key, required this.user, this.size = 72});

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Future<Uint8List?>? _photo;

  @override
  void initState() {
    super.initState();
    if (widget.user.foto != null) _photo = context.read<UsersProvider>().loadPhoto(widget.user.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = Text(
      userInitials(widget.user.name),
      style: TextStyle(
        fontSize: widget.size * 0.34,
        fontWeight: FontWeight.w700,
        color: scheme.onPrimaryContainer,
      ),
    );
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primaryContainer),
      child: _photo == null
          ? initials
          : FutureBuilder<Uint8List?>(
              future: _photo,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) return initials;
                return Image.memory(
                  bytes,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => initials,
                );
              },
            ),
    );
  }
}

String _names(List<UserOption> list) => list.isEmpty ? '—' : list.map((o) => o.name).join(', ');

String _optionName(List<UserOption> list, int? id) {
  if (id == null) return '—';
  for (final o in list) {
    if (o.id == id) return o.name;
  }
  return '—';
}

/// Detalle de un usuario con los mismos datos de la web: ficha, accesos (sucursales, listas de
/// precios, métodos de pago) y permisos adicionales. Devuelve `true` si se tocó "Editar".
Future<bool?> showUserDetail(
  BuildContext context,
  UserRecordEntity u, {
  bool canEdit = false,
  AppPaneController? pane,
}) {
  final everything = u.seesEverything;
  final extra = [for (final p in u.permissions) userPermissionLabels[p.name]].whereType<String>().toList()..sort();

  return showAppModal(
    context,
    pane: pane,
    paneId: u.id,
    keepPaneOpen: canEdit,
    title: u.name,
    subtitle: u.codigo ?? u.usuario,
    icon: Icons.person_outline,
    primaryLabel: canEdit ? 'Editar' : null,
    secondaryLabel: 'Cerrar',
    tabs: [
      AppTabItem(
        label: 'General',
        icon: Icons.info_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: UserAvatar(user: u, size: 88)),
            const SizedBox(height: 12),
            AppDetailRow(label: 'Código', value: u.codigo),
            AppDetailRow(label: 'Usuario', value: u.usuario),
            AppDetailRow(label: 'Nombre', value: u.name),
            AppDetailRow(label: 'Roles', value: u.roles.isEmpty ? null : u.rolesLabel),
            AppDetailRow(label: 'Correo', value: u.email),
            AppDetailRow(label: 'Teléfono', value: u.telefono),
            AppDetailRow(
              label: 'Estado',
              valueWidget: AppStatusBadge(
                label: u.estado ? 'Activo' : 'Inactivo',
                tone: u.estado ? AppBadgeTone.success : AppBadgeTone.neutral,
              ),
            ),
            AppDetailRow(label: 'Creado', value: _date(u.creado)),
          ],
        ),
      ),
      AppTabItem(
        label: 'Datos personales',
        icon: Icons.badge_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailRow(label: 'Tipo de documento', value: userDocumentTypeLabel(u.tipoDocumento)),
            AppDetailRow(label: 'N° de documento', value: u.numeroDocumento),
            AppDetailRow(label: 'Nombres', value: u.nombres ?? u.name),
            AppDetailRow(label: 'Apellidos', value: u.apellidos),
            AppDetailRow(label: 'Fecha de nacimiento', value: u.cumple == null ? null : userDateLabel(u.cumple)),
            AppDetailRow(label: 'Fecha de ingreso', value: u.fechaIngreso == null ? null : userDateLabel(u.fechaIngreso)),
            AppDetailRow(label: 'Dirección', value: u.direccion),
            AppDetailRow(label: 'Contacto de emergencia', value: u.contactoEmergencia),
            AppDetailRow(label: 'Teléfono de emergencia', value: u.telefonoEmergencia),
          ],
        ),
      ),
      AppTabItem(
        label: 'Accesos',
        icon: Icons.layers_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // El Ceo y el Admin de la empresa trabajan con todo: así lo dice la tabla de la web.
            AppDetailRow(label: 'Sucursales', value: everything ? 'Todos los Almacenes' : _names(u.warehouses)),
            AppDetailRow(label: 'Almacén predeterminado', value: _optionName(u.warehouses, u.warehouseId)),
            AppDetailRow(label: 'Listas de precios', value: everything ? 'Todas las Listas de Precios' : _names(u.listPrices)),
            AppDetailRow(label: 'Lista predeterminada', value: _optionName(u.listPrices, u.listPriceId)),
            AppDetailRow(label: 'Operaciones permitidas', value: _names(u.paymentMethods)),
            AppDetailRow(label: 'Método de pago predeterminado', value: _optionName(u.paymentMethods, u.paymentMethodId)),
            if (u.hasRole(UserRoles.vendedor)) ...[
              AppDetailRow(label: 'Método de entrega', value: userDeliveryLabel(u.metodoEntrega)),
              AppDetailRow(label: 'Ve ventas ajenas', value: u.ventasAjenas ? 'Sí' : 'No'),
            ],
            const AppSectionTitle('Permisos adicionales'),
            if (extra.isEmpty)
              Text(
                'No tiene permisos adicionales.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              for (final label in extra)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    ],
  );
}

/// Cómo se lee el tipo de documento guardado (`DNI`, `CE`, `PASAPORTE`).
String? userDocumentTypeLabel(String? type) => switch (type) {
      'DNI' => 'DNI',
      'CE' => 'Carné de extranjería',
      'PASAPORTE' => 'Pasaporte',
      _ => type,
    };

/// Cómo se lee el método de entrega guardado (`e` o `d`).
String? userDeliveryLabel(String? code) => switch (code) {
      'e' => 'Entrega Inmediata',
      'd' => 'Despacho',
      _ => null,
    };

// ---------------------------------------------------------------------------------------------

/// Panel de filtros de la lista: Estado y Rol. Devuelve los filtros elegidos o `null` si se cerró sin
/// aplicar. La búsqueda no se toca.
Future<UserFiltersEntity?> showUserFilters(
  BuildContext context, {
  required UserFiltersEntity current,
  required Future<List<UserOption>> Function() loadRoles,
}) async {
  final draft = ValueNotifier<UserFiltersEntity>(current);
  final applied = await showAppModal(
    context,
    title: 'Filtros',
    subtitle: 'Filtra la lista de usuarios',
    icon: Icons.filter_list,
    primaryLabel: 'Aplicar filtros',
    child: _UserFiltersBody(draft: draft, loadRoles: loadRoles),
  );
  final result = applied == true ? draft.value : null;
  draft.dispose();
  return result;
}

class _UserFiltersBody extends StatefulWidget {
  final ValueNotifier<UserFiltersEntity> draft;
  final Future<List<UserOption>> Function() loadRoles;

  const _UserFiltersBody({required this.draft, required this.loadRoles});

  @override
  State<_UserFiltersBody> createState() => _UserFiltersBodyState();
}

class _UserFiltersBodyState extends State<_UserFiltersBody> {
  List<UserOption>? _roles;
  String? _error;

  UserFiltersEntity get _f => widget.draft.value;
  set _f(UserFiltersEntity value) {
    widget.draft.value = value;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.loadRoles().then((roles) {
      if (mounted) setState(() => _roles = roles);
    }, onError: (Object e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    });
  }

  Future<void> _pickRole() async {
    final roles = _roles ?? const [];
    final current = roles.where((r) => r.name == _f.role).map((r) => r.id).firstOrNull;
    final result = await showAppSelectOne(
      context,
      title: 'Rol',
      subtitle: 'Elige uno',
      icon: Icons.badge_outlined,
      options: [for (final r in roles) (id: r.id, name: UserRoles.display(r.name))],
      selected: current,
    );
    if (result == null) return;
    final name = roles.where((r) => r.id == result.id).map((r) => r.name).firstOrNull;
    _f = name == null ? _f.copyWith(clearRole: true) : _f.copyWith(role: name);
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          selected: {f.estado == null ? 'todos' : (f.estado! ? 'activos' : 'inactivos')},
          onSelectionChanged: (s) => _f = switch (s.first) {
            'activos' => f.copyWith(estado: true),
            'inactivos' => f.copyWith(estado: false),
            _ => f.copyWith(clearEstado: true),
          },
          segments: const [
            ButtonSegment(value: 'todos', label: Text('Todos')),
            ButtonSegment(value: 'activos', label: Text('Activos')),
            ButtonSegment(value: 'inactivos', label: Text('Inactivos')),
          ],
        ),
        const SizedBox(height: 16),
        AppPickerField(
          label: 'Rol',
          value: f.role == null ? 'Todos' : UserRoles.display(f.role!),
          icon: Icons.badge_outlined,
          onTap: _roles == null ? null : _pickRole,
          onClear: f.role == null ? null : () => _f = f.copyWith(clearRole: true),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ErrorBanner(message: 'No se pudieron cargar los roles: $_error'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------

String _plain(String text) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
  const to = 'aaaaeeeeiiiioooouuuunAAAAEEEEIIIIOOOOUUUUN';
  final buffer = StringBuffer();
  for (final c in text.runes) {
    final ch = String.fromCharCode(c);
    final i = from.indexOf(ch);
    buffer.write(i < 0 ? ch : to[i]);
  }
  return buffer.toString().toLowerCase();
}

/// Los permisos que se ofrecen como "adicionales": solo los que están en la lista de la web
/// (`userPermissionLabels`), con su nombre en pantalla.
List<({int id, String name, String label})> userOfferedPermissions(List<UserPermissionEntity> all) => [
      for (final p in all)
        if (userPermissionLabels.containsKey(p.name)) (id: p.id, name: p.name, label: userPermissionLabels[p.name]!),
    ];

/// Elige los permisos adicionales de un usuario, agrupados por módulo y con búsqueda. Devuelve los
/// ids elegidos al aplicar, o `null` si se cerró sin aplicar.
Future<Set<int>?> showUserPermissionsPicker(
  BuildContext context, {
  required List<UserPermissionEntity> permissions,
  required Set<int> selected,
}) async {
  final chosen = ValueNotifier<Set<int>>({...selected});
  final applied = await showAppModal(
    context,
    title: 'Permisos adicionales',
    subtitle: 'Además de los de su rol',
    icon: Icons.verified_user_outlined,
    primaryLabel: 'Aplicar',
    fixedHeight: true,
    child: _PermissionsBody(permissions: userOfferedPermissions(permissions), chosen: chosen),
  );
  final result = applied == true ? chosen.value : null;
  chosen.dispose();
  return result;
}

class _PermissionsBody extends StatefulWidget {
  final List<({int id, String name, String label})> permissions;
  final ValueNotifier<Set<int>> chosen;

  const _PermissionsBody({required this.permissions, required this.chosen});

  @override
  State<_PermissionsBody> createState() => _PermissionsBodyState();
}

class _PermissionsBodyState extends State<_PermissionsBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = _plain(_query.trim());

    // Por módulo, en el orden en que aparecen en la lista de la web.
    final groups = <String, List<({int id, String name, String label})>>{};
    for (final p in widget.permissions) {
      if (q.isNotEmpty && !_plain(p.label).contains(q)) continue;
      groups.putIfAbsent(userPermissionModule(p.name), () => []).add(p);
    }

    final size = MediaQuery.sizeOf(context);
    final tablet = size.width >= AppConstants.tabletBreakpoint;
    final height = math.max(200.0, size.height * (tablet ? 0.8 : 0.85) - 340);

    final rows = <Widget>[];
    groups.forEach((module, list) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text(
            userPermissionModuleLabel(list.first.name),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      for (final p in list) {
        rows.add(
          ValueListenableBuilder<Set<int>>(
            valueListenable: widget.chosen,
            builder: (context, chosen, _) => CheckboxListTile(
              key: ValueKey('permiso-${p.name}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(p.label),
              value: chosen.contains(p.id),
              onChanged: (on) {
                final next = {...chosen};
                on == true ? next.add(p.id) : next.remove(p.id);
                widget.chosen.value = next;
              },
            ),
          ),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Set<int>>(
          valueListenable: widget.chosen,
          builder: (context, chosen, _) => Row(
            children: [
              Expanded(
                child: Text(
                  chosen.isEmpty ? 'Ninguno' : '${chosen.length} elegidos',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: chosen.isEmpty ? null : () => widget.chosen.value = {},
                child: const Text('Quitar todos'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    widget.permissions.isEmpty ? 'No hay permisos para agregar' : 'Sin resultados',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView(children: rows),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------

/// Gestión de roles, como la de la web: la lista de roles, crear uno nuevo, renombrarlo y
/// eliminarlo (según los permisos `usuarios.store`, `usuarios.update` y `usuarios.destroy`).
Future<void> showUserRoles(
  BuildContext context, {
  required bool canCreate,
  required bool canEdit,
  required bool canDelete,
}) {
  return showAppModal(
    context,
    title: 'Gestión de roles',
    subtitle: 'Roles de los usuarios',
    icon: Icons.shield_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    fixedHeight: true,
    child: _RolesBody(canCreate: canCreate, canEdit: canEdit, canDelete: canDelete),
  );
}

class _RolesBody extends StatefulWidget {
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const _RolesBody({required this.canCreate, required this.canEdit, required this.canDelete});

  @override
  State<_RolesBody> createState() => _RolesBodyState();
}

class _RolesBodyState extends State<_RolesBody> {
  List<UserOption>? _roles;
  String? _error;
  String? _actionError;

  UsersProvider get _provider => context.read<UsersProvider>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final roles = await _provider.loadRoles(force: true);
      if (mounted) setState(() => _roles = roles);
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _edit([UserOption? role]) async {
    final saved = await showUserRoleForm(
      context,
      role: role,
      onSubmit: (name) => _provider.saveRole(name, id: role?.id),
    );
    if (saved == true && mounted) {
      setState(() {
        _actionError = null;
        _roles = _provider.roles ?? _roles;
      });
    }
  }

  Future<void> _delete(UserOption role) async {
    final ok = await showAppConfirm(
      context,
      title: 'Eliminar rol',
      subtitle: UserRoles.display(role.name),
      icon: Icons.delete_outline,
      message: '¿Estás seguro de eliminar el rol "${UserRoles.display(role.name)}"?',
      confirmLabel: 'Eliminar',
    );
    if (!ok || !mounted) return;
    final error = await _provider.deleteRole(role.id);
    if (!mounted) return;
    setState(() {
      _actionError = error;
      if (error == null) _roles = _provider.roles ?? _roles;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roles = _roles;
    final size = MediaQuery.sizeOf(context);
    final tablet = size.width >= AppConstants.tabletBreakpoint;
    final height = math.max(200.0, size.height * (tablet ? 0.8 : 0.85) - 300);

    Widget content;
    if (_error != null) {
      content = AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los roles',
        message: _error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: _load),
      );
    } else if (roles == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (roles.isEmpty) {
      content = const AppEmptyState(icon: Icons.shield_outlined, title: 'No hay roles');
    } else {
      content = ListView.separated(
        itemCount: roles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final role = roles[i];
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    UserRoles.display(role.name),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.canEdit) AppActionButton(type: AppActionType.edit, onPressed: () => _edit(role)),
                if (widget.canDelete && role.name != UserRoles.adminGlobal)
                  AppActionButton(type: AppActionType.delete, onPressed: () => _delete(role)),
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.canCreate)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo rol'),
            ),
          ),
        if (_actionError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ErrorBanner(message: _actionError!),
          ),
        const SizedBox(height: 12),
        SizedBox(height: height, child: content),
      ],
    );
  }
}

/// Formulario de un rol: solo su nombre (obligatorio y único). [onSubmit] guarda y devuelve el
/// mensaje de error, o `null` si salió bien. Devuelve `true` si se guardó.
Future<bool?> showUserRoleForm(
  BuildContext context, {
  UserOption? role,
  required Future<String?> Function(String name) onSubmit,
}) {
  final editing = role != null;
  final name = TextEditingController(text: role?.name ?? '');
  final formKey = GlobalKey<FormState>();
  final error = ValueNotifier<String?>(null);

  return showAppModal(
    context,
    title: editing ? 'Editar rol' : 'Nuevo rol',
    subtitle: editing ? UserRoles.display(role.name) : null,
    icon: Icons.shield_outlined,
    primaryLabel: editing ? 'Guardar cambios' : 'Crear rol',
    formKey: formKey,
    error: error,
    onPrimary: () async {
      error.value = null;
      final message = await onSubmit(name.text.trim());
      if (message != null) {
        error.value = message;
        throw StateError(message);
      }
    },
    child: AppDisposer(
      onDispose: [name.dispose, error.dispose],
      child: TextFormField(
        controller: name,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nombre del rol', prefixIcon: Icon(Icons.shield_outlined)),
        validator: (v) => (v ?? '').trim().isEmpty ? 'El nombre es requerido' : null,
      ),
    ),
  );
}
