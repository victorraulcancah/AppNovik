import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/client_form_entity.dart';
import '../../domain/entities/client_record_entity.dart';
import '../components/components.dart';
import '../providers/clients_provider.dart';
import 'client_record_modals.dart' show clientCategoryColors;

/// Lo que puede hacer el usuario en el formulario, según sus permisos (los mismos de la web).
class ClientFormAccess {
  /// Información básica y adicional (`clientes.update.informacion-basica`, o `clientes.store` al crear).
  final bool basic;

  /// Direcciones (`clientes.update.direcciones`).
  final bool addresses;

  /// Contactos (`clientes.update.contactos`).
  final bool contacts;

  /// Condiciones de venta (`clientes.condiciones-de-venta`, o el rol Ceo Empresa).
  final bool conditions;

  /// Un Vendedor no elige el ejecutivo comercial ni activa o inactiva clientes.
  final bool onlySeller;

  /// Al crear, el ejecutivo comercial queda como este usuario (si puede serlo).
  final int? defaultExecutiveId;

  const ClientFormAccess({
    this.basic = true,
    this.addresses = true,
    this.contacts = true,
    this.conditions = false,
    this.onlySeller = false,
    this.defaultExecutiveId,
  });
}

class _AddressDraft {
  final int? id;
  final double? latitud;
  final double? longitud;
  final direccion = TextEditingController();
  final calle = TextEditingController();
  final lote = TextEditingController();
  final indicaciones = TextEditingController();
  final department = ValueNotifier<String?>(null);
  final province = ValueNotifier<String?>(null);
  final district = ValueNotifier<String?>(null);
  final predeterminado = ValueNotifier<bool>(false);

  _AddressDraft([ClientAddressEntity? a])
      : id = a?.id,
        latitud = a?.latitud,
        longitud = a?.longitud {
    if (a == null) return;
    direccion.text = a.direccion;
    calle.text = a.calle ?? '';
    lote.text = a.lote ?? '';
    indicaciones.text = a.indicaciones ?? '';
    department.value = a.departmentId;
    province.value = a.provinceId;
    district.value = a.districtId;
    predeterminado.value = a.predeterminado;
  }

  List<Listenable> get listenables => [direccion, calle, lote, indicaciones, department, province, district, predeterminado];

  ClientAddressEntity toEntity() => ClientAddressEntity(
        id: id,
        direccion: direccion.text,
        calle: calle.text,
        lote: lote.text,
        indicaciones: indicaciones.text,
        latitud: latitud,
        longitud: longitud,
        departmentId: department.value,
        provinceId: province.value,
        districtId: district.value,
        predeterminado: predeterminado.value,
      );

  void dispose() {
    for (final c in [direccion, calle, lote, indicaciones]) {
      c.dispose();
    }
    for (final n in [department, province, district]) {
      n.dispose();
    }
    predeterminado.dispose();
  }
}

class _ContactDraft {
  final int? id;
  final name = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();

  _ContactDraft([ClientContactEntity? c]) : id = c?.id {
    if (c == null) return;
    name.text = c.name;
    lastName.text = c.lastName ?? '';
    email.text = c.email ?? '';
    phone.text = c.telefono ?? '';
  }

  List<Listenable> get listenables => [name, lastName, email, phone];

  ClientContactEntity toEntity() => ClientContactEntity(
        id: id,
        name: name.text,
        lastName: lastName.text,
        email: email.text,
        telefono: phone.text,
      );

  void dispose() {
    for (final c in [name, lastName, email, phone]) {
      c.dispose();
    }
  }
}

/// Todo lo que se va llenando en el formulario de cliente.
class _ClientDraft {
  final ClientRecordEntity? client;
  final ClientFormAccess access;

