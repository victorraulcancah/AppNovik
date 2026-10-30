import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/document_entity.dart';
import '../models/document_model.dart';

abstract class DocumentRemoteDataSource {
  Future<DocumentPageModel> getDocuments({
    required String token,
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
    required int page,
    required int pageSize,
  });

  Future<DownloadedFile> exportDocuments({
    required String token,
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
  });

  Future<DocumentFilterCatalogs> getFilterCatalogs(String token, int companyId);
  Future<void> deleteSale(String token, int id);
  Future<void> deleteQuote(String token, int id);
  Future<void> createCreditNote({
    required String token,
    required int boletaId,
    required String descripcion,
    required DateTime fechaEmision,
  });
  Future<Uint8List> downloadBytes(String token, String path);
}

class DocumentRemoteDataSourceImpl implements DocumentRemoteDataSource {
  final http.Client client;

  DocumentRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  static final _day = DateFormat('yyyy-MM-dd');

  Uri _uri(String path, Map<String, dynamic> query) =>
      Uri.parse('${ApiConstants.baseUrl}$path').replace(queryParameters: query);

  /// Los mismos parámetros que manda la web (`fecha_desde`, `sucursales[]`...). Con un
  /// número buscado no se envían: el backend busca en toda la empresa.
  Map<String, dynamic> _filterParams(DocumentKind kind, DocumentFilters f) {
    final isQuote = kind == DocumentKind.cotizacion;
    List<String> ids(List<int> v) => [for (final i in v) '$i'];

    return {
      if (f.desde != null && f.hasta != null) ...{
        'fecha_desde': [_day.format(f.desde!)],
        'fecha_hasta': [_day.format(f.hasta!)],
      },
      if (f.sucursales.isNotEmpty) 'sucursales[]': ids(f.sucursales),
      if (f.vendedores.isNotEmpty) 'vendedores[]': ids(f.vendedores),
      if (f.clientes.isNotEmpty) 'clientes[]': ids(f.clientes),
      if (!isQuote) ...{
        if (f.tipo != null)
          'tipo_documento': [
            switch (f.tipo!) {
              DocumentTipo.boleta => 'b',
              DocumentTipo.factura => 'f',
              DocumentTipo.notaVenta => 'nt',
            },
          ],
        if (f.estado != null)
          'estado_documento': [f.estado == DocumentEstado.activos ? 'activos' : 'eliminados'],
      },
      if (isQuote) ...{
        if (f.estadoCotizacion != DocumentQuoteState.todas)
          'estado_cotizacion': [
            f.estadoCotizacion == DocumentQuoteState.pendientes ? 'pendientes' : 'procesadas',
          ],
        if (f.reserva != DocumentReserve.todas)
          'reserva': [f.reserva == DocumentReserve.reservadas ? 'reservadas' : 'no_reservadas'],
      },
    };
  }

  @override
  Future<DocumentPageModel> getDocuments({
    required String token,
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
    required int page,
    required int pageSize,
  }) async {
    final searching = search != null && search.isNotEmpty;
    final uri = _uri(kind == DocumentKind.cotizacion ? '/cotizaciones' : '/ventas', {
      'company_id': ['$companyId'],
      'pagination[current]': ['$page'],
      'pagination[pageSize]': ['$pageSize'],
      if (searching) 'search_input': [search] else ..._filterParams(kind, filters),
    });

    final body = await sendApiRequest(
      () => client.get(uri, headers: ApiConstants.authHeaders(token)),
    );
    return DocumentPageModel.fromJson(body as Map<String, dynamic>, kind);
  }

  @override
  Future<DownloadedFile> exportDocuments({
    required String token,
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
  }) async {
    final isQuote = kind == DocumentKind.cotizacion;
    final searching = search != null && search.isNotEmpty;
    final params = {
      // La web pide el Excel de cotizaciones con la empresa y el de ventas sin ella.
      if (isQuote) 'company_id': ['$companyId'],
      if (searching) 'search_input': [search] else ..._filterParams(kind, filters),
    };

    final uri = _uri(isQuote ? '/cotizaciones/export' : '/ventas/export', params);
    final bytes = await sendApiBytes(
      () => client.post(uri, headers: ApiConstants.authHeaders(token)),
    );

    final String name;
    if (!isQuote) {
      name = 'Ventas.xlsx';
    } else if (filters.estadoCotizacion == DocumentQuoteState.pendientes) {
      name = 'Cotizaciones pendientes.xlsx';
    } else {
      name = 'Cotizaciones.xlsx';
    }
    return DownloadedFile(name: name, bytes: bytes);
  }

  @override
  Future<DocumentFilterCatalogs> getFilterCatalogs(String token, int companyId) async {
    Future<List<({int id, String name})>> load(String path, Map<String, dynamic> query) async =>
        filterOptionsFromJson(await sendApiRequest(
          () => client.get(_uri(path, query), headers: ApiConstants.authHeaders(token)),
        ));

    final results = await Future.wait([
      load('/almacenes/list', {'company_id': ['$companyId']}),
      load('/usuarios/list', {
        'company_id': ['$companyId'],
        'roles[]': ['Vendedor'],
      }),
      load('/clientes/list', {
        'company_id': ['$companyId'],
        'solo_mi_cartera': ['true'],
      }),
    ]);
    return DocumentFilterCatalogs(
      sucursales: results[0],
      vendedores: results[1],
      clientes: results[2],
    );
  }

  @override
  Future<void> deleteSale(String token, int id) async {
    // Igual que la web: el PUT con `estado: false` elimina la venta y devuelve el stock.
    await sendApiRequest(
      () => client.put(
        Uri.parse('${ApiConstants.baseUrl}/ventas/$id'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode({'estado': false}),
      ),
    );
  }

  @override
  Future<void> deleteQuote(String token, int id) async {
    await sendApiRequest(
      () => client.delete(
        Uri.parse('${ApiConstants.baseUrl}/cotizaciones/$id'),
        headers: ApiConstants.authHeaders(token),
      ),
    );
  }

  @override
  Future<void> createCreditNote({
    required String token,
    required int boletaId,
    required String descripcion,
    required DateTime fechaEmision,
  }) async {
    await sendApiRequest(
      () => client.post(
        Uri.parse('${ApiConstants.baseUrl}/nota-credito'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode({
          'boleta_id': boletaId,
          'descripcion': descripcion,
          'fecha_emision': _day.format(fechaEmision),
        }),
      ),
    );
  }

  @override
  Future<Uint8List> downloadBytes(String token, String path) => sendApiBytes(
        () => client.get(
          Uri.parse('${ApiConstants.baseUrl}$path'),
          headers: ApiConstants.authHeaders(token),
        ),
      );
}
