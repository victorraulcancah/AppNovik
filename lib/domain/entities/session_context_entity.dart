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

  /// Almacén y lista de precios predeterminados del usuario (pueden no existir).
  final int? defaultWarehouseId;
  final int? defaultListPriceId;

  /// Método de entrega (`e` inmediata, `d` despacho) y forma de pago predeterminados del usuario.
  final String? defaultDelivery;
  final int? defaultPaymentMethodId;

  const SessionContextEntity({
    required this.user,
    required this.company,
    required this.modules,
    required this.permissions,
    required this.roles,
    required this.warehouses,
    this.defaultWarehouseId,
    this.defaultListPriceId,
    this.defaultDelivery,
    this.defaultPaymentMethodId,
  });

  bool hasModule(String slug) => modules.any((m) => m.slug == slug);

  bool can(String permission) => permissions.contains(permission);

  bool hasRole(String role) => roles.contains(role);
}
