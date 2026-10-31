import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/import_entity.dart';
import '../../domain/entities/product_form_entity.dart';
import '../models/product_form_model.dart';
import '../models/product_model.dart';

abstract class ProductRemoteDataSource {
  Future<ProductPageModel> getProducts({
    required String token,
    required int companyId,
    required int page,
    required int pageSize,
    required List<String> search,
    String? tipo,
  });

  Future<ProductCatalogsEntity> getCatalogs(String token);

  Future<ProductModel> saveProduct({
    required String token,
    required int companyId,
    required ProductFormEntity form,
    int? id,
  });

  Future<CatalogItemEntity> createCatalogItem({
    required String token,
    required CatalogKind kind,
    required String name,
  });

  Future<Uint8List> exportProducts(String token);

  Future<ImportResultEntity> importFile({
    required String token,
    required int companyId,
    required ImportKind kind,
    required String fileName,
    required Uint8List bytes,
  });
}

/// Ruta de la importación de cada tipo de archivo.
String _importPath(ImportKind kind) => switch (kind) {
      ImportKind.productos => '/productos/import',
      ImportKind.marcas => '/marcas/import',
      ImportKind.categorias => '/categorias/import',
    };

/// Respuesta de las importaciones: `{message}` o `{failures: {clave: {row, errors}}}`.
ImportResultEntity importResultFromJson(dynamic body) {
  if (body is! Map) return const ImportResultEntity();
  final raw = body['failures'];
  final failures = <ImportFailureEntity>[];
  final entries = raw is Map ? raw.values : (raw is List ? raw : const []);
  for (final f in entries) {
    if (f is! Map) continue;
    failures.add(ImportFailureEntity(
      row: f['row'] is num ? (f['row'] as num).toInt() : int.tryParse('${f['row']}') ?? 0,
      errors: [
        for (final e in (f['errors'] is List ? f['errors'] as List : const [])) '$e',
      ],
    ));
  }
  final message = body['message'];
  return ImportResultEntity(
    message: message is String && message.isNotEmpty ? message : 'Importación exitosa',
    failures: failures,
  );
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final http.Client client;

  ProductRemoteDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<ProductPageModel> getProducts({
    required String token,
    required int companyId,
    required int page,
    required int pageSize,
    required List<String> search,
    String? tipo,
  }) async {
    // Mismos parámetros que usa la web (`/productos`).
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.productosEndpoint}')
        .replace(queryParameters: {
      'company_id': ['$companyId'],
      'pagination[current]': ['$page'],
      'pagination[pageSize]': ['$pageSize'],
      if (search.isNotEmpty) 'search[]': search,
      if (tipo != null) 'tipo_producto': [tipo],
    });

    final body = await sendApiRequest(
      () => client.get(uri, headers: ApiConstants.authHeaders(token)),
    );
    return ProductPageModel.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<ProductCatalogsEntity> getCatalogs(String token) async {
    Future<List<CatalogItemEntity>> list(String path) async {
      final uri = Uri.parse('${ApiConstants.baseUrl}$path');
      final body = await sendApiRequest(
        () => client.get(uri, headers: ApiConstants.authHeaders(token)),
      );
      return catalogFromJson(body);
    }

    final results = await Future.wait([
      list('/marcas'),
      list('/categorias'),
      list('/medidas/list'),
      list('/proveedores/list'),
      list('/canales'),
      list('/giros-negocio'),
    ]);
    return ProductCatalogsEntity(
      marcas: results[0],
      categorias: results[1],
      medidas: results[2],
      proveedores: results[3],
      canales: results[4],
      giros: results[5],
    );
  }

  @override
  Future<ProductModel> saveProduct({
    required String token,
    required int companyId,
    required ProductFormEntity form,
    int? id,
  }) async {
    final editing = id != null;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.productosEndpoint}${editing ? '/$id' : ''}',
    );

    // Como la web: un formulario multipart con los campos como texto y, si hay, la foto.
    final body = await sendApiRequest(() async {
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(ApiConstants.authHeaders(token))
        ..fields.addAll(form.toFields(companyId: companyId, editing: editing));
      final foto = form.foto;
      if (foto != null) {
        request.files.add(http.MultipartFile.fromBytes('foto', foto.bytes, filename: foto.name));
      }
      return http.Response.fromStream(await client.send(request));
    });
    return ProductModel.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<CatalogItemEntity> createCatalogItem({
    required String token,
    required CatalogKind kind,
    required String name,
  }) async {
    final body = await sendApiRequest(
      () => client.post(
        Uri.parse('${ApiConstants.baseUrl}${kind.endpoint}'),
        headers: ApiConstants.authHeaders(token),
        // Canales y giros aceptan `name` como alias de `nombre`, igual que en la web.
        body: json.encode({'name': name}),
      ),
    );
    final item = catalogItemFromJson(body);
    if (item == null) throw const ServerException('Respuesta inesperada del servidor');
    return item;
  }

  @override
  Future<Uint8List> exportProducts(String token) => sendApiBytes(
        () => client.post(
          Uri.parse('${ApiConstants.baseUrl}/productos/export'),
          headers: ApiConstants.authHeaders(token),
        ),
      );

  @override
  Future<ImportResultEntity> importFile({
    required String token,
    required int companyId,
    required ImportKind kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${_importPath(kind)}');
    final body = await sendApiRequest(() async {
      // Como la web: el Excel en `file` y la empresa en `company_id`, en un formulario multipart.
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(ApiConstants.authHeaders(token))
        ..fields['company_id'] = '$companyId'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      return http.Response.fromStream(await client.send(request));
    });
    return importResultFromJson(body);
  }
}
