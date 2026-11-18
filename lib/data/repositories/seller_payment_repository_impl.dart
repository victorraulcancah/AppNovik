import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/seller_payment_entity.dart';
import '../../domain/repositories/seller_payment_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/seller_payment_remote_datasource.dart';
import 'token_guard.dart';

class SellerPaymentRepositoryImpl with TokenGuard implements SellerPaymentRepository {
  final SellerPaymentRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  SellerPaymentRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, SellerPaymentPageEntity>> getPayments({
    required int page,
    required int pageSize,
    required SellerPaymentFilters filters,
  }) =>
      withToken(
        (token) => remoteDataSource.getPayments(token, page: page, pageSize: pageSize, filters: filters),
      );

  @override
  Future<Either<Failure, Uint8List>> exportPayments({required SellerPaymentFilters filters}) =>
      withToken((token) => remoteDataSource.exportPayments(token, filters: filters));

  @override
  Future<Either<Failure, List<SellerPaymentOption>>> getPaymentMethods() =>
      withToken(remoteDataSource.getPaymentMethods);

  @override
  Future<Either<Failure, List<SellerPaymentOption>>> getClients({
    required int companyId,
    required bool onlyMine,
  }) =>
      withToken((token) => remoteDataSource.getClients(token, companyId: companyId, onlyMine: onlyMine));

  @override
  Future<Either<Failure, List<SellerPaymentOption>>> getSellers({required int companyId}) =>
      withToken((token) => remoteDataSource.getSellers(token, companyId: companyId));

  @override
  Future<Either<Failure, SellerClientDebt>> getClientDebt({required int clientId}) =>
      withToken((token) => remoteDataSource.getClientDebt(token, clientId: clientId));

  @override
  Future<Either<Failure, void>> createPayment({required SellerPaymentCreate payment}) =>
      withToken((token) => remoteDataSource.createPayment(token, payment: payment));

  @override
  Future<Either<Failure, void>> approvePayment({required int id}) =>
      withToken((token) => remoteDataSource.approvePayment(token, id: id));

  @override
  Future<Either<Failure, void>> editInstallmentPayment({
    required int id,
    required int paymentMethodId,
    double? monto,
    String? descripcionAdicional,
  }) =>
      withToken(
        (token) => remoteDataSource.editInstallmentPayment(
          token,
          id: id,
          paymentMethodId: paymentMethodId,
          monto: monto,
          descripcionAdicional: descripcionAdicional,
        ),
      );

  @override
  Future<Either<Failure, void>> editPayment({
    required int id,
    required int paymentMethodId,
    String? descripcion,
  }) =>
      withToken(
        (token) => remoteDataSource.editPayment(
          token,
          id: id,
          paymentMethodId: paymentMethodId,
          descripcion: descripcion,
        ),
      );

  @override
  Future<Either<Failure, void>> deletePayment({required int id, required bool afterConfirm}) =>
      withToken((token) => remoteDataSource.deletePayment(token, id: id, afterConfirm: afterConfirm));
}
