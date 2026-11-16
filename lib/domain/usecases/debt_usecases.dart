import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/debt_entity.dart';
import '../repositories/debt_repository.dart';

class GetDebtsUseCase {
  final DebtRepository repository;
  GetDebtsUseCase({required this.repository});

  Future<Either<Failure, DebtPageEntity>> call({
    required int page,
    required int pageSize,
    required DebtFiltersEntity filters,
  }) =>
      repository.getDebts(page: page, pageSize: pageSize, filters: filters);
}

class SearchDebtClientsUseCase {
  final DebtRepository repository;
  SearchDebtClientsUseCase({required this.repository});

  Future<Either<Failure, List<DebtOption>>> call({
    required int companyId,
    required String search,
    required bool onlyMine,
  }) =>
      repository.searchClients(companyId: companyId, search: search, onlyMine: onlyMine);
}

class GetDebtSellersUseCase {
  final DebtRepository repository;
  GetDebtSellersUseCase({required this.repository});

  Future<Either<Failure, List<DebtOption>>> call({required int companyId}) =>
      repository.getSellers(companyId: companyId);
}

class ExportDebtsUseCase {
  final DebtRepository repository;
  ExportDebtsUseCase({required this.repository});

  Future<Either<Failure, Uint8List>> call({required DebtFiltersEntity filters}) =>
      repository.exportDebts(filters: filters);
}
