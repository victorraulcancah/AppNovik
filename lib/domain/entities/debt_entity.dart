/// Un cliente con deuda pendiente: una fila de la tabla "Deudas Pendientes" de la web
/// (`GET /deudas/clientes/resumen`).
class DebtClientEntity {
  final int id;
  final String cliente;

  /// Lo que debe en soles y en dólares (puede ser negativo si tiene saldo a favor).
  final double deudaSoles;
  final double deudaDolares;

  /// Cuánto de su línea de crédito está usando (en soles).
  final double lineaUtilizada;

  /// Su línea de crédito.
  final double credito;

  const DebtClientEntity({
    required this.id,
    required this.cliente,
    required this.deudaSoles,
    required this.deudaDolares,
    required this.lineaUtilizada,
    required this.credito,
  });
}

/// Una página de la lista de deudas, con los dos totales de la cabecera de la web.
class DebtPageEntity {
  final List<DebtClientEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final double totalSoles;
  final double totalDolares;

  const DebtPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.totalSoles = 0,
    this.totalDolares = 0,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Una opción de los filtros (un cliente o un ejecutivo comercial).
class DebtOption {
  final int id;
  final String name;

  const DebtOption({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is DebtOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Lo que se filtra en Deudas (lo mismo que la web): cliente y ejecutivo comercial, más la
/// búsqueda por nombre del cliente.
class DebtFiltersEntity {
  final String search;
  final DebtOption? client;
  final DebtOption? seller;

  const DebtFiltersEntity({this.search = '', this.client, this.seller});

  /// Cuántos filtros del panel hay puestos (sin contar la búsqueda).
  int get count => (client != null ? 1 : 0) + (seller != null ? 1 : 0);

  bool get active => search.isNotEmpty || count > 0;

  DebtFiltersEntity copyWith({
    String? search,
    DebtOption? client,
    DebtOption? seller,
    bool clearClient = false,
    bool clearSeller = false,
  }) =>
      DebtFiltersEntity(
        search: search ?? this.search,
        client: clearClient ? null : (client ?? this.client),
        seller: clearSeller ? null : (seller ?? this.seller),
      );
}
