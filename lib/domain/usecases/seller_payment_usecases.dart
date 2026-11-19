import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/seller_payment_entity.dart';
import '../repositories/seller_payment_repository.dart';

class GetSellerPaymentsUseCase {
  final SellerPaymentRepository repository;
  GetSellerPaymentsUseCase({required this.repository});

  Future<Either<Failure, SellerPaymentPageEntity>> call({
    required int page,
    required int pageSize,
    required SellerPaymentFilters filters,
  }) =>
      repository.getPayments(page: page, pageSize: pageSize, filters: filters);
}

class ExportSellerPaymentsUseCase {
  final SellerPaymentRepository repository;
  ExportSellerPaymentsUseCase({required this.repository});

  Future<Either<Failure, Uint8List>> call({required SellerPaymentFilters filters}) =>
      repository.exportPayments(filters: filters);
}

class GetSellerPaymentMethodsUseCase {
  final SellerPaymentRepository repository;
  GetSellerPaymentMethodsUseCase({required this.repository});

  Future<Either<Failure, List<SellerPaymentOption>>> call() => repository.getPaymentMethods();
}

class GetSellerPaymentClientsUseCase {
  final SellerPaymentRepository repository;
  GetSellerPaymentClientsUseCase({required this.repository});

  Future<Either<Failure, List<SellerPaymentOption>>> call({
    required int companyId,
    required bool onlyMine,
  }) =>
      repository.getClients(companyId: companyId, onlyMine: onlyMine);
}

class GetSellerPaymentSellersUseCase {
  final SellerPaymentRepository repository;
  GetSellerPaymentSellersUseCase({required this.repository});

  Future<Either<Failure, List<SellerPaymentOption>>> call({required int companyId}) =>
      repository.getSellers(companyId: companyId);
}

class GetSellerClientDebtUseCase {
  final SellerPaymentRepository repository;
  GetSellerClientDebtUseCase({required this.repository});

  Future<Either<Failure, SellerClientDebt>> call({required int clientId}) =>
      repository.getClientDebt(clientId: clientId);
}

class CreateSellerPaymentUseCase {
  final SellerPaymentRepository repository;
  CreateSellerPaymentUseCase({required this.repository});

  Future<Either<Failure, void>> call({required SellerPaymentCreate payment}) =>
      repository.createPayment(payment: payment);
}

class ApproveSellerPaymentUseCase {
  final SellerPaymentRepository repository;
  ApproveSellerPaymentUseCase({required this.repository});

  Future<Either<Failure, void>> call({required int id}) => repository.approvePayment(id: id);
}

class EditSellerInstallmentPaymentUseCase {
  final SellerPaymentRepository repository;
  EditSellerInstallmentPaymentUseCase({required this.repository});

  Future<Either<Failure, void>> call({
    required int id,
    required int paymentMethodId,
    double? monto,
  }) =>
      repository.editInstallmentPayment(id: id, paymentMethodId: paymentMethodId, monto: monto);
}

class EditSellerPaymentUseCase {
  final SellerPaymentRepository repository;
  EditSellerPaymentUseCase({required this.repository});

  Future<Either<Failure, void>> call({required int id, required int paymentMethodId}) =>
      repository.editPayment(id: id, paymentMethodId: paymentMethodId);
}

class DeleteSellerPaymentUseCase {
  final SellerPaymentRepository repository;
  DeleteSellerPaymentUseCase({required this.repository});

  Future<Either<Failure, void>> call({required int id, required bool afterConfirm}) =>
      repository.deletePayment(id: id, afterConfirm: afterConfirm);
}

class GetSellerPaymentNotesUseCase {
  final SellerPaymentRepository repository;
  GetSellerPaymentNotesUseCase({required this.repository});

  Future<Either<Failure, SellerPaymentNotes>> call({required int paymentId}) =>
      repository.getNotes(paymentId: paymentId);
}

class AddSellerPaymentNoteUseCase {
  final SellerPaymentRepository repository;
  AddSellerPaymentNoteUseCase({required this.repository});

  Future<Either<Failure, SellerPaymentNote>> call({required int paymentId, required String texto}) =>
      repository.addNote(paymentId: paymentId, texto: texto);
}

class DeleteSellerPaymentNoteUseCase {
  final SellerPaymentRepository repository;
  DeleteSellerPaymentNoteUseCase({required this.repository});

  Future<Either<Failure, SellerPaymentNote>> call({required int noteId}) =>
      repository.deleteNote(noteId: noteId);
}