  final tipo = ValueNotifier<String>('p');
  final dni = TextEditingController();
  final name = TextEditingController();
  final lastName = TextEditingController();
  final razonSocial = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final giro = TextEditingController();
  final calle = TextEditingController();
  final direccion = TextEditingController();
  final lote = TextEditingController();
  final indicaciones = TextEditingController();
  final redes = TextEditingController();
  final pagina2 = TextEditingController();
  final pagina3 = TextEditingController();
  final nota = TextEditingController();
  final credito = TextEditingController();
  final extranjero = ValueNotifier<bool>(false);
  final estado = ValueNotifier<bool>(true);
  final department = ValueNotifier<String?>(null);
  final province = ValueNotifier<String?>(null);
  final district = ValueNotifier<String?>(null);
  final ejecutivo = ValueNotifier<int?>(null);
  final listPrice = ValueNotifier<int?>(null);
  final payment = ValueNotifier<int?>(null);
  final cumple = ValueNotifier<String?>(null);
  final addresses = ValueNotifier<List<_AddressDraft>>([]);
  final contacts = ValueNotifier<List<_ContactDraft>>([]);

  final catalogs = ValueNotifier<ClientFormCatalogsEntity?>(null);
  final catalogsError = ValueNotifier<String?>(null);

  /// Cambia a `true` con la primera modificación: al editar, no se guarda sin cambios.
  final changed = ValueNotifier<bool>(false);
  bool _disposed = false;

  _ClientDraft({this.client, required this.access}) {
    final c = client;
    if (c != null) {
      tipo.value = c.tipo;
      dni.text = c.dniRuc;
      name.text = c.name;
      lastName.text = c.lastName ?? '';
      razonSocial.text = c.razonSocial ?? '';
      // Los clientes antiguos guardaron el teléfono sin el "+51".
      final p = c.telefono ?? '';
      phone.text = p.isEmpty || p.startsWith('+') ? p : '+51$p';
      email.text = c.email ?? '';
      giro.text = c.giro ?? '';
      calle.text = c.calle ?? '';
      direccion.text = c.direccion ?? '';
      lote.text = c.lote ?? '';
      indicaciones.text = c.indicaciones ?? '';
      redes.text = c.redes ?? '';
      pagina2.text = c.pagina2 ?? '';
      pagina3.text = c.pagina3 ?? '';
      nota.text = c.nota ?? '';
      credito.text = c.credito == 0 ? '' : _plain(c.credito);
      extranjero.value = c.extranjero;
      estado.value = c.estado;
      department.value = c.departmentId;
      province.value = c.provinceId;
      district.value = c.districtId;
      ejecutivo.value = c.ejecutivoId;
      listPrice.value = c.listPriceId;
      payment.value = c.paymentMethodId;
      cumple.value = c.cumple;
      addresses.value = [for (final a in c.addresses) _AddressDraft(a)];
      contacts.value = [for (final k in c.contacts) _ContactDraft(k)];
    }
    // Recién ahora se escuchan los cambios: lo anterior es el valor inicial.
    final all = <Listenable>[
      tipo, dni, name, lastName, razonSocial, phone, email, giro, calle, direccion, lote, indicaciones,
      redes, pagina2, pagina3, nota, credito, extranjero, estado, department, province, district,
      ejecutivo, listPrice, payment, cumple,
    ];
    for (final l in all) {
      l.addListener(markChanged);
    }
    for (final a in addresses.value) {
      _watchAddress(a);
    }
    for (final k in contacts.value) {
      _watchContact(k);
    }
  }

