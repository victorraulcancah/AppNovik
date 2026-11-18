import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/client_form_entity.dart' show UbigeoItemEntity;
import '../entities/user_record_entity.dart';
import '../repositories/user_record_repository.dart';

class GetUsersUseCase {
  final UserRecordRepository repository;
  GetUsersUseCase({required this.repository});

  Future<Either<Failure, UserPageEntity>> call({
    required int companyId,
    required int page,
    required int pageSize,
    required UserFiltersEntity filters,
  }) =>
      repository.getUsers(companyId: companyId, page: page, pageSize: pageSize, filters: filters);
}

class GetUserCatalogsUseCase {
  final UserRecordRepository repository;
  GetUserCatalogsUseCase({required this.repository});

  Future<Either<Failure, UserCatalogsEntity>> call({required int companyId}) =>
      repository.getCatalogs(companyId: companyId);
}

/// Un campo del formulario que falta o está mal, y en qué pestaña está.
class UserFormProblem {
  /// El nombre del campo como lo manda la web (`roles`, `warehouse_id`...).
  final String field;

  /// Cómo se nombra en el aviso ("Rol en el sistema").
  final String label;

  /// Qué tiene mal ("El DNI tiene 8 dígitos"); `null` si solo falta.
  final String? reason;

  /// `true` si está en la pestaña Accesos y permisos.
  final bool inAccess;

  const UserFormProblem({required this.field, required this.label, this.reason, this.inAccess = false});

  @override
  String toString() => reason == null ? label : '$label ($reason)';
}

/// Las reglas de cada campo del formulario de usuario, las mismas de la web. Devuelven el motivo, o
/// `null` si el valor sirve.
class UserFormRules {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? mandatory(String? value) => (value ?? '').trim().isEmpty ? 'Obligatorio' : null;

  /// El DNI tiene 8 dígitos; el carné y el pasaporte solo se piden.
  static String? documentNumber(String type, String? value) {
    final missing = mandatory(value);
    if (missing != null) return missing;
    if (type == 'DNI' && !RegExp(r'^\d{8}$').hasMatch(value!.trim())) return 'El DNI tiene 8 dígitos';
    return null;
  }

  static String? email(String? value) {
    final missing = mandatory(value);
    if (missing != null) return missing;
    return _email.hasMatch(value!.trim()) ? null : 'Debe ser un correo válido';
  }

  /// La fecha de nacimiento (`yyyy-MM-dd`) es obligatoria y no puede ser futura.
  static String? birthday(String? value, {DateTime? today}) {
    if (value == null || value.isEmpty) return 'Obligatorio';
    final date = DateTime.tryParse(value);
    if (date == null) return 'Fecha inválida';
    final now = today ?? DateTime.now();
    final limit = DateTime(now.year, now.month, now.day);
    if (date.isAfter(limit)) return 'No puede ser futura';
    return null;
  }
}

/// Crea o edita un usuario con las mismas exigencias de la web.
class SaveUserUseCase {
  final UserRecordRepository repository;
  SaveUserUseCase({required this.repository});

  /// Todo lo que falta o está mal, en el orden del formulario (primero Datos personales).
  static List<UserFormProblem> problems(UserFormEntity f, {required bool editing, DateTime? today}) {
    final list = <UserFormProblem>[];
    void add(String field, String label, String? reason, {bool access = false}) {
      if (reason != null) list.add(UserFormProblem(field: field, label: label, reason: reason == 'Obligatorio' ? null : reason, inAccess: access));
    }

    add('tipo_documento', 'Tipo de documento', UserFormRules.mandatory(f.tipoDocumento));
    add('numero_documento', 'N° de documento', UserFormRules.documentNumber(f.tipoDocumento, f.numeroDocumento));
    add('nombres', 'Nombres', UserFormRules.mandatory(f.nombres));
    add('apellidos', 'Apellidos', UserFormRules.mandatory(f.apellidos));
    add('cumple', 'Fecha de nacimiento', UserFormRules.birthday(f.cumple, today: today));
    add('telefono', 'Celular', UserFormRules.mandatory(f.telefono));
    add('email', 'Correo', UserFormRules.email(f.email));

    String? needs(bool missing) => missing ? 'Obligatorio' : null;
    add('roles', 'Rol en el sistema', needs(f.roles.isEmpty), access: true);
    add('almacenes', 'Sucursales autorizadas', needs(f.almacenes.isEmpty), access: true);
    add('warehouse_id', 'Almacén predeterminado', needs(f.warehouseId == null), access: true);
    if (f.conPagos) {
      add('payment_methods', 'Operaciones permitidas', needs(f.paymentMethods.isEmpty), access: true);
      add('payment_method_id', 'Método de pago predeterminado', needs(f.paymentMethodId == null), access: true);
    }
    // Las listas de precios solo se exigen al crear: un usuario antiguo puede no tenerlas.
    if (!editing && f.conListas) {
      add('listPrices', 'Listas de precios', needs(f.listPrices.isEmpty), access: true);
      add('list_price_id', 'Lista de precios predeterminada', needs(f.listPriceId == null), access: true);
    }
    return list;
  }

