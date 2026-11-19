import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/seller_payment_entity.dart';
import '../components/components.dart';
import '../providers/seller_payments_provider.dart';

/// `10/11/2026 03:05 pm`, como la web (`vista_fecha_hora`).
String sellerPaymentNoteDate(DateTime d) =>
    '${DateFormat('dd/MM/yyyy hh:mm').format(d)} ${d.hour >= 12 ? 'pm' : 'am'}';

/// Las notas de un pago ("Notas del pago" de la web): la "Descripción adicional" ya no es un texto que se
/// edita sino notas con autor y fecha. Se agregan (si el servidor deja escribir) y no se editan;
/// eliminar una no la borra: queda tachada con quién la eliminó y cuándo. Cada uno elimina las suyas
/// (`puede_eliminar` lo decide el servidor).
class SellerPaymentNotesSection extends StatefulWidget {
  final SellerPaymentsProvider payments;
  final int paymentId;

  /// Se avisa al agregar o eliminar una nota, para refrescar la lista cuando se cierre el modal.
  final VoidCallback? onChanged;

  const SellerPaymentNotesSection({
    super.key,
    required this.payments,
    required this.paymentId,
    this.onChanged,
  });

  @override
  State<SellerPaymentNotesSection> createState() => _SellerPaymentNotesSectionState();
}

