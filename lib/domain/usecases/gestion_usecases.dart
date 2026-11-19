import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart';
import '../entities/gestion_entity.dart';
import '../repositories/gestion_repository.dart';

class GetGestionCatalogoUseCase {
  final GestionRepository repository;
  GetGestionCatalogoUseCase({required this.repository});

  Future<Either<Failure, GestionCatalogo>> call() => repository.getCatalogo();
}

class SearchGestionClientesUseCase {
  final GestionRepository repository;
  SearchGestionClientesUseCase({required this.repository});

  Future<Either<Failure, List<GestionClienteBuscado>>> call(String query) =>
      repository.buscarClientes(query);
}

class GetGestionTareasUseCase {
  final GestionRepository repository;
  GetGestionTareasUseCase({required this.repository});

  Future<Either<Failure, GestionTareas>> call() => repository.getTareas();
}

class GetGestionFichaUseCase {
  final GestionRepository repository;
  GetGestionFichaUseCase({required this.repository});

  Future<Either<Failure, GestionFicha>> call(int clienteId) => repository.getFicha(clienteId);
}

class GetGestionHistorialUseCase {
  final GestionRepository repository;
  GetGestionHistorialUseCase({required this.repository});

  Future<Either<Failure, GestionHistorial>> call(int clienteId) => repository.getGestiones(clienteId);
}

class RegisterGestionUseCase {
  final GestionRepository repository;
  RegisterGestionUseCase({required this.repository});

  Future<Either<Failure, void>> call(int clienteId, GestionNueva gestion) =>
      repository.registrar(clienteId, gestion);
}

class EditGestionUseCase {
  final GestionRepository repository;
  EditGestionUseCase({required this.repository});

  Future<Either<Failure, void>> call(int gestionId, GestionEdicion gestion) =>
      repository.editar(gestionId, gestion);
}

class RescheduleGestionUseCase {
  final GestionRepository repository;
  RescheduleGestionUseCase({required this.repository});

  Future<Either<Failure, void>> call(int gestionId, DateTime proximo) =>
      repository.reprogramar(gestionId, proximo);
}

class GetGestionComprasUseCase {
  final GestionRepository repository;
  GetGestionComprasUseCase({required this.repository});

  Future<Either<Failure, GestionCompras>> call(int clienteId, {int? anio}) =>
      repository.getCompras(clienteId, anio: anio);
}

class GetGestionDocumentosUseCase {
  final GestionRepository repository;
  GetGestionDocumentosUseCase({required this.repository});

  Future<Either<Failure, List<GestionDocumento>>> call(int clienteId, {required DateTime desde, required DateTime hasta}) =>
      repository.getDocumentos(clienteId, desde: desde, hasta: hasta);
}

class GetGestionVentaUseCase {
  final GestionRepository repository;
  GetGestionVentaUseCase({required this.repository});

  Future<Either<Failure, DocumentEntity>> call(int id) => repository.getVenta(id);
}

class GetGestionCotizacionUseCase {
  final GestionRepository repository;
  GetGestionCotizacionUseCase({required this.repository});

  Future<Either<Failure, DocumentEntity>> call({required int companyId, required int id, required int nroDocumento}) =>
      repository.getCotizacion(companyId: companyId, id: id, nroDocumento: nroDocumento);
}
