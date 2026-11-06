import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/other_document_entity.dart';
import '../../domain/entities/stock_manage_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/other_documents_provider.dart';
import '../providers/stock_provider.dart';
import '../utils/success_snack.dart';
import '../widgets/other_document_modals.dart';
import '../widgets/stock_product_search.dart';

/// "Transferir Stock" de la web: se elige el almacén de origen y el de destino, se buscan los
/// productos y cuántas unidades salen de cada uno, y al confirmar se crea el traslado
/// (`POST /stock-transfer`).
class StockTransferPage extends StatefulWidget {
  const StockTransferPage({super.key});

  @override
  State<StockTransferPage> createState() => _StockTransferPageState();
}

class _StockTransferPageState extends State<StockTransferPage> {
  int? _from;
  int? _to;
  List<StockTransferLine> _lines = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _from = context.read<StockProvider>().warehouseId;
  }

  String _nameOf(int? id) {
    for (final w in context.read<StockProvider>().warehouses) {
      if (w.id == id) return w.name;
    }
    return '';
  }

  /// Las líneas cuyo producto no está en el almacén de origen no se transfieren (la web las
  /// pinta de rojo).
  bool _considered(StockTransferLine l) => _from != null && l.product.existeEn(_from!);

  double _max(StockTransferLine l) => _from == null ? 0 : l.product.stockEn(_from!);

  bool _valid(StockTransferLine l) => l.cantidad >= 1 && l.cantidad <= _max(l);

  List<StockTransferLine> get _toSend => _lines.where(_considered).toList();

  bool get _canSave =>
      !_saving &&
      _from != null &&
      _to != null &&
      _from != _to &&
      _toSend.isNotEmpty &&
      _toSend.every(_valid);

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _changeFrom(int? id) {
    setState(() {
      _from = id;
      // No se puede transferir al mismo almacén.
      if (_to == id) _to = null;
      // Si la cantidad pedida supera lo que hay en el nuevo origen, baja a lo que hay.
      _lines = [
        for (final l in _lines)
          if (id != null && l.product.existeEn(id) && l.cantidad > l.product.stockEn(id))
            l.copyWith(cantidad: l.product.stockEn(id))
          else
            l,
      ];
    });
  }

  void _add(StockProductEntity product) {
    final from = _from;
    if (from == null) return _snack('Elige primero el almacén de origen');
    // Como la web: solo se agregan productos que tengan stock en el origen.
    if (!product.existeEn(from) || product.stockEn(from) <= 0) {
      return _snack('No hay stock disponible en ${_nameOf(from)}');
    }
    final i = _lines.indexWhere((l) => l.product.id == product.id);
    if (i >= 0 && _lines[i].cantidad + 1 > product.stockEn(from)) {
      return _snack('Stock insuficiente');
    }
    setState(() {
      if (i >= 0) {
        _lines = [
          for (var j = 0; j < _lines.length; j++)
            if (j == i) _lines[j].copyWith(cantidad: _lines[j].cantidad + 1) else _lines[j],
        ];
      } else {
        _lines = [..._lines, StockTransferLine(product: product)];
      }
    });
    HapticFeedback.selectionClick();
  }

  void _change(StockTransferLine line) {
    setState(() {
      _lines = [for (final l in _lines) if (l.product.id == line.product.id) line else l];
    });
  }

  void _remove(StockTransferLine line) {
    setState(() => _lines = [for (final l in _lines) if (l.product.id != line.product.id) l]);
  }

  bool get _showAmounts {
    final roles = context.read<AuthProvider>().session?.roles ?? const [];
    return !roles.any((r) => r.toLowerCase() == 'jefe de almacén');
  }

  Future<void> _transfer() async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Confirmar',
      message: '¿Desea confirmar la Transferencia de Stock?',
      subtitle: '${_nameOf(_from)} → ${_nameOf(_to)}',
      confirmLabel: 'Confirmar',
      tone: AppModalTone.normal,
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    final result = await context.read<StockProvider>().transferStock(
          from: _from,
          to: _to,
          lines: _toSend,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isLeft) return _snack(result.left.message);

    final document = result.right;
    // Si ya se miraron los traslados en Documentos, la lista se actualiza con el nuevo.
    final others = context.read<OtherDocumentsProvider?>();
    if (others != null && others.stateOf(OtherDocumentKind.traslado).loadedOnce) {
      others.refresh(OtherDocumentKind.traslado);
    }
    showSuccessSnack(context, 'Stock Transferido');
    setState(() {
      _lines = [];
      _to = null;
    });
    await showOtherDocumentDetail(context, document, showAmounts: _showAmounts);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Transferir stock')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdownField<int>(
                    key: ValueKey('origen-$_from'),
                    label: 'Desde',
                    value: _from,
                    items: [
                      for (final w in stock.warehouses)
                        DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _saving ? null : _changeFrom,
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<int>(
                    key: ValueKey('destino-$_to-$_from'),
                    label: 'Hacia',
                    value: _to,
                    // El destino no puede ser el origen.
                    items: [
                      for (final w in stock.warehouses)
                        if (w.id != _from)
                          DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name, overflow: TextOverflow.ellipsis),
                          ),
                    ],
                    onChanged: _saving ? null : (id) => setState(() => _to = id),
                  ),
                  const SizedBox(height: 12),
                  StockProductSearch(
                    enabled: !_saving,
                    search: stock.searchProducts,
                    detail: (p) {
                      final from = _from;
                      if (from == null) return '';
                      final name = _nameOf(from);
                      return p.existeEn(from)
                          ? '$name: ${formatQuantity(p.stockEn(from))}'
                          : 'Sin stock en $name';
                    },
                    onPick: _add,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _lines.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.swap_horiz,
                      title: 'Aún no hay productos',
                      message: 'Busca un producto del almacén de origen y tócalo para transferirlo.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final line = _lines[i];
                        return _TransferLineTile(
                          key: ValueKey('linea-${line.product.id}'),
                          line: line,
                          considered: _considered(line),
                          max: _max(line),
                          enabled: !_saving,
                          originName: _nameOf(_from),
                          onChanged: _change,
                          onRemove: () => _remove(line),
                        );
                      },
                    ),
            ),
            Material(
              color: scheme.surfaceContainerLowest,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: AppButton(
                  label: 'Transferir',
                  icon: Icons.swap_horiz,
                  loading: _saving,
                  onPressed: _canSave ? _transfer : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una línea de la transferencia: producto y cantidad (con su máximo en el origen).
class _TransferLineTile extends StatefulWidget {
  final StockTransferLine line;
  final bool considered;
  final double max;
  final bool enabled;
  final String originName;
  final ValueChanged<StockTransferLine> onChanged;
  final VoidCallback onRemove;

  const _TransferLineTile({
    super.key,
    required this.line,
    required this.considered,
    required this.max,
    required this.enabled,
    required this.originName,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_TransferLineTile> createState() => _TransferLineTileState();
}

class _TransferLineTileState extends State<_TransferLineTile> {
  late final TextEditingController _cantidad =
      TextEditingController(text: formatQuantity(widget.line.cantidad));

  @override
  void didUpdateWidget(_TransferLineTile old) {
    super.didUpdateWidget(old);
    // El padre cambió la cantidad (tocó el producto otra vez o ajustó al nuevo origen).
    final typed = double.tryParse(_cantidad.text.replaceAll(',', '.')) ?? 0;
    if (widget.line.cantidad != typed && widget.line.cantidad != old.line.cantidad) {
      _cantidad.text = formatQuantity(widget.line.cantidad);
    }
  }

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.line.product;
    final cantidad = widget.line.cantidad;

    String? error;
    if (widget.considered) {
      if (cantidad < 1) {
        error = 'Mínimo 1';
      } else if (cantidad > widget.max) {
        error = 'Stock insuficiente (máx. ${formatQuantity(widget.max)})';
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.considered ? scheme.outlineVariant : scheme.error),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: widget.considered ? null : scheme.error,
                        ),
                      ),
                      Text(
                        [if (p.codigo.isNotEmpty) p.codigo, if (p.marca != null) p.marca!].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if (!widget.considered)
                        Text(
                          'No está en ${widget.originName}: no se transfiere',
                          key: const ValueKey('fuera-del-origen'),
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
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
          if (widget.considered) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                key: const ValueKey('campo-cantidad'),
                controller: _cantidad,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}([.,]\d{0,2})?'))],
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  helperText: 'Disponible: ${formatQuantity(widget.max)}',
                  errorText: error,
                ),
                onChanged: (text) => widget.onChanged(
                  widget.line.copyWith(cantidad: double.tryParse(text.replaceAll(',', '.')) ?? 0),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
