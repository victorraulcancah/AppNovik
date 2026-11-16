import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/account_statement_entity.dart';
import '../entities/document_entity.dart' show DownloadedFile;
import '../entities/sale_entity.dart' show ClientEntity;

abstract class AccountStatementRepository {
  /// Clientes que el usuario puede ver en el estado de cuenta (`validar_vendedor`): sin el
  /// permiso `estado-de-cuenta.index-clientes-de-otros-vendedores`, solo los propios.
  Future<Either<Failure, List<ClientEntity>>> searchClients(int companyId, String search);

  /// Pestaña "Estado de Cuenta": movimientos intercalados por fecha, con la cabecera.
  Future<Either<Failure, StatementPageEntity>> getStatement(StatementQuery query, {required int page, required int pageSize});

  /// Pestaña "Pedidos": los productos de cada venta del rango.
  Future<Either<Failure, StatementPageEntity>> getOrders(StatementQuery query, {required int page, required int pageSize});

  /// Pestaña "Pagos".
  Future<Either<Failure, StatementPageEntity>> getPayments(StatementQuery query, {required int page, required int pageSize});

  /// El Excel de la pestaña [tab].
  Future<Either<Failure, DownloadedFile>> exportExcel(StatementTab tab, StatementQuery query);

  /// El PDF del estado de cuenta (lo arma el servidor).
  Future<Either<Failure, Uint8List>> exportPdf(StatementQuery query);
}
