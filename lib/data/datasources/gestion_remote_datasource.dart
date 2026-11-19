import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_request.dart';
import '../../core/network/connection_monitor.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/gestion_entity.dart';
import '../models/document_model.dart';
import '../models/gestion_model.dart';

abstract class GestionRemoteDataSource {
  Future<GestionCatalogo> getCatalogo(String token);

  Future<List<GestionClienteBuscado>> buscarClientes(String token, String query);

  Future<GestionTareas> getTareas(String token);

  Future<GestionFicha> getFicha(String token, int clienteId);

  Future<GestionHistorial> getGestiones(String token, int clienteId);

  Future<void> registrar(String token, int clienteId, GestionNueva gestion);

  Future<void> editar(String token, int gestionId, GestionEdicion gestion);

  Future<void> reprogramar(String token, int gestionId, DateTime proximo);

  Future<GestionCompras> getCompras(String token, int clienteId, {int? anio});

  Future<List<GestionDocumento>> getDocumentos(String token, int clienteId, {required DateTime desde, required DateTime hasta});

  Future<DocumentEntity> getVenta(String token, int id);

  /// `null` si la cotización no aparece en la lista.
  Future<DocumentEntity?> getCotizacion(String token, {required int companyId, required int id, required int nroDocumento});
}

/// El texto de un error del servidor: el primer mensaje de `errors{campo: [mensaje]}` (validación de
/// Laravel) o, si no hay, el `message` / `error` de siempre.
String? gestionErrorMessage(String body) {
  try {
    final data = json.decode(body);
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        final text = first is List && first.isNotEmpty ? first.first : first;
        if (text is String && text.trim().isNotEmpty) return text;
      }
    }
  } catch (_) {}
  return apiErrorMessage(body);
}

class GestionRemoteDataSourceImpl implements GestionRemoteDataSource {
  final http.Client client;

  GestionRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  static const _base = '/seguimiento-clientes';

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${ApiConstants.baseUrl}$_base$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  /// Como `sendApiRequest`, pero con el motivo que da el servidor en los 403 (cliente ajeno a la cartera),
  /// los 404 (no se encontró) y los 422 (validación): el usuario necesita leerlos.
  Future<dynamic> _send(Future<http.Response> Function() request, {bool retry = false}) {
    return sendApiRequest(
      () async {
        final response = await request();
        final status = response.statusCode;
        if (status == 403 || status == 404 || status == 422) {
          // Hubo respuesta: el servidor es alcanzable.
          ConnectionMonitor.reachedServer();
          final message = gestionErrorMessage(response.body);
          if (status == 422) throw ValidationException(message ?? 'Datos inválidos');
          throw ServerException(
            message ?? (status == 403 ? 'No tienes permiso para esta acción' : 'No se encontró lo que buscas'),
          );
        }
        return response;
      },
      retry: retry,
    );
  }

  @override
  Future<GestionCatalogo> getCatalogo(String token) async => gestionCatalogoFromJson(
        await _send(() => client.get(_uri('/catalogo'), headers: ApiConstants.authHeaders(token)), retry: true),
      );

  @override
  Future<List<GestionClienteBuscado>> buscarClientes(String token, String query) async => gestionClientesFromJson(
        await _send(
          () => client.get(_uri('/buscar', {'q': query}), headers: ApiConstants.authHeaders(token)),
          retry: true,
        ),
      );

  @override
  Future<GestionTareas> getTareas(String token) async => gestionTareasFromJson(
        await _send(() => client.get(_uri('/tareas'), headers: ApiConstants.authHeaders(token)), retry: true),
      );

  @override
  Future<GestionFicha> getFicha(String token, int clienteId) async => gestionFichaFromJson(
        await _send(() => client.get(_uri('/$clienteId/ficha'), headers: ApiConstants.authHeaders(token)), retry: true),
      );

  @override
  Future<GestionHistorial> getGestiones(String token, int clienteId) async => gestionHistorialFromJson(
        await _send(
          () => client.get(_uri('/$clienteId/gestiones'), headers: ApiConstants.authHeaders(token)),
          retry: true,
        ),
      );

  @override
  Future<void> registrar(String token, int clienteId, GestionNueva gestion) async {
    // Crear algo no se repite si se corta la conexión: podría duplicarse.
    await _send(
      () => client.post(
        _uri('/$clienteId/gestiones'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode(gestionNuevaToJson(gestion)),
      ),
    );
  }

  @override
  Future<void> editar(String token, int gestionId, GestionEdicion gestion) async {
    await _send(
      () => client.put(
        _uri('/gestiones/$gestionId'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode(gestionEdicionToJson(gestion)),
      ),
    );
  }

  @override
  Future<void> reprogramar(String token, int gestionId, DateTime proximo) async {
    await _send(
      () => client.put(
        _uri('/gestiones/$gestionId/reprogramar'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode({'proximo_seguimiento': gestionFechaHoraApi(proximo)}),
      ),
    );
  }

  @override
  Future<GestionCompras> getCompras(String token, int clienteId, {int? anio}) async => gestionComprasFromJson(
        await _send(
          () => client.get(
            _uri('/$clienteId/compras', {if (anio != null) 'anio': '$anio'}),
            headers: ApiConstants.authHeaders(token),
          ),
          retry: true,
        ),
      );

  @override
  Future<List<GestionDocumento>> getDocumentos(
    String token,
    int clienteId, {
    required DateTime desde,
    required DateTime hasta,
  }) async =>
      gestionDocumentosFromJson(
        await _send(
          () => client.get(
            _uri('/$clienteId/documentos', {'desde': gestionDiaApi(desde), 'hasta': gestionDiaApi(hasta)}),
            headers: ApiConstants.authHeaders(token),
          ),
          retry: true,
        ),
      );

  @override
  Future<DocumentEntity> getVenta(String token, int id) async {
    final body = await _send(
      () => client.get(Uri.parse('${ApiConstants.baseUrl}/ventas/$id'), headers: ApiConstants.authHeaders(token)),
      retry: true,
    );
    // La web acepta la venta suelta o dentro de `data`.
    final venta = body is Map<String, dynamic> && body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body as Map<String, dynamic>;
    return documentFromJson(venta, DocumentKind.venta);
  }

  @override
  Future<DocumentEntity?> getCotizacion(
    String token, {
    required int companyId,
    required int id,
    required int nroDocumento,
  }) async {
    final body = await _send(
      () => client.get(
        Uri.parse('${ApiConstants.baseUrl}/cotizaciones').replace(
          queryParameters: {'company_id': '$companyId', 'search_input': '$nroDocumento'},
        ),
        headers: ApiConstants.authHeaders(token),
      ),
      retry: true,
    );
    final lista = DocumentPageModel.fromJson(body as Map<String, dynamic>, DocumentKind.cotizacion).items;
    if (lista.isEmpty) return null;
    // La búsqueda por número puede traer otras que lo contienen: se toma la del cliente por su id.
    return lista.firstWhere((d) => d.id == id, orElse: () => lista.first);
  }
}
