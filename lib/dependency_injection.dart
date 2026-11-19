import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// Data Layer
import 'data/datasources/account_statement_remote_datasource.dart';
import 'data/repositories/account_statement_repository_impl.dart';
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/client_record_remote_datasource.dart';
import 'data/datasources/client_remote_datasource.dart';
import 'data/datasources/account_remote_datasource.dart';
import 'data/datasources/debt_remote_datasource.dart';
import 'data/datasources/price_list_remote_datasource.dart';
import 'data/datasources/seller_payment_remote_datasource.dart';
import 'data/datasources/user_record_remote_datasource.dart';
import 'data/datasources/document_remote_datasource.dart';
import 'data/datasources/guide_remote_datasource.dart';
import 'data/datasources/inicio_cache_datasource.dart';
import 'data/datasources/inicio_remote_datasource.dart';
import 'data/datasources/other_document_remote_datasource.dart';
import 'data/datasources/product_remote_datasource.dart';
import 'data/datasources/report_remote_datasource.dart';
import 'data/datasources/sale_remote_datasource.dart';
import 'data/datasources/stock_remote_datasource.dart';
import 'data/datasources/theme_local_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/client_record_repository_impl.dart';
import 'data/repositories/client_repository_impl.dart';
import 'data/repositories/account_repository_impl.dart';
import 'data/repositories/debt_repository_impl.dart';
import 'data/repositories/price_list_repository_impl.dart';
import 'data/repositories/seller_payment_repository_impl.dart';
import 'data/repositories/user_record_repository_impl.dart';
import 'data/repositories/document_repository_impl.dart';
import 'data/repositories/guide_repository_impl.dart';
import 'data/repositories/inicio_repository_impl.dart';
import 'data/repositories/other_document_repository_impl.dart';
import 'data/repositories/product_repository_impl.dart';
import 'data/repositories/report_repository_impl.dart';
import 'data/repositories/sale_repository_impl.dart';
import 'data/repositories/stock_repository_impl.dart';

// Domain Layer
import 'domain/repositories/account_statement_repository.dart';
import 'domain/usecases/account_statement_usecases.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/client_record_repository.dart';
import 'domain/repositories/client_repository.dart';
import 'domain/repositories/account_repository.dart';
import 'domain/repositories/debt_repository.dart';
import 'domain/repositories/price_list_repository.dart';
import 'domain/repositories/seller_payment_repository.dart';
import 'domain/repositories/user_record_repository.dart';
import 'domain/repositories/document_repository.dart';
import 'domain/repositories/guide_repository.dart';
import 'domain/repositories/inicio_repository.dart';
import 'domain/repositories/other_document_repository.dart';
import 'domain/repositories/product_repository.dart';
import 'domain/repositories/report_repository.dart';
import 'domain/repositories/sale_repository.dart';
import 'domain/repositories/stock_management_repository.dart';
import 'domain/repositories/stock_repository.dart';
import 'domain/usecases/auth_usecases.dart';
import 'domain/usecases/client_record_usecases.dart';
import 'domain/usecases/client_usecases.dart';
import 'domain/usecases/account_usecases.dart';
import 'domain/usecases/debt_usecases.dart';
import 'domain/usecases/price_list_usecases.dart';
import 'domain/usecases/seller_payment_usecases.dart';
import 'domain/usecases/user_record_usecases.dart';
import 'domain/usecases/document_usecases.dart';
import 'domain/usecases/guide_usecases.dart';
import 'domain/usecases/inicio_cache_usecases.dart';
import 'domain/usecases/inicio_usecases.dart';
import 'domain/usecases/other_document_usecases.dart';
import 'domain/usecases/product_usecases.dart';
import 'domain/usecases/report_usecases.dart';
import 'domain/usecases/sale_usecases.dart';
import 'domain/usecases/stock_manage_usecases.dart';
import 'domain/usecases/stock_usecases.dart';

