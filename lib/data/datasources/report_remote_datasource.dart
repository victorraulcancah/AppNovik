import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/entities/report_ranking_entity.dart';
import '../models/document_model.dart';
import '../models/report_model.dart';
import '../models/report_ranking_model.dart';

abstract class ReportRemoteDataSource {
  Future<SalesReportEntity> getSalesReport({
    required String token,
    required SalesReportFilters filters,
    required int page,
    required int pageSize,
    String? sortField,
    required bool sortDescending,
  });

  Future<RankingReport> getRanking({
    required String token,
    required ReportKind kind,
    required SalesReportFilters filters,
    required int companyId,
    required int page,
    required int pageSize,
    String? search,
  });

  Future<Uint8List> exportSalesReport(String token, SalesReportFilters filters);

  Future<SalesReportCatalogs> getCatalogs({
    required String token,
    required int companyId,
    required int userId,
    required bool soloMiCartera,
  });

  Future<DocumentEntity> getSale(String token, int id);
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final http.Client client;

  ReportRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Uri _uri(String path, Map<String, List<String>> query) =>
      Uri.parse('${ApiConstants.baseUrl}$path').replace(queryParameters: query);

  /// Los mismos parámetros que manda la web (`fechas[]`, `warehouse_id[]`, `clientes[]`...).
  Map<String, List<String>> _filterParams(SalesReportFilters f) => {
        'fechas[]': [_day(f.desde), _day(f.hasta)],
        if (f.sucursales.isNotEmpty) 'warehouse_id[]': f.sucursales,
        if (f.clientes.isNotEmpty) 'clientes[]': f.clientes,
        if (f.vendedores.isNotEmpty) 'vendedores[]': f.vendedores,
        if (f.marcas.isNotEmpty) 'marcas[]': f.marcas,
        if (f.categorias.isNotEmpty) 'tipos_producto[]': f.categorias,
        if (f.departamentos.isNotEmpty) 'departamentos[]': f.departamentos,
      };

  /// Dónde está cada ranking. Todos devuelven las filas por entidad de mayor a menor venta.
  static String _rankingPath(ReportKind kind) => switch (kind) {
    ReportKind.departamentos => '/ventas/reporte-departamentos-v2',
    ReportKind.vendedores => '/ventas/reporte-vendedores-v2',
    ReportKind.marcas => '/ventas/reporte-marcas-v2',
    ReportKind.categorias => '/ventas/reporte-categorias-v2',
    ReportKind.clientes => '/ventas/reporte-clientes-v2',
    ReportKind.general => '/ventas/reporte',
  };

  /// Parámetros de orden de `/ventas/reporte`.
  ///
  /// El backend ordena al revés de lo que se le pide: `SaleController::reporte` llama
  /// `sortBy($campo, SORT_REGULAR, $sortOrder === 'ascend')` y el tercer argumento de `sortBy` es
  /// "descendente". Por eso `descend` sale de menor a mayor. Aquí se pide el sentido contrario
  /// para que la lista salga como se eligió. Sin orden explícito, o con el de siempre (Venta
  /// total de mayor a menor), no se manda nada y el servidor usa el suyo, que ya es ese.
  /// Si se corrige el backend, hay que quitar esta inversión.
  static Map<String, List<String>> _sortParams(String? sortField, bool sortDescending) {
    if (sortField == null || (sortField == 'venta' && sortDescending)) return const {};
    return {
      'sortField': [sortField],
      'sortOrder': [sortDescending ? 'ascend' : 'descend'],
    };
  }

  @override
  Future<SalesReportEntity> getSalesReport({
    required String token,
    required SalesReportFilters filters,
    required int page,
    required int pageSize,
    String? sortField,
    required bool sortDescending,
  }) async {
    final uri = _uri('/ventas/reporte', {
      ..._filterParams(filters),
      'page': ['$page'],
      'results': ['$pageSize'],
      ..._sortParams(sortField, sortDescending),
    });
    final body = await sendApiRequest(
      () => client.get(uri, headers: ApiConstants.authHeaders(token)),
    );
    return salesReportFromJson(body as Map<String, dynamic>);
  }

  /// Los reportes por entidad de la web (`*-v2`) piden las sucursales como `sucursales[]` y las
  /// categorías como `tipos_producto[]`; el resto de los filtros se llaman igual que en Ventas General.
  @override
  Future<RankingReport> getRanking({
    required String token,
    required ReportKind kind,
    required SalesReportFilters filters,
    required int companyId,
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final uri = _uri(_rankingPath(kind), {
      'fechas[]': [_day(filters.desde), _day(filters.hasta)],
      'company_id': ['$companyId'],
      if (filters.sucursales.isNotEmpty) 'sucursales[]': filters.sucursales,
      if (filters.clientes.isNotEmpty) 'clientes[]': filters.clientes,
      if (filters.vendedores.isNotEmpty) 'vendedores[]': filters.vendedores,
      if (filters.marcas.isNotEmpty) 'marcas[]': filters.marcas,
      if (filters.categorias.isNotEmpty) 'tipos_producto[]': filters.categorias,
      if (filters.departamentos.isNotEmpty) 'departamentos[]': filters.departamentos,
      if (kind == ReportKind.clientes && search != null && search.trim().isNotEmpty)
        'cliente_search': [search.trim()],
      'page': ['$page'],
      'per_page': ['$pageSize'],
    });
    final body = await sendApiRequest(
      () => client.get(uri, headers: ApiConstants.authHeaders(token)),
    );
    return rankingFromJson(kind, body);
  }

  @override
  Future<Uint8List> exportSalesReport(String token, SalesReportFilters filters) => sendApiBytes(
        () => client.post(
          _uri('/ventas/export/reporte', _filterParams(filters)),
          headers: ApiConstants.authHeaders(token),
        ),
      );

  @override
  Future<SalesReportCatalogs> getCatalogs({
    required String token,
    required int companyId,
    required int userId,
    required bool soloMiCartera,
  }) async {
    Future<List<ReportOption>> load(String path, Map<String, List<String>> query) async =>
        reportOptionsFromJson(await sendApiRequest(
          () => client.get(_uri(path, query), headers: ApiConstants.authHeaders(token)),
        ));

    final company = {'company_id': ['$companyId']};
    final results = await Future.wait([
      load('/almacenes/list', company),
      // Los clientes que tiene asignados el vendedor, o todos.
      load('/clientes/list', {...company, 'solo_mi_cartera': ['true']}),
      load('/usuarios/list', {
        ...company,
        'roles[]': ['Vendedor', 'JEFE COMERCIAL', 'Ceo Empresa', 'Admin Empresa'],
      }),
      load('/marcas', company),
      load('/categorias', company),
      load('/ubigeo/search/departments', const {}),
    ]);

    return SalesReportCatalogs(
      sucursales: results[0],
      clientes: results[1],
      // Un vendedor sin permiso para ver a los demás solo se ve a sí mismo, como en la web.
      vendedores: soloMiCartera ? [for (final v in results[2]) if (v.id == '$userId') v] : results[2],
      marcas: results[3],
      categorias: results[4],
      departamentos: results[5],
    );
  }

  @override
  Future<DocumentEntity> getSale(String token, int id) async {
    final body = await sendApiRequest(
      () => client.get(
        Uri.parse('${ApiConstants.baseUrl}/ventas/$id'),
        headers: ApiConstants.authHeaders(token),
      ),
    );
    // La web acepta la venta suelta o dentro de `data`.
    final json = body is Map<String, dynamic> && body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body as Map<String, dynamic>;
    return documentFromJson(json, DocumentKind.venta);
  }
}
