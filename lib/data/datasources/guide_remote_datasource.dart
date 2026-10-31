import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/guide_form_entity.dart';
import '../../domain/entities/other_document_entity.dart';
import '../models/guide_model.dart';
import '../models/other_document_model.dart';

abstract class GuideRemoteDataSource {
  Future<GuideDefaultsEntity> getDefaults(String token, int saleId);
  Future<DriverEntity?> findDriver(String token, String dni);
  Future<OtherDocumentEntity> createGuide(String token, GuideFormEntity form);
}

class GuideRemoteDataSourceImpl implements GuideRemoteDataSource {
  final http.Client client;

  GuideRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  @override
  Future<GuideDefaultsEntity> getDefaults(String token, int saleId) async {
    final body = await sendApiRequest(
      () => client.get(
        Uri.parse('${ApiConstants.baseUrl}/ventas/$saleId'),
        headers: ApiConstants.authHeaders(token),
      ),
    );
    // La web acepta la venta suelta o dentro de `data`.
    final json = body is Map<String, dynamic> && body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body as Map<String, dynamic>;
    return guideDefaultsFromJson(json);
  }

  @override
  Future<DriverEntity?> findDriver(String token, String dni) async {
    try {
      final body = await sendApiRequest(
        () => client.get(
          Uri.parse('${ApiConstants.baseUrl}/conductores/$dni'),
          headers: ApiConstants.authHeaders(token),
        ),
      );
      return body is Map<String, dynamic> && body.isNotEmpty ? driverFromJson(body) : null;
    } on AuthException {
      rethrow;
    } on AppException {
      // Un chofer que no está registrado no es un error: se escriben sus datos a mano.
      return null;
    }
  }

  @override
  Future<OtherDocumentEntity> createGuide(String token, GuideFormEntity form) async {
    final body = await sendApiRequest(
      () => client.post(
        Uri.parse('${ApiConstants.baseUrl}/guia-remision'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode(guideToJson(form)),
      ),
      // Con boleta o factura el servidor emite la guía ante la SUNAT y consulta su constancia.
      timeout: const Duration(seconds: 120),
    );
    return otherDocumentFromJson(body as Map<String, dynamic>, OtherDocumentKind.guia);
  }
}
