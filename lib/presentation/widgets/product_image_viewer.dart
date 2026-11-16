import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../utils/share_file.dart';
import 'product_image.dart';

/// Abre la foto de un producto a pantalla completa: se acerca con los dedos, se cierra con la X o
/// tocando el fondo, y se puede compartir en el mismo formato en que está guardada en el servidor.
Future<void> openProductImage(BuildContext context, {required String path, String? title}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) => ProductImageViewer(path: path, title: title),
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

  const ProductImageViewer({super.key, required this.path, this.title});

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
      await shareDownloadedFile(DownloadedFile(name: name, bytes: response.bodyBytes));
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: SafeArea(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    ProductImage.urlOf(widget.path),
                    headers: _headers,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator(color: Colors.white)),
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cerrar',
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (widget.title != null)
                    Expanded(
                      child: Text(
                        widget.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
                      ),
                    )
                  else
                    const Spacer(),
                  IconButton(
                    tooltip: 'Compartir imagen',
                    color: Colors.white,
                    icon: _sharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.share_outlined),
                    onPressed: _sharing ? null : _share,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
