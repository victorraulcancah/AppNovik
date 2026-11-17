import 'package:app_novik/presentation/components/components.dart';
import 'package:app_novik/presentation/components/barcode_scanner_icon.dart';
import 'package:app_novik/presentation/utils/barcode_scanner.dart';
import 'package:app_novik/presentation/utils/voice_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Future<String?> Function(BuildContext) original;
  late Future<String?> Function(BuildContext) originalVoice;

  setUp(() {
    original = BarcodeScanner.scan;
    originalVoice = VoiceSearch.listen;
  });
  tearDown(() {
    BarcodeScanner.scan = original;
    VoiceSearch.listen = originalVoice;
  });

  Future<List<String>> pump(WidgetTester tester, {bool withScanner = true}) async {
    final scanned = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSearchBar(
          hint: 'Buscar por nombre, código…',
          onScanned: withScanner ? scanned.add : null,
        ),
      ),
    ));
    return scanned;
  }

  testWidgets('el buscador con escáner muestra el botón del código de barras', (tester) async {
    await pump(tester);

    expect(find.byTooltip('Escanear código de barras'), findsOneWidget);
    // El ícono del escáner: esquinas con las barras (no el del lector de Material).
    expect(find.byType(BarcodeScannerIcon), findsOneWidget);
  });

  testWidgets('sin escáner no hay botón', (tester) async {
    await pump(tester, withScanner: false);

    expect(find.byTooltip('Escanear código de barras'), findsNothing);
  });

  testWidgets('el código leído llega a quien lo pidió', (tester) async {
    BarcodeScanner.scan = (_) async => '7750000000017';
    final scanned = await pump(tester);

    await tester.tap(find.byTooltip('Escanear código de barras'));
    await tester.pumpAndSettle();

    expect(scanned, ['7750000000017']);
  });

  testWidgets('si se cierra la cámara sin leer nada, no pasa nada', (tester) async {
    BarcodeScanner.scan = (_) async => null;
    final scanned = await pump(tester);

    await tester.tap(find.byTooltip('Escanear código de barras'));
    await tester.pumpAndSettle();

    expect(scanned, isEmpty);
  });

  group('búsqueda por voz', () {
    Future<(TextEditingController, List<String>)> pumpVoice(WidgetTester tester, {bool voice = true}) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppSearchBar(controller: controller, onChanged: changes.add, voice: voice),
        ),
      ));
      return (controller, changes);
    }

    testWidgets('el campo trae el micrófono y lo dicho se escribe y busca', (tester) async {
      VoiceSearch.listen = (_) async => '  amplificador evo ';
      final (controller, changes) = await pumpVoice(tester);

      expect(find.byTooltip('Buscar por voz'), findsOneWidget);
      await tester.tap(find.byTooltip('Buscar por voz'));
      await tester.pumpAndSettle();

      expect(controller.text, 'amplificador evo');
      expect(changes, ['amplificador evo']);
    });

    testWidgets('si no se dijo nada, el campo queda como estaba', (tester) async {
      VoiceSearch.listen = (_) async => null;
      final (controller, changes) = await pumpVoice(tester);
      controller.text = 'antes';

      await tester.tap(find.byTooltip('Buscar por voz'));
      await tester.pumpAndSettle();

      expect(controller.text, 'antes');
      expect(changes, isEmpty);
    });

    testWidgets('sin voz o sin controlador no hay micrófono', (tester) async {
      await pumpVoice(tester, voice: false);
      expect(find.byTooltip('Buscar por voz'), findsNothing);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppSearchBar())));
      expect(find.byTooltip('Buscar por voz'), findsNothing);
    });
  });

  group('lo dicho se transcribe tal como se buscaría (números en dígitos)', () {
    test('un número dicho en palabras sale en dígitos', () {
      expect(spokenToSearchText('cien'), '100');
      expect(spokenToSearchText('ciento veinte'), '120');
      expect(spokenToSearchText('treinta y cinco'), '35');
      expect(spokenToSearchText('mil quinientos'), '1500');
      expect(spokenToSearchText('dos mil veintiuno'), '2021');
      expect(spokenToSearchText('cinco'), '5');
    });

    test('lo que ya viene en dígitos no se toca', () {
      expect(spokenToSearchText('100'), '100');
      expect(spokenToSearchText('V001-7435'), 'V001-7435');
    });

    test('dígitos dichos uno a uno se pegan (series y códigos)', () {
      expect(spokenToSearchText('cero cero uno'), '001');
      expect(spokenToSearchText('siete cuatro tres cinco'), '7435');
    });

    test('una serie con su letra y su guion', () {
      expect(spokenToSearchText('cero cero uno guion siete cuatro tres cinco'), '001-7435');
      expect(spokenToSearchText('be cero cero uno guion doscientos'), 'B001-200');
      expect(spokenToSearchText('ve cero cero uno menos siete mil cuatrocientos treinta y cinco'), 'V001-7435');
    });

    test('el texto normal queda como está y los números van en medio', () {
      expect(spokenToSearchText('amplificador'), 'amplificador');
      expect(spokenToSearchText('amplificador cuatro canales'), 'amplificador 4 canales');
      expect(spokenToSearchText('Un amplificador'), 'Un amplificador');
      expect(spokenToSearchText('  '), '');
    });
  });
}
