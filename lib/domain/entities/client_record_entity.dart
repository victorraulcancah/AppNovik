/// Un cliente tal como lo muestra el módulo Clientes (lista, detalle y formulario de edición).
/// No es el `ClientEntity` de Ventas, que solo lleva lo necesario para vender.
class ClientRecordEntity {
  final int id;
  final String? codigo;

  /// `p` persona o `e` empresa.
  final String tipo;
  final String dniRuc;
  final String name;
  final String? lastName;
  final String? razonSocial;
  final String? direccion;
  final String? calle;
  final String? lote;
  final String? indicaciones;
  final String? email;
  final String? telefono;
  final String? giro;
  final String? nota;
  final String? redes;
  final String? pagina2;
  final String? pagina3;

  /// Cumpleaños como `yyyy-MM-dd`.
  final String? cumple;
  final bool estado;
  final bool extranjero;
  final double credito;
  final double creditoDisponible;
  final double lineaUtilizada;

  final int? ejecutivoId;
  final String? ejecutivoNombre;
  final int? categoriaId;
  final String? categoriaNombre;
  final String? categoriaCodigo;
  final int? listPriceId;
  final int? paymentMethodId;

  final String? departmentId;
  final String? provinceId;
  final String? districtId;
  final String? departmentName;
  final String? provinceName;
  final String? districtName;

  /// Quién registró al cliente y cuándo.
  final String? registradoPor;
  final DateTime? creado;

  final List<ClientAddressEntity> addresses;
  final List<ClientContactEntity> contacts;

  const ClientRecordEntity({
    required this.id,
    this.codigo,
    this.tipo = 'p',
    this.dniRuc = '',
    this.name = '',
    this.lastName,
    this.razonSocial,
    this.direccion,
    this.calle,
    this.lote,
    this.indicaciones,
    this.email,
    this.telefono,
    this.giro,
    this.nota,
    this.redes,
    this.pagina2,
    this.pagina3,
    this.cumple,
    this.estado = true,
    this.extranjero = false,
    this.credito = 0,
    this.creditoDisponible = 0,
    this.lineaUtilizada = 0,
    this.ejecutivoId,
    this.ejecutivoNombre,
    this.categoriaId,
    this.categoriaNombre,
    this.categoriaCodigo,
    this.listPriceId,
    this.paymentMethodId,
    this.departmentId,
    this.provinceId,
    this.districtId,
    this.departmentName,
    this.provinceName,
    this.districtName,
    this.registradoPor,
    this.creado,
    this.addresses = const [],
    this.contacts = const [],
  });

  bool get esEmpresa => tipo == 'e';

  /// Razón social en empresas; nombre y apellido en personas (como la columna de la web).
  String get displayName {
    final text = esEmpresa
        ? (razonSocial ?? '')
        : [name, lastName ?? ''].where((t) => t.trim().isNotEmpty).join(' ');
    return text.trim().isEmpty ? (name.trim().isEmpty ? dniRuc : name.trim()) : text.trim();
  }
}

class ClientAddressEntity {
  /// `null` en una dirección que todavía no se guardó.
  final int? id;
  final String direccion;
  final String? calle;
  final String? lote;
  final String? indicaciones;
  final double? latitud;
  final double? longitud;
  final String? departmentId;
  final String? provinceId;
  final String? districtId;
  final String? provinceName;
  final String? districtName;
  final bool predeterminado;

  const ClientAddressEntity({
    this.id,
    this.direccion = '',
    this.calle,
    this.lote,
    this.indicaciones,
    this.latitud,
    this.longitud,
    this.departmentId,
    this.provinceId,
    this.districtId,
    this.provinceName,
    this.districtName,
    this.predeterminado = false,
  });

  ClientAddressEntity copyWith({
    String? direccion,
    String? calle,
    String? lote,
    String? indicaciones,
    String? departmentId,
    String? provinceId,
    String? districtId,
    bool? predeterminado,
    bool clearUbigeo = false,
  }) =>
      ClientAddressEntity(
        id: id,
        direccion: direccion ?? this.direccion,
        calle: calle ?? this.calle,
        lote: lote ?? this.lote,
        indicaciones: indicaciones ?? this.indicaciones,
        latitud: latitud,
        longitud: longitud,
        departmentId: clearUbigeo ? null : (departmentId ?? this.departmentId),
        provinceId: clearUbigeo ? null : (provinceId ?? this.provinceId),
        districtId: clearUbigeo ? null : (districtId ?? this.districtId),
        provinceName: provinceName,
        districtName: districtName,
        predeterminado: predeterminado ?? this.predeterminado,
      );
}

