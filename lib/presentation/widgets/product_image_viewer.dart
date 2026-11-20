import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../utils/share_file.dart';
import '../utils/share_product.dart';
import 'product_image.dart';

/// Pone la imagen sobre un fondo blanco. Las fotos sin fondo (PNG/WebP transparentes) se verían con
/// fondo negro en WhatsApp y otras apps al compartirlas; así salen siempre sobre blanco. Devuelve los
/// bytes de un PNG, o `null` si no se pudo leer la imagen (entonces se comparte tal cual).
Future<Uint8List?> flattenOnWhite(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(image.width.toDouble(), image.height.toDouble());
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    canvas.drawImage(image, Offset.zero, Paint());
    final flat = await recorder.endRecording().toImage(image.width, image.height);
    final data = await flat.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    flat.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Abre la foto de un producto a pantalla completa: se acerca con los dedos, se cierra con la X o
/// tocando el fondo, y se puede compartir en una imagen con fondo blanco.
Future<void> openProductImage(BuildContext context, {required String path, String? title, String? code}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.white,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) => ProductImageViewer(path: path, title: title, code: code),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class ProductImageViewer extends StatefulWidget {
  final String path;
  final String? title;

  /// Código del producto: se manda junto con la descripción al compartir la foto.
  final String? code;

  const ProductImageViewer({super.key, required this.path, this.title, this.code});

  @override
  State<ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<ProductImageViewer> {
  bool _sharing = false;

  Map<String, String> get _headers => {
        if (ApiConstants.apiHost.isNotEmpty) 'Host': ApiConstants.apiHost,
      };

  /// Baja la foto tal como está guardada y la comparte (WhatsApp, correo...).
  Future<void> _share() async {
    if (_sharing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      final response = await http.get(Uri.parse(ProductImage.urlOf(widget.path)), headers: _headers);
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final name = widget.path.split('/').last;
      // Con fondo blanco (las fotos sin fondo saldrían negras al compartirlas).
      final flat = await flattenOnWhite(response.bodyBytes);
      final file = flat == null
          ? DownloadedFile(name: name, bytes: response.bodyBytes)
          : DownloadedFile(name: '${name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name}.png', bytes: flat);
      await shareDownloadedFile(file, text: shareTextOf(code: widget.code, description: widget.title));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No se pudo compartir la imagen')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Las fotos de los productos se suben con fondo blanco: el visor también es blanco, así la foto
    // se funde con el fondo en lugar de quedar en un recuadro.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: SafeArea(
              child: Padding(
                // Deja libre arriba (botones) y abajo (nombre) para que no se encimen con la foto.
                padding: const EdgeInsets.only(top: 56, bottom: 96),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      ProductImage.urlOf(widget.path),
                      headers: _headers,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, _, _) => Icon(
                        Icons.image_not_supported_outlined,
                        color: scheme.outline,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Arriba: cerrar y compartir.
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Cerrar',
                      color: Colors.black87,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Compartir imagen',
                      color: Colors.black87,
                      icon: _sharing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.share_outlined),
                      onPressed: _sharing ? null : _share,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Abajo: el nombre del producto, completo.
          if (widget.title != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Text(
                    widget.title!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
