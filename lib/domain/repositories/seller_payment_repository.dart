import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/seller_payment_entity.dart';

/// El módulo Pagos vendedores ("Registro de Pagos" de la web): la lista de pagos de los clientes con sus
/// filtros y totales, el Excel, registrar un pago, editarlo, aprobarlo y eliminarlo.
abstract class SellerPaymentRepository {
  Future<Either<Failure, SellerPaymentPageEntity>> getPayments({
    required int page,
    required int pageSize,
    required SellerPaymentFilters filters,
  });

  /// Excel con lo que se está viendo (la búsqueda y los mismos filtros).
  Future<Either<Failure, Uint8List>> exportPayments({required SellerPaymentFilters filters});

  /// Los métodos de pago de la empresa (para registrar y editar pagos).
  Future<Either<Failure, List<SellerPaymentOption>>> getPaymentMethods();

  /// Todos los clientes de la empresa. Con [onlyMine], solo los de la cartera del usuario (el filtro).
  Future<Either<Failure, List<SellerPaymentOption>>> getClients({
    required int companyId,
    required bool onlyMine,
  });

  /// Ejecutivos comerciales (usuarios con rol Vendedor) para el filtro.
  Future<Either<Failure, List<SellerPaymentOption>>> getSellers({required int companyId});

  /// Lo que debe el cliente en soles y en dólares.
  Future<Either<Failure, SellerClientDebt>> getClientDebt({required int clientId});

  Future<Either<Failure, void>> createPayment({required SellerPaymentCreate payment});

  Future<Either<Failure, void>> approvePayment({required int id});

  Future<Either<Failure, void>> editInstallmentPayment({
    required int id,
    required int paymentMethodId,
    double? monto,
    String? descripcionAdicional,
  });

  Future<Either<Failure, void>> editPayment({
    required int id,
    required int paymentMethodId,
    String? descripcion,
  });

  Future<Either<Failure, void>> deletePayment({required int id, required bool afterConfirm});
}
