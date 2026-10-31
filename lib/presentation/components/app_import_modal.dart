import 'dart:async';
import 'package:flutter/material.dart';
import 'app_disposer.dart';
import 'app_modal.dart';

/// Modal para subir un archivo de importación (productos, marcas, categorías):
/// descarga de la plantilla, elección del archivo y botón de subir, que solo se
/// habilita cuando hay un archivo elegido.
///
/// [onPickFile] devuelve el nombre del archivo elegido (o `null` si se cancela);
/// [onUpload] recibe ese nombre y sube el archivo: devuelve `null` si salió bien, o el motivo
/// del rechazo, que se muestra dentro del modal (que sigue abierto para reintentar).
Future<bool?> showAppImportModal(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.upload_outlined,
  required String templateName,
  VoidCallback? onDownloadTemplate,
  required Future<String?> Function() onPickFile,
  required FutureOr<String?> Function(String fileName) onUpload,
  String uploadLabel = 'Subir',
}) {
  final fileName = ValueNotifier<String?>(null);
  final enabled = ValueNotifier<bool>(false);
  final error = ValueNotifier<String?>(null);

  return showAppModal(
    context,
    title: title,
    subtitle: subtitle,
    icon: icon,
    primaryLabel: uploadLabel,
    primaryEnabled: enabled,
    error: error,
    onPrimary: () async {
      error.value = null;
      final problem = await onUpload(fileName.value!);
      if (problem != null) {
        error.value = problem;
        // Mantiene el modal abierto para elegir otro archivo o reintentar.
        throw StateError(problem);
      }
    },
    child: AppDisposer(
      onDispose: [fileName.dispose, enabled.dispose, error.dispose],
      child: _ImportBody(
        templateName: templateName,
        fileName: fileName,
        enabled: enabled,
        error: error,
        onDownloadTemplate: onDownloadTemplate,
        onPickFile: onPickFile,
      ),
    ),
  );
}

class _ImportBody extends StatelessWidget {
  final String templateName;
  final ValueNotifier<String?> fileName;
  final ValueNotifier<bool> enabled;
  final ValueNotifier<String?> error;
  final VoidCallback? onDownloadTemplate;
  final Future<String?> Function() onPickFile;

  const _ImportBody({
    required this.templateName,
    required this.fileName,
    required this.enabled,
    required this.error,
    required this.onDownloadTemplate,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Descarga la plantilla, complétala y súbela en formato Excel (.xlsx).',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onDownloadTemplate,
            icon: const Icon(Icons.download_outlined, size: 20),
            label: Text('Descargar $templateName'),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<String?>(
          valueListenable: fileName,
          builder: (context, name, _) => InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await onPickFile();
              // Si cancela el selector se conserva el archivo que ya había.
              if (picked == null) return;
              fileName.value = picked;
              enabled.value = true;
              error.value = null;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outline),
              ),
              child: Column(
                children: [
                  Icon(
                    name == null ? Icons.cloud_upload_outlined : Icons.description_outlined,
                    size: 36,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name ?? 'Toca para elegir un archivo',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: name == null ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
