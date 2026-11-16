import 'package:flutter/material.dart';

import '../utils/barcode_scanner.dart';
import '../utils/voice_search.dart';
import 'barcode_scanner_icon.dart';

/// Campo de búsqueda Material 3 para listas, con botón de filtros opcional a la
/// derecha. [filterActive] marca el botón cuando hay filtros aplicados.
class AppSearchBar extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilter;
  final bool filterActive;

  /// Cuántos filtros hay puestos: el botón muestra ese número en una insignia. Con 0 se usa
  /// [filterActive] (un punto) para quien no cuenta sus filtros.
  final int filterCount;

  /// Otros botones junto al de filtros (por ejemplo, descargar el Excel).
  final List<Widget> actions;

  /// Con esto el campo lleva el botón de escanear un código de barras con la cámara; recibe el
  /// código leído.
  final ValueChanged<String>? onScanned;

  /// El micrófono dentro del campo para buscar hablando (solo si hay [controller]).
  final bool voice;

  const AppSearchBar({
    super.key,
    this.hint = 'Buscar',
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onFilter,
    this.filterActive = false,
    this.filterCount = 0,
    this.actions = const [],
    this.onScanned,
    this.voice = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SearchBar(
              controller: controller,
              hintText: hint,
              elevation: const WidgetStatePropertyAll(0),
              leading: const Icon(Icons.search),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              trailing: [
                if (voice && controller != null)
                  VoiceSearchButton(
                    onResult: (text) {
                      controller!.text = text;
                      onChanged?.call(text);
                    },
                  ),
              ],
            ),
          ),
          // El escáner de código de barras va a la derecha del campo, donde van los filtros.
          if (onScanned != null) ...[
            const SizedBox(width: 4),
            BarcodeScanButton(onScanned: onScanned!),
          ],
          if (onFilter != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Filtros',
              onPressed: onFilter,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Badge(
                isLabelVisible: filterActive || filterCount > 0,
                smallSize: 8,
                label: filterCount > 0 ? Text('$filterCount') : null,
                child: const Icon(Icons.filter_list),
              ),
            ),
          ],
          ...actions,
        ],
      ),
    );
  }
}

/// Botón de la cámara para escanear un código de barras: el ícono del escáner (esquinas con las
/// barras) en un cuadrado redondeado.
class BarcodeScanButton extends StatelessWidget {
  final ValueChanged<String> onScanned;

  const BarcodeScanButton({super.key, required this.onScanned});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Escanear código de barras',
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const BarcodeScannerIcon(size: 26),
      onPressed: () async {
        final code = await BarcodeScanner.scan(context);
        if (code != null && code.isNotEmpty) onScanned(code);
      },
    );
  }
}

/// Botón del micrófono para buscar hablando: devuelve lo que se dijo.
class VoiceSearchButton extends StatelessWidget {
  final ValueChanged<String> onResult;

  const VoiceSearchButton({super.key, required this.onResult});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Buscar por voz',
      icon: const Icon(Icons.mic_none),
      onPressed: () async {
        final said = await VoiceSearch.listen(context);
        if (said != null && said.trim().isNotEmpty) onResult(said.trim());
      },
    );
  }
}