  static String _plain(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  void markChanged() => changed.value = true;

  void _watchAddress(_AddressDraft a) {
    for (final l in a.listenables) {
      l.addListener(markChanged);
    }
  }

  void _watchContact(_ContactDraft k) {
    for (final l in k.listenables) {
      l.addListener(markChanged);
    }
  }

  void addAddress() {
    final a = _AddressDraft();
    _watchAddress(a);
    addresses.value = [...addresses.value, a];
    markChanged();
  }

  void removeAddress(_AddressDraft a) {
    addresses.value = addresses.value.where((x) => x != a).toList();
    a.dispose();
    markChanged();
  }

  /// Solo una dirección puede ser la predeterminada.
  void setDefaultAddress(_AddressDraft chosen, bool on) {
    if (on) {
      for (final a in addresses.value) {
        if (a != chosen) a.predeterminado.value = false;
      }
    }
    chosen.predeterminado.value = on;
  }

  void addContact() {
    final k = _ContactDraft();
    _watchContact(k);
    contacts.value = [...contacts.value, k];
    markChanged();
  }

  void removeContact(_ContactDraft k) {
    contacts.value = contacts.value.where((x) => x != k).toList();
    k.dispose();
    markChanged();
  }

  Future<void> loadCatalogs(Future<ClientFormCatalogsEntity> Function() load) async {
    try {
      final c = await load();
      if (_disposed) return;
      catalogs.value = c;
      // Al crear, el ejecutivo comercial es quien crea (si puede serlo).
      final me = access.defaultExecutiveId;
      if (client == null && ejecutivo.value == null && me != null && c.ejecutivos.any((e) => e.id == me)) {
        ejecutivo.value = me;
        changed.value = false;
      }
    } catch (e) {
      if (_disposed) return;
      catalogsError.value = '$e'.replaceFirst('Exception: ', '');
      catalogs.value = const ClientFormCatalogsEntity();
    }
  }

  ClientFormEntity toEntity() {
    final text = credito.text.trim();
    return ClientFormEntity(
      tipo: tipo.value,
      dniRuc: dni.text,
      name: name.text,
      lastName: lastName.text,
      razonSocial: razonSocial.text,
      telefono: phone.text,
      email: email.text,
      giro: giro.text,
      extranjero: extranjero.value,
      estado: estado.value,
      departmentId: department.value ?? '',
      provinceId: province.value ?? '',
      districtId: district.value ?? '',
      calle: calle.text,
      direccion: direccion.text,
      lote: lote.text,
      indicaciones: indicaciones.text,
      ejecutivoId: ejecutivo.value,
      redes: redes.text,
      pagina2: pagina2.text,
      pagina3: pagina3.text,
      cumple: cumple.value,
      nota: nota.text,
      incluyeCondiciones: access.conditions,
      listPriceId: listPrice.value,
      paymentMethodId: payment.value,
      credito: text.isEmpty ? null : double.tryParse(text.replaceAll(',', '.')),
      addresses: access.addresses ? [for (final a in addresses.value) a.toEntity()] : null,
      contacts: access.contacts ? [for (final k in contacts.value) k.toEntity()] : null,
      incluyeBasica: access.basic,
    );
  }

  void dispose() {
    _disposed = true;
    tipo.dispose();
    for (final c in [
      dni, name, lastName, razonSocial, phone, email, giro, calle, direccion, lote, indicaciones,
      redes, pagina2, pagina3, nota, credito,
    ]) {
      c.dispose();
    }
    for (final n in [extranjero, estado]) {
      n.dispose();
    }
    for (final n in [department, province, district, cumple, catalogsError]) {
      n.dispose();
    }
    for (final n in [ejecutivo, listPrice, payment]) {
      n.dispose();
    }
    for (final a in addresses.value) {
      a.dispose();
    }
    for (final k in contacts.value) {
      k.dispose();
    }
    addresses.dispose();
    contacts.dispose();
    catalogs.dispose();
    changed.dispose();
  }
}

/// Formulario para crear o editar un cliente, con las mismas pestañas y campos de la web:
/// Información básica, Direcciones, Contactos, Condiciones de venta e Información adicional (cada
/// una según los permisos). El mapa de la pestaña Ubicación no está en la app.
///
/// [onSubmit] guarda y devuelve el mensaje de error, o `null` si salió bien.
Future<bool?> showClientForm(
  BuildContext context, {
  ClientRecordEntity? client,
  required ClientFormAccess access,
  required Future<ClientFormCatalogsEntity> Function() loadCatalogs,
  required Future<String?> Function(ClientFormEntity form) onSubmit,
}) async {
  final editing = client != null;
  final draft = _ClientDraft(client: client, access: access);
  final error = ValueNotifier<String?>(null);
  // Las listas del formulario se piden ya, mientras se abre el modal.
  draft.loadCatalogs(loadCatalogs);

  final tabs = <AppTabItem>[
    if (access.basic)
      AppTabItem(
        label: 'Información básica',
        icon: Icons.badge_outlined,
        child: _BasicTab(draft: draft, editing: editing, error: error),
      ),
    if (access.addresses)
      AppTabItem(
        label: 'Direcciones',
        icon: Icons.location_on_outlined,
        child: _AddressesTab(draft: draft),
      ),
    if (access.contacts)
      AppTabItem(
        label: 'Contactos',
        icon: Icons.contacts_outlined,
        child: _ContactsTab(draft: draft),
      ),
    if (access.conditions)
      AppTabItem(
        label: 'Condiciones de venta',
        icon: Icons.sell_outlined,
        child: _ConditionsTab(draft: draft),
      ),
    if (access.basic)
      AppTabItem(
        label: 'Información adicional',
        icon: Icons.list_alt_outlined,
        child: _ExtraTab(draft: draft),
      ),
  ];
  if (tabs.isEmpty) {
    error.dispose();
    draft.dispose();
    return null;
  }
  // Todas las pestañas viven mientras el modal está abierto: la primera suelta los controles al cerrarse.
  final first = tabs.first;
  tabs[0] = AppTabItem(
    label: first.label,
    icon: first.icon,
    badge: first.badge,
    child: AppDisposer(onDispose: [draft.dispose, error.dispose], child: first.child),
  );

  return showAppModal(
    context,
    title: editing ? 'Editar cliente' : 'Crear cliente',
    subtitle: editing ? client.displayName : 'Se agrega a tu empresa',
    icon: editing ? Icons.edit_outlined : Icons.person_add_alt_outlined,
    primaryLabel: editing ? 'Guardar' : 'Crear',
    primaryEnabled: editing ? draft.changed : null,
    error: error,
    tabs: tabs,
    onPrimary: () async {
      error.value = null;
      final message = await onSubmit(draft.toEntity());
      if (message != null) {
        // El modal sigue abierto con el mensaje (por ejemplo, "El Cliente ya existe").
        error.value = message;
        throw StateError(message);
      }
    },
  );

}

// ---------------------------------------------------------------------------------------------

/// Departamento, provincia y distrito en cascada. Las listas se piden (y se guardan) con
/// `ClientsProvider`; lo elegido vive en los tres notificadores, que se pueden llenar desde fuera
/// (la consulta de un RUC trae el distrito).
class _UbigeoPicker extends StatefulWidget {
  final ValueNotifier<String?> department;
  final ValueNotifier<String?> province;
  final ValueNotifier<String?> district;

