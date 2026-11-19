import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/seller_payment_entity.dart';
import '../models/seller_payment_model.dart';

abstract class SellerPaymentRemoteDataSource {
  Future<SellerPaymentPageEntity> getPayments(
    String token, {
    required int page,
    required int pageSize,
    required SellerPaymentFilters filters,
  });

  Future<Uint8List> exportPayments(String token, {required SellerPaymentFilters filters});

  Future<List<SellerPaymentOption>> getPaymentMethods(String token);

  Future<List<SellerPaymentOption>> getClients(
    String token, {
    required int companyId,
    required bool onlyMine,
  });

  Future<List<SellerPaymentOption>> getSellers(String token, {required int companyId});

  Future<SellerClientDebt> getClientDebt(String token, {required int clientId});

  Future<void> createPayment(String token, {required SellerPaymentCreate payment});

  Future<void> approvePayment(String token, {required int id});

  /// Editar la parte de un pago aplicada a una cuota (`edit-pre-confirm`).
  Future<void> editInstallmentPayment(
    String token, {
    required int id,
    required int paymentMethodId,
    double? monto,
  });

  /// Editar un pago de saldo a favor (`edit-payment-seller`): solo el método de pago.
  Future<void> editPayment(
    String token, {
    required int id,
    required int paymentMethodId,
  });

  Future<void> deletePayment(String token, {required int id, required bool afterConfirm});

  /// El historial de notas del pago y si el usuario puede escribir una.
  Future<SellerPaymentNotes> getNotes(String token, {required int paymentId});

  /// Agrega una nota al pago, a nombre de quien la escribe.
  Future<SellerPaymentNote> addNote(String token, {required int paymentId, required String texto});

  /// Elimina una nota: queda en el historial como eliminada. Devuelve la nota ya eliminada.
  Future<SellerPaymentNote> deleteNote(String token, {required int noteId});
}

class SellerPaymentRemoteDataSourceImpl implements SellerPaymentRemoteDataSource {
  final http.Client client;

  SellerPaymentRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  static String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String _number(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  /// Los filtros como los manda la web (`parametrosDeFiltrosPagos` + `search[]`): `fecha_desde`,
  /// `fecha_hasta`, `clientes[]`, `ejecutivos[]`, `metodos[]`, `monto_min`, `monto_max`, `estado_filter`.
  static List<MapEntry<String, String>> filterParams(SellerPaymentFilters f) => [
        if (f.desde != null && f.hasta != null) ...[
          MapEntry('fecha_desde', _day(f.desde!)),
          MapEntry('fecha_hasta', _day(f.hasta!)),
        ],
        for (final id in f.clientes) MapEntry('clientes[]', '$id'),
        for (final id in f.ejecutivos) MapEntry('ejecutivos[]', '$id'),
        for (final id in f.metodos) MapEntry('metodos[]', '$id'),
        if (f.montoMin != null) MapEntry('monto_min', _number(f.montoMin!)),
        if (f.montoMax != null) MapEntry('monto_max', _number(f.montoMax!)),
        if (f.estado != null) MapEntry('estado_filter', '${f.estado!.code}'),
        for (final term in f.search) MapEntry('search[]', term),
      ];

  Uri _uri(String path, [List<MapEntry<String, String>> params = const []]) {
    final base = Uri.parse('${ApiConstants.baseUrl}$path');
    if (params.isEmpty) return base;
    // Los corchetes se arman a mano (`clientes[]=3`).
    final query = params
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return base.replace(query: query);
  }

  @override
  Future<SellerPaymentPageEntity> getPayments(
    String token, {
    required int page,
    required int pageSize,
    required SellerPaymentFilters filters,
  }) async {
    final body = await sendApiRequest(
      () => client.get(
        _uri('/pagos-vendedores-new', [
          MapEntry('pagination[current]', '$page'),
          MapEntry('pagination[pageSize]', '$pageSize'),
          ...filterParams(filters),
        ]),
        headers: ApiConstants.authHeaders(token),
      ),
      retry: true,
    );
    return sellerPaymentPageFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<Uint8List> exportPayments(String token, {required SellerPaymentFilters filters}) => sendApiBytes(
        () => client.post(
          // Como la web: POST con la búsqueda y los filtros en la dirección.
          _uri('/pagos-vendedores-new/export', filterParams(filters)),
          headers: ApiConstants.authHeaders(token),
        ),
      );

  @override
  Future<List<SellerPaymentOption>> getPaymentMethods(String token) async => sellerPaymentOptionsFromJson(
        await sendApiRequest(
          () => client.get(
            _uri('/metodos-de-pago/list', const [MapEntry('all', 'true')]),
            headers: ApiConstants.authHeaders(token),
          ),
          retry: true,
        ),
      );

  @override
  Future<List<SellerPaymentOption>> getClients(
    String token, {
    required int companyId,
    required bool onlyMine,
  }) async =>
      sellerPaymentClientOptionsFromJson(
        await sendApiRequest(
          () => client.get(
            _uri('/clientes/list', [
              MapEntry('company_id', '$companyId'),
              // El filtro, como los reportes de la web: el Vendedor solo ve sus clientes.
              if (onlyMine) const MapEntry('solo_mi_cartera', 'true'),
            ]),
            headers: ApiConstants.authHeaders(token),
          ),
          retry: true,
        ),
      );

  @override
  Future<List<SellerPaymentOption>> getSellers(String token, {required int companyId}) async =>
      sellerPaymentOptionsFromJson(
        await sendApiRequest(
          () => client.get(
            _uri('/usuarios/list', [
              MapEntry('company_id', '$companyId'),
              const MapEntry('roles[0]', 'Vendedor'),
            ]),
            headers: ApiConstants.authHeaders(token),
          ),
          retry: true,
        ),
      );

  @override
  Future<SellerClientDebt> getClientDebt(String token, {required int clientId}) async {
    final body = await sendApiRequest(
      () => client.get(
        _uri('/clientes/$clientId', const [MapEntry('include_deudas', 'true')]),
        headers: ApiConstants.authHeaders(token),
      ),
      retry: true,
    );
    return body is Map ? sellerClientDebtFromJson(body.cast<String, dynamic>()) : const SellerClientDebt();
  }

  @override
  Future<void> createPayment(String token, {required SellerPaymentCreate payment}) async {
    await sendApiRequest(
      () => client.post(
        _uri('/pagos-vendedores/deposito'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode({
          'client_id': payment.clientId,
          'payment_methods': [
            for (final l in payment.lines)
              {
                'payment_method_id': l.paymentMethodId,
                'monto': l.monto,
                if (l.descripcionAdicional != null) 'descripcion_adicional': l.descripcionAdicional,
              },
          ],
          if (payment.creado != null) 'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(payment.creado!),
          'moneda': payment.moneda,
        }),
      ),
    );
  }

  @override
  Future<void> approvePayment(String token, {required int id}) async {
    await sendApiRequest(
      () => client.put(
        _uri('/pagos-vendedores/confirmar-group/$id'),
        headers: ApiConstants.authHeaders(token),
      ),
    );
  }

  @override
  Future<void> editInstallmentPayment(
    String token, {
    required int id,
    required int paymentMethodId,
    double? monto,
  }) async {
    await sendApiRequest(
      () => client.put(
        _uri('/pagos-vendedores/edit-pre-confirm/$id'),
        headers: ApiConstants.authHeaders(token),
        // La descripción ya no se edita aquí: son las notas del pago.
        body: json.encode({
          'payment_method_id': paymentMethodId,
          'monto': ?monto,
        }),
      ),
    );
  }

  @override
  Future<void> editPayment(
    String token, {
    required int id,
    required int paymentMethodId,
  }) async {
    await sendApiRequest(
      () => client.put(
        _uri('/pagos-vendedores/edit-payment-seller/$id'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode({'payment_method_id': paymentMethodId}),
      ),
    );
  }

  @override
  Future<SellerPaymentNotes> getNotes(String token, {required int paymentId}) async {
    final body = await sendApiRequest(
      () => client.get(
        _uri('/pagos-vendedores/$paymentId/notas'),
        headers: ApiConstants.authHeaders(token),
      ),
      retry: true,
    );
    return body is Map ? sellerPaymentNotesFromJson(body.cast<String, dynamic>()) : const SellerPaymentNotes();
  }

  @override
  Future<SellerPaymentNote> addNote(String token, {required int paymentId, required String texto}) async {
    final body = await sendApiRequest(
      () => client.post(
        _uri('/pagos-vendedores/$paymentId/notas'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode({'texto': texto}),
      ),
    );
    return sellerPaymentNoteFromJson((body as Map).cast<String, dynamic>());
  }

  @override
  Future<SellerPaymentNote> deleteNote(String token, {required int noteId}) async {
    final body = await sendApiRequest(
      () => client.delete(
        _uri('/pagos-vendedores/notas/$noteId'),
        headers: ApiConstants.authHeaders(token),
      ),
    );
    return sellerPaymentNoteFromJson((body as Map).cast<String, dynamic>());
  }

  @override
  Future<void> deletePayment(String token, {required int id, required bool afterConfirm}) async {
    await sendApiRequest(
      () => client.delete(
        // Un pago ya confirmado se elimina por otra ruta (queda a la vista, marcado como eliminado).
        _uri(
          afterConfirm ? '/pagos-vendedores/delete-post-confirm/$id' : '/pagos-vendedores/$id',
          const [MapEntry('type', 'payment_seller')],
        ),
        headers: ApiConstants.authHeaders(token),
      ),
    );
  }
}
