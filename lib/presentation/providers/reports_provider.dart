import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/usecases/report_usecases.dart';

/// Rangos que se ofrecen en Reportes. `esteMes` es el predeterminado, como en la web.
enum ReportRange {
  hoy('Hoy'),
  esteMes('Este mes'),
  mesPasado('Mes pasado'),
  esteAnio('Este año'),
  personalizado('Elegir fechas');

  final String label;
  const ReportRange(this.label);
}

/// Estado de Reportes: el rango elegido y el resumen ejecutivo de ese rango.
class ReportsProvider extends ChangeNotifier {
  final GetExecutiveSummaryUseCase _getSummary;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  /// Hora actual; se puede reemplazar en pruebas.
  final DateTime Function() _now;

  ReportsProvider({
    required GetExecutiveSummaryUseCase getExecutiveSummaryUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  })  : _getSummary = getExecutiveSummaryUseCase,
        _onSessionExpired = onSessionExpired,
        _now = now ?? DateTime.now;

  int? _companyId;
  int _request = 0;
  bool _loadedOnce = false;

  ReportRange range = ReportRange.esteMes;
  DateTimeRange? _custom;

  ExecutiveSummaryEntity? summary;
  bool loading = false;
  String? error;

  /// Primer y último día del rango elegido.
  DateTimeRange get dates {
    final today = DateUtils.dateOnly(_now());
    return switch (range) {
      ReportRange.hoy => DateTimeRange(start: today, end: today),
      ReportRange.esteMes => DateTimeRange(start: DateTime(today.year, today.month), end: today),
      ReportRange.mesPasado => DateTimeRange(
          start: DateTime(today.year, today.month - 1),
          end: DateTime(today.year, today.month, 0),
        ),
      ReportRange.esteAnio => DateTimeRange(start: DateTime(today.year), end: today),
      ReportRange.personalizado => _custom ?? DateTimeRange(start: today, end: today),
    };
  }

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo.
  /// No notifica: corre mientras se construye el árbol de widgets.
  void syncCompany(int? companyId) {
    if (companyId == _companyId) return;
    _companyId = companyId;
    _request++;
    _loadedOnce = false;
    range = ReportRange.esteMes;
    _custom = null;
    summary = null;
    loading = false;
    error = null;
  }

  Future<void> ensureLoaded() async {
    if (_companyId == null || _loadedOnce || loading) return;
    await refresh();
  }

  Future<void> selectRange(ReportRange value) {
    range = value;
    return refresh();
  }

  Future<void> selectCustom(DateTimeRange value) {
    _custom = value;
    range = ReportRange.personalizado;
    return refresh();
  }

  Future<void> refresh() async {
    if (_companyId == null) return;
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();

    final r = dates;
    final result = await _getSummary(desde: r.start, hasta: r.end);
    // Llegó tarde: ya se pidió otro rango o cambió la empresa.
    if (request != _request) return;

    result.fold(
      (failure) {
        summary = null;
        error = failure.message;
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
      },
      (data) => summary = data,
    );
    _loadedOnce = true;
    loading = false;
    notifyListeners();
  }
}
