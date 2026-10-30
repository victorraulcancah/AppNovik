import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// Data Layer
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/client_remote_datasource.dart';
import 'data/datasources/document_remote_datasource.dart';
import 'data/datasources/product_remote_datasource.dart';
import 'data/datasources/report_remote_datasource.dart';
import 'data/datasources/sale_remote_datasource.dart';
import 'data/datasources/stock_remote_datasource.dart';
import 'data/datasources/theme_local_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/client_repository_impl.dart';
import 'data/repositories/document_repository_impl.dart';
import 'data/repositories/product_repository_impl.dart';
import 'data/repositories/report_repository_impl.dart';
import 'data/repositories/sale_repository_impl.dart';
import 'data/repositories/stock_repository_impl.dart';

// Domain Layer
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/client_repository.dart';
import 'domain/repositories/document_repository.dart';
import 'domain/repositories/product_repository.dart';
import 'domain/repositories/report_repository.dart';
import 'domain/repositories/sale_repository.dart';
import 'domain/repositories/stock_repository.dart';
import 'domain/usecases/auth_usecases.dart';
import 'domain/usecases/client_usecases.dart';
import 'domain/usecases/document_usecases.dart';
import 'domain/usecases/product_usecases.dart';
import 'domain/usecases/report_usecases.dart';
import 'domain/usecases/sale_usecases.dart';
import 'domain/usecases/stock_usecases.dart';

// Presentation Layer
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/clients_provider.dart';
import 'presentation/providers/documents_provider.dart';
import 'presentation/providers/products_provider.dart';
import 'presentation/providers/reports_provider.dart';
import 'presentation/providers/sales_provider.dart';
import 'presentation/providers/stock_provider.dart';
import 'presentation/providers/theme_provider.dart';

class DependencyInjection {
  static final http.Client _httpClient = http.Client();

  static List<SingleChildWidget> get providers => [
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            loginUseCase: LoginUseCase(repository: _authRepository),
            logoutUseCase: LogoutUseCase(repository: _authRepository),
            getSessionContextUseCase:
                GetSessionContextUseCase(repository: _authRepository),
            getSavedCredentialsUseCase:
                GetSavedCredentialsUseCase(repository: _authRepository),
            saveCredentialsUseCase:
                SaveCredentialsUseCase(repository: _authRepository),
            clearSavedCredentialsUseCase:
                ClearSavedCredentialsUseCase(repository: _authRepository),
          ),
        ),

        ChangeNotifierProvider<ThemeProvider>(
          create: (context) =>
              ThemeProvider(storage: ThemeLocalDataSourceImpl())..load(),
        ),

        // Depende de la sesión: al cambiar de empresa descarta sus datos.
        ChangeNotifierProxyProvider<AuthProvider, ProductsProvider>(
          create: (context) => ProductsProvider(
            getProductsUseCase: GetProductsUseCase(repository: _productRepository),
            getCatalogsUseCase:
                GetProductCatalogsUseCase(repository: _productRepository),
            saveProductUseCase: SaveProductUseCase(repository: _productRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) =>
              previous!..syncCompany(auth.session?.company.id),
        ),

        ChangeNotifierProxyProvider<AuthProvider, DocumentsProvider>(
          create: (context) => DocumentsProvider(
            getDocumentsUseCase: GetDocumentsUseCase(repository: _documentRepository),
            exportDocumentsUseCase: ExportDocumentsUseCase(repository: _documentRepository),
            getFilterCatalogsUseCase:
                GetDocumentFilterCatalogsUseCase(repository: _documentRepository),
            deleteDocumentUseCase: DeleteDocumentUseCase(repository: _documentRepository),
            createCreditNoteUseCase: CreateCreditNoteUseCase(repository: _documentRepository),
            downloadCdrUseCase: DownloadCdrUseCase(repository: _documentRepository),
            getCompanyLogoUseCase: GetCompanyLogoUseCase(repository: _documentRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
        ),

        ChangeNotifierProxyProvider<AuthProvider, ReportsProvider>(
          create: (context) => ReportsProvider(
            getExecutiveSummaryUseCase:
                GetExecutiveSummaryUseCase(repository: _reportRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) =>
              previous!..syncCompany(auth.session?.company.id),
        ),

        ChangeNotifierProxyProvider<AuthProvider, SalesProvider>(
          create: (context) => SalesProvider(
            getWarehousesUseCase: GetWarehousesUseCase(repository: _stockRepository),
            getPriceListsUseCase: GetPriceListsUseCase(repository: _stockRepository),
            getPaymentMethodsUseCase: GetPaymentMethodsUseCase(repository: _saleRepository),
            getSaleProductFiltersUseCase:
                GetSaleProductFiltersUseCase(repository: _saleRepository),
            getExchangeRateUseCase: GetExchangeRateUseCase(repository: _saleRepository),
            getWalkInClientUseCase: GetWalkInClientUseCase(repository: _saleRepository),
            searchClientsUseCase: SearchClientsUseCase(repository: _saleRepository),
            searchSaleProductsUseCase: SearchSaleProductsUseCase(repository: _saleRepository),
            createSaleUseCase: CreateSaleUseCase(repository: _saleRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
        ),

        ChangeNotifierProxyProvider<AuthProvider, ClientsProvider>(
          create: (context) => ClientsProvider(
            getDepartmentsUseCase: GetDepartmentsUseCase(repository: _clientRepository),
            getProvincesUseCase: GetProvincesUseCase(repository: _clientRepository),
            getDistrictsUseCase: GetDistrictsUseCase(repository: _clientRepository),
            lookupDocumentUseCase: LookupDocumentUseCase(repository: _clientRepository),
            createClientUseCase: CreateClientUseCase(repository: _clientRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
        ),

        ChangeNotifierProxyProvider<AuthProvider, StockProvider>(
          create: (context) => StockProvider(
            getWarehousesUseCase: GetWarehousesUseCase(repository: _stockRepository),
            getPriceListsUseCase: GetPriceListsUseCase(repository: _stockRepository),
            getStockUseCase: GetStockUseCase(repository: _stockRepository),
            exportStockUseCase: ExportStockUseCase(repository: _stockRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!
            ..syncSession(
              auth.session?.company.id,
              defaultWarehouseId: auth.session?.defaultWarehouseId,
              defaultPriceListId: auth.session?.defaultListPriceId,
            ),
        ),
      ];

  // Repositories
  static AuthRepository get _authRepository => AuthRepositoryImpl(
        remoteDataSource: _authRemoteDataSource,
        localDataSource: _authLocalDataSource,
      );

  static DocumentRepository get _documentRepository => DocumentRepositoryImpl(
        remoteDataSource: DocumentRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static ClientRepository get _clientRepository => ClientRepositoryImpl(
        remoteDataSource: ClientRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static ReportRepository get _reportRepository => ReportRepositoryImpl(
        remoteDataSource: ReportRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static SaleRepository get _saleRepository => SaleRepositoryImpl(
        remoteDataSource: SaleRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static StockRepository get _stockRepository => StockRepositoryImpl(
        remoteDataSource: StockRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static ProductRepository get _productRepository => ProductRepositoryImpl(
        remoteDataSource: ProductRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  // DataSources
  static AuthRemoteDataSource get _authRemoteDataSource =>
      AuthRemoteDataSourceImpl(client: _httpClient);

  static AuthLocalDataSource get _authLocalDataSource =>
      AuthLocalDataSourceImpl();
}
