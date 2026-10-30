import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/sale_entity.dart';

/// Tipo de cambio comercial vigente: `TC: S/ 3.452`, con la fuente, la fecha y el margen al
/// tocarlo, y un botón para actualizarlo. Si no hay tipo de cambio avisa en rojo.
class ExchangeRateBadge extends StatelessWidget {
  final ExchangeRateEntity? rate;
  final bool loading;
  final VoidCallback onRefresh;

  const ExchangeRateBadge({
    super.key,
    required this.rate,
    required this.loading,
    required this.onRefresh,
  });

  String _detail(ExchangeRateEntity r) {
    final date = r.fechaFuente == null ? '' : ' (${DateFormat(AppConstants.dateFormat).format(r.fechaFuente!)})';
    return '${r.fuenteNombre} ${r.valorFuente.toStringAsFixed(3)}$date + margen S/ ${r.margen}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = rate;

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.currency_exchange, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          if (r != null)
            Tooltip(
              message: _detail(r),
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 4),
              child: Text(
                'TC: S/ ${r.valorFinal.toStringAsFixed(3)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            )
          else
            Text(
              loading ? 'Cargando TC…' : 'TC no disponible',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: loading ? scheme.onSurfaceVariant : scheme.error,
              ),
            ),
          IconButton(
            tooltip: 'Actualizar tipo de cambio',
            onPressed: loading ? null : onRefresh,
            visualDensity: VisualDensity.compact,
            icon: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
    );
  }
}
