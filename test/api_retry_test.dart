import 'package:app_novik/core/errors/exceptions.dart';
import 'package:app_novik/core/network/api_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const dropped = 'Connection closed before full header was received';

  Future<http.Response> Function() flaky(List<Object> outcomes, void Function() onCall) {
    var i = 0;
    return () async {
      onCall();
      final o = outcomes[i < outcomes.length ? i : outcomes.length - 1];
      i++;
      if (o is Exception) throw o;
      return o as http.Response;
    };
  }

  test('una consulta con retry se repite una vez si se corta la conexión', () async {
    var calls = 0;
    final body = await sendApiRequest(
      flaky([http.ClientException(dropped), http.Response('{"ok": true}', 200)], () => calls++),
      retry: true,
    );

    expect(body, {'ok': true});
    expect(calls, 2);
  });

  test('sin retry (crear algo) no se repite nunca: no se duplica', () async {
    var calls = 0;
    await expectLater(
      sendApiRequest(flaky([http.ClientException(dropped)], () => calls++)),
      throwsA(isA<NetworkException>()),
    );
    expect(calls, 1);
  });

  test('si el segundo intento también falla, avisa con un mensaje claro y no con el error técnico', () async {
    var calls = 0;
    await expectLater(
      sendApiRequest(flaky([http.ClientException(dropped)], () => calls++), retry: true),
      throwsA(
        isA<NetworkException>().having((e) => e.message, 'message', 'Se cortó la conexión con el servidor. Intenta de nuevo.'),
      ),
    );
    expect(calls, 2);
  });

  test('un error del servidor no se repite', () async {
    var calls = 0;
    await expectLater(
      sendApiRequest(flaky([http.Response('{}', 500)], () => calls++), retry: true),
      throwsA(isA<ServerException>()),
    );
    expect(calls, 1);
  });
}
