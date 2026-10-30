import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/client_form_entity.dart';
import '../../domain/entities/sale_entity.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/client_remote_datasource.dart';
import 'token_guard.dart';

class ClientRepositoryImpl with TokenGuard implements ClientRepository {
  final ClientRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  ClientRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDepartments() =>
      withToken(remoteDataSource.getDepartments);

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getProvinces(String departmentId) =>
      withToken((token) => remoteDataSource.getProvinces(token, departmentId));

  @override
  Future<Either<Failure, List<UbigeoItemEntity>>> getDistricts(String provinceId) =>
      withToken((token) => remoteDataSource.getDistricts(token, provinceId));

  @override
  Future<Either<Failure, DocumentLookupEntity>> lookupDocument({
    required String tipo,
    required String number,
  }) =>
      withToken((token) => remoteDataSource.lookupDocument(token, tipo, number));

  @override
  Future<Either<Failure, ClientEntity>> createClient({
    required int companyId,
    int? executiveId,
    required NewClientFormEntity form,
  }) =>
      withToken(
        (token) => remoteDataSource.createClient(
          token: token,
          companyId: companyId,
          executiveId: executiveId,
          form: form,
        ),
      );
}
