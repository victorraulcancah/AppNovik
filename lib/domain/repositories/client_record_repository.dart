import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/client_record_entity.dart';

/// El módulo Clientes: lista con filtros, formulario completo, categorías y Excel.
abstract class ClientRecordRepository {
  Future<Either<Failure, ClientPageEntity>> getClients({
    required int companyId,
    required int page,
    required int pageSize,
    required ClientFiltersEntity filters,
  });

  Future<Either<Failure, ClientFilterCatalogsEntity>> getFilterCatalogs();

  /// Ejecutivos (Vendedor o Ceo), listas de precios, métodos de pago y categorías del formulario.
  Future<Either<Failure, ClientFormCatalogsEntity>> getFormCatalogs({required int companyId});

  /// Crea el cliente, o lo edita si se pasa [id]. Devuelve el cliente guardado.
  Future<Either<Failure, ClientRecordEntity>> saveClient({
    required int companyId,
    required ClientFormEntity form,
    int? id,
  });

  /// Excel con lo que se está viendo (mismos filtros que la lista).
  Future<Either<Failure, Uint8List>> exportClients({
    required int companyId,
    required ClientFiltersEntity filters,
  });

  Future<Either<Failure, CategoriesConfigEntity>> getCategories();

  /// Guarda nombres y rangos de cada categoría y el ciclo activo. Devuelve el recálculo si el
  /// cambio de ciclo lo disparó.
  Future<Either<Failure, CategoryCalcEntity?>> saveCategories({
    required List<ClientCategoryEntity> categorias,
    required String ciclo,
  });

  /// Guarda el ciclo y recalcula la categoría de cada cliente con lo comprado en el último ciclo cerrado.
  Future<Either<Failure, CategoryCalcEntity>> calculateCategories({required String ciclo});
}
