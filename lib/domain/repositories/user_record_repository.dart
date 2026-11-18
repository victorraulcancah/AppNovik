import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/client_form_entity.dart' show UbigeoItemEntity;
import '../entities/user_record_entity.dart';

/// El módulo Usuarios: lista con búsqueda y filtros, formulario de usuario (con su foto) y la
/// gestión de roles.
abstract class UserRecordRepository {
  Future<Either<Failure, UserPageEntity>> getUsers({
    required int companyId,
    required int page,
    required int pageSize,
    required UserFiltersEntity filters,
  });

  /// Roles, sucursales, listas de precios, métodos de pago y permisos del formulario.
  Future<Either<Failure, UserCatalogsEntity>> getCatalogs({required int companyId});

  /// Crea el usuario, o lo edita si se pasa [id]. Devuelve el usuario guardado.
  Future<Either<Failure, UserRecordEntity>> saveUser({
    required int companyId,
    required UserFormEntity form,
    int? id,
  });

  /// Reemplaza la foto del usuario (JPG, PNG o WEBP de hasta 2 MB).
  Future<Either<Failure, void>> uploadPhoto({required int id, required Uint8List bytes, required String name});

  /// La foto del usuario; `null` si no tiene.
  Future<Either<Failure, Uint8List?>> getPhoto(int id);

  Future<Either<Failure, List<UserOption>>> getRoles();

  /// Crea el rol, o lo renombra si se pasa [id].
  Future<Either<Failure, UserOption>> saveRole({required String name, int? id});

  Future<Either<Failure, void>> deleteRole(int id);

  Future<Either<Failure, List<UbigeoItemEntity>>> getDepartments();
  Future<Either<Failure, List<UbigeoItemEntity>>> getProvinces(String departmentId);
  Future<Either<Failure, List<UbigeoItemEntity>>> getDistricts(String provinceId);
}
