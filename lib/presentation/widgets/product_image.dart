import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';

/// La imagen de un producto, tal como la guarda el servidor (`/storage/images/...`), con la
/// cabecera `Host` de la API local cuando hace falta. Mientras llega se ve un fondo neutro y al
/// llegar aparece con un fundido; si falla, un ícono.
class ProductImage extends StatelessWidget {
  final String path;
  final double size;
  final double radius;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.path,
    this.size = 48,
    this.radius = 10,
    this.fit = BoxFit.cover,
  });

  /// La dirección completa de la imagen.
  static String urlOf(String path) =>
      path.startsWith('http') ? path : '${ApiConstants.baseDomain}$path';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Image.network(
          urlOf(path),
          width: size,
          height: size,
          fit: fit,
          headers: {
            if (ApiConstants.apiHost.isNotEmpty) 'Host': ApiConstants.apiHost,
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (still || wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (_, _, _) => SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.image_not_supported_outlined,
              size: size * 0.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// La imagen grande del detalle: crece y aparece con un fundido, como si saliera de la miniatura
/// de la lista. (Un `Hero` no sirve aquí: el detalle se abre como modal o panel y no como una
/// pantalla, y Flutter solo anima héroes entre pantallas.) Con "quitar animaciones" sale directa.
class ProductImageGrow extends StatelessWidget {
  final String path;
  final String? semanticLabel;
  final double size;

  const ProductImageGrow({
    super.key,
    required this.path,
    this.semanticLabel,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    final image = Semantics(
      image: true,
      label: semanticLabel,
      child: ProductImage(path: path, size: size, radius: 16),
    );
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return image;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: image,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.55 + 0.45 * t, child: child),
      ),
    );
  }
}
