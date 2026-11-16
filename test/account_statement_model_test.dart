import 'package:app_novik/data/models/account_statement_model.dart';
import 'package:app_novik/domain/entities/account_statement_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una venta tal como la manda el servidor dentro de las filas de pago.
Map<String, dynamic> _sale({int id = 12, Object? total = 0, bool estado = true, bool boleta = true}) => {
      'id': id,
      'nro_documento': 45,
      'estado': estado,
      'total_soles': 100,
      'total_dolares': total,
      'created_at': '2026-11-03T10:00:00.000000Z',
      'boleta': boleta ? {'id': 5, 'tipo': 'b', 'serie': 1, 'numero': 7} : null,
      'client': {'id': 3, 'name': 'ACME', 'razon_social': 'ACME SAC', 'dni_ruc': '20123456789'},
      'products': [
        {
          'id': 1,
          'name': 'SUBWOOFER',
          'codigo': 'SUB-12',
          'brand': {'name': '7POWER'},
          'pivot': {'cantidad': 2, 'precio': 50, 'subtotal_con_dto': 100},
        },
      ],
    };

Map<String, dynamic> _productRow({Object dolares = false}) => {
      'id': 's-10',
      'cantidad': 2,
      'dolares': dolares,
      'subtotal_con_dto': 100,
      'created_at': '2026-11-03T10:00:00.000000Z',
      'sale': _sale(),
      'product': {'name': 'SUBWOOFER', 'codigo': 'SUB-12', 'brand': {'name': '7POWER'}},
    };

