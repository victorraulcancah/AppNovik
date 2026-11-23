import 'package:app_novik/core/utils/format.dart';
import 'package:app_novik/presentation/components/components.dart';
import 'package:app_novik/presentation/widgets/inicio_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shortPersonName', () {
    test('nombre y apellido paterno + materno: nombre e inicial del apellido', () {
      expect(shortPersonName('FRANCIS BULNES GONZALES'), 'FRANCIS B.');
      expect(shortPersonName('HANS DAVILA PRADO'), 'HANS D.');
    });

    test('nombre y un apellido', () {
      expect(shortPersonName('NAOMI RIVAS'), 'NAOMI R.');
    });

    test('dos nombres y dos apellidos: la inicial es la del apellido paterno', () {
      expect(shortPersonName('NAOMI ROXANA RIVAS LOPEZ'), 'NAOMI R.');
      expect(shortPersonName('MARIA ELENA QUISPE HUAMAN'), 'MARIA Q.');
    });

    test('una sola palabra, vacío o con espacios de más', () {
      expect(shortPersonName('Prueba'), 'Prueba');
      expect(shortPersonName(''), '');
      expect(shortPersonName(null), '');
      expect(shortPersonName('  Juan    Pérez  '), 'Juan P.');
    });

    test('la inicial sale en mayúscula aunque el apellido venga en minúscula', () {
      expect(shortPersonName('juan pérez'), 'juan P.');
    });
  });

  group('shortClientName', () {
    test('los ejemplos del cliente: todo menos la última palabra, que va en inicial', () {
      expect(shortClientName('Yoselin Rosa Miranda'), 'Yoselin Rosa M.');
      expect(shortClientName('Juan Carlos Contreras'), 'Juan Carlos C.');
      expect(shortClientName('Bolívar Store Express'), 'Bolívar Store E.');
      expect(shortClientName('Larry Christian Pérez'), 'Larry Christian P.');
    });

    test('con dos apellidos (cuatro palabras) se abrevia el paterno, no el materno', () {
      expect(shortClientName('YOSELIN ROSA MIRANDA SALAZAR'), 'YOSELIN ROSA M.');
      expect(shortClientName('JUAN CARLOS CONTRERAS PEREZ'), 'JUAN CARLOS C.');
      expect(shortClientName('Larry Christian Pérez Soto'), 'Larry Christian P.');
    });

    test('sin el artículo del inicio', () {
      expect(shortClientName('La Casa del Auto'), 'Casa del A.');
      expect(shortClientName('EL MAESTRO'), 'MAESTRO');
    });

    test('sin la forma legal del final', () {
      expect(shortClientName('AUTO MARKET PERU E.I.R.L.'), 'AUTO MARKET P.');
      expect(shortClientName('CORREA CARDENAS S.A.C.'), 'CORREA C.');
    });

    test('una palabra, vacío o con espacios de más', () {
      expect(shortClientName('Prueba'), 'Prueba');
      expect(shortClientName(''), '');
      expect(shortClientName(null), '');
      expect(shortClientName('  Juan    Pérez  '), 'Juan P.');
    });
  });

  test('nameDisplayOptions: del nombre completo al más corto', () {
    expect(nameDisplayOptions('CASA DEL AUTO'), ['CASA DEL AUTO', 'CASA DEL A.', 'CASA D.']);
    expect(nameDisplayOptions('AUTO MARKET PERU E.I.R.L.'), [
      'AUTO MARKET PERU E.I.R.L.',
      'AUTO MARKET PERU',
      'AUTO MARKET P.',
      'AUTO M.',
    ]);
    expect(nameDisplayOptions('YOSELIN ROSA MIRANDA SALAZAR'), [
      'YOSELIN ROSA MIRANDA SALAZAR',
      'YOSELIN ROSA MIRANDA S.',
      'YOSELIN ROSA M.',
      'YOSELIN R.',
    ]);
    expect(nameDisplayOptions('EMPRESA MULTISERVICIOS GENERALES').last, 'EMPRESA M.');
    expect(nameDisplayOptions('TRANSFERENCIA BANCARIA'), ['TRANSFERENCIA BANCARIA', 'TRANSFERENCIA B.']);
    expect(nameDisplayOptions('EFECTIVO'), ['EFECTIVO']);
    expect(nameDisplayOptions(null), ['']);
  });

  testWidgets('InicioNameCell: completo si cabe; si no, la última palabra en inicial; al final, "…"', (tester) async {
    Future<void> show(double width, String name) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, child: InicioNameCell(name)),
              ),
            ),
          ),
        );

    // (En las pruebas la letra mide 12 px por carácter.)
    await show(400, 'MALDONADO ALCCAHUAMAN CCORI');
    expect(find.text('MALDONADO ALCCAHUAMAN CCORI'), findsOneWidget);

    await show(300, 'MALDONADO ALCCAHUAMAN CCORI');
    expect(find.text('MALDONADO ALCCAHUAMAN C.'), findsOneWidget);

    await show(200, 'YOSELIN ROSA MIRANDA SALAZAR');
    expect(find.text('YOSELIN ROSA M.'), findsOneWidget);

    // Con poco ancho se siguen quitando palabras en vez de cortar con "…".
    await show(130, 'EMPRESA MULTISERVICIOS GENERALES');
    expect(find.text('EMPRESA M.'), findsOneWidget);
  });

  testWidgets('la tarjeta de lista ya no lleva número en la esquina', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppListCard(title: 'V001-7310', lines: ['FRANCIS B. · PRINCIPAL'])),
      ),
    );
    expect(find.text('V001-7310'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    // El texto arranca en el margen normal, sin el hueco que dejaba la marca.
    final left = tester.getTopLeft(find.text('V001-7310')).dx - tester.getTopLeft(find.byType(AppListCard)).dx;
    expect(left, lessThan(24));
  });
}
