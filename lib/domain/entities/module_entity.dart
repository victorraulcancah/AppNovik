import '../../core/utils/slug.dart';

/// Módulo contratado por la empresa y permitido para el usuario.
class ModuleEntity {
  final int id;
  final String name;
  final String? icon;

  const ModuleEntity({required this.id, required this.name, this.icon});

  String get slug => toSlug(name);
}
