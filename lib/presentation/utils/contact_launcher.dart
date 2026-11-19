import 'package:url_launcher/url_launcher.dart';

/// Abre otra app para contactar al cliente: el marcador (`tel:`), el correo (`mailto:`) o WhatsApp
/// (`https://wa.me/51…`). [open] se puede cambiar en las pruebas (ahí no hay plataforma).
class ContactLauncher {
  ContactLauncher._();

  /// Abre [uri] fuera de la app; `false` si no hay nada que lo abra.
  static Future<bool> Function(Uri uri) open = _open;

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Llama al [phone]: se dejan solo los dígitos y el `+`, como la web.
  static Future<bool> call(String phone) => open(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')));

  static Future<bool> email(String address) => open(Uri(scheme: 'mailto', path: address.trim()));

  /// Abre el chat de WhatsApp con [number] (el que da [whatsappNumber]).
  static Future<bool> whatsapp(String number) => open(Uri.parse('https://wa.me/$number'));

  /// El número de WhatsApp de un teléfono peruano (`51` + 9 dígitos): un celular de 9 dígitos que empieza
  /// con 9, con o sin el 51 delante y con cualquier separador. `null` si no se reconoce uno (un fijo, un
  /// número cortado): no se ofrece WhatsApp.
  static String? whatsappNumber(String? phone) {
    var digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('51')) digits = digits.substring(2);
    if (digits.length == 9 && digits.startsWith('9')) return '51$digits';
    return null;
  }
}
