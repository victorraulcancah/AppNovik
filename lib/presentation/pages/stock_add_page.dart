import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/stock_manage_entity.dart';
import '../components/components.dart';
import '../providers/stock_provider.dart';
import '../utils/download_file.dart';
import '../utils/import_file.dart';
import '../utils/success_snack.dart';
import '../widgets/stock_operations_modals.dart';
import '../widgets/stock_product_search.dart';

/// "Agregar Stock" de la web: se elige el almacén, se buscan productos y se anota cuántas
/// unidades entran y a qué costo; al guardar se registra el aumento (`POST /stock`). También
/// permite bajar la plantilla de Excel y subir los stocks desde un archivo.
class StockAddPage extends StatefulWidget {
  /// Selector del Excel a subir; se cambia en las pruebas.
  final Future<PickedImportFile?> Function() pickFile;

  const StockAddPage({super.key, this.pickFile = pickImportFile});

  @override
  State<StockAddPage> createState() => _StockAddPageState();
}

class _StockAddPageState extends State<StockAddPage> {
  int? _warehouseId;
  List<StockEntryLine> _lines = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _warehouseId = context.read<StockProvider>().warehouseId;
  }

  String get _warehouseName {
    for (final w in context.read<StockProvider>().warehouses) {
      if (w.id == _warehouseId) return w.name;
    }
    return '';
  }

  double get _total => _lines.fold(0, (sum, l) => sum + l.totalCosto);

  bool get _canSave => !_saving && _lines.isNotEmpty && _lines.every((l) => l.stock >= 1);

  /// Como en la web: un producto repetido suma una unidad; uno nuevo entra con 1 unidad y el
  /// costo de su última entrada de stock.
  void _add(StockProductEntity product) {
    setState(() {
      final i = _lines.indexWhere((l) => l.product.id == product.id);
      if (i >= 0) {
        _lines = [
          for (var j = 0; j < _lines.length; j++)
            if (j == i) _lines[j].copyWith(stock: _lines[j].stock + 1) else _lines[j],
        ];
      } else {
        _lines = [..._lines, StockEntryLine(product: product, costo: product.ultimoCosto)];
      }
    });
    HapticFeedback.selectionClick();
  }

  void _change(StockEntryLine line) {
    setState(() {
      _lines = [for (final l in _lines) if (l.product.id == line.product.id) line else l];
    });
  }

  void _remove(StockEntryLine line) {
    setState(() => _lines = [for (final l in _lines) if (l.product.id != line.product.id) l]);
  }

  Future<void> _save() async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Confirmar',
      message: '¿Desea confirmar el aumento de Stock?',
      confirmLabel: 'Confirmar',
      tone: AppModalTone.normal,
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    final problem = await context.read<StockProvider>().addStock(_warehouseId, _lines);
    if (!mounted) return;
    setState(() => _saving = false);

    if (problem != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    showSuccessSnack(context, 'Stock Registrado');
    Navigator.of(context).pop(true);
  }

  Future<void> _template() async {
    final result = await context.read<StockProvider>().downloadStockTemplate();
    if (!mounted) return;
    if (result.isLeft) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.left.message)));
      return;
    }
    await downloadFile(context, result.right);
  }

  Future<void> _upload() {
    return showStockImport(
      context,
      stock: context.read<StockProvider>(),
      warehouseId: _warehouseId,
      warehouseName: _warehouseName,
      pickFile: widget.pickFile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar stock')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdownField<int>(
                    key: ValueKey('almacen-$_warehouseId'),
                    label: 'Almacén seleccionado',
                    value: _warehouseId,
                    items: [
                      for (final w in stock.warehouses)
                        DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _saving ? null : (id) => setState(() => _warehouseId = id),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _template,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Plantilla'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _saving || _warehouseId == null ? null : _upload,
                          icon: const Icon(Icons.file_upload_outlined, size: 18),
                          label: const Text('Subir stocks'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StockProductSearch(
                    enabled: !_saving,
                    search: stock.searchProducts,
                    detail: (p) {
                      final id = _warehouseId;
                      if (id == null || !p.existeEn(id)) return '';
                      return 'En el almacén: ${formatQuantity(p.stockEn(id))}';
                    },
                    onPick: _add,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _lines.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.add_box_outlined,
                      title: 'Aún no hay productos',
                      message: 'Busca un producto y tócalo para sumarle stock.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _EntryLineTile(
                        key: ValueKey('linea-${_lines[i].product.id}'),
                        line: _lines[i],
                        enabled: !_saving,
                        onChanged: _change,
                        onRemove: () => _remove(_lines[i]),
                      ),
                    ),
            ),
            Material(
              color: scheme.surfaceContainerLowest,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total costo',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            formatMoney(_total, symbol: 'S/.'),
                            key: const ValueKey('total-costo'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: AppButton(
                        label: 'Guardar',
                        icon: Icons.save_outlined,
                        loading: _saving,
                        onPressed: _canSave ? _save : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una línea del aumento: producto, costo por unidad y cantidad, con su botón de quitar.
class _EntryLineTile extends StatefulWidget {
  final StockEntryLine line;
  final bool enabled;
  final ValueChanged<StockEntryLine> onChanged;
  final VoidCallback onRemove;

  const _EntryLineTile({
    super.key,
    required this.line,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_EntryLineTile> createState() => _EntryLineTileState();
}

class _EntryLineTileState extends State<_EntryLineTile> {
  late final TextEditingController _stock = TextEditingController(text: '${widget.line.stock}');
  late final TextEditingController _costo = TextEditingController(
    text: widget.line.costo == null || widget.line.costo == 0 ? '' : _decimal(widget.line.costo!),
  );

  static String _decimal(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  @override
  void didUpdateWidget(_EntryLineTile old) {
    super.didUpdateWidget(old);
    // El padre sumó una unidad (el mismo producto tocado otra vez): se refleja en el campo.
    if (widget.line.stock != (int.tryParse(_stock.text) ?? 0) && widget.line.stock != old.line.stock) {
      _stock.text = '${widget.line.stock}';
    }
  }

  @override
  void dispose() {
    _stock.dispose();
    _costo.dispose();
    super.dispose();
  }

  void _emit() {
    final stock = int.tryParse(_stock.text.trim()) ?? 0;
    final costo = double.tryParse(_costo.text.trim().replaceAll(',', '.'));
    widget.onChanged(
      StockEntryLine(product: widget.line.product, stock: stock, costo: costo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.line.product;
    final invalid = widget.line.stock < 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        [if (p.codigo.isNotEmpty) p.codigo, if (p.marca != null) p.marca!].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar',
                onPressed: widget.enabled ? widget.onRemove : null,
                icon: Icon(Icons.delete_outline, color: scheme.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('campo-costo'),
                    controller: _costo,
                    enabled: widget.enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}([.,]\d{0,2})?'))],
                    decoration: const InputDecoration(
                      labelText: 'Costo / U',
                      prefixText: 'S/. ',
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('campo-stock'),
                    controller: _stock,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Stock',
                      errorText: invalid ? 'Mínimo 1' : null,
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
