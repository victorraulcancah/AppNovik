import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/client_form_entity.dart';
import '../../domain/entities/sale_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/client_usecases.dart';

/// Lo necesario para crear un cliente desde Ventas: departamentos, provincias y distritos
/// (se guardan para no pedirlos otra vez), la consulta de DNI/RUC y el alta del cliente.
class ClientsProvider extends ChangeNotifier {
  final GetDepartmentsUseCase _getDepartments;
  final GetProvincesUseCase _getProvinces;
  final GetDistrictsUseCase _getDistricts;
  final LookupDocumentUseCase _lookup;
  final CreateClientUseCase _create;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  ClientsProvider({
    required GetDepartmentsUseCase getDepartmentsUseCase,
    required GetProvincesUseCase getProvincesUseCase,
    required GetDistrictsUseCase getDistrictsUseCase,
    required LookupDocumentUseCase lookupDocumentUseCase,
    required CreateClientUseCase createClientUseCase,
    VoidCallback? onSessionExpired,
  })  : _getDepartments = getDepartmentsUseCase,
        _getProvinces = getProvincesUseCase,
        _getDistricts = getDistrictsUseCase,
        _lookup = lookupDocumentUseCase,
        _create = createClientUseCase,
        _onSessionExpired = onSessionExpired;

  int? _companyId;
  int? _userId;

  /// Solo un Vendedor o el Ceo puede ser ejecutivo comercial: el cliente que crean queda en su cartera.
  bool _canBeExecutive = false;

  List<UbigeoItemEntity>? _departments;
  final Map<String, List<UbigeoItemEntity>> _provinces = {};
  final Map<String, List<UbigeoItemEntity>> _districts = {};

  /// Se llama cuando cambia la sesión. No notifica: corre mientras se arma el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    _companyId = session?.company.id;
    _userId = session?.user.id;
    _canBeExecutive = session != null && (session.hasRole('Vendedor') || session.hasRole('Ceo Empresa'));
  }

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

  Future<Either<Failure, DocumentLookupEntity>> lookup({required String tipo, required String number}) async {
    final result = await _lookup(tipo: tipo, number: number);
    _checkSession(result);
    return result;
  }

  Future<Either<Failure, ClientEntity>> create(NewClientFormEntity form) async {
    final companyId = _companyId;
    if (companyId == null) return Either.left(const AuthenticationFailure('Sesión expirada'));
    final result = await _create(
      companyId: companyId,
      executiveId: _canBeExecutive ? _userId : null,
      form: form,
    );
    _checkSession(result);
    return result;
  }

  void _checkSession(Either<Failure, Object?> result) {
    if (result.isLeft && result.left is AuthenticationFailure) _onSessionExpired?.call();
  }
}
