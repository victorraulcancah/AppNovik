import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/client_form_entity.dart';
import '../entities/sale_entity.dart';

abstract class ClientRepository {
  Future<Either<Failure, List<UbigeoItemEntity>>> getDepartments();
  Future<Either<Failure, List<UbigeoItemEntity>>> getProvinces(String departmentId);
  Future<Either<Failure, List<UbigeoItemEntity>>> getDistricts(String provinceId);

  /// Consulta un DNI (persona) o un RUC (empresa) para rellenar los datos del cliente.
  Future<Either<Failure, DocumentLookupEntity>> lookupDocument({
    required String tipo,
    required String number,
  });

  /// Crea el cliente en la empresa. Con [executiveId] queda en la cartera de ese ejecutivo.
  Future<Either<Failure, ClientEntity>> createClient({
    required int companyId,
    int? executiveId,
    required NewClientFormEntity form,
  });
}