  const _UbigeoPicker({
    required this.department,
    required this.province,
    required this.district,
  });

  @override
  State<_UbigeoPicker> createState() => _UbigeoPickerState();
}

class _UbigeoPickerState extends State<_UbigeoPicker> {
  List<UbigeoItemEntity> _departments = [];
  List<UbigeoItemEntity> _provinces = [];
  List<UbigeoItemEntity> _districts = [];

  ClientsProvider get _clients => context.read<ClientsProvider>();

  @override
  void initState() {
    super.initState();
    widget.department.addListener(_loadProvinces);
    widget.province.addListener(_loadDistricts);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final result = await _clients.departments();
      if (!mounted) return;
      if (result.isRight) setState(() => _departments = result.right);
      await _loadProvinces();
      await _loadDistricts();
    });
  }

  @override
  void dispose() {
    widget.department.removeListener(_loadProvinces);
    widget.province.removeListener(_loadDistricts);
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    final id = widget.department.value;
    if (id == null) {
      if (mounted) setState(() => _provinces = []);
      return;
    }
    final result = await _clients.provincesOf(id);
    if (!mounted || widget.department.value != id) return;
    if (result.isRight) setState(() => _provinces = result.right);
  }

  Future<void> _loadDistricts() async {
    final id = widget.province.value;
    if (id == null) {
      if (mounted) setState(() => _districts = []);
      return;
    }
    final result = await _clients.districtsOf(id);
    if (!mounted || widget.province.value != id) return;
    if (result.isRight) setState(() => _districts = result.right);
  }

  void _pickDepartment(String? id) {
    widget.province.value = null;
    widget.district.value = null;
    widget.department.value = id;
  }

  void _pickProvince(String? id) {
    widget.district.value = null;
    widget.province.value = id;
  }

  Widget _dropdown(
    String label,
    List<UbigeoItemEntity> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    // Solo se ofrece el valor elegido si está en la lista (evita un valor sin opción).
    final selected = items.any((i) => i.id == value) ? value : null;
    return AppDropdownField<String>(
      key: ValueKey('$label-$selected-${items.length}'),
      label: label,
      value: selected,
      items: [
        for (final i in items) DropdownMenuItem(value: i.id, child: Text(i.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: items.isEmpty ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.department, widget.province, widget.district]),
      builder: (context, _) => Column(
        children: [
          _dropdown('Departamento', _departments, widget.department.value, _pickDepartment),
          const SizedBox(height: 16),
          _dropdown('Provincia', _provinces, widget.province.value, _pickProvince),
          const SizedBox(height: 16),
          _dropdown('Distrito', _districts, widget.district.value, (v) => widget.district.value = v),
        ],
      ),
    );
  }
}