class ClientContactEntity {
  final int? id;
  final String name;
  final String? lastName;
  final String? email;
  final String? telefono;

  const ClientContactEntity({
    this.id,
    this.name = '',
    this.lastName,
    this.email,
    this.telefono,
  });
}

/// Una página de la lista de clientes, con los contadores de Personas y Empresas de la web.
class ClientPageEntity {
  final List<ClientRecordEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int totalPersonas;
  final int totalEmpresas;

  const ClientPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.totalPersonas = 0,
    this.totalEmpresas = 0,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Atajos de los filtros de Categoría y Ejecutivo: sin ninguno / con alguno.
const clientFilterNone = 'sin';
const clientFilterAny = 'con';

/// Lo que se filtra en la lista de clientes (los mismos filtros que la web). Los valores de
/// [categorias] y [ejecutivos] son ids como texto, o [clientFilterNone] / [clientFilterAny].
class ClientFiltersEntity {
  /// Términos de búsqueda: cada palabra tiene que aparecer en algún campo.
  final List<String> search;

  /// `p`, `e` o `null` (ambos).
  final String? tipo;

  /// `true` activos, `false` inactivos, `null` ambos.
  final bool? estado;
  final Set<String> categorias;
  final Set<String> ejecutivos;
  final Set<String> departamentos;

  const ClientFiltersEntity({
    this.search = const [],
    this.tipo,
    this.estado,
    this.categorias = const {},
    this.ejecutivos = const {},
    this.departamentos = const {},
  });

  /// Los filtros del panel (sin contar la búsqueda).
  bool get panelActive =>
      tipo != null || estado != null || categorias.isNotEmpty || ejecutivos.isNotEmpty || departamentos.isNotEmpty;

  bool get active => panelActive || search.isNotEmpty;

  ClientFiltersEntity copyWith({
    List<String>? search,
    String? tipo,
    bool clearTipo = false,
    bool? estado,
    bool clearEstado = false,
    Set<String>? categorias,
    Set<String>? ejecutivos,
    Set<String>? departamentos,
  }) =>
      ClientFiltersEntity(
        search: search ?? this.search,
        tipo: clearTipo ? null : (tipo ?? this.tipo),
        estado: clearEstado ? null : (estado ?? this.estado),
        categorias: categorias ?? this.categorias,
        ejecutivos: ejecutivos ?? this.ejecutivos,
        departamentos: departamentos ?? this.departamentos,
      );
}

/// Opción de un filtro, con cuántos clientes trae.
class ClientFilterOption {
  final String id;
  final String name;
  final int clientes;

  const ClientFilterOption({required this.id, required this.name, this.clientes = 0});
}

/// Lo que ofrecen los filtros: categorías, ejecutivos con clientes y departamentos con clientes.
class ClientFilterCatalogsEntity {
  final List<ClientFilterOption> categorias;
  final int sinCategoria;
  final int conCategoria;
  final List<ClientFilterOption> ejecutivos;
  final List<ClientFilterOption> departamentos;

  const ClientFilterCatalogsEntity({
    this.categorias = const [],
    this.sinCategoria = 0,
    this.conCategoria = 0,
    this.ejecutivos = const [],
    this.departamentos = const [],
  });
}

/// Opción de una lista de selección del formulario (lista de precios, método de pago, ejecutivo).
class ClientOption {
  final int id;
  final String name;

  const ClientOption({required this.id, required this.name});
}

/// Lo que necesita el formulario: ejecutivos comerciales (Vendedor o Ceo), listas de precios,
/// métodos de pago y categorías.
class ClientFormCatalogsEntity {
  final List<ClientOption> ejecutivos;
  final List<ClientOption> listasDePrecios;
  final List<ClientOption> metodosDePago;
  final List<ClientCategoryEntity> categorias;

  const ClientFormCatalogsEntity({
    this.ejecutivos = const [],
    this.listasDePrecios = const [],
    this.metodosDePago = const [],
    this.categorias = const [],
  });
}

/// Categoría de cliente (Socio, Distribuidor...) con los montos de cada ciclo.
class ClientCategoryEntity {
  final int id;
  final String nombre;
  final String codigo;
  final int orden;

