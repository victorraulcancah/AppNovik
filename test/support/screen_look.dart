import 'dart:io';
import 'dart:typed_data';

import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';

/// Cómo dibujar una pantalla completa en las pruebas de modo oscuro y letra grande: la letra
/// real (Roboto, no la Ahem de las pruebas, que es casi el doble de ancha), el modo claro u
/// oscuro, el factor de letra del sistema y el tamaño de una pantalla de celular.
class ScreenLook {
  final bool dark;
  final double scale;
  final Size size;

  const ScreenLook({this.dark = false, this.scale = 1.3, this.size = const Size(360, 780)});

  /// El mismo caso en una pantalla más alta (para listas que se arman a medida que se baja).
  ScreenLook tall([double height = 2400]) =>
      ScreenLook(dark: dark, scale: scale, size: Size(size.width, height));

  String get label =>
      '${dark ? 'modo oscuro' : 'modo claro'}, letra ${scale}x, ${size.width.toInt()} px';
}

/// Los cuatro casos que se revisan en cada pantalla: claro y oscuro, a 360 y a 320 px de ancho,
/// siempre con letra 1.3x.
const screenLooks = [
  ScreenLook(dark: false, size: Size(360, 780)),
  ScreenLook(dark: true, size: Size(360, 780)),
  ScreenLook(dark: false, size: Size(320, 640)),
  ScreenLook(dark: true, size: Size(320, 640)),
];

var _robotoLoaded = false;

/// Carga la fuente Roboto del proyecto (la misma que usa el PDF) con el nombre `Roboto`.
Future<void> loadRoboto() async {
  if (_robotoLoaded) return;
  final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
  final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();
  ByteData data(List<int> bytes) => ByteData.view(Uint8List.fromList(bytes).buffer);
  // Con el nombre `Roboto` (lo usan los temas) y también en lugar de la fuente por defecto de las
  // pruebas (Ahem): así los textos que no traen familia (los de los botones, por ejemplo) también
  // salen con letra real y los anchos son los de un celular.
  for (final family in ['Roboto', 'FlutterTest']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(data(regular)))
      ..addFont(Future.value(data(bold)));
    await loader.load();
  }
  _robotoLoaded = true;
}

/// El estilo de un botón con la letra Roboto. Los botones traen su `TextStyle` sin familia y en
/// las pruebas eso cae en Ahem (cuadros anchos); en un celular es la letra del sistema.
ButtonStyle? _buttonRoboto(ButtonStyle? style) {
  final textStyle = style?.textStyle?.resolve(const <WidgetState>{});
  if (style == null || textStyle == null) return style;
  return style.copyWith(textStyle: WidgetStatePropertyAll(textStyle.copyWith(fontFamily: 'Roboto')));
}

ThemeData _withRoboto(ThemeData base) => base.copyWith(
  textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
  primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
  filledButtonTheme: FilledButtonThemeData(style: _buttonRoboto(base.filledButtonTheme.style)),
  outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonRoboto(base.outlinedButtonTheme.style)),
  textButtonTheme: TextButtonThemeData(style: _buttonRoboto(base.textButtonTheme.style)),
  elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonRoboto(base.elevatedButtonTheme.style)),
);

/// Prepara la vista de la prueba para [look] (tamaño, densidad y letra del sistema) y carga la
/// fuente. Sin [look] no hace nada: la prueba usa lo suyo (Ahem a 0.55).
Future<void> prepareLook(WidgetTester tester, ScreenLook? look) async {
  if (look == null) return;
  await loadRoboto();
  tester.view.physicalSize = Size(look.size.width * 3, look.size.height * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = look.scale;
  // Si algo se desborda, imprime el widget responsable (la excepción sola no lo dice).
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint(details.toString());
    previous?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = previous;
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// El `MaterialApp` de la prueba: con [look] usa los dos temas reales de la app con Roboto y el
/// modo elegido; sin él, el tema claro de siempre.
MaterialApp lookApp(ScreenLook? look, {required Widget home}) {
  if (look == null) return MaterialApp(theme: AppTheme.light, home: home);
  return MaterialApp(
    theme: _withRoboto(AppTheme.light),
    darkTheme: _withRoboto(AppTheme.dark),
    themeMode: look.dark ? ThemeMode.dark : ThemeMode.light,
    home: home,
  );
}

/// La revisión de una pantalla ya dibujada: sin desbordes ni otras excepciones y con el tema
/// pedido; y los textos con el contraste suficiente.
Future<void> expectLooksRight(WidgetTester tester, ScreenLook look, {bool contrast = true}) async {
  final exception = tester.takeException();
  if (exception != null) {
    // Con el detalle (qué widget se desborda y por cuántos píxeles) para poder arreglarlo.
    fail('${look.label}: ${exception is FlutterError ? exception.toStringDeep() : exception}');
  }
  final context = tester.element(find.byType(Scaffold).first);
  expect(
    Theme.of(context).brightness,
    look.dark ? Brightness.dark : Brightness.light,
    reason: look.label,
  );
  if (contrast) {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
}
