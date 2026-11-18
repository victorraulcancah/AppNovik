import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/client_form_entity.dart' show UbigeoItemEntity;
import '../../domain/entities/session_context_entity.dart';
import '../../domain/entities/user_record_entity.dart';
import '../../domain/usecases/user_record_usecases.dart';

/// Estado del módulo Usuarios: lista con búsqueda, filtros (rol y estado) y paginación, el
/// formulario de usuario con su foto, y los roles (crear, renombrar y eliminar).
class UsersProvider extends ChangeNotifier {
  static const pageSize = 20;

  final GetUsersUseCase _getUsers;
  final GetUserCatalogsUseCase _getCatalogs;
  final SaveUserUseCase _saveUser;
  final UploadUserPhotoUseCase _uploadPhoto;
  final GetUserPhotoUseCase _getPhoto;
  final GetRolesUseCase _getRoles;
  final SaveRoleUseCase _saveRole;
  final DeleteRoleUseCase _deleteRole;
  final GetUserDepartmentsUseCase _getDepartments;
  final GetUserProvincesUseCase _getProvinces;
  final GetUserDistrictsUseCase _getDistricts;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? onSessionExpired;

  UsersProvider({
    required GetUsersUseCase getUsersUseCase,
    required GetUserCatalogsUseCase getCatalogsUseCase,
    required SaveUserUseCase saveUserUseCase,
    required UploadUserPhotoUseCase uploadPhotoUseCase,
    required GetUserPhotoUseCase getPhotoUseCase,
    required GetRolesUseCase getRolesUseCase,
    required SaveRoleUseCase saveRoleUseCase,
    required DeleteRoleUseCase deleteRoleUseCase,
    required GetUserDepartmentsUseCase getDepartmentsUseCase,
    required GetUserProvincesUseCase getProvincesUseCase,
    required GetUserDistrictsUseCase getDistrictsUseCase,
    this.onSessionExpired,
  })  : _getUsers = getUsersUseCase,
        _getCatalogs = getCatalogsUseCase,
        _saveUser = saveUserUseCase,
        _uploadPhoto = uploadPhotoUseCase,
        _getPhoto = getPhotoUseCase,
        _getRoles = getRolesUseCase,
        _saveRole = saveRoleUseCase,
        _deleteRole = deleteRoleUseCase,
        _getDepartments = getDepartmentsUseCase,
        _getProvinces = getProvincesUseCase,
        _getDistricts = getDistrictsUseCase;

  int? _companyId;
  bool _isCeo = false;
  bool _canStoreContador = false;
  int _page = 0;
  int _request = 0;
  UserCatalogsEntity? _catalogs;
  List<UserOption>? _roles;
  List<UbigeoItemEntity>? _departments;
  final Map<String, List<UbigeoItemEntity>> _provinces = {};
  final Map<String, List<UbigeoItemEntity>> _districts = {};
  final Map<int, Uint8List?> _photos = {};

  List<UserRecordEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  String? error;
  UserFiltersEntity filters = const UserFiltersEntity();

