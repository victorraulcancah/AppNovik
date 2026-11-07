import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/client_record_entity.dart';
import '../../domain/usecases/client_record_usecases.dart' show categoryCycleName;
import '../components/components.dart';

/// Colores de cada categoría de cliente por su código (los mismos de la web).
({Color background, Color foreground}) clientCategoryColors(String? code, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = switch (code) {
    'A' => const Color(0xFF0284C7),
    'B' => const Color(0xFF059669),
    'C' => const Color(0xFFD97706),
    'D' => const Color(0xFFEA580C),
    'E' => const Color(0xFF7C3AED),
    _ => const Color(0xFF6B7280),
  };
  final hsl = HSLColor.fromColor(base);
  return (
    background: base.withValues(alpha: dark ? 0.24 : 0.14),
    foreground: hsl.withLightness(dark ? 0.74 : 0.30).toColor(),
  );
}

/// Insignia de la categoría de un cliente (Socio, Distribuidor...), con el color de su código.
class ClientCategoryBadge extends StatelessWidget {
  final String name;
  final String? code;

  const ClientCategoryBadge({super.key, required this.name, this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = clientCategoryColors(code, theme.brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _date(DateTime? value) => value == null ? '—' : DateFormat(AppConstants.dateFormat).format(value);

/// `yyyy-MM-dd` → `dd/MM/yyyy`.
String clientBirthdayLabel(String? iso) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  return date == null ? '—' : DateFormat(AppConstants.dateFormat).format(date);
}

/// Detalle de un cliente con los mismos datos de la web: datos generales, crédito, direcciones,
/// contactos y lo adicional. Devuelve `true` si se tocó "Editar".
Future<bool?> showClientDetail(
  BuildContext context,
  ClientRecordEntity c, {
  bool canEdit = false,
  bool canSeePhone = false,
  AppPaneController? pane,
}) {
  final ubigeo = [c.districtName, c.provinceName, c.departmentName].whereType<String>().join(', ');

  return showAppModal(
    context,
    pane: pane,
    paneId: c.id,
    title: c.displayName,
    subtitle: [c.esEmpresa ? 'RUC' : 'DNI', c.dniRuc].join(' '),
    icon: c.esEmpresa ? Icons.business_outlined : Icons.person_outline,
    primaryLabel: canEdit ? 'Editar' : null,
    secondaryLabel: 'Cerrar',
    tabs: [
      AppTabItem(
        label: 'General',
        icon: Icons.info_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailRow(label: 'Código', value: c.codigo),
            AppDetailRow(label: 'Tipo', value: c.esEmpresa ? 'Empresa' : 'Persona'),
            AppDetailRow(label: c.esEmpresa ? 'RUC' : 'DNI', value: c.dniRuc),
            if (c.esEmpresa) AppDetailRow(label: 'Razón social', value: c.razonSocial),
            AppDetailRow(
              label: c.esEmpresa ? 'Contacto' : 'Nombre',
              value: [c.name, c.lastName ?? ''].where((t) => t.trim().isNotEmpty).join(' '),
            ),
            AppDetailRow(
              label: 'Categoría',
              valueWidget: c.categoriaNombre == null
                  ? null
                  : ClientCategoryBadge(name: c.categoriaNombre!, code: c.categoriaCodigo),
            ),
            if (canSeePhone) AppDetailRow(label: 'Teléfono', value: c.telefono),
            AppDetailRow(label: 'Correo', value: c.email),
            AppDetailRow(label: 'Giro', value: c.giro),
            AppDetailRow(label: 'Ubicación', value: ubigeo.isEmpty ? null : ubigeo),
            AppDetailRow(
              label: 'Dirección',
              value: [c.calle, c.direccion, c.lote].whereType<String>().join(', ').isEmpty
                  ? null
                  : [c.calle, c.direccion, c.lote].whereType<String>().join(', '),
            ),
            AppDetailRow(label: 'Ejecutivo comercial', value: c.ejecutivoNombre ?? 'Sin asignar'),
            AppDetailRow(
              label: 'Estado',
              valueWidget: AppStatusBadge(
                label: c.estado ? 'Activo' : 'Inactivo',
                tone: c.estado ? AppBadgeTone.success : AppBadgeTone.neutral,
              ),
            ),
            if (c.extranjero) const AppDetailRow(label: 'Extranjero', value: 'Sí'),
            const AppSectionTitle('Crédito'),
            AppDetailRow(label: 'Línea de crédito', value: formatMoney(c.credito, symbol: 'S/.')),
            AppDetailRow(label: 'Línea utilizada', value: formatMoney(c.lineaUtilizada, symbol: 'S/.')),
            AppDetailRow(label: 'Crédito disponible', value: formatMoney(c.creditoDisponible, symbol: 'S/.')),
          ],
        ),
      ),
      AppTabItem(
        label: 'Direcciones',
        icon: Icons.location_on_outlined,
        badge: c.addresses.length,
        child: c.addresses.isEmpty
            ? const AppEmptyState(
                icon: Icons.location_off_outlined,
                title: 'Sin direcciones',
                message: 'Este cliente no tiene direcciones adicionales.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in c.addresses) ...[
                    AppItemCard(
                      title: a.direccion,
                      subtitle: [a.districtName, a.provinceName].whereType<String>().join(', '),
                      columns: [
                        if (a.calle != null) AppItemColumn('Calle', a.calle!),
                        if (a.lote != null) AppItemColumn('Lote', a.lote!),
                        if (a.indicaciones != null) AppItemColumn('Indicaciones', a.indicaciones!),
                        if (a.predeterminado) const AppItemColumn('Predeterminada', 'Sí'),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
      AppTabItem(
        label: 'Contactos',
        icon: Icons.contacts_outlined,
        badge: c.contacts.length,
        child: c.contacts.isEmpty
            ? const AppEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Sin contactos',
                message: 'Este cliente no tiene contactos registrados.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final k in c.contacts) ...[
                    AppItemCard(
                      title: [k.name, k.lastName ?? ''].where((t) => t.trim().isNotEmpty).join(' '),
                      columns: [
                        if (k.email != null) AppItemColumn('Correo', k.email!),
                        if (canSeePhone && k.telefono != null) AppItemColumn('Teléfono', k.telefono!),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
      AppTabItem(
        label: 'Adicional',
        icon: Icons.list_alt_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailRow(label: 'Cumpleaños', value: c.cumple == null ? null : clientBirthdayLabel(c.cumple)),
            AppDetailRow(label: 'Facebook', value: c.redes),
            AppDetailRow(label: 'Página 2', value: c.pagina2),
            AppDetailRow(label: 'Página 3', value: c.pagina3),
            AppDetailRow(label: 'Notas', value: c.nota),
            AppDetailRow(label: 'Registrado por', value: c.registradoPor),
            AppDetailRow(label: 'Creado', value: _date(c.creado)),
          ],
        ),
      ),
    ],
  );
}

/// Panel de filtros de la lista: Tipo, Estado, Categoría, Ejecutivo y Departamento. Devuelve los
/// filtros elegidos o `null` si se cerró sin aplicar. La búsqueda no se toca.
Future<ClientFiltersEntity?> showClientFilters(
  BuildContext context, {
  required ClientFiltersEntity current,
  required Future<ClientFilterCatalogsEntity> Function() loadCatalogs,
}) async {
  final draft = ValueNotifier<ClientFiltersEntity>(current);
  final applied = await showAppModal(
    context,
    title: 'Filtros',
    subtitle: 'Filtra la lista de clientes',
    icon: Icons.filter_list,
    primaryLabel: 'Aplicar filtros',
    child: _ClientFiltersBody(draft: draft, loadCatalogs: loadCatalogs),
  );
  final result = applied == true ? draft.value : null;
  draft.dispose();
  return result;
}

class _ClientFiltersBody extends StatefulWidget {
  final ValueNotifier<ClientFiltersEntity> draft;
  final Future<ClientFilterCatalogsEntity> Function() loadCatalogs;

  const _ClientFiltersBody({required this.draft, required this.loadCatalogs});

  @override
  State<_ClientFiltersBody> createState() => _ClientFiltersBodyState();
}

class _ClientFiltersBodyState extends State<_ClientFiltersBody> {
  ClientFilterCatalogsEntity? _catalogs;

  ClientFiltersEntity get _f => widget.draft.value;
  set _f(ClientFiltersEntity value) {
    widget.draft.value = value;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.loadCatalogs().then((c) {
      if (mounted) setState(() => _catalogs = c);
    });
  }

  /// Texto de lo elegido en un filtro de varios ("Todas", "Sin categoría", "Socio", "3 elegidas").
  String _summary(Set<String> chosen, List<ClientFilterOption> options, {required String all, String? none, String? any}) {
    if (chosen.isEmpty) return all;
    if (chosen.length == 1) {
      final id = chosen.first;
      if (id == clientFilterNone) return none ?? id;
      if (id == clientFilterAny) return any ?? id;
      return options.where((o) => o.id == id).map((o) => o.name).firstOrNull ?? id;
    }
    return '${chosen.length} elegidos';
  }

  Future<Set<String>?> _pick({
    required String title,
    required List<ClientFilterOption> options,
    required Set<String> chosen,
  }) async {
    // El selector trabaja con ids numéricos; los departamentos son códigos con cero (`01`), así
    // que se guarda a qué código corresponde cada número.
    final byNumber = <int, String>{};
    var counter = 0;
    final numbered = <({int id, String name})>[];
    for (final o in options) {
      counter++;
      byNumber[counter] = o.id;
      numbered.add((id: counter, name: '${o.name} (${o.clientes})'));
    }
    final selected = [
      for (final e in byNumber.entries)
        if (chosen.contains(e.value)) e.key,
    ];
    final result = await showAppMultiSelect(
      context,
      title: title,
      options: numbered,
      selected: selected,
    );
    if (result == null) return null;
    return {for (final n in result) byNumber[n]!};
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = _catalogs;
    final f = _f;

    Widget shortcutChips({
      required Set<String> chosen,
      required String noneLabel,
      required String anyLabel,
      int? noneCount,
      required int anyCount,
      required ValueChanged<Set<String>> onChanged,
    }) {
      FilterChip chip(String id, String label, int? count) => FilterChip(
            label: Text(count == null ? label : '$label ($count)'),
            selected: chosen.length == 1 && chosen.contains(id),
            onSelected: (on) => onChanged(on ? {id} : {}),
          );
      return Wrap(
        spacing: 8,
        children: [
          chip(clientFilterNone, noneLabel, noneCount),
          chip(clientFilterAny, anyLabel, anyCount),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          selected: {f.tipo ?? 'todos'},
          onSelectionChanged: (s) => _f = s.first == 'todos' ? f.copyWith(clearTipo: true) : f.copyWith(tipo: s.first),
          segments: const [
            ButtonSegment(value: 'todos', label: Text('Todos')),
            ButtonSegment(value: 'p', label: Text('Personas')),
            ButtonSegment(value: 'e', label: Text('Empresas')),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          selected: {f.estado == null ? 'todos' : (f.estado! ? 'activo' : 'inactivo')},
          onSelectionChanged: (s) => _f = switch (s.first) {
            'activo' => f.copyWith(estado: true),
            'inactivo' => f.copyWith(estado: false),
            _ => f.copyWith(clearEstado: true),
          },
          segments: const [
            ButtonSegment(value: 'todos', label: Text('Todos')),
            ButtonSegment(value: 'activo', label: Text('Activos')),
            ButtonSegment(value: 'inactivo', label: Text('Inactivos')),
          ],
        ),
        const SizedBox(height: 16),
        if (catalogs == null)
          const AppSkeletonForm(fields: 2)
        else ...[
          const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          shortcutChips(
            chosen: f.categorias,
            noneLabel: 'Sin categoría',
            anyLabel: 'Con categoría',
            noneCount: catalogs.sinCategoria,
            anyCount: catalogs.conCategoria,
            onChanged: (v) => _f = f.copyWith(categorias: v),
          ),
          const SizedBox(height: 8),
          AppPickerField(
            label: 'Categorías',
            value: _summary(
              f.categorias,
              catalogs.categorias,
              all: 'Todas',
              none: 'Sin categoría',
              any: 'Con categoría',
            ),
            onTap: () async {
              final result = await _pick(
                title: 'Categorías',
                options: catalogs.categorias,
                chosen: f.categorias.where((c) => c != clientFilterNone && c != clientFilterAny).toSet(),
              );
              if (result != null) _f = f.copyWith(categorias: result);
            },
            onClear: f.categorias.isEmpty ? null : () => _f = f.copyWith(categorias: {}),
          ),
          const SizedBox(height: 16),
          const Text('Ejecutivo comercial', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          shortcutChips(
            chosen: f.ejecutivos,
            noneLabel: 'Sin asignar',
            anyLabel: 'Con ejecutivo',
            anyCount: catalogs.ejecutivos.fold(0, (sum, e) => sum + e.clientes),
            onChanged: (v) => _f = f.copyWith(ejecutivos: v),
          ),
          const SizedBox(height: 8),
          AppPickerField(
            label: 'Ejecutivos',
            value: _summary(
              f.ejecutivos,
              catalogs.ejecutivos,
              all: 'Todos',
              none: 'Sin asignar',
              any: 'Con ejecutivo',
            ),
            onTap: () async {
              final result = await _pick(
                title: 'Ejecutivos',
                options: catalogs.ejecutivos,
                chosen: f.ejecutivos.where((c) => c != clientFilterNone && c != clientFilterAny).toSet(),
              );
              if (result != null) _f = f.copyWith(ejecutivos: result);
            },
            onClear: f.ejecutivos.isEmpty ? null : () => _f = f.copyWith(ejecutivos: {}),
          ),
          const SizedBox(height: 16),
          AppPickerField(
            label: 'Departamento',
            value: _summary(f.departamentos, catalogs.departamentos, all: 'Todos'),
            onTap: () async {
              final result = await _pick(
                title: 'Departamentos',
                options: catalogs.departamentos,
                chosen: f.departamentos,
              );
              if (result != null) _f = f.copyWith(departamentos: result);
            },
            onClear: f.departamentos.isEmpty ? null : () => _f = f.copyWith(departamentos: {}),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: f.panelActive
                ? () => _f = ClientFiltersEntity(search: f.search)
                : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Restablecer'),
          ),
        ),
      ],
    );
  }
}

/// Las categorías de cliente y los montos de cada una, solo para mirar: es lo que ve quien no
/// puede configurarlas (por ejemplo el Vendedor).
Future<void> showClientCategories(
  BuildContext context, {
  required Future<CategoriesConfigEntity> Function() load,
}) {
  return showAppModal(
    context,
    title: 'Categorías de clientes',
    subtitle: 'Qué significa cada categoría',
    icon: Icons.workspace_premium_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: _CategoriesView(load: load),
  );
}

String _cyclePeriod(String cycle) => switch (cycle) {
      'mensual' => 'mes',
      'trimestral' => 'trimestre',
      'cuatrimestral' => 'cuatrimestre',
      'anual' => 'año',
      _ => 'periodo',
    };

class _CategoriesView extends StatefulWidget {
  final Future<CategoriesConfigEntity> Function() load;

  const _CategoriesView({required this.load});

  @override
  State<_CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<_CategoriesView> {
  late final Future<CategoriesConfigEntity> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<CategoriesConfigEntity>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppSkeletonForm(fields: 3);
        }
        if (snapshot.hasError) {
          return ErrorBanner(message: '${snapshot.error}'.replaceFirst('Exception: ', ''));
        }
        final config = snapshot.data!;
        final period = _cyclePeriod(config.ciclo);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cada cliente recibe una categoría según el monto total de sus compras durante el último $period '
              'cerrado. La categoría se actualiza automáticamente cada $period.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final c in config.categorias) ...[
              AppItemCard(
                title: c.nombre,
                subtitle: 'Código ${c.codigo}',
                columns: [
                  AppItemColumn('Desde (S/)', c.montoDesde == null ? '0' : formatQuantity(c.montoDesde!)),
                  AppItemColumn('Hasta (S/)', c.montoHasta == null ? 'A más' : formatQuantity(c.montoHasta!)),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'Los montos están expresados en la moneda base del sistema.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

/// Configuración de categorías (ciclo y rangos de cada categoría), con Guardar y Calcular ahora.
/// [onSave] guarda (y con `calculate` calcula ya) y devuelve el recálculo si se hizo; lanza una
/// excepción con el mensaje si falla. Devuelve `true` si se guardó o calculó algo.
Future<bool> showClientCategoriesConfig(
  BuildContext context, {
  required Future<CategoriesConfigEntity> Function() load,
  required Future<CategoryCalcEntity?> Function(
    List<ClientCategoryEntity> categorias,
    String ciclo, {
    required bool calculate,
  }) onSave,
}) async {
  final changed = ValueNotifier<bool>(false);
  final error = ValueNotifier<String?>(null);
  final state = _CategoriesConfigController(load: load, onSave: onSave, error: error, changed: changed);

  await showAppModal(
    context,
    title: 'Categorización de clientes',
    subtitle: 'Ciclo y rangos de cada categoría',
    icon: Icons.tune,
    primaryLabel: 'Guardar configuración',
    error: error,
    child: AppDisposer(
      onDispose: [state.dispose, error.dispose],
      child: _CategoriesConfigBody(controller: state),
    ),
    onPrimary: () async {
      error.value = null;
      try {
        final calc = await state.save(calculate: false);
        if (context.mounted) _announceCalc(context, calc);
      } catch (e) {
        error.value = '$e'.replaceFirst('Exception: ', '');
        rethrow;
      }
    },
  );
  final result = changed.value;
  changed.dispose();
  return result;
}

void _announceCalc(BuildContext context, CategoryCalcEntity? calc) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  String text;
  if (calc != null && calc.recalculado) {
    final range = (calc.desde != null && calc.hasta != null)
        ? ' con lo comprado del ${clientBirthdayLabel(calc.desde)} al ${clientBirthdayLabel(calc.hasta)}'
        : '';
    text = 'Categorías calculadas$range (${calc.clientesActualizados} clientes actualizados)';
  } else if (calc != null) {
    text = calc.mensaje ?? 'No se pudieron calcular las categorías';
  } else {
    text = 'Configuración guardada correctamente';
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Estado de la pantalla de configuración de categorías.
class _CategoriesConfigController extends ChangeNotifier {
  final Future<CategoriesConfigEntity> Function() load;
  final Future<CategoryCalcEntity?> Function(
    List<ClientCategoryEntity> categorias,
    String ciclo, {
    required bool calculate,
  }) onSave;
  final ValueNotifier<String?> error;
  final ValueNotifier<bool> changed;

  _CategoriesConfigController({
    required this.load,
    required this.onSave,
    required this.error,
    required this.changed,
  });

  List<ClientCategoryEntity> categorias = [];
  String ciclo = 'mensual';
  Map<String, CategoryPeriod> periodos = {};
  bool loading = true;
  bool calculating = false;

  Future<void> start() async {
    try {
      final config = await load();
      categorias = config.categorias;
      ciclo = config.ciclo;
      periodos = config.periodos;
    } catch (e) {
      error.value = '$e'.replaceFirst('Exception: ', '');
    }
    loading = false;
    notifyListeners();
  }

  void setCycle(String value) {
    ciclo = value;
    notifyListeners();
  }

  void setName(int id, String name) {
    categorias = [for (final c in categorias) c.id == id ? c.copyWith(nombre: name) : c];
  }

  void setRange(int id, {double? desde, double? hasta, bool clearDesde = false, bool clearHasta = false}) {
    categorias = [
      for (final c in categorias)
        if (c.id == id)
          c.copyWith(
            rangos: {
              ...c.rangos,
              ciclo: CategoryRange(
                desde: clearDesde ? null : (desde ?? c.rangoDe(ciclo).desde),
                hasta: clearHasta ? null : (hasta ?? c.rangoDe(ciclo).hasta),
              ),
            },
          )
        else
          c,
    ];
  }

  Future<CategoryCalcEntity?> save({required bool calculate}) async {
    final calc = await onSave(categorias, ciclo, calculate: calculate);
    changed.value = true;
    return calc;
  }

  Future<void> calculate(BuildContext context) async {
    error.value = null;
    calculating = true;
    notifyListeners();
    try {
      final calc = await save(calculate: true);
      if (context.mounted) _announceCalc(context, calc);
      // Los rangos y periodos vuelven a pedirse para mostrar lo vigente.
      final config = await load();
      categorias = config.categorias;
      ciclo = config.ciclo;
      periodos = config.periodos;
    } catch (e) {
      error.value = '$e'.replaceFirst('Exception: ', '');
    }
    calculating = false;
    notifyListeners();
  }
}

class _CategoriesConfigBody extends StatefulWidget {
  final _CategoriesConfigController controller;

  const _CategoriesConfigBody({required this.controller});

  @override
  State<_CategoriesConfigBody> createState() => _CategoriesConfigBodyState();
}

class _CategoriesConfigBodyState extends State<_CategoriesConfigBody> {
  _CategoriesConfigController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.start();
  }

  String _fmtDate(String? iso) => iso == null ? '—' : clientBirthdayLabel(iso);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        if (_c.loading) {
          return const AppSkeletonForm(fields: 3);
        }
        final period = _c.periodos[_c.ciclo];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('CICLO DE ACTUALIZACIÓN', style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final cycle in categoryCycles)
                  ChoiceChip(
                    label: Text(categoryCycleName(cycle)),
                    selected: _c.ciclo == cycle,
                    onSelected: (_) => _c.setCycle(cycle),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AppDetailRow(
              label: 'Compras evaluadas',
              value: '${_fmtDate(period?.evaluadoDesde)} - ${_fmtDate(period?.evaluadoHasta)}',
            ),
            AppDetailRow(label: 'El resultado cambia el', value: _fmtDate(period?.cambiaEl)),
            AppDetailRow(label: 'El actual rige desde el', value: _fmtDate(period?.vigenteDesde)),
            const SizedBox(height: 8),
            for (final cat in _c.categorias)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CategoryRow(
                  // La clave incluye el ciclo para que los campos tomen el rango del ciclo elegido.
                  key: ValueKey('${cat.id}-${_c.ciclo}'),
                  category: cat,
                  cycle: _c.ciclo,
                  onName: (v) => _c.setName(cat.id, v),
                  onDesde: (v) => v == null ? _c.setRange(cat.id, clearDesde: true) : _c.setRange(cat.id, desde: v),
                  onHasta: (v) => v == null ? _c.setRange(cat.id, clearHasta: true) : _c.setRange(cat.id, hasta: v),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _c.calculating
                  ? null
                  : () async {
                      final ok = await showAppConfirm(
                        context,
                        title: '¿Calcular las categorías ahora?',
                        message:
                            'Guarda estos rangos y asigna a cada cliente su categoría según lo comprado en el último ciclo cerrado.',
                        confirmLabel: 'Calcular',
                        icon: Icons.calculate_outlined,
                        tone: AppModalTone.warning,
                      );
                      if (ok && context.mounted) await _c.calculate(context);
                    },
              icon: _c.calculating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.calculate_outlined),
              label: const Text('Calcular ahora'),
            ),
            const SizedBox(height: 8),
            Text(
              'Cada ciclo tiene sus propios rangos. Los montos están en la moneda base del sistema.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryRow extends StatefulWidget {
  final ClientCategoryEntity category;
  final String cycle;
  final ValueChanged<String> onName;
  final ValueChanged<double?> onDesde;
  final ValueChanged<double?> onHasta;

  const _CategoryRow({
    super.key,
    required this.category,
    required this.cycle,
    required this.onName,
    required this.onDesde,
    required this.onHasta,
  });

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  late final TextEditingController _name = TextEditingController(text: widget.category.nombre);
  late final TextEditingController _desde = TextEditingController(text: _show(widget.category.rangoDe(widget.cycle).desde));
  late final TextEditingController _hasta = TextEditingController(text: _show(widget.category.rangoDe(widget.cycle).hasta));

  static String _show(double? v) => v == null ? '' : formatQuantity(v);

  @override
  void dispose() {
    _name.dispose();
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  double? _parse(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          onChanged: widget.onName,
          decoration: InputDecoration(
            labelText: 'Categoría (código ${widget.category.codigo})',
            prefixIcon: const Icon(Icons.workspace_premium_outlined),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _desde,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => widget.onDesde(_parse(v)),
                decoration: InputDecoration(labelText: 'Desde (S/) · ${widget.cycle}', hintText: '0'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _hasta,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => widget.onHasta(_parse(v)),
                decoration: InputDecoration(labelText: 'Hasta (S/) · ${widget.cycle}', hintText: 'A más'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
