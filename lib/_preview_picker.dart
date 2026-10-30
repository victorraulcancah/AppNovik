// TEMPORAL: vista previa del selector de productos. Se borra al terminar la revisión.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/errors/failures.dart';
import 'core/utils/either.dart';
import 'domain/entities/company_entity.dart';
import 'domain/entities/document_entity.dart';
import 'domain/entities/product_form_entity.dart';
import 'domain/entities/sale_entity.dart';
import 'domain/entities/session_context_entity.dart';
import 'domain/entities/stock_entity.dart';
import 'domain/entities/user_entity.dart';
import 'domain/repositories/sale_repository.dart';
import 'domain/repositories/stock_repository.dart';
import 'domain/usecases/sale_usecases.dart';
import 'domain/usecases/stock_usecases.dart';
import 'presentation/providers/sales_provider.dart';
import 'presentation/widgets/sale_product_picker.dart';
import 'theme/app_theme.dart';

void main() => runApp(const _Preview());

class _Stock implements StockRepository {
  @override
  Future<Either<Failure, List<CatalogItemEntity>>> getWarehouses(int c) async =>
      Either.right(const [CatalogItemEntity(id: 1, name: 'PRINCIPAL')]);
  @override
  Future<Either<Failure, List<PriceListEntity>>> getPriceLists(int c) async =>
      Either.right(const [PriceListEntity(id: 10, name: 'MINORISTA')]);
  @override
  Future<Either<Failure, StockPageEntity>> getStock({
    required int companyId,
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    bool includeZero = false,
    int page = 1,
    int pageSize = 20,
  }) =>
      throw UnimplementedError();
}

SaleProductEntity _p(int id, String name, String code, String brand, int cat, double stock, double price,
        {String unit = 'Unidad'}) =>
    SaleProductEntity(
      id: id,
      codigo: code,
      name: name,
      marca: brand,
      categoryId: cat,
      brandId: id,
      unidad: unit,
      stockPorAlmacen: {1: stock},
      precioPorLista: {10: price},
    );

class _Sales implements SaleRepository {
  @override
  Future<Either<Failure, SaleProductFiltersEntity>> getProductFilters() async =>
      Either.right(const SaleProductFiltersEntity(
        categorias: [(id: 1, name: 'Abarrotes'), (id: 2, name: 'Audio')],
        marcas: [(id: 1, name: 'Cartavio'), (id: 2, name: 'Faraon')],
      ));
  @override
  Future<Either<Failure, List<SaleProductEntity>>> searchProducts({
    required int companyId,
    required String search,
  }) async =>
      Either.right([
        _p(1, 'Azúcar Rubia Cartavio con un nombre largo', 'PROD014', 'Cartavio', 1, 190, 3.8, unit: 'Kilogramo'),
        _p(2, 'Arroz Faraón naranja', 'PROD013', 'Faraón', 1, 1, 4.5, unit: 'Kilogramo'),
        _p(3, 'Radio Bluetooth 1 DIN', 'RAD-DEH', 'Pioneer', 2, 0, 299),
      ]);
  @override
  Future<Either<Failure, List<ClientEntity>>> searchClients({required int companyId, required String search}) async =>
      Either.right(const []);
  @override
  Future<Either<Failure, List<PaymentMethodEntity>>> getPaymentMethods() async =>
      Either.right(const [PaymentMethodEntity(id: 1, name: 'EFECTIVO')]);
  @override
  Future<Either<Failure, SaleResultEntity>> createSale({
    required int companyId,
    required int userId,
    required SaleFormEntity form,
  }) =>
      throw UnimplementedError();
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final stock = _Stock();
    final sales = _Sales();
    final provider = SalesProvider(
      getWarehousesUseCase: GetWarehousesUseCase(repository: stock),
      getPriceListsUseCase: GetPriceListsUseCase(repository: stock),
      getPaymentMethodsUseCase: GetPaymentMethodsUseCase(repository: sales),
      getSaleProductFiltersUseCase: GetSaleProductFiltersUseCase(repository: sales),
      searchClientsUseCase: SearchClientsUseCase(repository: sales),
      searchSaleProductsUseCase: SearchSaleProductsUseCase(repository: sales),
      createSaleUseCase: CreateSaleUseCase(repository: sales),
    )..syncSession(SessionContextEntity(
        user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
        company: const CompanyEntity(id: 1, razonSocial: 'ACME'),
        modules: const [],
        permissions: const {'ventas.store'},
        roles: const [],
        warehouses: const [],
      ));
    provider.ensureLoaded();

    return ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showSaleProductPicker(context),
                child: const Text('Abrir selector'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
