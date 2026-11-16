import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Búsqueda por voz: abre una hoja que escucha y devuelve lo que se dijo (o `null` si se cerró sin
/// decir nada). [listen] se puede cambiar en las pruebas (el micrófono no corre en ellas).
class VoiceSearch {
  VoiceSearch._();

  static Future<String?> Function(BuildContext context) listen = _open;

  static Future<String?> _open(BuildContext context) => showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const _VoiceSheet(),
      );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  final _speech = SpeechToText();
  String _text = '';
  String? _error;
  bool _listening = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await _speech.initialize(
      onError: (e) {
        if (mounted) setState(() => _error = 'No te escuché. Toca el micrófono para intentar de nuevo.');
      },
      onStatus: (status) {
        // Al terminar de escuchar, se entrega lo que se dijo.
        if (status == 'done' || status == 'notListening') _finish();
      },
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'Permite el micrófono en los ajustes del teléfono para buscar por voz.');
      return;
    }
    setState(() {
      _listening = true;
      _error = null;
      _text = '';
    });
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        if (mounted) setState(() => _text = r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: true, localeId: 'es_PE'),
    );
  }

  void _finish() {
    if (_closed || !mounted) return;
    final said = _text.trim();
    if (said.isEmpty) {
      setState(() => _listening = false);
      return;
    }
    _closed = true;
    Navigator.of(context).pop(said);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: _listening ? 'Escuchando' : 'Hablar',
            child: GestureDetector(
              onTap: _listening ? _speech.stop : _start,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening ? scheme.primary : scheme.surfaceContainerHighest,
                ),
                child: Icon(
                  Icons.mic,
                  size: 34,
                  color: _listening ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? (_text.isEmpty ? (_listening ? 'Escuchando… di el nombre o el código' : 'Toca el micrófono') : _text),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _error != null ? scheme.error : scheme.onSurface,
              fontWeight: _text.isEmpty ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ],
      ),
    );
  }
}
