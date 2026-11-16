import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/debt_entity.dart';

/// El módulo Deudas: el resumen de deuda pendiente por cliente, sus filtros y el Excel.
abstract class DebtRepository {
  Future<Either<Failure, DebtPageEntity>> getDebts({
    required int page,
    required int pageSize,
    required DebtFiltersEntity filters,
  });

  /// Busca clientes para el filtro. Con [onlyMine] solo los de la cartera del usuario (como la
  /// web cuando el usuario no ve a todos los vendedores).
  Future<Either<Failure, List<DebtOption>>> searchClients({
    required int companyId,
    required String search,
    required bool onlyMine,
  });

  /// Ejecutivos comerciales (usuarios con rol Vendedor) para el filtro.
  Future<Either<Failure, List<DebtOption>>> getSellers({required int companyId});

  /// Excel con lo que se está viendo (mismos filtros de cliente y ejecutivo).
  Future<Either<Failure, Uint8List>> exportDebts({required DebtFiltersEntity filters});
}