  /// Rango que rige hoy (el del ciclo activo).
  final double? montoDesde;
  final double? montoHasta;

  /// Rango de cada ciclo: `mensual`, `trimestral`, `cuatrimestral`, `anual`.
  final Map<String, CategoryRange> rangos;

  const ClientCategoryEntity({
    required this.id,
    required this.nombre,
    required this.codigo,
    this.orden = 0,
    this.montoDesde,
    this.montoHasta,
    this.rangos = const {},
  });

  CategoryRange rangoDe(String ciclo) => rangos[ciclo] ?? const CategoryRange();

  ClientCategoryEntity copyWith({String? nombre, Map<String, CategoryRange>? rangos}) => ClientCategoryEntity(
        id: id,
        nombre: nombre ?? this.nombre,
        codigo: codigo,
        orden: orden,
        montoDesde: montoDesde,
        montoHasta: montoHasta,
        rangos: rangos ?? this.rangos,
      );
}

class CategoryRange {
  final double? desde;
  final double? hasta;

  const CategoryRange({this.desde, this.hasta});
}

/// Qué compras se miran hoy en un ciclo y cuándo cambia el resultado.
class CategoryPeriod {
  final String? evaluadoDesde;
  final String? evaluadoHasta;
  final String? vigenteDesde;
  final String? cambiaEl;

  const CategoryPeriod({this.evaluadoDesde, this.evaluadoHasta, this.vigenteDesde, this.cambiaEl});
}

/// Las categorías y el ciclo de actualización de la empresa.
class CategoriesConfigEntity {
  final List<ClientCategoryEntity> categorias;

  /// `mensual`, `trimestral`, `cuatrimestral` o `anual`.
  final String ciclo;
  final Map<String, CategoryPeriod> periodos;

  const CategoriesConfigEntity({
    this.categorias = const [],
    this.ciclo = 'mensual',
    this.periodos = const {},
  });
}

/// Resultado de recalcular las categorías.
class CategoryCalcEntity {
  final bool recalculado;
  final String? mensaje;
  final String? desde;
  final String? hasta;
  final int clientesActualizados;

  const CategoryCalcEntity({
    required this.recalculado,
    this.mensaje,
    this.desde,
    this.hasta,
    this.clientesActualizados = 0,
  });
}

const categoryCycles = ['mensual', 'trimestral', 'cuatrimestral', 'anual'];

/// Todo lo que se guarda al crear o editar un cliente. Los bloques `null` no se mandan: el
/// backend deja como estaba lo que no recibe (así quien solo puede editar un bloque no toca el resto).
class ClientFormEntity {
  final String tipo;
  final String dniRuc;
  final String name;
  final String? lastName;
  final String? razonSocial;
  final String telefono;
  final String email;
  final String? giro;
  final bool extranjero;
  final bool estado;
  final String departmentId;
  final String provinceId;
  final String districtId;
  final String? calle;
  final String? direccion;
  final String? lote;
  final String? indicaciones;
  final int? ejecutivoId;

  /// Información adicional.
  final String? redes;
  final String? pagina2;
  final String? pagina3;
  final String? cumple;
  final String? nota;

  /// Condiciones de venta (solo con permiso).
  final bool incluyeCondiciones;
  final int? listPriceId;
  final int? paymentMethodId;
  final double? credito;

  /// `null` = no se tocan las direcciones / contactos.
  final List<ClientAddressEntity>? addresses;
  final List<ClientContactEntity>? contacts;

  /// Información básica (tipo, documento, nombre, teléfono, correo, dirección, ejecutivo...). Sin
  /// permiso para editarla, no se manda.
  final bool incluyeBasica;

  const ClientFormEntity({
    this.tipo = 'p',
    this.dniRuc = '',
    this.name = '',
    this.lastName,
    this.razonSocial,
    this.telefono = '',
    this.email = '',
    this.giro,
    this.extranjero = false,
    this.estado = true,
    this.departmentId = '',
    this.provinceId = '',
    this.districtId = '',
    this.calle,
    this.direccion,
    this.lote,
    this.indicaciones,
    this.ejecutivoId,
    this.redes,
    this.pagina2,
    this.pagina3,
    this.cumple,
    this.nota,
    this.incluyeCondiciones = false,
    this.listPriceId,
    this.paymentMethodId,
    this.credito,
    this.addresses,
    this.contacts,
    this.incluyeBasica = true,
  });

  bool get esEmpresa => tipo == 'e';
}
