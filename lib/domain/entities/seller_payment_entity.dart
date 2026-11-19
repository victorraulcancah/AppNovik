/// Estado de un pago de vendedor: lo mismo que el filtro "Estado" de la web
/// (`estado_filter`: 1 aprobado, 2 pendiente, 0 cancelado).
enum SellerPaymentStatus {
  cancelado(0),
  aprobado(1),
  pendiente(2);

  /// El valor que manda y recibe el servidor.
  final int code;
  const SellerPaymentStatus(this.code);

  String get label => switch (this) {
        SellerPaymentStatus.cancelado => 'Cancelado',
        SellerPaymentStatus.aprobado => 'Aprobado',
        SellerPaymentStatus.pendiente => 'Pendiente',
      };

  /// En plural, como los muestra el filtro de la web ("Aprobados", "Pendientes", "Cancelados").
  String get pluralLabel => switch (this) {
        SellerPaymentStatus.cancelado => 'Cancelados',
        SellerPaymentStatus.aprobado => 'Aprobados',
        SellerPaymentStatus.pendiente => 'Pendientes',
      };
}

/// Una opción de un filtro o de un selector: un cliente, un ejecutivo comercial o un método de pago.
class SellerPaymentOption {
  final int id;
  final String name;

  const SellerPaymentOption({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is SellerPaymentOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// La parte de un pago que se aplicó a una cuota (`fee_payments_sellers` en la web). Cuando un pago tiene
/// cuotas, editarlo es editar su primera parte.
class SellerPaymentAllocation {
  final int id;
  final int? paymentMethodId;
  final String? paymentMethodName;
  final double monto;

  /// Ya confirmada (aprobada): su monto no se puede cambiar.
  final bool confirmed;

  /// El monto total del pago al que pertenece (`payment_seller.monto_total`), si lo trae.
  final double? paymentTotal;

  const SellerPaymentAllocation({
    required this.id,
    this.paymentMethodId,
    this.paymentMethodName,
    this.monto = 0,
    this.confirmed = false,
    this.paymentTotal,
  });
}

/// La última nota (no eliminada) de un pago, tal como la trae la lista (`ultima_nota`).
class SellerPaymentLastNote {
  final String texto;
  final String? autor;

  const SellerPaymentLastNote({required this.texto, this.autor});
}

/// Una nota de un pago: la "Descripción adicional" ya no es un texto editable sino notas con autor y
/// fecha. Cada uno edita solo las suyas (las de otros no se editan: se agrega una nota nueva); eliminar
/// una no la borra: queda tachada con quién y cuándo.
class SellerPaymentNote {
  final int id;
  final String texto;
  final DateTime? creado;
  final String? autor;
  final DateTime? eliminadaEn;
  final String? eliminadaPor;

  /// Lo decide el servidor: cada uno elimina las suyas y quien tiene `pagos-vendedores.notas.destroy`
  /// las de todos.
  final bool puedeEliminar;

  /// Lo decide el servidor: solo el autor edita su nota (y mientras no esté eliminada).
  final bool puedeEditar;

  /// Cuándo se editó por última vez, si se editó.
  final DateTime? editadaEn;

  const SellerPaymentNote({
    required this.id,
    required this.texto,
    this.creado,
    this.autor,
    this.eliminadaEn,
    this.eliminadaPor,
    this.puedeEliminar = false,
    this.puedeEditar = false,
    this.editadaEn,
  });

  bool get editada => editadaEn != null;

  bool get eliminada => eliminadaEn != null;
}

/// El historial de notas de un pago (la más reciente primero) y si el usuario puede escribir una.
class SellerPaymentNotes {
  final List<SellerPaymentNote> notas;
  final bool puedeEscribir;

  const SellerPaymentNotes({this.notas = const [], this.puedeEscribir = false});
}

/// Un pago de un cliente registrado por un ejecutivo: una fila de "Registro de Pagos" de la web
/// (`GET /pagos-vendedores-new`).
class SellerPaymentEntity {
  final int id;
  final int? clientId;

  /// Razón social, o nombre y apellido, del cliente.
  final String cliente;

  /// Quien registró el pago (la columna "Ejecutivo").
  final String? ejecutivo;

  /// La columna "Descripción Adicional": la última nota del pago y cuántas hay (sin contar las eliminadas).
  final SellerPaymentLastNote? ultimaNota;
  final int notasCount;
  final DateTime? creado;
  final double montoTotal;

  /// `soles` o `dolares`.
  final String moneda;

  /// 1 aprobado, 2 pendiente, 0 cancelado.
  final int estado;

  /// Con `deleted_at` el registro está eliminado, igual que con estado 0.
  final bool deleted;
  final bool esSaldoAFavor;

  /// El método de pago del propio pago (un saldo a favor no tiene partes).
  final int? paymentMethodId;
  final String? paymentMethodName;
  final List<SellerPaymentAllocation> allocations;

  const SellerPaymentEntity({
    required this.id,
    this.clientId,
    this.cliente = '',
    this.ejecutivo,
    this.ultimaNota,
    this.notasCount = 0,
    this.creado,
    this.montoTotal = 0,
    this.moneda = 'soles',
    this.estado = 2,
    this.deleted = false,
    this.esSaldoAFavor = false,
    this.paymentMethodId,
    this.paymentMethodName,
    this.allocations = const [],
  });

  /// El texto de la última nota, si hay.
  String? get descripcion => ultimaNota?.texto;

  bool get esDolares => moneda == 'dolares';

  /// `$.` o `S/.`, como en la tabla de la web.
  String get simbolo => esDolares ? r'$.' : 'S/.';

  SellerPaymentStatus get status {
    if (deleted || estado == 0) return SellerPaymentStatus.cancelado;
    if (estado == 1) return SellerPaymentStatus.aprobado;
    return SellerPaymentStatus.pendiente;
  }

  /// Como la web: un pago sin partes (o marcado así) es un saldo a favor, y de ese solo se edita el
  /// método de pago y la descripción.
  bool get isSaldoAFavor => esSaldoAFavor || allocations.isEmpty;

  /// Los métodos de pago de sus partes (sin repetir) y, si no hay, el del propio pago.
  List<String> get metodos {
    final names = <String>[];
    for (final a in allocations) {
      final n = a.paymentMethodName;
      if (n != null && n.isNotEmpty && !names.contains(n)) names.add(n);
    }
    if (names.isEmpty && paymentMethodName != null && paymentMethodName!.isNotEmpty) {
      names.add(paymentMethodName!);
    }
    return names;
  }

  /// Lo que se edita: el propio pago si es un saldo a favor; si no, su primera parte.
  SellerPaymentAllocation? get editAllocation => isSaldoAFavor || allocations.isEmpty ? null : allocations.first;
}

/// Una página de la lista, con los totales de la cabecera de la web y los métodos de pago que
/// aparecen en lo filtrado (los que ofrece el panel de filtros).
class SellerPaymentPageEntity {
  final List<SellerPaymentEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final double totalSoles;
  final double totalDolares;
  final List<SellerPaymentOption> methods;

  const SellerPaymentPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.totalSoles = 0,
    this.totalDolares = 0,
    this.methods = const [],
  });

  bool get hasMore => currentPage < lastPage;
}

const Object _keep = Object();

/// Lo que se filtra en "Registro de Pagos" (lo mismo que el panel de la web): rango de fechas (por
/// defecto, el mes), clientes, ejecutivos, monto, métodos de pago y estado; más la búsqueda, que son
/// uno o varios términos que tienen que estar todos.
class SellerPaymentFilters {
  final DateTime? desde;
  final DateTime? hasta;
  final List<int> clientes;
  final List<int> ejecutivos;
  final double? montoMin;
  final double? montoMax;
  final List<int> metodos;
  final SellerPaymentStatus? estado;

