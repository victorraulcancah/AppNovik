import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart';
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

  /// La pestaña Compras. [anio] elige de qué año son las últimas compras y los top 10 (el actual o el
  /// anterior); sin él, el actual.
  Future<Either<Failure, GestionCompras>> getCompras(int clienteId, {int? anio});

  /// La pestaña Documentos: cotizaciones y ventas del cliente entre dos fechas.
  Future<Either<Failure, List<GestionDocumento>>> getDocumentos(int clienteId, {required DateTime desde, required DateTime hasta});

  /// Una venta completa, para abrir su comprobante.
  Future<Either<Failure, DocumentEntity>> getVenta(int id);

  /// Una cotización completa, para abrir su comprobante. El backend no tiene `GET /cotizaciones/{id}`: se busca
  /// por su número en la lista de la empresa (como la web) y se toma la que tiene este [id].
  Future<Either<Failure, DocumentEntity>> getCotizacion({required int companyId, required int id, required int nroDocumento});
}
