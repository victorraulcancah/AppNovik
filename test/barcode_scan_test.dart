import 'package:app_novik/presentation/components/components.dart';
import 'package:app_novik/presentation/utils/barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Future<String?> Function(BuildContext) original;

  setUp(() => original = BarcodeScanner.scan);
  tearDown(() => BarcodeScanner.scan = original);

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
    expect(find.byIcon(Icons.barcode_reader), findsOneWidget);
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
}