// Presentation Layer
import 'presentation/providers/account_statement_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/other_documents_provider.dart';
import 'presentation/providers/client_list_provider.dart';
import 'presentation/providers/clients_provider.dart';
import 'presentation/providers/debts_provider.dart';
import 'presentation/providers/price_lists_provider.dart';
import 'presentation/providers/seller_payments_provider.dart';
import 'presentation/providers/users_provider.dart';
import 'presentation/providers/guide_provider.dart';
import 'presentation/providers/inicio_provider.dart';
import 'presentation/providers/documents_provider.dart';
import 'presentation/providers/products_provider.dart';
import 'presentation/providers/reports_provider.dart';
import 'presentation/providers/sales_provider.dart';
import 'presentation/providers/shell_navigation.dart';
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

        // Cambiar la propia contraseña (menú de la cuenta).
        Provider<ChangePasswordUseCase>(
          create: (_) => ChangePasswordUseCase(repository: _accountRepository),
        ),

        ChangeNotifierProvider<ShellNavigation>(create: (_) => ShellNavigation()),

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
            exportProductsUseCase: ExportProductsUseCase(repository: _productRepository),
            importCatalogUseCase: ImportCatalogUseCase(repository: _productRepository),
            createCatalogItemUseCase: CreateCatalogItemUseCase(repository: _productRepository),
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

        ChangeNotifierProxyProvider<AuthProvider, OtherDocumentsProvider>(
          create: (context) => OtherDocumentsProvider(
            getDocumentsUseCase: GetOtherDocumentsUseCase(repository: _otherDocumentRepository),
            deleteTransferUseCase: DeleteTransferUseCase(repository: _otherDocumentRepository),
            receiveTransferProductUseCase: ReceiveTransferProductUseCase(repository: _otherDocumentRepository),
            confirmTransferProductUseCase: ConfirmTransferProductUseCase(repository: _otherDocumentRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) =>
              previous!..syncCompany(auth.session?.company.id),
        ),

        // `lazy: false`: tiene que existir desde el login para adelantar sus datos (ver `prefetch`); si
        // se creara al abrir Inicio, ya sería tarde.
        ChangeNotifierProxyProvider<AuthProvider, InicioProvider>(
          lazy: false,
          create: (context) => InicioProvider(
            getWarehouseSalesUseCase: GetWarehouseSalesUseCase(repository: _inicioRepository),
            getExecutiveSummaryUseCase: GetExecutiveSummaryUseCase(repository: _inicioRepository),
            getTeamSummaryUseCase: GetTeamSummaryUseCase(repository: _inicioRepository),
            getCeoSummaryUseCase: GetCeoSummaryUseCase(repository: _inicioRepository),
            getCachedInicioUseCase: GetCachedInicioUseCase(repository: _inicioRepo),
            clearInicioCacheUseCase: ClearInicioCacheUseCase(repository: _inicioRepo),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          // Con los roles que dio el login, Inicio empieza a pedir sus datos sin esperar a `/auth`.
          update: (context, auth, previous) => previous!
            ..syncSession(auth.session)
            ..prefetch(auth.pendingUser),
        ),

        // El módulo Estado de cuenta (cabecera, movimientos, pedidos y pagos de un cliente).
        ChangeNotifierProxyProvider<AuthProvider, AccountStatementProvider>(
          create: (context) => AccountStatementProvider(
            searchClientsUseCase: SearchStatementClientsUseCase(repository: _accountStatementRepository),
            getStatementUseCase: GetStatementUseCase(repository: _accountStatementRepository),
            getOrdersUseCase: GetStatementOrdersUseCase(repository: _accountStatementRepository),
            getPaymentsUseCase: GetStatementPaymentsUseCase(repository: _accountStatementRepository),
            exportExcelUseCase: ExportStatementExcelUseCase(repository: _accountStatementRepository),
            exportPdfUseCase: ExportStatementPdfUseCase(repository: _accountStatementRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
        ),

        ChangeNotifierProxyProvider<AuthProvider, ReportsProvider>(
          create: (context) => ReportsProvider(
            getSalesReportUseCase: GetSalesReportUseCase(repository: _reportRepository),
            exportSalesReportUseCase: ExportSalesReportUseCase(repository: _reportRepository),
            getCatalogsUseCase: GetReportCatalogsUseCase(repository: _reportRepository),
            getSaleUseCase: GetReportSaleUseCase(repository: _reportRepository),
            getRankingUseCase: GetRankingReportUseCase(repository: _reportRepository),
            searchProductCodesUseCase: SearchReportProductCodesUseCase(repository: _reportRepository),
            getRankingProductsUseCase: GetRankingProductsUseCase(repository: _reportRepository),
            getRankingProductDocumentsUseCase: GetRankingProductDocumentsUseCase(repository: _reportRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
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
            // Una venta o cotización nueva: Documentos la trae al entrar, sin tener que refrescar a mano.
            onDocumentsChanged: () => context.read<DocumentsProvider>().markStale(),
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

        // El módulo Clientes (lista, formulario completo y categorías). Ventas usa `ClientsProvider`.
        ChangeNotifierProxyProvider<AuthProvider, ClientListProvider>(
          create: (context) => ClientListProvider(
            getClientsUseCase: GetClientsUseCase(repository: _clientRecordRepository),
            getFilterCatalogsUseCase: GetClientFilterCatalogsUseCase(repository: _clientRecordRepository),
            getFormCatalogsUseCase: GetClientFormCatalogsUseCase(repository: _clientRecordRepository),
            saveClientUseCase: SaveClientUseCase(repository: _clientRecordRepository),
            exportClientsUseCase: ExportClientsUseCase(repository: _clientRecordRepository),
            getCategoriesUseCase: GetClientCategoriesUseCase(repository: _clientRecordRepository),
            saveCategoriesUseCase: SaveClientCategoriesUseCase(repository: _clientRecordRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
        ),

        // El módulo Deudas (resumen de deuda pendiente por cliente).
        ChangeNotifierProxyProvider<AuthProvider, DebtsProvider>(
          create: (context) => DebtsProvider(
            getDebtsUseCase: GetDebtsUseCase(repository: _debtRepository),
            searchClientsUseCase: SearchDebtClientsUseCase(repository: _debtRepository),
            getSellersUseCase: GetDebtSellersUseCase(repository: _debtRepository),
            exportDebtsUseCase: ExportDebtsUseCase(repository: _debtRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
        ),

        // El módulo Pagos vendedores (Registro de Pagos de la web).
        ChangeNotifierProxyProvider<AuthProvider, SellerPaymentsProvider>(
          create: (context) => SellerPaymentsProvider(
            getPaymentsUseCase: GetSellerPaymentsUseCase(repository: _sellerPaymentRepository),
            exportPaymentsUseCase: ExportSellerPaymentsUseCase(repository: _sellerPaymentRepository),
            getMethodsUseCase: GetSellerPaymentMethodsUseCase(repository: _sellerPaymentRepository),
            getClientsUseCase: GetSellerPaymentClientsUseCase(repository: _sellerPaymentRepository),
            getSellersUseCase: GetSellerPaymentSellersUseCase(repository: _sellerPaymentRepository),
            getClientDebtUseCase: GetSellerClientDebtUseCase(repository: _sellerPaymentRepository),
            createUseCase: CreateSellerPaymentUseCase(repository: _sellerPaymentRepository),
            approveUseCase: ApproveSellerPaymentUseCase(repository: _sellerPaymentRepository),
            editInstallmentUseCase: EditSellerInstallmentPaymentUseCase(repository: _sellerPaymentRepository),
            editUseCase: EditSellerPaymentUseCase(repository: _sellerPaymentRepository),
            deleteUseCase: DeleteSellerPaymentUseCase(repository: _sellerPaymentRepository),
            getNotesUseCase: GetSellerPaymentNotesUseCase(repository: _sellerPaymentRepository),
            addNoteUseCase: AddSellerPaymentNoteUseCase(repository: _sellerPaymentRepository),
            deleteNoteUseCase: DeleteSellerPaymentNoteUseCase(repository: _sellerPaymentRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
        ),

        // El módulo Usuarios (lista, formulario con foto y gestión de roles).
        ChangeNotifierProxyProvider<AuthProvider, UsersProvider>(
          create: (context) => UsersProvider(
            getUsersUseCase: GetUsersUseCase(repository: _userRecordRepository),
            getCatalogsUseCase: GetUserCatalogsUseCase(repository: _userRecordRepository),
            saveUserUseCase: SaveUserUseCase(repository: _userRecordRepository),
            uploadPhotoUseCase: UploadUserPhotoUseCase(repository: _userRecordRepository),
            getPhotoUseCase: GetUserPhotoUseCase(repository: _userRecordRepository),
            getRolesUseCase: GetRolesUseCase(repository: _userRecordRepository),
            saveRoleUseCase: SaveRoleUseCase(repository: _userRecordRepository),
            deleteRoleUseCase: DeleteRoleUseCase(repository: _userRecordRepository),
            getDepartmentsUseCase: GetUserDepartmentsUseCase(repository: _userRecordRepository),
            getProvincesUseCase: GetUserProvincesUseCase(repository: _userRecordRepository),
            getDistrictsUseCase: GetUserDistrictsUseCase(repository: _userRecordRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
        ),

        // El módulo Lista de precios.
        ChangeNotifierProxyProvider<AuthProvider, PriceListsProvider>(
          create: (context) => PriceListsProvider(
            getPriceListsUseCase: GetPriceListPageUseCase(repository: _priceListRepository),
            savePriceListUseCase: SavePriceListUseCase(repository: _priceListRepository),
            getProductsUseCase: GetPriceListProductsUseCase(repository: _priceListRepository),
            updatePriceUseCase: UpdatePriceListPriceUseCase(repository: _priceListRepository),
            exportTemplateUseCase: ExportPriceListTemplateUseCase(repository: _priceListRepository),
            importPricesUseCase: ImportPriceListUseCase(repository: _priceListRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncCompany(auth.session?.company.id),
        ),

        ChangeNotifierProxyProvider<AuthProvider, GuideProvider>(
          create: (context) => GuideProvider(
            getDefaultsUseCase: GetGuideDefaultsUseCase(repository: _guideRepository),
            findDriverUseCase: FindDriverUseCase(repository: _guideRepository),
            createGuideUseCase: CreateGuideUseCase(repository: _guideRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!..syncSession(auth.session),
        ),

        ChangeNotifierProxyProvider<AuthProvider, StockProvider>(
          create: (context) => StockProvider(
            getWarehousesUseCase: GetWarehousesUseCase(repository: _stockRepository),
            getPriceListsUseCase: GetPriceListsUseCase(repository: _stockRepository),
            getStockUseCase: GetStockUseCase(repository: _stockManagementRepository),
            exportStockUseCase: ExportStockUseCase(repository: _stockRepository),
            searchStockProductsUseCase:
                SearchStockProductsUseCase(repository: _stockManagementRepository),
            addStockUseCase: AddStockUseCase(repository: _stockManagementRepository),
            updateStockUseCase: UpdateStockUseCase(repository: _stockManagementRepository),
            downloadStockTemplateUseCase:
                DownloadStockTemplateUseCase(repository: _stockManagementRepository),
            importStockUseCase: ImportStockUseCase(repository: _stockManagementRepository),
            transferStockUseCase: TransferStockUseCase(repository: _stockManagementRepository),
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) => previous!
            ..syncSession(
              auth.session?.company.id,
              defaultWarehouseId: auth.session?.defaultWarehouseId,
              defaultPriceListId: auth.session?.defaultListPriceId,
              userId: auth.session?.user.id,
            ),
        ),
      ];

  // Repositories
  static AuthRepository get _authRepository => AuthRepositoryImpl(
        remoteDataSource: _authRemoteDataSource,
        localDataSource: _authLocalDataSource,
      );

  static AccountRepository get _accountRepository => AccountRepositoryImpl(
        remoteDataSource: AccountRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static DocumentRepository get _documentRepository => DocumentRepositoryImpl(
        remoteDataSource: DocumentRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static OtherDocumentRepository get _otherDocumentRepository => OtherDocumentRepositoryImpl(
        remoteDataSource: OtherDocumentRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static GuideRepository get _guideRepository => GuideRepositoryImpl(
        remoteDataSource: GuideRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static ClientRepository get _clientRepository => ClientRepositoryImpl(
        remoteDataSource: ClientRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  /// Una sola instancia (hace tanto de repositorio de datos como de caché del Inicio).
  static final InicioRepositoryImpl _inicioRepo = InicioRepositoryImpl(
        remoteDataSource: InicioRemoteDataSourceImpl(
          client: _httpClient,
          cache: InicioCacheDataSourceImpl(),
        ),
        authLocalDataSource: _authLocalDataSource,
      );

  static InicioRepository get _inicioRepository => _inicioRepo;

  static DebtRepository get _debtRepository => DebtRepositoryImpl(
        remoteDataSource: DebtRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static PriceListRepository get _priceListRepository => PriceListRepositoryImpl(
        remoteDataSource: PriceListRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static SellerPaymentRepository get _sellerPaymentRepository => SellerPaymentRepositoryImpl(
        remoteDataSource: SellerPaymentRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static UserRecordRepository get _userRecordRepository => UserRecordRepositoryImpl(
        remoteDataSource: UserRecordRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static AccountStatementRepository get _accountStatementRepository => AccountStatementRepositoryImpl(
        remoteDataSource: AccountStatementRemoteDataSourceImpl(client: _httpClient),
        authLocalDataSource: _authLocalDataSource,
      );

  static ClientRecordRepository get _clientRecordRepository => ClientRecordRepositoryImpl(
        remoteDataSource: ClientRecordRemoteDataSourceImpl(client: _httpClient),
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

  static StockRepository get _stockRepository => _stockManagementRepository;

  static StockManagementRepository get _stockManagementRepository => StockRepositoryImpl(
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

  /// Una sola instancia: guarda el token en memoria y todos los repositorios deben verlo igual.
  static final AuthLocalDataSource _authLocalDataSource = AuthLocalDataSourceImpl();
}
