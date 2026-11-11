import 'package:app_novik/core/utils/format.dart';
import 'package:app_novik/presentation/components/components.dart';
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
