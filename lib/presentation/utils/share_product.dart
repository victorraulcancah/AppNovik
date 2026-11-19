import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../core/constants/api_constants.dart';
import '../../domain/entities/product_entity.dart';
import '../widgets/product_image.dart';

/// El texto que se manda de un producto: su código y su descripción.
String productShareText(ProductEntity p) => [
      if (p.codigo.isNotEmpty) 'Cód: ${p.codigo}',
      if (p.name.isNotEmpty) 'Descripción: ${p.name}',
    ].join('\n');

String _extensionOf(String path) {
  final clean = path.split('?').first.toLowerCase();
  for (final ext in const ['png', 'webp', 'gif', 'jpeg', 'jpg']) {
    if (clean.endsWith('.$ext')) return ext;
  }
  return 'jpg';
}

/// Compartir un producto con el menú del sistema (WhatsApp, correo…): su foto, su código y su descripción.
/// Sin foto, o si no se puede bajar, se manda solo el texto. [share] se cambia en las pruebas.
class ProductSharer {
  ProductSharer._();

  static Future<void> Function(ProductEntity product) share = _share;

  /// Baja la foto del producto; `null` si no tiene o falla (se comparte solo el texto).
  static Future<({Uint8List bytes, String ext})?> _photo(ProductEntity p) async {
    final path = p.imagen;
    if (path == null) return null;
    try {
      final response = await http.get(
        Uri.parse(ProductImage.urlOf(path)),
        headers: {if (ApiConstants.apiHost.isNotEmpty) 'Host': ApiConstants.apiHost},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      return (bytes: response.bodyBytes, ext: _extensionOf(path));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _share(ProductEntity p) async {
    final photo = await _photo(p);
    final text = productShareText(p);
    final name = (p.codigo.isEmpty ? 'producto' : p.codigo).replaceAll(RegExp(r'[^\w.\-]+'), '_');
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: p.codigo.isEmpty ? p.name : p.codigo,
        files: photo == null
            ? null
            : [XFile.fromData(photo.bytes, name: '$name.${photo.ext}', mimeType: 'image/${photo.ext == 'jpg' ? 'jpeg' : photo.ext}')],
        fileNameOverrides: photo == null ? null : ['$name.${photo.ext}'],
      ),
    );
  }
}
