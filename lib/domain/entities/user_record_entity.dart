/// Algo que se elige de una lista: un rol, un almacén, una lista de precios, un método de pago...
class UserOption {
  final int id;
  final String name;

  const UserOption({required this.id, required this.name});
}

/// Un permiso (`documentos.ventas.index`) tal como lo guarda el sistema.
class UserPermissionEntity {
  final int id;
  final String name;

  const UserPermissionEntity({required this.id, required this.name});
}

/// Los roles que la web trata aparte al armar el formulario (los números son los de la tabla `roles`).
class UserRoles {
  static const adminGlobal = 'Admin Global';
  static const ceoEmpresa = 'Ceo Empresa';
  static const adminEmpresa = 'Admin Empresa';
  static const contador = 'Contador';
  static const vendedor = 'Vendedor';
  static const jefeComercial = 'JEFE COMERCIAL';

  static const adminEmpresaId = 3;
  static const contadorId = 4;
  static const cajeroId = 6;
  static const vendedorId = 7;

  /// En pantalla el rol Vendedor se lee "Ejecutivo Comercial" (el dato guardado sigue siendo "Vendedor").
  static String display(String name) => name == vendedor ? 'Ejecutivo Comercial' : name;
}

/// Un usuario de la empresa, con lo que muestra la pantalla Usuarios de la web: su ficha personal,
/// sus roles, las sucursales, listas de precios y métodos de pago que puede usar y sus permisos
/// adicionales.
class UserRecordEntity {
  final int id;
  final String? codigo;
  final String? usuario;
  final String name;
  final String? email;
  final String? telefono;
  final bool estado;
  final bool ventasAjenas;

  // La ficha personal.
  final String? tipoDocumento;
  final String? numeroDocumento;
  final String? nombres;
  final String? apellidos;

  /// Fecha de nacimiento (`yyyy-MM-dd`).
  final String? cumple;
  final String? direccion;
  final String? departmentId;
  final String? provinceId;
  final String? districtId;
  final String? contactoEmergencia;
  final String? telefonoEmergencia;
  final String? area;

  /// Fecha de ingreso (`yyyy-MM-dd`).
  final String? fechaIngreso;

  /// Ruta de la foto en el servidor; `null` si no tiene.
  final String? foto;

  // Lo que puede usar.
  final int? warehouseId;
  final int? listPriceId;
  final int? paymentMethodId;

  /// `e` entrega inmediata, `d` despacho.
  final String? metodoEntrega;
  final List<UserOption> roles;
  final List<UserOption> warehouses;
  final List<UserOption> listPrices;
  final List<UserOption> paymentMethods;
  final List<UserPermissionEntity> permissions;
  final DateTime? creado;

  const UserRecordEntity({
    required this.id,
    this.codigo,
    this.usuario,
    required this.name,
    this.email,
    this.telefono,
    this.estado = true,
    this.ventasAjenas = false,
    this.tipoDocumento,
    this.numeroDocumento,
    this.nombres,
    this.apellidos,
    this.cumple,
    this.direccion,
    this.departmentId,
    this.provinceId,
    this.districtId,
    this.contactoEmergencia,
    this.telefonoEmergencia,
    this.area,
    this.fechaIngreso,
    this.foto,
    this.warehouseId,
    this.listPriceId,
    this.paymentMethodId,
    this.metodoEntrega,
    this.roles = const [],
    this.warehouses = const [],
    this.listPrices = const [],
    this.paymentMethods = const [],
    this.permissions = const [],
    this.creado,
  });

  bool hasRole(String role) => roles.any((r) => r.name == role);

  /// Los roles como se leen en pantalla ("Ejecutivo Comercial" en lugar de "Vendedor").
  String get rolesLabel => roles.map((r) => UserRoles.display(r.name)).join(', ');

  /// El Ceo y el Admin de la empresa trabajan con todas las sucursales y listas de precios.
  bool get seesEverything => hasRole(UserRoles.adminEmpresa) || hasRole(UserRoles.ceoEmpresa);