class _SellerPaymentNotesSectionState extends State<SellerPaymentNotesSection> {
  final _text = TextEditingController();
  List<SellerPaymentNote> _notes = const [];
  bool _canWrite = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// La nota que se está editando (una a la vez), con su caja de texto, si se está guardando y el error
  /// del servidor (que no borra lo escrito).
  int? _editingId;
  TextEditingController? _editText;
  bool _editSaving = false;
  String? _editError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _editText?.dispose();
    super.dispose();
  }

  void _startEdit(SellerPaymentNote note) {
    // Una a la vez: abrir otra deja la anterior como estaba.
    final previous = _editText;
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    setState(() {
      _editingId = note.id;
      _editText = TextEditingController(text: note.texto);
      _editSaving = false;
      _editError = null;
    });
  }

  void _cancelEdit() {
    final controller = _editText;
    setState(() {
      _editingId = null;
      _editText = null;
      _editError = null;
    });
    // Se libera después de dibujar sin la caja.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller?.dispose());
  }

  Future<void> _saveEdit(SellerPaymentNote note) async {
    final texto = _editText?.text.trim() ?? '';
    if (texto.isEmpty || texto == note.texto.trim() || _editSaving) return;
    setState(() {
      _editSaving = true;
      _editError = null;
    });
    final result = await widget.payments.editNote(note.id, texto);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _editSaving = false;
        _editError = failure.message;
      }),
      (updated) {
        setState(() => _notes = [for (final n in _notes) n.id == updated.id ? updated : n]);
        _cancelEdit();
        widget.onChanged?.call();
      },
    );
  }

  Future<void> _load() async {
    final result = await widget.payments.loadNotes(widget.paymentId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold(
        (failure) => _error = failure.message,
        (data) {
          _notes = data.notas;
          _canWrite = data.puedeEscribir;
          _error = null;
        },
      );
    });
  }

  Future<void> _add() async {
    final texto = _text.text.trim();
    if (texto.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.payments.addNote(widget.paymentId, texto);
    if (!mounted) return;
    setState(() {
      _saving = false;
      result.fold(
        (failure) => _error = failure.message,
        (note) {
          _notes = [note, ..._notes];
          _text.clear();
          widget.onChanged?.call();
        },
      );
    });
  }

  Future<void> _delete(SellerPaymentNote note) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Eliminar nota',
      icon: Icons.delete_outline,
      message: '¿Eliminar esta nota?',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    setState(() => _error = null);
    final result = await widget.payments.deleteNote(note.id);
    if (!mounted) return;
    setState(() {
      result.fold(
        (failure) => _error = failure.message,
        (deleted) {
          _notes = [for (final n in _notes) n.id == deleted.id ? deleted : n];
          widget.onChanged?.call();
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Una nota eliminada ya no se ve (el servidor la conserva en su historial).
    final visibleNotes = [for (final n in _notes) if (!n.eliminada) n];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.chat_bubble_outline, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text('Notas del pago', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        if (_canWrite) ...[
          TextField(
            key: const ValueKey('nota-texto'),
            controller: _text,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nueva nota',
              hintText: 'Escribe una nota (queda con tu nombre y la fecha)',
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _text.text.trim().isEmpty || _saving ? null : _add,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              label: const Text('Agregar nota'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
          const SizedBox(height: 8),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visibleNotes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('Sin notas', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          )
        else
          for (final note in visibleNotes) ...[
            _NoteCard(
              key: ValueKey('nota-${note.id}'),
              note: note,
              onEdit: note.puedeEditar ? () => _startEdit(note) : null,
              onDelete: note.puedeEliminar ? () => _delete(note) : null,
              editController: _editingId == note.id ? _editText : null,
              editSaving: _editSaving,
              editError: _editingId == note.id ? _editError : null,
              onEditChanged: () => setState(() {}),
              onCancelEdit: _cancelEdit,
              onSaveEdit: () => _saveEdit(note),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final SellerPaymentNote note;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Con caja de texto, la nota está en edición (en esta misma tarjeta).
  final TextEditingController? editController;
  final bool editSaving;
  final String? editError;
  final VoidCallback onEditChanged;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;

  const _NoteCard({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.editController,
    required this.editSaving,
    required this.editError,
    required this.onEditChanged,
    required this.onCancelEdit,
    required this.onSaveEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final removed = note.eliminada;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final controller = editController;
    final editing = controller != null;
    final newText = controller?.text.trim() ?? '';
    // Guardar: no vacío y con cambios (el servidor también lo exige).
    final canSave = editing && !editSaving && newText.isNotEmpty && newText != note.texto.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
      decoration: BoxDecoration(
        color: removed ? scheme.surfaceContainerHighest.withValues(alpha: 0.5) : null,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: muted,
                    children: [
                      TextSpan(
                        // Nombre + inicial del apellido ("Gustavo M.").
                        text: note.autor == null || note.autor!.trim().isEmpty
                            ? 'Sin autor'
                            : shortPersonName(note.autor),
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                      ),
                      if (note.creado != null) TextSpan(text: '  ${sellerPaymentNoteDate(note.creado!)}'),
                    ],
                  ),
                ),
              ),
              if (onEdit != null && !editing)
                IconButton(
                  tooltip: 'Editar nota',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 18, color: scheme.primary),
                ),
              if (onDelete != null && !editing)
                IconButton(
                  tooltip: 'Eliminar nota',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
                )
              else if (onEdit == null || editing)
                const SizedBox(height: 8, width: 8),
            ],
          ),
          if (editing)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('nota-editar-texto'),
                    controller: controller,
                    maxLength: 1000,
                    minLines: 2,
                    maxLines: 5,
                    enabled: !editSaving,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) => onEditChanged(),
                    decoration: const InputDecoration(labelText: 'Editar nota'),
                  ),
                  if (editError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(editError!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: editSaving ? null : onCancelEdit,
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        // El tema los estira a todo el ancho: en una fila se achican.
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: canSave ? onSaveEdit : null,
                        child: editSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                note.texto,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: removed ? TextDecoration.lineThrough : null,
                  color: removed ? scheme.onSurfaceVariant : null,
                ),
              ),
            ),
          if (note.editada && !removed && !editing)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Text('Editada el ${sellerPaymentNoteDate(note.editadaEn!)}', style: muted),
            ),
          if (removed)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Text(
                'Eliminada por ${note.eliminadaPor ?? '—'} el ${sellerPaymentNoteDate(note.eliminadaEn!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
