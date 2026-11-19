import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
      message: '¿Eliminar esta nota? Quedará en el historial como eliminada por ti.',
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
        else if (_notes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('Sin notas', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          )
        else
          for (final note in _notes) ...[
            _NoteCard(note: note, onDelete: note.puedeEliminar ? () => _delete(note) : null),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final SellerPaymentNote note;
  final VoidCallback? onDelete;

  const _NoteCard({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final removed = note.eliminada;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

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
                        text: note.autor ?? 'Sin autor',
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                      ),
                      if (note.creado != null) TextSpan(text: '  ${sellerPaymentNoteDate(note.creado!)}'),
                    ],
                  ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Eliminar nota',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
                )
              else
                const SizedBox(height: 8, width: 8),
            ],
          ),
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
