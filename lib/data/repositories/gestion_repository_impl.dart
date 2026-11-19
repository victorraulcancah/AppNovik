import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/gestion_entity.dart';
import '../../domain/repositories/gestion_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/gestion_remote_datasource.dart';
import 'token_guard.dart';

class GestionRepositoryImpl with TokenGuard implements GestionRepository {
  final GestionRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  GestionRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, GestionCatalogo>> getCatalogo() => withToken(remoteDataSource.getCatalogo);

  @override
  Future<Either<Failure, List<GestionClienteBuscado>>> buscarClientes(String query) =>
      withToken((token) => remoteDataSource.buscarClientes(token, query));

  @override
  Future<Either<Failure, GestionTareas>> getTareas() => withToken(remoteDataSource.getTareas);

  @override
  Future<Either<Failure, GestionFicha>> getFicha(int clienteId) =>
      withToken((token) => remoteDataSource.getFicha(token, clienteId));

  @override
  Future<Either<Failure, GestionHistorial>> getGestiones(int clienteId) =>
      withToken((token) => remoteDataSource.getGestiones(token, clienteId));

  @override
  Future<Either<Failure, void>> registrar(int clienteId, GestionNueva gestion) =>
      withToken((token) => remoteDataSource.registrar(token, clienteId, gestion));

  @override
  Future<Either<Failure, void>> editar(int gestionId, GestionEdicion gestion) =>
      withToken((token) => remoteDataSource.editar(token, gestionId, gestion));

  @override
  Future<Either<Failure, void>> reprogramar(int gestionId, DateTime proximo) =>
      withToken((token) => remoteDataSource.reprogramar(token, gestionId, proximo));
}
