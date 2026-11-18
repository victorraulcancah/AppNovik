/// Una lista de precios de la empresa: una fila de la tabla de `/lista-de-precios` de la web
/// (`GET /lista-de-precios`).
class PriceListEntity {
  final int id;
  final String name;

  /// `s` soles, `d` dólares.
  final String currency;
  final bool active;

  const PriceListEntity({
    required this.id,
    required this.name,
    required this.currency,
    required this.active,
  });

  bool get isDollars => currency == 'd';

  /// "Soles" o "Dólares", como los muestra la web.
  String get currencyLabel => isDollars ? 'Dólares' : 'Soles';

  /// "S/." o "$.", el prefijo de los precios de esta lista.
  String get symbol => isDollars ? r'$.' : 'S/.';
}

/// Una página de la lista de listas de precios.
class PriceListPageEntity {
  final List<PriceListEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const PriceListPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Lo que se filtra en la lista de listas de precios (lo mismo que la web): búsqueda por nombre
/// (cada término es un chip, como en la web) y los filtros de las columnas Moneda y Estado.
class PriceListFiltersEntity {
  final List<String> terms;

  /// `s` soles, `d` dólares, `null` ambas.
  final String? currency;

  /// `true` solo activas, `false` solo inactivas, `null` todas.
  final bool? active;

  const PriceListFiltersEntity({
    this.terms = const [],
    this.currency,
    this.active,
  });

  /// Cuántos filtros del panel hay puestos (sin contar la búsqueda).
  int get count => (currency != null ? 1 : 0) + (active != null ? 1 : 0);

  bool get isActive => terms.isNotEmpty || count > 0;

  PriceListFiltersEntity copyWith({
    List<String>? terms,
    String? currency,
    bool? active,
    bool clearCurrency = false,
    bool clearActive = false,
  }) => PriceListFiltersEntity(
    terms: terms ?? this.terms,
    currency: clearCurrency ? null : (currency ?? this.currency),
    active: clearActive ? null : (active ?? this.active),
  );
}

/// Lo que se manda al crear o editar una lista (`POST/PUT /lista-de-precios/storeOnlyList`).
/// La moneda solo se elige al crear: al editar no se envía.
class PriceListFormEntity {
  final String name;
  final String currency;
  final bool active;

  const PriceListFormEntity({
    required this.name,
    required this.currency,
    this.active = true,
  });
}

/// Un producto (o servicio) con el precio que tiene en una lista: una fila de la tabla del detalle
/// de la web (`GET /lista-de-precios/details`).
class PriceListProductEntity {
  final int id;

  /// `p` producto, `s` servicio.
  final String tipo;
  final String codigo;
  final String name;
  final String? marca;
  final String? imagen;

  /// El precio en esta lista; `null` si todavía no tiene.
  final double? precio;

  const PriceListProductEntity({
    required this.id,
    required this.tipo,
    required this.codigo,
    required this.name,
    this.marca,
    this.imagen,
    this.precio,
  });

  bool get esServicio => tipo == 's';

  PriceListProductEntity withPrice(double? value) => PriceListProductEntity(
    id: id,
    tipo: tipo,
    codigo: codigo,
    name: name,
    marca: marca,
    imagen: imagen,
    precio: value,
  );
}

/// Una página de productos de una lista de precios.
class PriceListProductPageEntity {
  final List<PriceListProductEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const PriceListProductPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Búsqueda y filtro de tipo del detalle de una lista.
class PriceListProductFiltersEntity {
  /// La web busca de un solo texto a la vez en el detalle.
  final String search;

  /// `p` productos, `s` servicios, `null` ambos.
  final String? tipo;

  const PriceListProductFiltersEntity({this.search = '', this.tipo});

  bool get isActive => search.isNotEmpty || tipo != null;

  PriceListProductFiltersEntity copyWith({
    String? search,
    String? tipo,
    bool clearTipo = false,
  }) => PriceListProductFiltersEntity(
    search: search ?? this.search,
    tipo: clearTipo ? null : (tipo ?? this.tipo),
  );
}
