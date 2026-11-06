import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/inicio_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/inicio_provider.dart';
import '../providers/reports_provider.dart' show ReportRange;
import '../providers/shell_navigation.dart';
import '../utils/inicio_copy.dart';
import '../widgets/inicio_ceo_view.dart';
import '../widgets/inicio_executive_view.dart';
import '../widgets/inicio_team_view.dart';
import '../widgets/inicio_widgets.dart';

/// Módulo Inicio: el Dashboard de la web. Según el rol del usuario muestra su resumen (Vendedor →
/// "Ejecutivo", Jefe Comercial → "Jefe", CEO → "CEO"), con el switch cuando tiene más de un
/// perfil y arrancando en el cargo más alto. Los demás (y el Jefe de Almacén, que no ve importes)
/// ven la pantalla de siempre: el resumen de ventas del mes por almacén.
class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  static final _day = DateFormat(AppConstants.dateFormat);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InicioProvider>().ensureLoaded();
    });
  }

  Future<void> _pickCustom() async {
    final inicio = context.read<InicioProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: inicio.dates,
      helpText: 'Elegir fechas',
      saveText: 'Aplicar',
    );
    if (picked != null) inicio.selectCustom(picked);
  }

  /// Las cotizaciones se ven en Documentos: solo se ofrece el enlace si el usuario puede verlas.
  /// Abre Documentos en Cotizaciones pendientes, en el rango del resumen (como la web).
  VoidCallback? _quotesLink(DateTime desde, DateTime hasta) {
    final session = context.read<AuthProvider>().session;
    if (session == null || !session.hasModule('documentos') || !session.can('documentos.cotizaciones.index')) {
      return null;
    }
    return () => context.read<ShellNavigation>().goToPendingQuotes(desde: desde, hasta: hasta);
  }

  @override
  Widget build(BuildContext context) {
    final inicio = context.watch<InicioProvider>();
    final view = inicio.view;
    final hasData = _data(inicio, view) != null;

    return Column(
      children: [
        const AppPageHeader(
          icon: Icons.home_outlined,
          title: 'Inicio',
          subtitle: 'Resumen',
          trailing: AppAccountMenu(),
        ),
        if (inicio.hasSwitch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: InicioViewSwitch(views: inicio.views, selected: view, onChanged: inicio.selectView),
            ),
          ),
        if (inicio.usesRange) _toolbar(inicio),
        if (inicio.loading && hasData) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _body(inicio, view)),
      ],
    );
  }

  Object? _data(InicioProvider inicio, InicioView view) => switch (view) {
    InicioView.general => inicio.warehouses,
    InicioView.ejecutivo => inicio.executive,
    InicioView.jefe => inicio.team,
    InicioView.ceo => inicio.ceo,
  };

  Widget _toolbar(InicioProvider inicio) {
    final ceo = inicio.view == InicioView.ceo ? inicio.ceo : null;
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            itemCount: ReportRange.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final range = ReportRange.values[i];
              final custom = range == ReportRange.personalizado;
              final selected = inicio.range == range;
              return ChoiceChip(
                label: Text(
                  custom && selected
                      ? '${_day.format(inicio.dates.start)} – ${_day.format(inicio.dates.end)}'
                      : range.label,
                ),
                avatar: custom ? const Icon(Icons.date_range, size: 18) : null,
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => custom ? _pickCustom() : inicio.selectRange(range),
              );
            },
          ),
        ),
        // El CEO también filtra por almacén (el de la venta).
        if (ceo != null && ceo.sucursales.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: AppDropdownField<int>(
              label: 'Almacén',
              value: inicio.sucursal ?? 0,
              items: [
                const DropdownMenuItem(value: 0, child: Text('Todos los almacenes')),
                for (final s in ceo.sucursales) DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => inicio.selectSucursal(v == null || v == 0 ? null : v),
            ),
          ),
      ],
    );
  }

  Widget _body(InicioProvider inicio, InicioView view) {
    final hasData = _data(inicio, view) != null;
    if (!hasData) {
      if (inicio.error != null) {
        return AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'No se pudo cargar el resumen',
          message: inicio.error,
          action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: inicio.refresh),
        );
      }
      return const AppSkeletonList(count: 4);
    }

    final now = inicio.now;
    final Widget content = switch (view) {
      InicioView.general => _GeneralView(warehouses: inicio.warehouses!, now: now),
      InicioView.ejecutivo => _withGreeting(
        view,
        inicio,
        inicio.executive!.vendedor,
        InicioExecutiveView(
          data: inicio.executive!,
          now: now,
          onOpenQuotes: _quotesLink(inicio.executive!.desde, inicio.executive!.hasta),
        ),
      ),
      InicioView.jefe => _withGreeting(
        view,
        inicio,
        inicio.team!.jefe,
        InicioTeamView(
          data: inicio.team!,
          onOpenQuotes: _quotesLink(inicio.team!.desde, inicio.team!.hasta),
        ),
      ),
      InicioView.ceo => _withGreeting(
        view,
        inicio,
        inicio.ceo!.ceo,
        InicioCeoView(data: inicio.ceo!),
        subtitle: 'Panorama general de ${inicio.ceo!.empresa}',
      ),
    };

    return RefreshIndicator(
      onRefresh: inicio.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              // Cada vista con su propia llave: al cambiar de perfil sus secciones vuelven a entrar.
              child: KeyedSubtree(key: ValueKey(view), child: content),
            ),
          ),
        ],
      ),
    );
  }

  Widget _withGreeting(InicioView view, InicioProvider inicio, String fullName, Widget body, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppEntrance(
          child: InicioGreeting(
            greeting: greetingFor(view, firstName(fullName), inicio.now.hour),
            subtitle: subtitle,
            loading: inicio.loading,
          ),
        ),
        const SizedBox(height: 14),
        body,
      ],
    );
  }
}

/// La pantalla de siempre: "Resumen de Ventas MES / AÑO" con el total y el de cada almacén.
class _GeneralView extends StatelessWidget {
  final List<WarehouseSalesEntity> warehouses;
  final DateTime now;

  const _GeneralView({required this.warehouses, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = warehouses.fold<double>(0, (s, w) => s + w.total);

    return AppEntrance(
      child: InicioPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumen de Ventas ${monthsLong[now.month - 1].toUpperCase()} / ${now.year}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Center(
              child: AppCountUp(
                value: total,
                format: (v) => 'S/. ${NumberFormat('#,##0.00', 'en_US').format(v)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (warehouses.isEmpty)
              const InicioEmpty(text: 'Sin almacenes para mostrar')
            else
              for (final w in warehouses)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront, size: 18, color: Color(0xFF84CC16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Almacén ${w.nombre}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'S/. ${NumberFormat('#,##0.00', 'en_US').format(w.total)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