  /// La misma ficha con la foto recién subida.
  UserRecordEntity withFoto(String path) => UserRecordEntity(
        id: id,
        codigo: codigo,
        usuario: usuario,
        name: name,
        email: email,
        telefono: telefono,
        estado: estado,
        ventasAjenas: ventasAjenas,
        tipoDocumento: tipoDocumento,
        numeroDocumento: numeroDocumento,
        nombres: nombres,
        apellidos: apellidos,
        cumple: cumple,
        direccion: direccion,
        departmentId: departmentId,
        provinceId: provinceId,
        districtId: districtId,
        contactoEmergencia: contactoEmergencia,
        telefonoEmergencia: telefonoEmergencia,
        area: area,
        fechaIngreso: fechaIngreso,
        foto: path,
        warehouseId: warehouseId,
        listPriceId: listPriceId,
        paymentMethodId: paymentMethodId,
        metodoEntrega: metodoEntrega,
        roles: roles,
        warehouses: warehouses,
        listPrices: listPrices,
        paymentMethods: paymentMethods,
        permissions: permissions,
        creado: creado,
      );
}

/// Una página de la lista de usuarios.
class UserPageEntity {
  final List<UserRecordEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const UserPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Búsqueda y filtros de la lista. La web busca por usuario, nombre, roles, correo y teléfono, y
/// filtra por estado en la columna Estado.
class UserFiltersEntity {
  /// Texto de la búsqueda (`search`).
  final String search;

  /// `true` activos, `false` inactivos, `null` todos.
  final bool? estado;

  /// Nombre guardado del rol (`Vendedor`, no "Ejecutivo Comercial"); `null` todos.
  final String? role;

  const UserFiltersEntity({this.search = '', this.estado, this.role});

  /// Si hay algún filtro del panel puesto (la búsqueda no cuenta).
  bool get hasPanelFilters => estado != null || role != null;

  /// Si hay búsqueda o algún filtro.
  bool get active => search.isNotEmpty || hasPanelFilters;

  UserFiltersEntity copyWith({
    String? search,
    bool? estado,
    String? role,
    bool clearEstado = false,
    bool clearRole = false,
  }) =>
      UserFiltersEntity(
        search: search ?? this.search,
        estado: clearEstado ? null : (estado ?? this.estado),
        role: clearRole ? null : (role ?? this.role),
      );
}

/// Las listas que usa el formulario: roles, sucursales, listas de precios, métodos de pago y los
/// permisos que se pueden agregar.
class UserCatalogsEntity {
  final List<UserOption> roles;
  final List<UserOption> warehouses;
  final List<UserOption> listPrices;
  final List<UserOption> paymentMethods;
  final List<UserPermissionEntity> permissions;

  const UserCatalogsEntity({
    this.roles = const [],
    this.warehouses = const [],
    this.listPrices = const [],
    this.paymentMethods = const [],
    this.permissions = const [],
  });
}

/// Lo que se llena en el formulario de usuario (los mismos campos de la web).
class UserFormEntity {
  /// `DNI`, `CE` o `PASAPORTE`.
  final String tipoDocumento;
  final String numeroDocumento;
  final String? fechaIngreso;
  final bool estado;
  final String nombres;
  final String apellidos;
  final String? cumple;
  final String telefono;
  final String email;
  final String direccion;
  final String? departmentId;
  final String? provinceId;
  final String? districtId;
  final String contactoEmergencia;
  final String telefonoEmergencia;

  final List<int> roles;
  final bool ventasAjenas;
  final List<int> almacenes;
  final int? warehouseId;
  final List<int> paymentMethods;
  final int? paymentMethodId;
  final String? metodoEntrega;
  final List<int> listPrices;
  final int? listPriceId;
  final List<int> permisos;

  /// Según los roles elegidos, lo mismo que decide la web: si se piden los métodos de pago, si se
  /// piden las listas de precios y si es un Vendedor (ventas ajenas y método de entrega).
  final bool conPagos;
  final bool conListas;
  final bool esVendedor;

  const UserFormEntity({
    this.tipoDocumento = 'DNI',
    this.numeroDocumento = '',
    this.fechaIngreso,
    this.estado = true,
    this.nombres = '',
    this.apellidos = '',
    this.cumple,
    this.telefono = '',
    this.email = '',
    this.direccion = '',
    this.departmentId,
    this.provinceId,
    this.districtId,
    this.contactoEmergencia = '',
    this.telefonoEmergencia = '',
    this.roles = const [],
    this.ventasAjenas = false,
    this.almacenes = const [],
    this.warehouseId,
    this.paymentMethods = const [],
    this.paymentMethodId,
    this.metodoEntrega,
    this.listPrices = const [],
    this.listPriceId,
    this.permisos = const [],
    this.conPagos = false,
    this.conListas = false,
    this.esVendedor = false,
  });

  /// El nombre completo que usa el resto del sistema (`nombres` + `apellidos`).
  String get fullName => [nombres, apellidos].map((p) => p.trim()).where((p) => p.isNotEmpty).join(' ');
}
