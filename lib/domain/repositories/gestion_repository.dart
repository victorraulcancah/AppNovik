import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/gestion_entity.dart';

/// El módulo Gestión: seguimiento de clientes (tareas pendientes, ficha del cliente y sus gestiones).
abstract class GestionRepository {
  /// Los resultados que se pueden elegir al registrar una gestión, con su guía "cuándo elegirlo".
  Future<Either<Failure, GestionCatalogo>> getCatalogo();

  /// Busca clientes por nombre, documento o código (también los dados de baja; el Vendedor solo
  /// encuentra los de su cartera).
  Future<Either<Failure, List<GestionClienteBuscado>>> buscarClientes(String query);

  /// Las gestiones programadas sin hacer, desde las vencidas hasta fin de mes.
  Future<Either<Failure, GestionTareas>> getTareas();

  Future<Either<Failure, GestionFicha>> getFicha(int clienteId);

  Future<Either<Failure, GestionHistorial>> getGestiones(int clienteId);

  Future<Either<Failure, void>> registrar(int clienteId, GestionNueva gestion);

  Future<Either<Failure, void>> editar(int gestionId, GestionEdicion gestion);

  Future<Either<Failure, void>> reprogramar(int gestionId, DateTime proximo);
}
