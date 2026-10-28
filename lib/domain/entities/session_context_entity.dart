import 'company_entity.dart';
import 'module_entity.dart';
import 'user_entity.dart';
import 'warehouse_entity.dart';

/// Todo lo que el backend (`POST /auth`) dice del usuario autenticado: su
/// empresa, los módulos que esa empresa tiene habilitados y sus permisos.
class SessionContextEntity {
  final UserEntity user;
  final CompanyEntity company;
  final List<ModuleEntity> modules;
  final Set<String> permissions;
  final List<String> roles;
  final List<WarehouseEntity> warehouses;

  const SessionContextEntity({
    required this.user,
    required this.company,
    required this.modules,
    required this.permissions,
    required this.roles,
    required this.warehouses,
  });

  bool hasModule(String slug) => modules.any((m) => m.slug == slug);

  bool can(String permission) => permissions.contains(permission);
}