  /// Los términos de búsqueda (`search[]`).
  final List<String> search;

  const SellerPaymentFilters({
    this.desde,
    this.hasta,
    this.clientes = const [],
    this.ejecutivos = const [],
    this.montoMin,
    this.montoMax,
    this.metodos = const [],
    this.estado,
    this.search = const [],
  });

  /// Lo que se ve al entrar: los pagos del mes.
  factory SellerPaymentFilters.mes(DateTime now) => SellerPaymentFilters(
        desde: DateTime(now.year, now.month),
        hasta: DateTime(now.year, now.month + 1, 0),
      );

  bool sameDates(SellerPaymentFilters other) => _sameDay(desde, other.desde) && _sameDay(hasta, other.hasta);

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a == null || b == null ? a == b : (a.year == b.year && a.month == b.month && a.day == b.day);

  /// Cuántos filtros del panel hay puestos distintos de como se entra (el mes), sin contar la búsqueda.
  int count(SellerPaymentFilters base) =>
      (sameDates(base) ? 0 : 1) +
      (clientes.isEmpty ? 0 : 1) +
      (ejecutivos.isEmpty ? 0 : 1) +
      (montoMin != null || montoMax != null ? 1 : 0) +
      (metodos.isEmpty ? 0 : 1) +
      (estado == null ? 0 : 1);

  SellerPaymentFilters copyWith({
    Object? desde = _keep,
    Object? hasta = _keep,
    List<int>? clientes,
    List<int>? ejecutivos,
    Object? montoMin = _keep,
    Object? montoMax = _keep,
    List<int>? metodos,
    Object? estado = _keep,
    List<String>? search,
  }) =>
      SellerPaymentFilters(
        desde: identical(desde, _keep) ? this.desde : desde as DateTime?,
        hasta: identical(hasta, _keep) ? this.hasta : hasta as DateTime?,
        clientes: clientes ?? this.clientes,
        ejecutivos: ejecutivos ?? this.ejecutivos,
        montoMin: identical(montoMin, _keep) ? this.montoMin : (montoMin as num?)?.toDouble(),
        montoMax: identical(montoMax, _keep) ? this.montoMax : (montoMax as num?)?.toDouble(),
        metodos: metodos ?? this.metodos,
        estado: identical(estado, _keep) ? this.estado : estado as SellerPaymentStatus?,
        search: search ?? this.search,
      );
}

/// Una línea del pago que se registra: un método de pago, su monto y una descripción opcional.
class SellerPaymentLine {
  final int paymentMethodId;
  final double monto;
  final String? descripcionAdicional;

  const SellerPaymentLine({
    required this.paymentMethodId,
    required this.monto,
    this.descripcionAdicional,
  });
}

/// Lo que se manda para registrar un pago (`POST /pagos-vendedores/deposito`): el cliente, la moneda,
/// la fecha de pago (opcional) y una o varias líneas.
class SellerPaymentCreate {
  final int clientId;

  /// `soles` o `dolares`.
  final String moneda;
  final DateTime? creado;
  final List<SellerPaymentLine> lines;

  const SellerPaymentCreate({
    required this.clientId,
    required this.moneda,
    required this.lines,
    this.creado,
  });
}

/// Lo que debe un cliente en soles y en dólares (`deuda_pendiente_soles` / `deuda_pendiente_dolares`).
class SellerClientDebt {
  final double soles;
  final double dolares;

  const SellerClientDebt({this.soles = 0, this.dolares = 0});
}
