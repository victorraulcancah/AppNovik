import 'dart:async';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/domain/entities/account_statement_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/account_statement_fakes.dart';

void main() {
  late FakeStatementRepository repo;

  setUp(() => repo = FakeStatementRepository());

  test('sin cliente no se pide nada', () async {
    final p = statementProvider(repo)..syncSession(statementSession());

    await p.ensureLoaded();
    await p.refresh();

    expect(repo.calls, isEmpty);
    expect(p.hasClient, isFalse);
    expect(p.summaryLoading, isFalse);
  });

  test('al elegir un cliente se pide la pestaña principal con el mes y llega la cabecera', () async {
    final p = statementProvider(repo)..syncSession(statementSession());

    await p.selectClient(acme);

    expect(repo.calls, ['main:1']);
    expect(repo.lastQuery!.clientId, 7);
    expect(repo.lastQuery!.from, DateTime(2026, 11));
    expect(repo.lastQuery!.to, DateTime(2026, 11, 18));
    expect(p.current.rows.map((r) => r.id), ['s-1', 'f-1']);
    expect(p.summary!.deudaTotalSoles, 1500.5);
    expect(p.summaryLoading, isFalse);
  });

  test('mientras llega, la cabecera está cargando', () async {
    repo.mainGate = Completer<void>();
    final p = statementProvider(repo)..syncSession(statementSession());

    final future = p.selectClient(acme);
    expect(p.summaryLoading, isTrue);
    expect(p.current.loading, isTrue);

    repo.mainGate!.complete();
    await future;
    expect(p.summaryLoading, isFalse);
  });

  test('las otras pestañas se piden al abrirlas, una sola vez', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);

    await p.selectTab(StatementTab.pedidos);
    await p.selectTab(StatementTab.pagos);
    await p.selectTab(StatementTab.pedidos);

    expect(repo.calls, ['main:1', 'orders:1', 'payments:1']);
    expect(p.lists[StatementTab.pedidos]!.rows.single.titulo, 'PEDIDO 2');
  });

  test('cambiar de fechas vacía todo, también la cabecera, y vuelve a pedir la pestaña abierta', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);
    await p.selectTab(StatementTab.pedidos);
    repo.calls.clear();

    await p.selectRange(StatementRange.ultimoMes);

    expect(repo.calls, ['main:1', 'orders:1']);
    expect(repo.lastQuery!.from, DateTime(2026, 10));
    expect(repo.lastQuery!.to, DateTime(2026, 10, 31));
    // Una pestaña que no estaba abierta no se pide hasta abrirla.
    expect(p.lists[StatementTab.pagos]!.loaded, isFalse);
  });

  test('fechas personalizadas', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);

    await p.selectCustom((start: DateTime(2026, 5, 1), end: DateTime(2026, 5, 15)));

    expect(p.range, StatementRange.personalizado);
    expect(repo.lastQuery!.from, DateTime(2026, 5, 1));
    expect(repo.lastQuery!.to, DateTime(2026, 5, 15));
  });

  test('quitar el cliente vacía todo y no pide nada', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);
    repo.calls.clear();

    await p.selectClient(null);

    expect(p.hasClient, isFalse);
    expect(p.summary, isNull);
    expect(p.current.rows, isEmpty);
    expect(repo.calls, isEmpty);
  });

  test('una respuesta tardía de otro cliente se descarta', () async {
    repo.mainGate = Completer<void>();
    final p = statementProvider(repo)..syncSession(statementSession());

    final first = p.selectClient(acme); // pide las filas de ACME…
    repo.main = [saleRow(9)];
    final second = p.selectClient(ana); // …y antes de que lleguen se elige a ANA
    repo.mainGate!.complete();
    await Future.wait([first, second]);

    expect(p.client!.id, 8);
    expect(p.current.rows.map((r) => r.id), ['s-9']);
  });

  test('el modo agrupado vuelve a pedir la principal con agrupado', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);
    repo.calls.clear();

    await p.setAgrupado(true);

    expect(repo.calls, ['main:1']);
    expect(repo.lastQuery!.agrupado, isTrue);
    await p.setAgrupado(true);
    expect(repo.calls, ['main:1'], reason: 'sin cambio no repite');
  });

  test('la búsqueda de producto se pide sin espacios y solo si cambió', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);
    repo.calls.clear();

    await p.setSearch('  sub ');
    await p.setSearch('sub');

    expect(repo.calls, ['main:1']);
    expect(repo.lastQuery!.search, 'sub');
  });

  test('paginación: la siguiente página se agrega y se detiene al llegar al total', () async {
    repo.main = [for (var i = 1; i <= 45; i++) saleRow(i)];
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);

    expect(p.current.rows, hasLength(30));
    expect(p.current.hasMore, isTrue);

    await p.loadMore();
    expect(p.current.rows, hasLength(45));
    expect(p.current.hasMore, isFalse);

    await p.loadMore();
    expect(repo.calls, ['main:1', 'main:2']);
  });

  test('un error se guarda y reintentar lo recupera', () async {
    repo.mainFailure = const ServerFailure('Error del servidor');
    final p = statementProvider(repo)..syncSession(statementSession());

    await p.selectClient(acme);
    expect(p.current.error, 'Error del servidor');
    expect(p.current.rows, isEmpty);
    expect(p.summaryLoading, isFalse, reason: 'con error no queda cargando para siempre');

    repo.mainFailure = null;
    await p.refresh();
    expect(p.current.error, isNull);
    expect(p.current.rows, isNotEmpty);
  });

  test('si vence la sesión avisa y no deja un error en pantalla', () async {
    var expired = 0;
    repo.mainFailure = const AuthenticationFailure('Sesión expirada');
    final p = statementProvider(repo, onExpired: () => expired++)..syncSession(statementSession());

    await p.selectClient(acme);

    expect(expired, 1);
    expect(p.current.error, isNull);
  });

  test('cambiar de empresa descarta todo', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);
    await p.setAgrupado(true);

    p.syncSession(statementSession(companyId: 99));

    expect(p.client, isNull);
    expect(p.summary, isNull);
    expect(p.agrupado, isFalse);
    expect(p.range, StatementRange.esteMes);
    expect(p.current.rows, isEmpty);
  });

  test('la misma empresa no descarta nada', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);

    p.syncSession(statementSession());

    expect(p.client, acme);
    expect(p.current.rows, isNotEmpty);
  });

  test('buscar clientes pide los de la empresa', () async {
    final p = statementProvider(repo)..syncSession(statementSession());

    final result = await p.searchClients(' ana ');

    expect(repo.calls, ['search:ana']);
    expect(result.right.map((c) => c.name), ['ACME SAC', 'ANA RUIZ']);
  });

  test('el Excel lleva el nombre de la pestaña y del cliente', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);
    await p.selectTab(StatementTab.pagos);

    final file = (await p.exportExcel()).right;

    expect(repo.calls.last, 'excel:pagos');
    expect(file.name, 'Estado de cuenta Pagos - ACME SAC.xlsx');
    expect(p.exporting, isFalse);
  });

  test('el PDF se pide con el modo agrupado y tiene nombre de archivo', () async {
    final p = statementProvider(repo)..syncSession(statementSession());
    await p.selectClient(acme);
    await p.setAgrupado(true);

    final result = await p.exportPdf();

    expect(result.isRight, isTrue);
    expect(repo.calls.last, 'pdf:true');
    expect(p.pdfFileName, 'Estado de cuenta - ACME SAC.pdf');
  });

  test('sin cliente no se exporta', () async {
    final p = statementProvider(repo)..syncSession(statementSession());

    expect((await p.exportExcel()).isLeft, isTrue);
    expect((await p.exportPdf()).isLeft, isTrue);
    expect(repo.calls, isEmpty);
  });
}
