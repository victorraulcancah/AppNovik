import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/entities/stock_manage_entity.dart';
import '../components/components.dart';
import '../providers/stock_provider.dart';
import '../utils/download_file.dart';
import '../utils/import_file.dart';
import '../utils/success_snack.dart';
import 'stock_modals.dart' show stockLabel;

/// "Actualizar" de la lista de stock de la web: se escribe el stock que debe quedar y la app
/// manda la diferencia (`POST /stock`) con el costo que usa la web. El costo solo se muestra a
/// quien puede ver costos. Devuelve `true` si se actualizó.
Future<bool?> showStockUpdate(
  BuildContext context, {
  required StockProvider stock,
  required StockItemEntity item,
  required String warehouseName,
  bool canSeeCost = false,
}) {
  final controller = TextEditingController(text: formatQuantity(item.disponible));
  final enabled = ValueNotifier<bool>(false);
  final error = ValueNotifier<String?>(null);
  final difference = ValueNotifier<double?>(null);

  double? parse() {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  void changed() {
    final value = parse();
    final diff = value == null ? null : value - item.disponible;
    difference.value = diff;
    // Se habilita cuando hay un valor entero de 0 en adelante y distinto al actual.
    enabled.value = value != null &&
        value >= 0 &&
        value == value.roundToDouble() &&
        diff != null &&
        diff != 0;
    error.value = null;
  }

  return showAppModal(
    context,
    title: 'Actualizar stock',
    subtitle: [if (item.codigo.isNotEmpty) item.codigo, item.name].join(' · '),
    icon: Icons.edit_note_outlined,
    primaryLabel: 'Actualizar',
    primaryEnabled: enabled,
    error: error,
    onPrimary: () async {
      final value = parse();
      if (value == null) {
        error.value = 'Escribe el stock que debe quedar';
        throw StateError('Sin stock');
      }
      final problem = await stock.updateStock(item, value);
      if (problem != null) {
        error.value = problem;
        // El modal sigue abierto con el motivo.
        throw StateError(problem);
      }
      if (context.mounted) showSuccessSnack(context, 'Cambio Registrado');
    },
    child: AppDisposer(
      onDispose: [controller.dispose, enabled.dispose, error.dispose, difference.dispose],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDetailRow(label: 'Almacén', value: warehouseName),
          AppDetailRow(label: 'Stock actual', value: stockLabel(item)),
          if (canSeeCost)
            AppDetailRow(label: 'Costo', value: formatMoney(stockUpdateCost(item), symbol: 'S/.')),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('stock-nuevo'),
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Stock nuevo', hintText: '0'),
            onChanged: (_) => changed(),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<double?>(
            valueListenable: difference,
            builder: (context, diff, _) {
              if (diff == null || diff == 0) return const SizedBox.shrink();
              final scheme = Theme.of(context).colorScheme;
              return Text(
                diff > 0 ? 'Se suman ${formatQuantity(diff)}' : 'Se restan ${formatQuantity(-diff)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: diff > 0 ? const Color(0xFF16A34A) : scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// "Subir Stocks" de la web: se descarga la plantilla, se elige el Excel y se sube al almacén
/// elegido. Al terminar muestra las filas leídas y las que fallaron.
Future<void> showStockImport(
  BuildContext context, {
  required StockProvider stock,
  required int? warehouseId,
  required String warehouseName,
  Future<PickedImportFile?> Function() pickFile = pickImportFile,
}) async {
  PickedImportFile? picked;
  StockImportResultEntity? result;

  await showAppImportModal(
    context,
    title: 'Subir stocks',
    subtitle: warehouseName.isEmpty ? 'Importación masiva' : 'Almacén: $warehouseName',
    icon: Icons.upload_outlined,
    templateName: 'plantilla de stocks',
    onDownloadTemplate: () async {
      final template = await stock.downloadStockTemplate();
      if (!context.mounted) return;
      if (template.isLeft) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(template.left.message)));
        return;
      }
      await downloadFile(context, template.right);
    },
    onPickFile: () async {
      final file = await pickFile();
      if (file == null) return null;
      picked = file;
      return file.name;
    },
    onUpload: (_) async {
      final file = picked;
      if (file == null) return 'Elige el archivo Excel';
      final response = await stock.importStock(
        warehouseId: warehouseId,
        fileName: file.name,
        bytes: file.bytes,
      );
      if (response.isLeft) return response.left.message;
      result = response.right;
      return null;
    },
  );

  final done = result;
  if (done == null || !context.mounted) return;
  if (!done.hasFailures) showSuccessSnack(context, 'Stocks subidos');
  await showStockImportResult(context, done);
}

/// Las filas del Excel de stocks que leyó el servidor, con el motivo en las que fallaron
/// (como la lista "Se subieron los Productos" de la web).
Future<void> showStockImportResult(BuildContext context, StockImportResultEntity result) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final failed = result.hasFailures;

  // Si el servidor no devolvió las filas, se muestran solo las que fallaron.
  final entries = result.rows.isNotEmpty
      ? [
          for (final r in result.rows)
            (
              codigo: r.codigo,
              costo: r.costo,
              stock: r.stock,
              failure: result.failureOf(r.row),
            ),
        ]
      : [
          for (final f in result.failures)
            (codigo: 'Fila ${f.row}', costo: null, stock: '', failure: f),
        ];

  return showAppModal(
    context,
    title: 'Se subieron los stocks',
    subtitle: failed ? 'Menos las filas con error' : null,
    icon: failed ? Icons.error_outline : Icons.check_circle_outline,
    tone: failed ? AppModalTone.warning : AppModalTone.normal,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
      child: entries.isEmpty
          ? const Text('El servidor no devolvió filas.')
          : ListView.separated(
              shrinkWrap: true,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 20),
              itemBuilder: (context, i) {
                final e = entries[i];
                final color = e.failure != null ? scheme.error : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.codigo,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if (e.costo != null)
                      Text(
                        'Costo: ${formatMoney(double.tryParse(e.costo!) ?? 0, symbol: 'S/.')}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (e.stock.isNotEmpty)
                      Text(
                        'Stock: ${e.stock}',
                        style: theme.textTheme.bodySmall?.copyWith(color: color),
                      ),
                    if (e.failure != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Error en fila ${e.failure!.row}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final error in e.failure!.errors)
                        Text('• $error', style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
                    ],
                  ],
                );
              },
            ),
    ),
  );
}