const _gap = SizedBox(height: 16);

class _BasicTab extends StatefulWidget {
  final _ClientDraft draft;
  final bool editing;
  final ValueNotifier<String?> error;

  const _BasicTab({required this.draft, required this.editing, required this.error});

  @override
  State<_BasicTab> createState() => _BasicTabState();
}

class _BasicTabState extends State<_BasicTab> {
  bool _lookingUp = false;

  _ClientDraft get _d => widget.draft;

  Future<void> _lookup() async {
    widget.error.value = null;
    FocusScope.of(context).unfocus();
    setState(() => _lookingUp = true);
    final result = await context.read<ClientsProvider>().lookup(tipo: _d.tipo.value, number: _d.dni.text);
    if (!mounted) return;
    setState(() => _lookingUp = false);

    if (result.isLeft) {
      widget.error.value = result.left.message;
      return;
    }
    final found = result.right;
    _d.tipo.value = found.tipo;
    if (found.esEmpresa) {
      _d.razonSocial.text = found.razonSocial ?? '';
      _d.direccion.text = found.direccion ?? '';
      // Con un RUC, la SUNAT trae el distrito: se eligen los tres niveles de una vez.
      if (found.departmentId != null && found.provinceId != null && found.districtId != null) {
        _d.department.value = found.departmentId;
        _d.province.value = found.provinceId;
        _d.district.value = found.districtId;
      }
    } else {
      _d.name.text = found.name ?? '';
      _d.lastName.text = found.lastName ?? '';
    }
  }

