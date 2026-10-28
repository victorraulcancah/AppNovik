import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/models/document_model.dart';
import 'package:app_novik/domain/entities/document_entity.dart';
import 'package:app_novik/domain/repositories/document_repository.dart';
import 'package:app_novik/domain/usecases/document_usecases.dart';
import 'package:app_novik/presentation/providers/documents_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _Call {
  final DocumentKind kind;
  final String? search;
  final DateTime? from;
  final DateTime? to;
  final DocumentTipo? tipo;
  final DocumentEstado? estado;
  final bool soloPendientes;
  final int page;

  _Call(this.kind, this.search, this.from, this.to, this.tipo, this.estado, this.soloPendientes, this.page);
}

class _FakeDocumentRepository implements DocumentRepository {
  final List<_Call> calls = [];
  Either<Failure, DocumentPageEntity>? next;

  @override
  Future<Either<Failure, DocumentPageEntity>> getDocuments({
    required int companyId,
    required DocumentKind kind,
    String? search,
    DateTime? from,
    DateTime? to,
    DocumentTipo? tipo,
    DocumentEstado? estado,
    bool soloPendientes = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add(_Call(kind, search, from, to, tipo, estado, soloPendientes, page));
    return next ??
        Either.right(DocumentPageEntity(
          items: [
            DocumentEntity(id: page, kind: kind, numero: 'V001-000$page', comprobante: 'Nota de venta'),
          ],
          currentPage: page,
          lastPage: 2,
          total: 2,
        ));
  }
}

DocumentsProvider _provider(_FakeDocumentRepository repo) => DocumentsProvider(
      getDocumentsUseCase: GetDocumentsUseCase(repository: repo),
      now: () => DateTime(2026, 10, 28, 15, 30),
    )..syncCompany(7);

void main() {
  group('documentFromJson', () {
    test('arma el número de boleta y de factura como la web', () {
      expect(
        documentNumber({'boleta': {'tipo': 'b', 'serie': 1, 'numero': 123}}, DocumentKind.venta),
        'B001-00123',
      );
      expect(
        documentNumber({'boleta': {'tipo': 'f', 'serie': 1, 'numero': 45}}, DocumentKind.venta),
        'F001-0045',
      );
      expect(documentNumber({'nro_documento': 12}, DocumentKind.venta), 'V001-0012');
      expect(documentNumber({'nro_documento': 34}, DocumentKind.cotizacion), 'C001-0034');
    });

    test('lee una venta con sus productos y pagos', () {
      final d = documentFromJson({
        'id': 9,
        'nro_documento': 16,
        'estado': false,
        'total_soles': '51.50',
        'total_dolares': 0,
        'created_at': '2026-10-22T15:30:00.000000Z',
        'client': {'razon_social': '', 'name': 'GLADIS', 'last_name': 'PUCHOC'},
        'vendedor': {'name': 'LINDA'},
        'user': {'name': 'ADMIN'},
        'warehouse': {'name': 'LIMA'},
        'anulado_por': {'name': 'JEFE'},
        'products': [
          {
            'name': 'TORNILLO',
            'codigo': '8809',
            'brand': {'name': 'ANTONIO'},
            'pivot': {'cantidad': 2, 'precio': '17.50', 'subtotal_con_dto': '35.00', 'dolares': 0},
          },
        ],
        'payment_methods': [
          {
            'name': 'EFECTIVO',
            'pivot': {'monto': '51.50'},
          },
        ],
      }, DocumentKind.venta);

      expect(d.numero, 'V001-0016');
      expect(d.comprobante, 'Nota de venta');
      expect(d.activo, isFalse);
      expect(d.cliente, 'GLADIS PUCHOC');
      expect(d.vendedor, 'LINDA');
      expect(d.monto, 51.5);
      expect(d.simboloMoneda, 'S/');
      expect(d.anuladoPor, 'JEFE');
      expect(d.items.single.cantidad, 2);
      expect(d.items.single.subtotal, 35);
      expect(d.items.single.marca, 'ANTONIO');
      expect(d.pagos.single.metodo, 'EFECTIVO');
      expect(d.pagos.single.monto, 51.5);
    });

    test('el vendedor es el ejecutivo del cliente si lo hay, y el monto va en dólares si corresponde', () {
      final d = documentFromJson({
        'id': 1,
        'nro_documento': 1,
        'total_soles': 0,
        'total_dolares': 100,
        'ejecutivo_de_la_venta': {'name': 'EJECUTIVO'},
        'vendedor': {'name': 'OTRO'},
        'boleta': {'tipo': 'f', 'serie': 1, 'numero': 7},
      }, DocumentKind.venta);

      expect(d.vendedor, 'EJECUTIVO');
      expect(d.esDolares, isTrue);
      expect(d.monto, 100);
      expect(d.comprobante, 'Factura');
    });

    test('una cotización usa la fecha de emisión y dice si reservó stock', () {
      final d = documentFromJson({
        'id': 2,
        'nro_documento': 5,
        'estado': true,
        'reservar_stock': 1,
        'fecha_emision': '2026-10-20T10:00:00.000000Z',
        'created_at': '2026-10-01T10:00:00.000000Z',
      }, DocumentKind.cotizacion);

      expect(d.comprobante, 'Cotización');
      expect(d.reservado, isTrue);
      expect(d.creado!.toUtc().day, 20);
    });
  });

  group('DocumentDateRange', () {
    final now = DateTime(2026, 10, 28, 15, 30);

    test('hoy, semana, mes y todos', () {
      expect(DocumentDateRange.hoy.bounds(now), (DateTime(2026, 10, 28), DateTime(2026, 10, 28)));
      expect(DocumentDateRange.semana.bounds(now), (DateTime(2026, 10, 22), DateTime(2026, 10, 28)));
      expect(DocumentDateRange.mes.bounds(now), (DateTime(2026, 10, 1), DateTime(2026, 10, 28)));
      expect(DocumentDateRange.todos.bounds(now), isNull);
    });
  });

  group('DocumentsProvider', () {
    test('arranca con las ventas de hoy, como la web', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);

      await provider.ensureLoaded();

      final call = repo.calls.single;
      expect(call.kind, DocumentKind.venta);
      expect(call.from, DateTime(2026, 10, 28));
      expect(call.to, DateTime(2026, 10, 28));
      expect(provider.filtersActive, isFalse);
    });

    test('buscar por número ignora las fechas', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      await provider.setSearch(' 123 ');

      expect(repo.calls.last.search, '123');
      expect(repo.calls.last.from, isNull);
      expect(repo.calls.last.to, isNull);
    });

