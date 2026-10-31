import 'dart:typed_data';

import 'package:app_novik/domain/entities/document_entity.dart' show DownloadedFile;
import 'package:app_novik/presentation/utils/download_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// El "Guardar como" del sistema, simulado.
class _FakePicker extends FilePickerPlatform with MockPlatformInterfaceMixin {
  final saved = <({String fileName, int size, String mimeType})>[];
  Uri? result = Uri.parse('content://downloads/Lista.xlsx');
  Object? error;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (error != null) throw error!;
    saved.add((fileName: fileName, size: bytes.length, mimeType: mimeType));
    return result;
  }
}

void main() {
  late _FakePicker picker;
  late FilePickerPlatform original;

  setUp(() {
    original = FilePickerPlatform.instance;
    picker = _FakePicker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() => FilePickerPlatform.instance = original);

  Future<void> pumpAndTap(WidgetTester tester, DownloadedFile file) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => downloadFile(context, file),
              child: const Text('Descargar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Descargar'));
    await tester.pumpAndSettle();
  }

  final excel = DownloadedFile(name: 'Lista de Productos.xlsx', bytes: Uint8List.fromList([1, 2, 3]));

  testWidgets('descargar guarda el archivo en el dispositivo y avisa, con opción de compartir', (tester) async {
    await pumpAndTap(tester, excel);

    expect(picker.saved.single.fileName, 'Lista de Productos.xlsx');
    expect(picker.saved.single.size, 3);
    expect(
      picker.saved.single.mimeType,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    expect(find.text('Lista de Productos.xlsx guardado'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
  });

  testWidgets('un PDF se guarda con su tipo', (tester) async {
    await pumpAndTap(tester, DownloadedFile(name: 'B001-00231.pdf', bytes: Uint8List.fromList([1])));

    expect(picker.saved.single.mimeType, 'application/pdf');
    expect(find.text('B001-00231.pdf guardado'), findsOneWidget);
  });

  testWidgets('si se cancela el diálogo no se avisa nada', (tester) async {
    picker.result = null;

    await pumpAndTap(tester, excel);

    expect(picker.saved, hasLength(1));
    expect(find.textContaining('guardado'), findsNothing);
    expect(find.textContaining('No se pudo'), findsNothing);
  });

  testWidgets('si no se puede guardar avisa el error', (tester) async {
    picker.error = Exception('sin espacio');

    await pumpAndTap(tester, excel);

    expect(find.text('No se pudo guardar el archivo'), findsOneWidget);
  });
}