  /// Los roles ya traídos (para ponerle nombre al chip del filtro); `null` hasta pedirlos.
  List<UserOption>? get roles => _roles;

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo, para no mostrar
  /// usuarios de la empresa anterior. No notifica: corre mientras se arma el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    _isCeo = session?.hasRole(UserRoles.ceoEmpresa) ?? false;
    _canStoreContador = session?.can('usuarios.store.contador') ?? false;
    final companyId = session?.company.id;
    if (companyId == _companyId) return;
    _companyId = companyId;
    items = [];
    loading = false;
    loadingMore = false;
    hasMore = false;
    total = 0;
    error = null;
    filters = const UserFiltersEntity();
    _page = 0;
    _request++;
    _catalogs = null;
    _roles = null;
    _departments = null;
    _provinces.clear();
    _districts.clear();
    _photos.clear();
  }

  bool _isExpired(Failure failure) {
    if (failure is AuthenticationFailure) {
      onSessionExpired?.call();
      return true;
    }
    return false;
  }

  /// Los roles que el usuario puede asignar: como la web, solo el Ceo asigna Ceo y Admin Empresa, y
  /// el Contador exige el permiso `usuarios.store.contador`.
  List<UserOption> assignableRoles(List<UserOption> all) => [
        for (final r in all)
          if ((_isCeo || (r.name != UserRoles.ceoEmpresa && r.name != UserRoles.adminEmpresa)) &&
              (_canStoreContador || r.name != UserRoles.contador))
            r,
      ];

  // --- Lista -------------------------------------------------------------------------------------

  /// Carga la primera página si todavía no se cargó nada.
  Future<void> ensureLoaded() async {
    if (_companyId != null && _page == 0 && !loading && error == null) {
      await refresh();
    }
  }

  Future<void> refresh() => _fetch(page: 1);

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    await _fetch(page: _page + 1);
  }

  Future<void> setSearch(String text) {
    filters = filters.copyWith(search: text.trim());
    return refresh();
  }

  Future<void> setFilters(UserFiltersEntity value) {
    filters = value;
    return refresh();
  }

  Future<void> _fetch({required int page}) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final request = ++_request;
    final first = page == 1;
    if (first) {
      loading = true;
      error = null;
    } else {
      loadingMore = true;
    }
    notifyListeners();

    final result = await _getUsers(companyId: companyId, page: page, pageSize: pageSize, filters: filters);

    // Llegó tarde: ya se pidió otra cosa (otra búsqueda, otra empresa).
    if (request != _request) return;

    result.fold(
      (failure) {
        if (first) {
          items = [];
          hasMore = false;
          error = failure.message;
        }
        _isExpired(failure);
      },
      (data) {
        items = first ? data.items : [...items, ...data.items];
        _page = data.currentPage;
        hasMore = data.hasMore;
        total = data.total;
        error = null;
      },
    );
    loading = false;
    loadingMore = false;
    notifyListeners();
  }

  // --- Formulario --------------------------------------------------------------------------------

  /// Roles, sucursales, listas de precios, métodos de pago y permisos del formulario. Se piden una
  /// vez por empresa. Lanza una excepción con el mensaje si falla.
  Future<UserCatalogsEntity> loadCatalogs() async {
    final cached = _catalogs;
    if (cached != null) return cached;
    final companyId = _companyId;
    if (companyId == null) throw Exception('No hay una empresa activa');

    final result = await _getCatalogs(companyId: companyId);
    return result.fold(
      (failure) {
        _isExpired(failure);
        throw Exception(failure.message);
      },
      (catalogs) {
        _roles = catalogs.roles;
        return _catalogs = catalogs;
      },
    );
  }

  /// Crea el usuario, o lo edita si se pasa [id]; con [photo] sube después la foto elegida (como la
  /// web, que primero guarda y luego sube, porque al crear el usuario todavía no existe).
  ///
  /// Devuelve `error` si no se pudo guardar; `warning` si se guardó pero la foto no se pudo subir.
  /// El usuario guardado entra a la lista (arriba si es nuevo, en su lugar si se editó).
  Future<({String? error, String? warning})> saveUser(
    UserFormEntity form, {
    int? id,
    ({String name, Uint8List bytes})? photo,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return (error: 'No hay una empresa activa', warning: null);

    final result = await _saveUser(companyId: companyId, form: form, id: id);
    if (result.isLeft) {
      _isExpired(result.left);
      return (error: result.left.message, warning: null);
    }

    var saved = result.right;
    String? warning;
    if (photo != null) {
      final upload = await _uploadPhoto(id: saved.id, bytes: photo.bytes, name: photo.name);
      if (upload.isLeft) {
        _isExpired(upload.left);
        // 422 es la validación del archivo; cualquier otro error es del servidor y cambiar de formato no lo arregla.
        warning = upload.left is ValidationFailure
            ? 'El usuario se guardó, pero la foto debe ser JPG, PNG o WEBP de hasta 2 MB'
            : 'El usuario se guardó, pero no se pudo subir la foto. Inténtalo de nuevo.';
      } else {
        _photos.remove(saved.id);
        saved = saved.withFoto(saved.foto ?? 'images/usuarios/${saved.id}');
      }
    }

    if (id != null) {
      items = [for (final u in items) u.id == saved.id ? saved : u];
    } else {
      items = [saved, ...items];
      total++;
    }
    notifyListeners();
    return (error: null, warning: warning);
  }

  /// La foto del usuario (se guarda para no pedirla otra vez); `null` si no tiene o no se pudo traer.
  Future<Uint8List?> loadPhoto(int id) async {
    if (_photos.containsKey(id)) return _photos[id];
    final result = await _getPhoto(id);
    if (result.isLeft) {
      _isExpired(result.left);
      return null;
    }
    return _photos[id] = result.right;
  }

  // --- Ubicación ---------------------------------------------------------------------------------

  Future<Either<Failure, List<UbigeoItemEntity>>> departments() async {
    final cached = _departments;
    if (cached != null) return Either.right(cached);
    final result = await _getDepartments();
    _checkSession(result);
    if (result.isRight) _departments = result.right;
    return result;
  }

  Future<Either<Failure, List<UbigeoItemEntity>>> provincesOf(String departmentId) async {
    final cached = _provinces[departmentId];
    if (cached != null) return Either.right(cached);
    final result = await _getProvinces(departmentId);
    _checkSession(result);
    if (result.isRight) _provinces[departmentId] = result.right;
    return result;
  }

  Future<Either<Failure, List<UbigeoItemEntity>>> districtsOf(String provinceId) async {
    final cached = _districts[provinceId];
    if (cached != null) return Either.right(cached);
    final result = await _getDistricts(provinceId);
    _checkSession(result);
    if (result.isRight) _districts[provinceId] = result.right;
    return result;
  }

  void _checkSession(Either<Failure, Object?> result) {
    if (result.isLeft) _isExpired(result.left);
  }

  // --- Roles -------------------------------------------------------------------------------------

  /// Los roles de la empresa (sin el Admin Global). Con [force] se vuelven a pedir. Lanza una
  /// excepción con el mensaje si falla.
  Future<List<UserOption>> loadRoles({bool force = false}) async {
    final cached = _roles;
    if (cached != null && !force) return cached;
    final result = await _getRoles();
    return result.fold(
      (failure) {
        _isExpired(failure);
        throw Exception(failure.message);
      },
      (roles) => _roles = roles,
    );
  }

  /// Crea el rol, o lo renombra si se pasa [id]. Devuelve `null` si salió bien o el mensaje de error.
  Future<String?> saveRole(String name, {int? id}) async {
    final result = await _saveRole(name: name, id: id);
    if (result.isLeft) {
      _isExpired(result.left);
      return result.left.message;
    }
    final saved = result.right;
    List<UserOption> apply(List<UserOption> list) =>
        id == null ? [saved, ...list] : [for (final r in list) r.id == saved.id ? saved : r];
    final roles = _roles;
    if (roles != null) _roles = apply(roles);
    _updateCatalogRoles(apply);
    // Renombrar un rol cambia cómo se lee en la lista de usuarios: se recarga.
    if (id != null) await refresh();
    notifyListeners();
    return null;
  }

  /// Elimina el rol. Devuelve `null` si salió bien o el mensaje de error (por ejemplo, que todavía
  /// lo tiene algún usuario).
  Future<String?> deleteRole(int id) async {
    final result = await _deleteRole(id);
    if (result.isLeft) {
      _isExpired(result.left);
      return result.left.message;
    }
    List<UserOption> apply(List<UserOption> list) => [for (final r in list) if (r.id != id) r];
    final roles = _roles;
    if (roles != null) _roles = apply(roles);
    _updateCatalogRoles(apply);
    notifyListeners();
    return null;
  }

  void _updateCatalogRoles(List<UserOption> Function(List<UserOption>) apply) {
    final c = _catalogs;
    if (c == null) return;
    _catalogs = UserCatalogsEntity(
      roles: apply(c.roles),
      warehouses: c.warehouses,
      listPrices: c.listPrices,
      paymentMethods: c.paymentMethods,
      permissions: c.permissions,
    );
  }
}