    test('cambiar de lista limpia los filtros propios de cada una', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.applyFilters(
        range: DocumentDateRange.mes,
        tipo: DocumentTipo.boleta,
        estado: DocumentEstado.activos,
      );
      expect(repo.calls.last.tipo, DocumentTipo.boleta);
      expect(provider.filtersActive, isTrue);

      await provider.selectKind(DocumentKind.cotizacion);

      expect(repo.calls.last.kind, DocumentKind.cotizacion);
      expect(repo.calls.last.tipo, isNull);
      expect(repo.calls.last.estado, isNull);
      // El rango de fechas se mantiene.
      expect(provider.range, DocumentDateRange.mes);
    });

    test('loadMore pide la página siguiente y se detiene al final', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.refresh();
      await provider.loadMore();
      await provider.loadMore();

      expect(provider.items, hasLength(2));
      expect(repo.calls.map((c) => c.page), [1, 2]);
    });

    test('cambiar de empresa descarta todo', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.refresh();

      provider.syncCompany(8);

      expect(provider.items, isEmpty);
      expect(provider.kind, DocumentKind.venta);
    });

    test('un error en la primera página queda en error', () async {
      final repo = _FakeDocumentRepository()
        ..next = Either.left(const NetworkFailure('Sin conexión a internet'));
      final provider = _provider(repo);

      await provider.refresh();

      expect(provider.error, 'Sin conexión a internet');
      expect(provider.items, isEmpty);
    });
  });
}