  void _changeTipo(String value) {
    if (value == _d.tipo.value) return;
    _d.tipo.value = value;
    // Como la web: al cambiar de tipo se vacían la razón social, la dirección y el distrito.
    _d.razonSocial.clear();
    _d.direccion.clear();
    _d.department.value = null;
    _d.province.value = null;
    _d.district.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: _d.tipo,
      builder: (context, _) {
        final esEmpresa = _d.tipo.value == 'e';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_d.client?.codigo != null) ...[
              AppDetailRow(label: 'Código', value: _d.client!.codigo),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text('Extranjero', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<bool>(
                        valueListenable: _d.extranjero,
                        builder: (_, v, _) => Switch(value: v, onChanged: (x) => _d.extranjero.value = x),
                      ),
                    ],
                  ),
                ),
                // Un Vendedor no activa ni inactiva clientes: el cliente nuevo queda activo.
                if (!_d.access.onlySeller)
                  Row(
                    children: [
                      const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<bool>(
                        valueListenable: _d.estado,
                        builder: (_, v, _) => Switch(value: v, onChanged: (x) => _d.estado.value = x),
                      ),
                    ],
                  ),
              ],
            ),
            _gap,
            SegmentedButton<String>(
              showSelectedIcon: false,
              selected: {_d.tipo.value},
              onSelectionChanged: (s) => _changeTipo(s.first),
              segments: const [
                ButtonSegment(value: 'p', icon: Icon(Icons.person_outline), label: Text('Persona')),
                ButtonSegment(value: 'e', icon: Icon(Icons.business_outlined), label: Text('Empresa')),
              ],
            ),
            _gap,
            TextField(
              controller: _d.dni,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              onSubmitted: (_) => _lookup(),
              decoration: InputDecoration(
                labelText: esEmpresa ? 'RUC' : 'DNI',
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: _lookingUp
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        tooltip: 'Buscar en ${esEmpresa ? 'SUNAT' : 'RENIEC'}',
                        icon: const Icon(Icons.search),
                        onPressed: _lookup,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 4),
              child: Text(
                'Toca la lupa para traer los datos de ${esEmpresa ? 'la SUNAT' : 'RENIEC'}.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            _gap,
            if (esEmpresa) ...[
              AppTextField(controller: _d.razonSocial, label: 'Razón social', prefixIcon: Icons.business_outlined),
              _gap,
            ],
            AppTextField(
              controller: _d.phone,
              label: 'Teléfono',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            _gap,
            AppTextField(controller: _d.giro, label: 'Giro (opcional)', prefixIcon: Icons.info_outline),
            _gap,
            AppTextField(
              controller: _d.name,
              label: esEmpresa ? 'Nombre del contacto' : 'Nombre',
              prefixIcon: Icons.person_outline,
            ),
            _gap,
            AppTextField(
              controller: _d.lastName,
              label: esEmpresa ? 'Apellido del contacto (opcional)' : 'Apellidos (opcional)',
              prefixIcon: Icons.person_outline,
            ),
            _gap,
            AppTextField(
              controller: _d.email,
              label: 'Correo',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const AppSectionTitle('Dirección'),
            _UbigeoPicker(department: _d.department, province: _d.province, district: _d.district),
            _gap,
            AppTextField(
              controller: _d.calle,
              label: 'Urbanización, calle, etc. (opcional)',
              prefixIcon: Icons.add_road_outlined,
            ),
            _gap,
            AppTextField(controller: _d.direccion, label: 'Dirección (opcional)', prefixIcon: Icons.home_outlined),
            _gap,
            AppTextField(
              controller: _d.lote,
              label: 'Número, manzana, lote, etc. (opcional)',
              prefixIcon: Icons.landscape_outlined,
            ),
            _gap,
            AppTextField(
              controller: _d.indicaciones,
              label: 'Indicaciones para la dirección (opcional)',
              prefixIcon: Icons.notes_outlined,
              maxLines: 2,
            ),
            const AppSectionTitle('Ejecutivo comercial'),
            _ExecutiveField(draft: _d),
          ],
        );
      },
    );
  }
}

class _ExecutiveField extends StatelessWidget {
  final _ClientDraft draft;

  const _ExecutiveField({required this.draft});

