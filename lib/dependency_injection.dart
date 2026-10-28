import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// Data Layer
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/product_remote_datasource.dart';
import 'data/datasources/theme_local_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/product_repository_impl.dart';

// Domain Layer
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/product_repository.dart';
import 'domain/usecases/auth_usecases.dart';
import 'domain/usecases/product_usecases.dart';

// Presentation Layer
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/products_provider.dart';
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
            onSessionExpired: () => context.read<AuthProvider>().checkAuthStatus(),
          ),
          update: (context, auth, previous) =>
              previous!..syncCompany(auth.session?.company.id),
        ),
      ];

  // Repositories
  static AuthRepository get _authRepository => AuthRepositoryImpl(
        remoteDataSource: _authRemoteDataSource,
        localDataSource: _authLocalDataSource,
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