  /// El aviso de lo que falta para guardar, como el de la web.
  static String? validate(UserFormEntity f, {required bool editing, DateTime? today}) {
    final list = problems(f, editing: editing, today: today);
    if (list.isEmpty) return null;
    return 'Completa estos campos: ${list.join(', ')}';
  }

  Future<Either<Failure, UserRecordEntity>> call({
    required int companyId,
    required UserFormEntity form,
    int? id,
  }) {
    final message = validate(form, editing: id != null);
    if (message != null) return Future.value(Either.left(ValidationFailure(message)));
    return repository.saveUser(companyId: companyId, form: form, id: id);
  }
}

/// Sube la foto del usuario (JPG, PNG o WEBP de hasta 2 MB).
class UploadUserPhotoUseCase {
  final UserRecordRepository repository;
  UploadUserPhotoUseCase({required this.repository});

  static const maxBytes = 2 * 1024 * 1024;

  Future<Either<Failure, void>> call({required int id, required Uint8List bytes, required String name}) {
    if (bytes.length > maxBytes) {
      return Future.value(Either.left(const ValidationFailure('La foto no puede pesar más de 2 MB')));
    }
    return repository.uploadPhoto(id: id, bytes: bytes, name: name);
  }
}

class GetUserPhotoUseCase {
  final UserRecordRepository repository;
  GetUserPhotoUseCase({required this.repository});

  Future<Either<Failure, Uint8List?>> call(int id) => repository.getPhoto(id);
}

class GetRolesUseCase {
  final UserRecordRepository repository;
  GetRolesUseCase({required this.repository});

  Future<Either<Failure, List<UserOption>>> call() => repository.getRoles();
}

/// Crea o renombra un rol. El nombre es obligatorio y no puede repetirse (lo valida el servidor).
class SaveRoleUseCase {
  final UserRecordRepository repository;
  SaveRoleUseCase({required this.repository});

  Future<Either<Failure, UserOption>> call({required String name, int? id}) {
    final text = name.trim();
    if (text.isEmpty) return Future.value(Either.left(const ValidationFailure('El nombre es requerido')));
    return repository.saveRole(name: text, id: id);
  }
}

class DeleteRoleUseCase {
  final UserRecordRepository repository;
  DeleteRoleUseCase({required this.repository});

  Future<Either<Failure, void>> call(int id) => repository.deleteRole(id);
}

class GetUserDepartmentsUseCase {
  final UserRecordRepository repository;
  GetUserDepartmentsUseCase({required this.repository});

  Future<Either<Failure, List<UbigeoItemEntity>>> call() => repository.getDepartments();
}

class GetUserProvincesUseCase {
  final UserRecordRepository repository;
  GetUserProvincesUseCase({required this.repository});

  Future<Either<Failure, List<UbigeoItemEntity>>> call(String departmentId) => repository.getProvinces(departmentId);
}

class GetUserDistrictsUseCase {
  final UserRecordRepository repository;
  GetUserDistrictsUseCase({required this.repository});

  Future<Either<Failure, List<UbigeoItemEntity>>> call(String provinceId) => repository.getDistricts(provinceId);
}
