import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// Data Layer
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';

// Domain Layer
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/auth_usecases.dart';

// Presentation Layer
import 'presentation/providers/auth_provider.dart';

class DependencyInjection {
  static final http.Client _httpClient = http.Client();

  static List<ChangeNotifierProvider> get providers => [
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
      ];

  // Repositories
  static AuthRepository get _authRepository => AuthRepositoryImpl(
        remoteDataSource: _authRemoteDataSource,
        localDataSource: _authLocalDataSource,
      );

  // DataSources
  static AuthRemoteDataSource get _authRemoteDataSource =>
      AuthRemoteDataSourceImpl(client: _httpClient);

  static AuthLocalDataSource get _authLocalDataSource =>
      AuthLocalDataSourceImpl();
}
