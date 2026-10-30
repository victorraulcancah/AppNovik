import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/sale_entity.dart';
import '../models/document_model.dart';
import '../models/sale_model.dart';

abstract class SaleRemoteDataSource {
  Future<List<ClientEntity>> searchClients(String token, int companyId, String search);
  Future<List<SaleProductEntity>> searchProducts(String token, int companyId, String search);
  Future<ExchangeRateEntity> getExchangeRate(String token);
  Future<ClientEntity> getWalkInClient(String token, int companyId);
  Future<SaleProductFiltersEntity> getProductFilters(String token);
  Future<List<PaymentMethodEntity>> getPaymentMethods(String token);
  Future<SaleResultEntity> createSale({
    required String token,
    required int companyId,
    required int userId,
    required SaleFormEntity form,
  });
}

class SaleRemoteDataSourceImpl implements SaleRemoteDataSource {
  final http.Client client;

  SaleRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConstants.baseUrl}$path').replace(queryParameters: query);

  @override
  Future<List<ClientEntity>> searchClients(String token, int companyId, String search) async =>
      clientsFromJson(await sendApiRequest(
        () => client.get(
          _uri('/clientes/search', {'company_id': '$companyId', 'search': search}),
          headers: ApiConstants.authHeaders(token),
        ),
      ));

  @override
  Future<List<SaleProductEntity>> searchProducts(
    String token,
    int companyId,
    String search,
  ) async =>
      saleProductsFromJson(await sendApiRequest(
        () => client.get(
          _uri('/productos/search', {'company_id': '$companyId', 'search': search}),
          headers: ApiConstants.authHeaders(token),
        ),
      ));

  @override
  Future<ExchangeRateEntity> getExchangeRate(String token) async {
    final body = await sendApiRequest(
      () => client.get(_uri('/tipo-cambio/comercial'), headers: ApiConstants.authHeaders(token)),
    );
    return exchangeRateFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<ClientEntity> getWalkInClient(String token, int companyId) async {
    final body = await sendApiRequest(
      () => client.get(
        _uri('/clientes/varios', {'company_id': '$companyId'}),
        headers: ApiConstants.authHeaders(token),
      ),
    );
    return clientFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<SaleProductFiltersEntity> getProductFilters(String token) async {
    // Los mismos catálogos que usa el formulario de producto (la API los limita a la empresa del usuario).
    Future<dynamic> load(String path) => sendApiRequest(
          () => client.get(_uri(path), headers: ApiConstants.authHeaders(token)),
        );
    final results = await Future.wait([load('/categorias'), load('/marcas')]);
    return saleProductFiltersFromJson(categorias: results[0], marcas: results[1]);
  }

  @override
  Future<List<PaymentMethodEntity>> getPaymentMethods(String token) async =>
      paymentMethodsFromJson(await sendApiRequest(
        () => client.get(
          _uri('/metodos-de-pago/list'),
          headers: ApiConstants.authHeaders(token),
        ),
      ));

  @override
  Future<SaleResultEntity> createSale({
    required String token,
    required int companyId,
    required int userId,
    required SaleFormEntity form,
  }) async {
    final isQuote = form.tipoDocumento.esCotizacion;
    final payload = json.encode(
      isQuote
          ? quoteToJson(form, companyId: companyId, userId: userId)
          : saleToJson(form, companyId: companyId, userId: userId),
    );
    final body = await sendApiRequest(
      () => client.post(
        _uri(isQuote ? '/cotizaciones' : '/ventas'),
        headers: ApiConstants.authHeaders(token),
        body: payload,
      ),
    );
    return documentFromJson(
      body as Map<String, dynamic>,
      isQuote ? DocumentKind.cotizacion : DocumentKind.venta,
    );
  }
}