void main() {
  group('Cabecera', () {
    test('usa los totales que calcula el servidor y limpia lo menor a medio centavo', () {
      final s = statementSummaryFromJson({
        'deudaTotalSoles': 1500.5,
        'deudaTotalDolares': 0.004,
        'deuda_anterior_soles': 200,
        'deuda_anterior_dolares': 0,
        'client': {'credito': 5000, 'credito_disponible': 3000, 'linea_utilizada': 2000},
      });

      expect(s.deudaTotalSoles, 1500.5);
      expect(s.deudaTotalDolares, 0);
      expect(s.deudaAnteriorSoles, 200);
      expect(s.hayDeudaAnterior, isTrue);
      expect(s.credito, 5000);
      expect(s.creditoDisponible, 3000);
      expect(s.lineaUtilizada, 2000);
    });

    test('sin línea utilizada se calcula: crédito menos disponible, sin bajar de cero', () {
      expect(
        statementSummaryFromJson({'client': {'credito': 5000, 'credito_disponible': 3000}}).lineaUtilizada,
        2000,
      );
      expect(
        statementSummaryFromJson({'client': {'credito': 100, 'credito_disponible': 400}}).lineaUtilizada,
        0,
      );
    });

    test('sin deuda anterior no se marca', () {
      expect(statementSummaryFromJson({'deuda_anterior_soles': 0}).hayDeudaAnterior, isFalse);
    });
  });

  group('Número de documento', () {
    test('con boleta: tipo en mayúscula, serie de 3 y número de 4 dígitos', () {
      expect(statementDocumentNumber({'boleta': {'tipo': 'b', 'serie': 1, 'numero': 7}}), 'B001-0007');
      expect(statementDocumentNumber({'boleta': {'tipo': 'f', 'serie': 2, 'numero': 12345}}), 'F002-12345');
    });

    test('sin boleta: V001 y el número de documento (C001 si es cotización)', () {
      expect(statementDocumentNumber({'nro_documento': 45}), 'V001-0045');
      expect(statementDocumentNumber({'nro_documento': 3, 'reservar_stock': true}), 'C001-0003');
    });
  });

  group('Pestaña principal, por producto', () {
    test('una venta por producto: cantidad, producto, soles y número de boleta', () {
      final r = statementRowFromJson(_productRow(), agrupado: false);

      expect(r.titulo, 'SUBWOOFER');
      expect(r.detalle, 'SUB-12 · 7POWER');
      expect(r.cantidad, 2);
      expect(r.soles, 100);
      expect(r.dolares, 0);
      expect(r.documento, 'B001-0007');
      expect(r.esPago, isFalse);
      expect(r.enRojo, isFalse);
      expect(r.fecha, isNotNull);
    });

    test('un producto en dólares va en la columna de dólares', () {
      final r = statementRowFromJson(_productRow(dolares: true), agrupado: false);

      expect(r.soles, 0);
      expect(r.dolares, 100);
    });

    test('un pago: "Pagó con", en rojo, con quién lo registró y de dónde salió', () {
      final r = statementRowFromJson({
        'id': 'f-4',
        'monto': 60,
        'created_at': '2026-11-04T12:00:00.000000Z',
        'registrado_por': 'FRANCIS BULNES GONZALES',
        'origen': 'Pago de cuota',
        'payment_method': {'name': 'YAPE'},
        'sale': _sale(),
      }, agrupado: false);

      expect(r.titulo, 'Pagó con YAPE');
      expect(r.esPago, isTrue);
      expect(r.enRojo, isTrue);
      expect(r.soles, 60);
      expect(r.dolares, 0);
      expect(r.cantidad, isNull);
      expect(r.registradoPor, 'FRANCIS BULNES GONZALES');
      expect(r.origen, 'Pago de cuota');
    });

    test('un pago de una venta en dólares va en dólares', () {
      final r = statementRowFromJson({
        'id': 'o-2',
        'monto': 30,
        'created_at': '2026-11-04T12:00:00.000000Z',
        'payment_method': {'name': 'EFECTIVO'},
        'sale': _sale(total: 100),
      }, agrupado: false);

      expect(r.soles, 0);
      expect(r.dolares, 30);
    });

    test('un pago sin método dice N/A', () {
      final r = statementRowFromJson({'id': 'f-9', 'monto': 5, 'payment_method': <String, dynamic>{}, 'sale': _sale()}, agrupado: false);
      expect(r.titulo, 'Pagó con N/A');
    });

    test('un pago de vendedor agrupado no tiene documento y usa su moneda', () {
      final r = statementRowFromJson({
        'id': 'ps-agg-dolares-3',
        'type': 'payment_seller_aggregated',
        'moneda': 'dolares',
        'total_sumado': 250,
        'created_at': '2026-11-05T09:00:00.000-05:00',
        'payment_method': {'name': 'TRANSFERENCIA'},
        'registrado_por': 'LUIS PEREZ',
        'origen': 'Pago de vendedor',
        'sale': {'estado': true, 'nro_documento': 3, 'boleta': null},
      }, agrupado: false);

      expect(r.documento, '-');
      expect(r.esPago, isTrue);
      expect(r.soles, 0);
      expect(r.dolares, 250);
      expect(r.document, isNull);
    });

    test('una venta anulada sale en rojo', () {
      final row = _productRow();
      (row['sale'] as Map<String, dynamic>)['estado'] = false;

      final r = statementRowFromJson(row, agrupado: false);

      expect(r.anulado, isTrue);
      expect(r.enRojo, isTrue);
    });

    test('trae el comprobante de la venta para abrirlo', () {
      final r = statementRowFromJson(_productRow(), agrupado: false);

      expect(r.document, isNotNull);
      expect(r.document!.id, 12);
      expect(r.document!.cliente, 'ACME SAC');
      expect(r.document!.items.single.name, 'SUBWOOFER');
    });
  });

  group('Pestaña principal, agrupada por venta', () {
    test('la fila de venta es la venta: "Venta N", su total y su número', () {
      final r = statementRowFromJson({
        'id': 's-12',
        'nro_documento': 45,
        'total_soles': 480,
        'total_dolares': 0,
        'estado': true,
        'created_at': '2026-11-03T10:00:00.000000Z',
        'boleta': {'tipo': 'f', 'serie': 1, 'numero': 9},
      }, agrupado: true);

      expect(r.titulo, 'Venta 45');
      expect(r.soles, 480);
      expect(r.dolares, 0);
      expect(r.documento, 'F001-0009');
      expect(r.esPago, isFalse);
    });

    test('los pagos siguen siendo individuales y en rojo', () {
      final r = statementRowFromJson({
        'id': 'o-8',
        'monto': 80,
        'created_at': '2026-11-03T10:00:00.000000Z',
        'payment_method': {'name': 'EFECTIVO'},
        'origen': 'Cobrado en la venta',
        'sale': _sale(),
      }, agrupado: true);

      expect(r.titulo, 'Pagó con EFECTIVO');
      expect(r.esPago, isTrue);
      expect(r.soles, 80);
      // La venta de un pago es la misma: su número sale con la boleta (la web ponía V001).
      expect(r.documento, 'B001-0007');
    });

    test('la fila de venta lleva su comprobante con el número de venta real', () {
      final r = statementRowFromJson({
        'id': 's-12',
        'nro_documento': 45,
        'total_soles': 480,
        'total_dolares': 0,
        'estado': true,
        'created_at': '2026-11-03T10:00:00.000000Z',
        'client': {'id': 3, 'name': 'ACME'},
        'products': <dynamic>[],
      }, agrupado: true);

      expect(r.document?.id, 12);
    });
  });

  group('Páginas', () {
    test('la principal trae filas, total y cabecera', () {
      final page = statementPageFromJson({
        'data': [_productRow()],
        'total': 41,
        'deudaTotalSoles': 90,
        'client': {'credito': 10},
      }, agrupado: false);

      expect(page.rows, hasLength(1));
      expect(page.total, 41);
      expect(page.summary!.deudaTotalSoles, 90);
    });

    test('pedidos: un producto por fila, con la fecha de la venta', () {
      final page = statementOrdersFromJson({
        'total': 2,
        'data': [
          {
            'id': 10,
            'cantidad': 3,
            'dolares': false,
            'subtotal_con_dto': 150,
            'sale': _sale(),
            'product': {'name': 'SUBWOOFER', 'codigo': 'SUB-12', 'brand': {'name': '7POWER'}},
          },
          {
            'id': 11,
            'cantidad': 1,
            'dolares': true,
            'subtotal_con_dto': 20,
            'sale': _sale(estado: false, boleta: false),
            'product': {'name': 'KIT', 'codigo': 'K-1', 'brand': null},
          },
        ],
      });

      expect(page.total, 2);
      expect(page.summary, isNull);
      final a = page.rows[0];
      expect(a.titulo, 'SUBWOOFER');
      expect(a.cantidad, 3);
      expect(a.soles, 150);
      expect(a.documento, 'B001-0007');
      expect(a.anulado, isFalse);
      final b = page.rows[1];
      expect(b.dolares, 20);
      expect(b.soles, 0);
      expect(b.documento, 'V001-0045');
      expect(b.detalle, 'K-1 · -');
      expect(b.anulado, isTrue);
    });

    test('pagos: método, monto en la moneda de la venta y origen', () {
      final page = statementPaymentsFromJson({
        'total': 3,
        'data': [
          {
            'id': 'd-1',
            'monto': 40,
            'created_at': '2026-11-04T12:00:00.000000Z',
            'payment_method': {'name': 'YAPE'},
            'registrado_por': 'ANA GOMEZ RUIZ',
            'origen': 'Pago de cuota',
            'sale': _sale(),
          },
          {
            'id': 'o-2',
            'monto': 25,
            'created_at': '2026-11-04T12:00:00.000000Z',
            'payment_method': {'name': 'EFECTIVO'},
            'sale': _sale(total: 100),
          },
          {
            'id': 'ps-5',
            'monto': 300,
            'moneda': 'dolares',
            'created_at': '2026-11-05T12:00:00.000000Z',
            'payment_method': {'name': 'TRANSFERENCIA'},
            'origen': 'Pago de vendedor',
            'sale': {'estado': false, 'nro_documento': 5, 'boleta': null},
          },
        ],
      });

      expect(page.total, 3);
      expect(page.rows[0].titulo, 'YAPE');
      expect(page.rows[0].soles, 40);
      expect(page.rows[0].documento, 'B001-0007');
      expect(page.rows[0].esPago, isTrue);
      expect(page.rows[1].dolares, 25);
      expect(page.rows[2].dolares, 300);
      expect(page.rows[2].documento, '-');
      expect(page.rows[2].anulado, isTrue);
    });

    test('sin datos devuelve una página vacía', () {
      expect(statementOrdersFromJson({}).rows, isEmpty);
      expect(statementPaymentsFromJson({'data': null}).total, 0);
      expect(statementPageFromJson({}, agrupado: true).rows, isEmpty);
    });
  });

  group('Rangos de fechas', () {
    final now = DateTime(2026, 11, 18); // miércoles

    test('los mismos rápidos que la web', () {
      expect(StatementRange.esteMes.datesFor(now), (start: DateTime(2026, 11), end: DateTime(2026, 11, 18)));
      expect(StatementRange.ultimoMes.datesFor(now), (start: DateTime(2026, 10), end: DateTime(2026, 10, 31)));
      expect(StatementRange.estaSemana.datesFor(now), (start: DateTime(2026, 11, 16), end: DateTime(2026, 11, 18)));
      expect(StatementRange.ultimaSemana.datesFor(now), (start: DateTime(2026, 11, 9), end: DateTime(2026, 11, 15)));
      expect(StatementRange.esteAnio.datesFor(now), (start: DateTime(2026), end: DateTime(2026, 11, 18)));
      expect(StatementRange.ultimoAnio.datesFor(now), (start: DateTime(2025), end: DateTime(2025, 12, 31)));
    });

    test('personalizado usa las fechas elegidas', () {
      final custom = (start: DateTime(2026, 5, 1), end: DateTime(2026, 5, 31));
      expect(StatementRange.personalizado.datesFor(now, custom: custom), custom);
    });
  });
}
