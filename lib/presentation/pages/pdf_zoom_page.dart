import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../components/components.dart';

/// Convierte el PDF en una imagen PNG por página (para poder acercarla).
typedef PdfPageRasterizer = Future<List<Uint8List>> Function(Uint8List pdf);

/// Rasteriza con el motor del teléfono a 220 ppp: con eso el texto pequeño de un comprobante
/// sigue nítido hasta unas 4 veces de acercamiento.
Future<List<Uint8List>> rasterizePdfPages(Uint8List pdf) async {
  final pages = <Uint8List>[];
  await for (final page in Printing.raster(pdf, dpi: 220)) {
    pages.add(await page.toPng());
  }
  return pages;
}

/// Abre el PDF en una pantalla para acercarlo con la lupa: se pellizca con dos dedos, se toca
/// dos veces (acerca o vuelve al tamaño normal) y se arrastra para moverse por la hoja.
Future<void> openPdfZoom(
  BuildContext context, {
  required Uint8List pdf,
  required String title,
  String? subtitle,
  @visibleForTesting PdfPageRasterizer? rasterizer,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PdfZoomPage(
        pdf: pdf,
        title: title,
        subtitle: subtitle,
        rasterizer: rasterizer ?? rasterizePdfPages,
      ),
    ),
  );
}

class PdfZoomPage extends StatefulWidget {
  final Uint8List pdf;
  final String title;
  final String? subtitle;
  final PdfPageRasterizer rasterizer;

  const PdfZoomPage({
    super.key,
    required this.pdf,
    required this.title,
    this.subtitle,
    required this.rasterizer,
  });

  @override
  State<PdfZoomPage> createState() => _PdfZoomPageState();
}

class _PdfZoomPageState extends State<PdfZoomPage>
    with SingleTickerProviderStateMixin {
  static const _doubleTapScale = 3.0;

  final _transform = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late Future<List<Uint8List>> _pages = widget.rasterizer(widget.pdf);
  Offset _doubleTapAt = Offset.zero;

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.05;

  void _animateTo(Matrix4 end) {
    final tween = Matrix4Tween(begin: _transform.value, end: end);
    final curved = CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic);
    void tick() => _transform.value = tween.evaluate(curved);
    _animation
      ..reset()
      ..addListener(tick);
    _animation.forward().whenComplete(() {
      _animation.removeListener(tick);
      curved.dispose();
    });
  }

  /// Dos toques: si ya está acercado vuelve al tamaño normal; si no, acerca hacia donde se tocó.
  void _toggleZoom() {
    if (_zoomed) {
      _animateTo(Matrix4.identity());
    } else {
      final p = _doubleTapAt;
      _animateTo(
        Matrix4.identity()
          ..translateByDouble(
            -p.dx * (_doubleTapScale - 1),
            -p.dy * (_doubleTapScale - 1),
            0,
            1,
          )
          ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1),
      );
    }
  }

  void _reset() => _animateTo(Matrix4.identity());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      body: Column(
        children: [
          AppPageHeader(
            icon: Icons.zoom_in,
            title: widget.title,
            subtitle: widget.subtitle ?? 'Pellizca o toca dos veces para acercar',
            trailing: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Uint8List>>(
              future: _pages,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const AppSkeletonDetail();
                }
                final pages = snapshot.data;
                if (snapshot.hasError || pages == null || pages.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'No se pudo acercar el documento',
                    message: 'Vuelve al PDF e inténtalo otra vez.',
                    action: AppButton(
                      label: 'Reintentar',
                      icon: Icons.refresh,
                      onPressed: () {
                        final again = widget.rasterizer(widget.pdf);
                        setState(() {
                          _pages = again;
                        });
                      },
                    ),
                  );
                }
                return _viewer(pages);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _transform,
        builder: (context, _) => AnimatedScale(
          scale: _zoomed ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: FloatingActionButton.small(
            tooltip: 'Tamaño normal',
            onPressed: _zoomed ? _reset : null,
            child: const Icon(Icons.zoom_out_map),
          ),
        ),
      ),
    );
  }

  Widget _viewer(List<Uint8List> pages) {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 6,
          constrained: false,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final page in pages)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Material(
                      elevation: 3,
                      color: Colors.white,
                      child: Image.memory(
                        page,
                        width: constraints.maxWidth - 16,
                        fit: BoxFit.fitWidth,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
