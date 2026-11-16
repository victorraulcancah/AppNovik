import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pantalla de la cámara para leer un código de barras: se apunta al código dentro del marco y,
/// al leerlo, se cierra devolviendo su texto. Tiene linterna y cambio de cámara.
class BarcodeScanPage extends StatefulWidget {
  const BarcodeScanPage({super.key});

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf14,
      BarcodeFormat.codabar,
      BarcodeFormat.qrCode,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _done = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  Widget _error(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Permite el acceso a la cámara en los ajustes del teléfono para escanear códigos de barras.'
                    : 'No se pudo abrir la cámara.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final frameWidth = size.width * 0.82;
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: frameWidth,
      height: frameWidth * 0.62,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: _error,
            scanWindow: frame,
          ),
          IgnorePointer(child: CustomPaint(painter: _FramePainter(frame))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Linterna',
                    color: Colors.white,
                    icon: const Icon(Icons.flash_on_outlined),
                    onPressed: _controller.toggleTorch,
                  ),
                  IconButton(
                    tooltip: 'Cambiar de cámara',
                    color: Colors.white,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    onPressed: _controller.switchCamera,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: frame.bottom + 24,
            child: Text(
              'Mantén el código de barras dentro del marco para escanearlo',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Oscurece todo menos el marco y le dibuja las cuatro esquinas.
class _FramePainter extends CustomPainter {
  final Rect frame;
  const _FramePainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(16));
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = Colors.black.withValues(alpha: 0.55));

    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const arm = 28.0;
    void corner(Offset c, double dx, double dy) {
      canvas.drawLine(c, c + Offset(dx * arm, 0), line);
      canvas.drawLine(c, c + Offset(0, dy * arm), line);
    }

    corner(frame.topLeft, 1, 1);
    corner(frame.topRight, -1, 1);
    corner(frame.bottomLeft, 1, -1);
    corner(frame.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.frame != frame;
}
