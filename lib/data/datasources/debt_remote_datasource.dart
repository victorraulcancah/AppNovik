import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/debt_entity.dart';
import '../models/debt_model.dart';

abstract class DebtRemoteDataSource {
  Future<DebtPageEntity> getDebts(
    String token, {
    required int page,
    required int pageSize,
    required DebtFiltersEntity filters,
  });

  Future<List<DebtOption>> searchClients(
    String token, {
    required int companyId,
    required String search,
    required bool onlyMine,
  });

  Future<List<DebtOption>> getSellers(String token, {required int companyId});

  Future<Uint8List> exportDebts(String token, {required DebtFiltersEntity filters});
}

class DebtRemoteDataSourceImpl implements DebtRemoteDataSource {
  final http.Client client;

  DebtRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  /// Los filtros que manda la web: `filters[client_id]`, `filters[vendedor_id]` y, en la búsqueda
  /// por columna, `filters[cliente]`.
  static List<MapEntry<String, String>> filterParams(DebtFiltersEntity filters) => [
        if (filters.client != null) MapEntry('filters[client_id]', '${filters.client!.id}'),
        if (filters.seller != null) MapEntry('filters[vendedor_id]', '${filters.seller!.id}'),
        if (filters.search.isNotEmpty) MapEntry('filters[cliente]', filters.search),
      ];

  Uri _uri(String path, [List<MapEntry<String, String>> params = const []]) {
    final base = Uri.parse('${ApiConstants.baseUrl}$path');
    if (params.isEmpty) return base;
    // Los corchetes se arman a mano (`filters[client_id]=3`).
    final query = params
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return base.replace(query: query);
  }

  @override
  Future<DebtPageEntity> getDebts(
    String token, {
    required int page,
    required int pageSize,
    required DebtFiltersEntity filters,
  }) async {
    final body = await sendApiRequest(
      () => client.get(
        _uri('/deudas/clientes/resumen', [
          MapEntry('pagination[current]', '$page'),
          MapEntry('pagination[pageSize]', '$pageSize'),
          ...filterParams(filters),
        ]),
        headers: ApiConstants.authHeaders(token),
      ),
    );
    return debtPageFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<List<DebtOption>> searchClients(
    String token, {
    required int companyId,
    required String search,
    required bool onlyMine,
  }) async =>
      debtClientOptionsFromJson(
        await sendApiRequest(
          () => client.get(
            // Sin texto: la lista completa de clientes (la misma del filtro de Documentos), para
            // elegirlos de una lista; con texto, la búsqueda en el servidor.
            search.isEmpty
                ? _uri('/clientes/list', [
                    MapEntry('company_id', '$companyId'),
                    if (onlyMine) const MapEntry('solo_mi_cartera', 'true'),
                  ])
                : _uri('/clientes/search', [
                    MapEntry('company_id', '$companyId'),
                    MapEntry('search', search),
                    if (onlyMine) const MapEntry('validar_vendedor', 'true'),
                  ]),
            headers: ApiConstants.authHeaders(token),
          ),
        ),
      );

  @override
  Future<List<DebtOption>> getSellers(String token, {required int companyId}) async =>
      debtSellerOptionsFromJson(
        await sendApiRequest(
          () => client.get(
            _uri('/usuarios/list', [
              MapEntry('company_id', '$companyId'),
              const MapEntry('roles[0]', 'Vendedor'),
            ]),
            headers: ApiConstants.authHeaders(token),
          ),
        ),
      );

  @override
  Future<Uint8List> exportDebts(String token, {required DebtFiltersEntity filters}) => sendApiBytes(
        () => client.post(
          // Como la web: POST con los filtros de cliente y ejecutivo en la dirección.
          _uri('/deudas/clientes/resumen/export-excel', [
            if (filters.client != null) MapEntry('filters[client_id]', '${filters.client!.id}'),
            if (filters.seller != null) MapEntry('filters[vendedor_id]', '${filters.seller!.id}'),
          ]),
          headers: ApiConstants.authHeaders(token),
        ),
      );
}