  @override
  Widget build(BuildContext context) {
    final onlySeller = draft.access.onlySeller;
    return ListenableBuilder(
      listenable: Listenable.merge([draft.catalogs, draft.ejecutivo]),
      builder: (context, _) {
        final options = <ClientOption>[...?draft.catalogs.value?.ejecutivos];
        // Al editar, el ejecutivo que el cliente ya tiene se muestra aunque su rol no sea de los
        // que pueden serlo (clientes asignados antes de esa regla).
        final current = draft.client;
        if (current?.ejecutivoId != null &&
            current?.ejecutivoNombre != null &&
            !options.any((o) => o.id == current!.ejecutivoId)) {
          options.add(ClientOption(id: current!.ejecutivoId!, name: current.ejecutivoNombre!));
        }
        final selected = options.any((o) => o.id == draft.ejecutivo.value) ? draft.ejecutivo.value : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPickerField(
              key: ValueKey('ejecutivo-$selected-${options.length}'),
              label: 'Ejecutivo comercial',
              value: selected == null
                  ? (onlySeller ? 'Tú (vendedor)' : 'Sin asignar')
                  : options.firstWhere((o) => o.id == selected).name,
              icon: Icons.person_search_outlined,
              onTap: onlySeller || options.isEmpty
                  ? null
                  : () async {
                      final result = await showClientOptionPicker(
                        context,
                        title: 'Ejecutivo comercial',
                        options: options,
                        selected: selected,
                      );
                      if (result != null) draft.ejecutivo.value = result == -1 ? null : result;
                    },
              onClear: onlySeller || selected == null ? null : () => draft.ejecutivo.value = null,
            ),
            if (onlySeller)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 4),
                child: Text(
                  'Los vendedores no pueden cambiar el ejecutivo comercial.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ValueListenableBuilder<String?>(
              valueListenable: draft.catalogsError,
              builder: (context, message, _) => message == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ErrorBanner(message: 'No se pudieron cargar las listas: $message'),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Elige una opción de una lista con búsqueda. Devuelve su id, `-1` si se quitó la elección, o
/// `null` si se cerró sin elegir.
Future<int?> showClientOptionPicker(
  BuildContext context, {
  required String title,
  required List<ClientOption> options,
  int? selected,
}) async {
  final result = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _SingleSelectSheet(title: title, options: options, selected: selected),
  );
  return result;
}

class _SingleSelectSheet extends StatefulWidget {
  final String title;
  final List<ClientOption> options;
  final int? selected;

  const _SingleSelectSheet({required this.title, required this.options, this.selected});

  @override
  State<_SingleSelectSheet> createState() => _SingleSelectSheetState();
}

class _SingleSelectSheetState extends State<_SingleSelectSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final visible = [
      for (final o in widget.options)
        if (q.isEmpty || o.name.toLowerCase().contains(q)) o,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(widget.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(hintText: 'Buscar', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in visible)
                  ListTile(
                    title: Text(o.name),
                    trailing: o.id == widget.selected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(context).pop(o.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressesTab extends StatelessWidget {
  final _ClientDraft draft;

  const _AddressesTab({required this.draft});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<_AddressDraft>>(
      valueListenable: draft.addresses,
      builder: (context, list, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < list.length; i++) ...[
            _AddressCard(key: ObjectKey(list[i]), draft: draft, address: list[i], number: i + 1),
            _gap,
          ],
          OutlinedButton.icon(
            onPressed: draft.addAddress,
            icon: const Icon(Icons.add),
            label: const Text('Agregar dirección'),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final _ClientDraft draft;
  final _AddressDraft address;
  final int number;

  const _AddressCard({super.key, required this.draft, required this.address, required this.number});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Dirección $number', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: 'Quitar dirección',
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                onPressed: () => draft.removeAddress(address),
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: address.predeterminado,
            builder: (context, on, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Predeterminada'),
              value: on,
              onChanged: (v) => draft.setDefaultAddress(address, v),
            ),
          ),
          AppTextField(controller: address.direccion, label: 'Dirección', prefixIcon: Icons.home_outlined),
          _gap,
          _UbigeoPicker(department: address.department, province: address.province, district: address.district),
          _gap,
          AppTextField(
            controller: address.calle,
            label: 'Urbanización, calle, etc. (opcional)',
            prefixIcon: Icons.add_road_outlined,
          ),
          _gap,
          AppTextField(
            controller: address.lote,
            label: 'Número, manzana, lote, etc. (opcional)',
            prefixIcon: Icons.landscape_outlined,
          ),
          _gap,
          AppTextField(
            controller: address.indicaciones,
            label: 'Indicaciones (opcional)',
            prefixIcon: Icons.notes_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _ContactsTab extends StatelessWidget {
  final _ClientDraft draft;

  const _ContactsTab({required this.draft});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<List<_ContactDraft>>(
      valueListenable: draft.contacts,
      builder: (context, list, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < list.length; i++) ...[
            Container(
              key: ObjectKey(list[i]),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Contacto ${i + 1}',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        tooltip: 'Quitar contacto',
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                        onPressed: () => draft.removeContact(list[i]),
                      ),
                    ],
                  ),
                  AppTextField(controller: list[i].name, label: 'Nombres', prefixIcon: Icons.person_outline),
                  _gap,
                  AppTextField(controller: list[i].lastName, label: 'Apellidos (opcional)', prefixIcon: Icons.badge_outlined),
                  _gap,
                  AppTextField(
                    controller: list[i].email,
                    label: 'Correo (opcional)',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _gap,
                  AppTextField(
                    controller: list[i].phone,
                    label: 'Teléfono (opcional)',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            _gap,
          ],
          OutlinedButton.icon(
            onPressed: draft.addContact,
            icon: const Icon(Icons.add),
            label: const Text('Agregar contacto'),
          ),
        ],
      ),
    );
  }
}

class _ConditionsTab extends StatelessWidget {
  final _ClientDraft draft;

  const _ConditionsTab({required this.draft});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([draft.catalogs, draft.listPrice, draft.payment]),
      builder: (context, _) {
        final catalogs = draft.catalogs.value;
        if (catalogs == null) {
          return const AppSkeletonForm(fields: 3);
        }

        Widget dropdown(String label, List<ClientOption> options, ValueNotifier<int?> value) {
          final selected = options.any((o) => o.id == value.value) ? value.value : null;
          return Row(
            children: [
              Expanded(
                child: AppDropdownField<int>(
                  key: ValueKey('$label-$selected-${options.length}'),
                  label: label,
                  value: selected,
                  items: [
                    for (final o in options) DropdownMenuItem(value: o.id, child: Text(o.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: options.isEmpty ? null : (v) => value.value = v,
                ),
              ),
              if (selected != null)
                IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close),
                  onPressed: () => value.value = null,
                ),
            ],
          );
        }

        final category = draft.client?.categoriaId;
        final categoryName = draft.client?.categoriaNombre;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dropdown('Lista de precios predeterminada', catalogs.listasDePrecios, draft.listPrice),
            _gap,
            dropdown('Método de pago predeterminado', catalogs.metodosDePago, draft.payment),
            _gap,
            TextField(
              controller: draft.credito,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(
                labelText: 'Línea de crédito',
                prefixIcon: Icon(Icons.payments_outlined),
                prefixText: 'S/. ',
              ),
            ),
            _gap,
            // La categoría la calcula el sistema según lo comprado: aquí solo se muestra.
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Categoría de cliente (automática)',
                prefixIcon: Icon(Icons.workspace_premium_outlined),
                enabled: false,
              ),
              child: category == null || categoryName == null
                  ? Text('Sin categoría', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                  : Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: clientCategoryColors(draft.client?.categoriaCodigo, theme.brightness).foreground,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(categoryName),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 4),
              child: Text(
                'Se asigna automáticamente según el rango de montos y el ciclo de actualización configurado.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExtraTab extends StatelessWidget {
  final _ClientDraft draft;

  const _ExtraTab({required this.draft});

  Future<void> _pickBirthday(BuildContext context) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(draft.cumple.value ?? '') ?? DateTime(now.year - 30, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Cumpleaños',
    );
    if (picked != null) draft.cumple.value = DateFormat('yyyy-MM-dd').format(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: draft.redes,
          label: 'Facebook (facebook.com/…)',
          prefixIcon: Icons.facebook_outlined,
          keyboardType: TextInputType.url,
        ),
        _gap,
        AppTextField(
          controller: draft.pagina2,
          label: 'Página 2 (.com/…)',
          prefixIcon: Icons.link,
          keyboardType: TextInputType.url,
        ),
        _gap,
        AppTextField(
          controller: draft.pagina3,
          label: 'Página 3 (.com/…)',
          prefixIcon: Icons.link,
          keyboardType: TextInputType.url,
        ),
        _gap,
        ValueListenableBuilder<String?>(
          valueListenable: draft.cumple,
          builder: (context, value, _) {
            final date = value == null ? null : DateTime.tryParse(value);
            return AppPickerField(
              label: 'Cumpleaños',
              value: date == null ? 'Sin fecha' : DateFormat(AppConstants.dateFormat).format(date),
              icon: Icons.cake_outlined,
              onTap: () => _pickBirthday(context),
              onClear: date == null ? null : () => draft.cumple.value = null,
            );
          },
        ),
        _gap,
        AppTextField(
          controller: draft.nota,
          label: 'Detalle adicional del cliente',
          prefixIcon: Icons.notes_outlined,
          maxLines: 3,
        ),
      ],
    );
  }
}
