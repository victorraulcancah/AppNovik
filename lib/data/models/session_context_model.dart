import '../../domain/entities/company_entity.dart';
import '../../domain/entities/module_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/entities/warehouse_entity.dart';
import 'user_model.dart';

/// Respuesta de `POST /auth`.
///
/// OJO: el backend incluye en `user.company` columnas sensibles (clave SOL,
/// secret_client, certificado). Aquí solo se leen los campos necesarios y
/// nada más se guarda ni se conserva.
class SessionContextModel extends SessionContextEntity {
  const SessionContextModel({
    required super.user,
    required super.company,
    required super.modules,
    required super.permissions,
    required super.roles,
    required super.warehouses,
    super.defaultWarehouseId,
    super.defaultListPriceId,
  });

  factory SessionContextModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final company = user['company'] as Map<String, dynamic>?;
    if (company == null) {
      throw const FormatException('El usuario no tiene empresa asignada');
    }

    return SessionContextModel(
      user: UserModel.fromJson(user),
      company: _company(company),
      modules: _list(json['modulos'])
          .map((m) => ModuleEntity(
                id: _int(m['id']) ?? 0,
                name: (m['name'] ?? '') as String,
                icon: m['icon'] as String?,
              ))
          .toList(),
      permissions: _list(user['permissions'])
          .map((p) => (p['name'] ?? '') as String)
          .where((name) => name.isNotEmpty)
          .toSet(),
      roles: _list(user['roles'])
          .map((r) => (r['name'] ?? '') as String)
          .where((name) => name.isNotEmpty)
          .toList(),
      warehouses: _list(user['warehouses'])
          .map((w) => WarehouseEntity(
                id: _int(w['id']) ?? 0,
                name: (w['name'] ?? '') as String,
                codigo: w['codigo'] as String?,
              ))
          .toList(),
      defaultWarehouseId: _int(user['warehouse_id']),
      defaultListPriceId: _int(user['list_price_id']),
    );
  }

  static CompanyEntity _company(Map<String, dynamic> c) {
    final profile = c['profile'] as Map<String, dynamic>?;
    return CompanyEntity(
      id: _int(c['id']) ?? 0,
      razonSocial: (c['razon_social'] ?? '') as String,
      ruc: c['ruc'] as String?,
      direccion: c['direccion'] as String?,
      telefono: c['telefono'] as String?,
      email: c['email'] as String?,
      web: c['web'] as String?,
      igv: _double(c['igv']),
      emiteComprobantes: c['certificado'] != null && '${c['certificado']}'.isNotEmpty,
      plan: profile == null
          ? null
          : PlanEntity(
              name: (profile['name'] ?? '') as String,
              documentosMax: _int(profile['documentos_max']),
              almacenesMax: _int(profile['almacenes_max']),
              estadoCuentaClientes: _bool(profile['estado_cuenta_clientes']),
              ecommerce: _bool(profile['ecommerce']),
            ),
    );
  }

  static List<Map<String, dynamic>> _list(dynamic value) =>
      value is List ? value.whereType<Map<String, dynamic>>().toList() : [];

  static int? _int(dynamic v) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  static double? _double(dynamic v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

  static bool _bool(dynamic v) => v == true || v == 1 || v == '1';
}
