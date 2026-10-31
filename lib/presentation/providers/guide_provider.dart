import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/guide_form_entity.dart';
import '../../domain/entities/other_document_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/guide_usecases.dart';

/// Crear una guía de remisión desde una venta: lo que ya se sabe de ella, el chofer por su DNI y
/// el envío. No guarda estado de pantalla: cada formulario lleva el suyo.
class GuideProvider extends ChangeNotifier {
  final GetGuideDefaultsUseCase _getDefaults;
  final FindDriverUseCase _findDriver;
  final CreateGuideUseCase _create;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  GuideProvider({
    required GetGuideDefaultsUseCase getDefaultsUseCase,
    required FindDriverUseCase findDriverUseCase,
    required CreateGuideUseCase createGuideUseCase,
    VoidCallback? onSessionExpired,
  })  : _getDefaults = getDefaultsUseCase,
        _findDriver = findDriverUseCase,
        _create = createGuideUseCase,
        _onSessionExpired = onSessionExpired;

  /// RUC de la empresa: en una guía privada el transportista es la propia empresa.
  String? companyRuc;
  bool creating = false;

  /// Se llama cuando cambia la sesión. No notifica: corre mientras se arma el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    companyRuc = session?.company.ruc;
  }

  void _check(Either<Failure, Object?> result) {
    if (result.isLeft && result.left is AuthenticationFailure) _onSessionExpired?.call();
  }

  Future<Either<Failure, GuideDefaultsEntity>> loadDefaults(int saleId) async {
    final result = await _getDefaults(saleId);
    _check(result);
    return result;
  }

  Future<DriverEntity?> findDriver(String dni) async {
    final result = await _findDriver(dni);
    _check(result);
    return result.isRight ? result.right : null;
  }

  Future<Either<Failure, OtherDocumentEntity>> create(GuideFormEntity form) async {
    if (creating) return Either.left(const ValidationFailure('Ya se está creando la guía'));
    creating = true;
    notifyListeners();
    final result = await _create(form);
    creating = false;
    _check(result);
    notifyListeners();
    return result;
  }
}
