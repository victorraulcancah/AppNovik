import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Lo que dijo el reconocedor, tal como se escribiría en un buscador: los números dichos en palabras
/// pasan a dígitos y las series a su forma escrita. "cien" → "100", "mil quinientos" → "1500",
/// "cero cero uno guion siete cuatro tres cinco" → "001-7435", "be cero cero uno guion doscientos" →
/// "B001-200". La búsqueda por voz solo transcribe: lo que se dice es lo que se busca.
String spokenToSearchText(String input) {
  const units = {
    'cero': 0, 'uno': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8,
    'nueve': 9, 'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15,
    'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19, 'veinte': 20, 'veintiuno': 21,
    'veintiun': 21, 'veintidos': 22, 'veintitres': 23, 'veinticuatro': 24, 'veinticinco': 25,
    'veintiseis': 26, 'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29,
  };
  const tens = {
    'treinta': 30, 'cuarenta': 40, 'cincuenta': 50, 'sesenta': 60, 'setenta': 70, 'ochenta': 80,
    'noventa': 90,
  };
  const hundreds = {
    'cien': 100, 'ciento': 100, 'doscientos': 200, 'trescientos': 300, 'cuatrocientos': 400,
    'quinientos': 500, 'seiscientos': 600, 'setecientos': 700, 'ochocientos': 800, 'novecientos': 900,
  };
  const letters = {
    've': 'V', 'be': 'B', 'efe': 'F', 'ese': 'S', 'ce': 'C', 'te': 'T', 'pe': 'P', 'eme': 'M', 'a': 'A',
  };
  const dashes = {'guion', 'menos', 'raya'};

  String plain(String w) => w
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[.,;:!?¿¡]'), '');

  bool isNumberWord(String w) =>
      units.containsKey(w) || tens.containsKey(w) || hundreds.containsKey(w) || w == 'mil';

  final words = input.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final out = <String>[];
  var i = 0;
  while (i < words.length) {
    final w = plain(words[i]);

    // Un guion dicho: "-" pegado a lo de los lados.
    if (dashes.contains(w)) {
      out.add('-');
      i++;
      continue;
    }

    // La letra de una serie ("be cero cero uno"): solo si lo que sigue es un número.
    if (letters.containsKey(w) && i + 1 < words.length) {
      final next = plain(words[i + 1]);
      if (isNumberWord(next) || RegExp(r'^\d').hasMatch(next)) {
        out.add(letters[w]!);
        i++;
        continue;
      }
    }

    if (!isNumberWord(w)) {
      out.add(words[i]);
      i++;
      continue;
    }

    // Una racha de números dichos ("treinta y cinco", "cero cero uno", "mil quinientos").
    final run = <String>[];
    while (i < words.length) {
      final x = plain(words[i]);
      if (isNumberWord(x) || (x == 'y' && run.isNotEmpty && i + 1 < words.length && isNumberWord(plain(words[i + 1])))) {
        if (x != 'y') run.add(x);
        i++;
      } else if ((x == 'un' || x == 'una') && run.isNotEmpty) {
        run.add('uno');
        i++;
      } else {
        break;
      }
    }
    final onlyDigits = run.length > 1 && run.every((x) => units.containsKey(x) && units[x]! <= 9);
    if (onlyDigits) {
      out.add(run.map((x) => '${units[x]}').join());
      continue;
    }
    var total = 0;
    var current = 0;
    for (final x in run) {
      if (x == 'mil') {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
      } else {
        current += units[x] ?? tens[x] ?? hundreds[x] ?? 0;
      }
    }
    out.add('${total + current}');
  }

  // Une lo que va pegado: letra + número ("B 001") y el guion con sus lados ("001 - 7435").
  final text = StringBuffer();
  for (var k = 0; k < out.length; k++) {
    final token = out[k];
    final glue = k > 0 &&
        (token == '-' ||
            out[k - 1] == '-' ||
            (RegExp(r'^[A-Z]$').hasMatch(out[k - 1]) && RegExp(r'^\d').hasMatch(token)));
    if (k > 0 && !glue) text.write(' ');
    text.write(token);
  }
  return text.toString();
}

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
  Timer? _silence;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _silence?.cancel();
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
        if (!mounted) return;
        setState(() => _text = spokenToSearchText(r.recognizedWords));
        // El resultado final cierra la ventana de una vez y lo dicho pasa al buscador. Por si el
        // reconocedor no avisa que terminó, un momento sin palabras nuevas también lo cierra.
        _silence?.cancel();
        if (r.finalResult) {
          _finish();
        } else {
          _silence = Timer(const Duration(milliseconds: 1600), _finish);
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: 'es_PE',
        // Dictado libre: acepta números, series y códigos, no solo nombres de cosas.
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 2),
      ),
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
    _silence?.cancel();
    _speech.stop();
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
              // Tocar el micrófono mientras escucha entrega lo que se alcanzó a decir.
              onTap: _listening ? _finish : _start,
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
