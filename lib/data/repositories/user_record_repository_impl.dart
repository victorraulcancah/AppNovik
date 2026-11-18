import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/client_form_entity.dart' show UbigeoItemEntity;
import '../../domain/entities/user_record_entity.dart';
import '../../domain/repositories/user_record_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/user_record_remote_datasource.dart';
import 'token_guard.dart';

class UserRecordRepositoryImpl with TokenGuard implements UserRecordRepository {
  final UserRecordRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  UserRecordRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, UserPageEntity>> getUsers({
    required int companyId,
    required int page,
    required int pageSize,
    required UserFiltersEntity filters,
  }) =>
      withToken(
        (token) => remoteDataSource.getUsers(
          token,
          companyId: companyId,
          page: page,
          pageSize: pageSize,
          filters: filters,
        ),
      );

  @override
  Future<Either<Failure, UserCatalogsEntity>> getCatalogs({required int companyId}) =>
      withToken((token) => remoteDataSource.getCatalogs(token, companyId: companyId));

  @override
  Future<Either<Failure, UserRecordEntity>> saveUser({
    required int companyId,
    required UserFormEntity form,
    int? id,
  }) =>
      withToken((token) => remoteDataSource.saveUser(token, companyId: companyId, form: form, id: id));

  @override
  Future<Either<Failure, void>> uploadPhoto({required int id, required Uint8List bytes, required String name}) =>
      withToken((token) => remoteDataSource.uploadPhoto(token, id: id, bytes: bytes, name: name));

  @override
  Future<Either<Failure, Uint8List?>> getPhoto(int id) => withToken((token) => remoteDataSource.getPhoto(token, id));

  @override
  Future<Either<Failure, List<UserOption>>> getRoles() => withToken(remoteDataSource.getRoles);

  @override
  Future<Either<Failure, UserOption>> saveRole({required String name, int? id}) =>
      withToken((token) => remoteDataSource.saveRole(token, name: name, id: id));

  @override
  Future<Either<Failure, void>> deleteRole(int id) => withToken((token) => remoteDataSource.deleteRole(token, id));

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDepartments() => withToken(remoteDataSource.getDepartments);

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getProvinces(String departmentId) =>
      withToken((token) => remoteDataSource.getProvinces(token, departmentId));

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDistricts(String provinceId) =>
      withToken((token) => remoteDataSource.getDistricts(token, provinceId));
}
