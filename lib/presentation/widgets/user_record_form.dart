import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/user_permissions.dart';
import '../../domain/entities/client_form_entity.dart' show UbigeoItemEntity;
import '../../domain/entities/user_record_entity.dart';
import '../../domain/usecases/user_record_usecases.dart';
import '../components/components.dart';
import '../providers/users_provider.dart';
import 'user_record_modals.dart';

/// Los tipos de documento que acepta la web.
const _documentTypes = {
  'DNI': 'DNI',
  'CE': 'Carné de extranjería',
  'PASAPORTE': 'Pasaporte',
};

/// Una foto elegida del dispositivo, lista para subirse al guardar.
typedef PickedUserPhoto = ({String name, Uint8List bytes});

/// Abre el selector del sistema para elegir la foto del usuario (JPG, PNG o WEBP de hasta 2 MB).
/// Devuelve `null` si se cancela; lanza una excepción con el mensaje si pesa más de 2 MB.
Future<PickedUserPhoto?> pickUserPhoto() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > UploadUserPhotoUseCase.maxBytes) {
    throw Exception('La foto no puede pesar más de 2 MB');
  }
  return (name: file.name, bytes: bytes);
}

/// Todo lo que se va llenando en el formulario de usuario.
class _UserDraft {
  final UserRecordEntity? user;

  final tipoDocumento = ValueNotifier<String>('DNI');
  final numeroDocumento = TextEditingController();
  final fechaIngreso = ValueNotifier<String?>(null);
  final estado = ValueNotifier<bool>(true);
  final nombres = TextEditingController();
  final apellidos = TextEditingController();
  final cumple = ValueNotifier<String?>(null);
  final telefono = TextEditingController();
  final email = TextEditingController();
  final direccion = TextEditingController();
  final department = ValueNotifier<String?>(null);
  final province = ValueNotifier<String?>(null);
  final district = ValueNotifier<String?>(null);
  final contacto = TextEditingController();
  final telefonoEmergencia = TextEditingController();

  final roles = ValueNotifier<List<int>>([]);
  final ventasAjenas = ValueNotifier<bool>(false);
  final almacenes = ValueNotifier<List<int>>([]);
  final warehouseId = ValueNotifier<int?>(null);
  final paymentMethods = ValueNotifier<List<int>>([]);
  final paymentMethodId = ValueNotifier<int?>(null);
  final metodoEntrega = ValueNotifier<String?>(null);
  final listPrices = ValueNotifier<List<int>>([]);
  final listPriceId = ValueNotifier<int?>(null);

  /// Los permisos adicionales que se ven y se eligen (los de la lista de la web).
  final permisos = ValueNotifier<Set<int>>({});

  /// Los permisos del usuario que la web no ofrece: no se tocan, pero se mandan igual para que
  /// guardar no se los quite.
  final List<int> _hiddenPermisos;

  final catalogs = ValueNotifier<UserCatalogsEntity?>(null);
  final catalogsError = ValueNotifier<String?>(null);

  /// La foto que el usuario ya tiene y la que se eligió ahora (se sube al guardar).
  final currentPhoto = ValueNotifier<Uint8List?>(null);
  final newPhoto = ValueNotifier<PickedUserPhoto?>(null);

  /// Cambia a `true` con la primera modificación: al editar, no se guarda sin cambios.
  final changed = ValueNotifier<bool>(false);
  bool _disposed = false;

  _UserDraft({this.user})
      : _hiddenPermisos = [
          for (final p in user?.permissions ?? const <UserPermissionEntity>[])
            if (!userPermissionLabels.containsKey(p.name)) p.id,
        ] {
    final u = user;
    if (u != null) {
      tipoDocumento.value = _documentTypes.containsKey(u.tipoDocumento) ? u.tipoDocumento! : 'DNI';
      numeroDocumento.text = u.numeroDocumento ?? '';
      fechaIngreso.value = u.fechaIngreso;
      estado.value = u.estado;
      // Un usuario antiguo solo tiene el nombre completo: entra a Nombres hasta que se separe.
      nombres.text = u.nombres ?? u.name;
      apellidos.text = u.apellidos ?? '';
      cumple.value = u.cumple;
      telefono.text = u.telefono ?? '';
      email.text = u.email ?? '';
      direccion.text = u.direccion ?? '';
      department.value = u.departmentId;
      province.value = u.provinceId;
      district.value = u.districtId;
      contacto.text = u.contactoEmergencia ?? '';
      telefonoEmergencia.text = u.telefonoEmergencia ?? '';
      roles.value = [for (final r in u.roles) r.id];
      ventasAjenas.value = u.ventasAjenas;
      almacenes.value = [for (final w in u.warehouses) w.id];
      warehouseId.value = u.warehouseId;
      paymentMethods.value = [for (final p in u.paymentMethods) p.id];
      paymentMethodId.value = u.paymentMethodId;
      metodoEntrega.value = u.metodoEntrega;
      listPrices.value = [for (final l in u.listPrices) l.id];
      listPriceId.value = u.listPriceId;
      permisos.value = {
        for (final p in u.permissions)
          if (userPermissionLabels.containsKey(p.name)) p.id,
      };
    }
    // Recién ahora se escuchan los cambios: lo anterior es el valor inicial.
    final all = <Listenable>[
      tipoDocumento, numeroDocumento, fechaIngreso, estado, nombres, apellidos, cumple, telefono, email,
      direccion, department, province, district, contacto, telefonoEmergencia, roles, ventasAjenas,
      almacenes, warehouseId, paymentMethods, paymentMethodId, metodoEntrega, listPrices, listPriceId,
      permisos, newPhoto,
    ];
    for (final l in all) {
      l.addListener(markChanged);
    }
  }

  void markChanged() => changed.value = true;

  Future<void> loadCatalogs(Future<UserCatalogsEntity> Function() load) async {
    try {
      final c = await load();
      if (_disposed) return;
      catalogs.value = c;
    } catch (e) {
      if (_disposed) return;
      catalogsError.value = '$e'.replaceFirst('Exception: ', '');
      catalogs.value = const UserCatalogsEntity();
    }
  }

  Future<void> loadPhoto(Future<Uint8List?> Function() load) async {
    final bytes = await load();
    if (_disposed) return;
    currentPhoto.value = bytes;
  }

  /// Los nombres de los roles elegidos (los ids que la lista no conoce se ignoran).
  Iterable<String> get _roleNames sync* {
    final all = catalogs.value?.roles ?? const <UserOption>[];
    for (final id in roles.value) {
      for (final r in all) {
        if (r.id == id) yield r.name;
      }
    }
  }

  /// Igual que la web: los Contadores, Cajeros, Vendedores y el Ceo trabajan con métodos de pago.
  bool get conPagos =>
      roles.value.contains(UserRoles.contadorId) ||
      roles.value.contains(UserRoles.cajeroId) ||
      roles.value.contains(UserRoles.vendedorId) ||
      _roleNames.contains(UserRoles.ceoEmpresa);

  /// Y con listas de precios, además, el Admin Empresa y el Jefe Comercial.
  bool get conListas =>
      roles.value.contains(UserRoles.adminEmpresaId) || conPagos || _roleNames.contains(UserRoles.jefeComercial);

  bool get esVendedor => roles.value.contains(UserRoles.vendedorId);

  UserFormEntity toEntity() => UserFormEntity(
        tipoDocumento: tipoDocumento.value,
        numeroDocumento: numeroDocumento.text,
        fechaIngreso: fechaIngreso.value,
        estado: estado.value,
        nombres: nombres.text,
        apellidos: apellidos.text,
        cumple: cumple.value,
        telefono: telefono.text,
        email: email.text,
        direccion: direccion.text,
        departmentId: department.value,
        provinceId: province.value,
        districtId: district.value,
        contactoEmergencia: contacto.text,
        telefonoEmergencia: telefonoEmergencia.text,
        roles: roles.value,
        ventasAjenas: ventasAjenas.value,
        almacenes: almacenes.value,
        warehouseId: warehouseId.value,
        paymentMethods: paymentMethods.value,
        paymentMethodId: paymentMethodId.value,
        metodoEntrega: metodoEntrega.value,
        listPrices: listPrices.value,
        listPriceId: listPriceId.value,
        permisos: [...permisos.value, ..._hiddenPermisos],
        conPagos: conPagos,
        conListas: conListas,
        esVendedor: esVendedor,
      );

  void dispose() {
    _disposed = true;
    for (final c in [numeroDocumento, nombres, apellidos, telefono, email, direccion, contacto, telefonoEmergencia]) {
      c.dispose();
    }
    for (final n in [tipoDocumento, fechaIngreso, cumple, department, province, district, metodoEntrega, catalogsError]) {
      n.dispose();
    }
    for (final n in [estado, ventasAjenas]) {
      n.dispose();
    }
    for (final n in [roles, almacenes, paymentMethods, listPrices]) {
      n.dispose();
    }
    for (final n in [warehouseId, paymentMethodId, listPriceId]) {
      n.dispose();
    }
    permisos.dispose();
    catalogs.dispose();
    currentPhoto.dispose();
    newPhoto.dispose();
    changed.dispose();
  }
}

/// Formulario para crear o editar un usuario, con las mismas pestañas y campos de la web: Datos
/// personales y Accesos y permisos. No pide contraseña: al crear, el servidor envía un correo para
/// que el usuario active su cuenta y la cree.
///
/// [onSubmit] guarda y devuelve el mensaje de error, o `null` si salió bien. Devuelve `true` si se
/// guardó.
Future<bool?> showUserForm(
  BuildContext context, {
  UserRecordEntity? user,
  required Future<UserCatalogsEntity> Function() loadCatalogs,
  required List<UserOption> Function(List<UserOption> all) assignableRoles,
  required Future<String?> Function(UserFormEntity form, PickedUserPhoto? photo) onSubmit,
}) {
  final editing = user != null;
  final draft = _UserDraft(user: user);
  final error = ValueNotifier<String?>(null);
  final tabs = AppTabsController();
  final personalKey = GlobalKey<FormState>();
  final accessKey = GlobalKey<FormState>();
  // Las listas del formulario y la foto se piden ya, mientras se abre el modal.
  draft.loadCatalogs(loadCatalogs);
  if (user != null && user.foto != null) {
    draft.loadPhoto(() => context.read<UsersProvider>().loadPhoto(user.id));
  }

  final items = <AppTabItem>[
    AppTabItem(
      label: 'Datos personales',
      icon: Icons.person_outline,
      child: AppDisposer(
        // Todas las pestañas viven mientras el modal está abierto: la primera suelta los controles al cerrarse.
        onDispose: [draft.dispose, error.dispose, tabs.dispose],
        child: Form(key: personalKey, child: _PersonalTab(draft: draft, editing: editing)),
      ),
    ),
    AppTabItem(
      label: 'Accesos y permisos',
      icon: Icons.layers_outlined,
      child: Form(
        key: accessKey,
        child: _AccessTab(draft: draft, editing: editing, assignableRoles: assignableRoles),
      ),
    ),
  ];

  return showAppModal(
    context,
    title: editing ? 'Editar usuario' : 'Crear usuario',
    subtitle: editing ? user.name : 'Se agrega a tu empresa',
    icon: editing ? Icons.edit_outlined : Icons.person_add_alt_outlined,
    primaryLabel: editing ? 'Guardar' : 'Crear',
    primaryEnabled: editing ? draft.changed : null,
    error: error,
    tabs: items,
    tabsController: tabs,
    // Las pestañas son largas y cambian con el rol: la ventana mide siempre lo mismo.
    fixedHeight: true,
    onPrimary: () async {
      error.value = null;
      final form = draft.toEntity();
      final problems = SaveUserUseCase.problems(form, editing: editing);
      // Marca los campos y las pestañas con error y salta a la primera.
      final valid = tabs.validate([personalKey, accessKey]);
      if (!valid || problems.isNotEmpty) {
        if (valid) tabs.select(problems.first.inAccess ? 1 : 0);
        final message = problems.isEmpty ? 'Revisa los campos marcados' : 'Completa estos campos: ${problems.join(', ')}';
        error.value = message;
        throw StateError(message);
      }
      final message = await onSubmit(form, draft.newPhoto.value);
      if (message != null) {
        // El modal sigue abierto con el mensaje (por ejemplo, "El correo ya está en uso").
        error.value = message;
        throw StateError(message);
      }
    },
  );
}

// ---------------------------------------------------------------------------------------------

const _gap = SizedBox(height: 16);

Widget _textField(
  TextEditingController controller,
  String label,
  IconData icon, {
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  int? maxLength,
  bool digitsOnly = false,
  Key? fieldKey,
}) =>
    TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      inputFormatters: [
        if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );

/// Un selector (`AppPickerField`) que también se valida con el formulario: muestra el motivo debajo
/// cuando falta.
class _PickerFormField extends FormField<int> {
  _PickerFormField({
    super.key,
    required String label,
    required String Function() value,
    required IconData icon,
    required Future<void> Function() onTap,
    VoidCallback? onClear,
    String? Function()? check,
  }) : super(
          validator: check == null ? null : (_) => check(),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPickerField(
                label: label,
                value: value(),
                icon: icon,
                onTap: () async {
                  await onTap();
                  // Vuelve a revisar con lo que se eligió (quita el aviso de "Obligatorio").
                  if (state.mounted) state.didChange(null);
                },
                onClear: onClear,
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 14, top: 6),
                  child: Text(
                    state.errorText!,
                    style: Theme.of(state.context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(state.context).colorScheme.error,
                        ),
                  ),
                ),
            ],
          ),
        );
}

class _PersonalTab extends StatelessWidget {
  final _UserDraft draft;
  final bool editing;

  const _PersonalTab({required this.draft, required this.editing});

  _UserDraft get _d => draft;

  Future<void> _pickDate(
    BuildContext context,
    ValueNotifier<String?> target, {
    required String help,
    required DateTime last,
    DateTime? fallback,
  }) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(target.value ?? '') ?? fallback ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: DateTime(1900),
      lastDate: last,
      helpText: help,
    );
    if (picked != null) target.value = DateFormat('yyyy-MM-dd').format(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhotoField(draft: _d),
        _gap,
        ValueListenableBuilder<bool>(
          valueListenable: _d.estado,
          builder: (_, active, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(active ? 'Activo' : 'Inactivo'),
            value: active,
            onChanged: (v) => _d.estado.value = v,
          ),
        ),
        _gap,
        ValueListenableBuilder<String>(
          valueListenable: _d.tipoDocumento,
          builder: (context, type, _) => AppDropdownField<String>(
            key: ValueKey('tipo-$type'),
            label: 'Tipo de documento',
            value: type,
            items: [
              for (final e in _documentTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v != null) _d.tipoDocumento.value = v;
            },
          ),
        ),
        _gap,
        // El DNI tiene 8 dígitos: la regla depende del tipo elegido.
        ListenableBuilder(
          listenable: _d.tipoDocumento,
          builder: (context, _) => _textField(
            _d.numeroDocumento,
            'N° de documento',
            Icons.badge_outlined,
            maxLength: 20,
            keyboardType: _d.tipoDocumento.value == 'DNI' ? TextInputType.number : TextInputType.text,
            digitsOnly: _d.tipoDocumento.value == 'DNI',
            validator: (v) => UserFormRules.documentNumber(_d.tipoDocumento.value, v),
          ),
        ),
        _gap,
        _textField(_d.nombres, 'Nombres', Icons.person_outline,
            maxLength: 120, validator: UserFormRules.mandatory),
        _gap,
        _textField(_d.apellidos, 'Apellidos', Icons.person_outline,
            maxLength: 120, validator: UserFormRules.mandatory),
        _gap,
        ValueListenableBuilder<String?>(
          valueListenable: _d.cumple,
          builder: (context, value, _) => _PickerFormField(
            key: ValueKey('cumple-$value'),
            label: 'Fecha de nacimiento',
            value: () => value == null ? 'Elige la fecha' : userDateLabel(value),
            icon: Icons.cake_outlined,
            onTap: () => _pickDate(
              context,
              _d.cumple,
              help: 'Fecha de nacimiento',
              last: DateTime(now.year, now.month, now.day),
              fallback: DateTime(now.year - 30, now.month, now.day),
            ),
            check: () => UserFormRules.birthday(value),
          ),
        ),
        _gap,
        _textField(_d.telefono, 'Celular', Icons.phone_outlined,
            keyboardType: TextInputType.phone, validator: UserFormRules.mandatory),
        _gap,
        _textField(_d.email, 'Correo', Icons.mail_outline,
            keyboardType: TextInputType.emailAddress, validator: UserFormRules.email),
        if (!editing)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 4),
            child: Text(
              'Recibirá un correo para activar su cuenta y crear su contraseña.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        _gap,
        ValueListenableBuilder<String?>(
          valueListenable: _d.fechaIngreso,
          builder: (context, value, _) => AppPickerField(
            label: 'Fecha de ingreso (opcional)',
            value: value == null ? 'Sin fecha' : userDateLabel(value),
            icon: Icons.event_outlined,
            onTap: () => _pickDate(
              context,
              _d.fechaIngreso,
              help: 'Fecha de ingreso',
              last: DateTime(now.year + 1, 12, 31),
            ),
            onClear: value == null ? null : () => _d.fechaIngreso.value = null,
          ),
        ),
        const AppSectionTitle('Domicilio'),
        _textField(_d.direccion, 'Dirección de domicilio', Icons.location_on_outlined, maxLength: 255),
        _gap,
        _UbigeoPicker(department: _d.department, province: _d.province, district: _d.district),
        const AppSectionTitle('Contacto de emergencia'),
        _textField(_d.contacto, 'Contacto de emergencia (opcional)', Icons.group_outlined, maxLength: 120),
        _gap,
        _textField(_d.telefonoEmergencia, 'Teléfono de emergencia (opcional)', Icons.phone_in_talk_outlined,
            maxLength: 30, keyboardType: TextInputType.phone),
      ],
    );
  }
}

/// La foto del usuario: la que tiene o la recién elegida, con el botón para cambiarla.
class _PhotoField extends StatelessWidget {
  final _UserDraft draft;

  const _PhotoField({required this.draft});

  Future<void> _pick(BuildContext context) async {
    try {
      final photo = await pickUserPhoto();
      if (photo != null) draft.newPhoto.value = photo;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([draft.currentPhoto, draft.newPhoto, draft.nombres, draft.apellidos]),
      builder: (context, _) {
        final bytes = draft.newPhoto.value?.bytes ?? draft.currentPhoto.value;
        final name = '${draft.nombres.text} ${draft.apellidos.text}'.trim();
        return Row(
          children: [
            Container(
              width: 72,
              height: 72,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primaryContainer),
              child: bytes != null
                  ? Image.memory(bytes, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person_outline))
                  : (name.isEmpty
                      ? Icon(Icons.person_outline, size: 34, color: scheme.onPrimaryContainer)
                      : Text(
                          userInitials(name),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
                        )),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pick(context),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(bytes == null ? 'Agregar foto' : 'Cambiar foto'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Text(
                      'JPG, PNG o WEBP de hasta 2 MB',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Departamento, provincia y distrito en cascada. Las listas se piden (y se guardan) con
/// `UsersProvider`.
class _UbigeoPicker extends StatefulWidget {
  final ValueNotifier<String?> department;
  final ValueNotifier<String?> province;
  final ValueNotifier<String?> district;

  const _UbigeoPicker({required this.department, required this.province, required this.district});

  @override
  State<_UbigeoPicker> createState() => _UbigeoPickerState();
}

class _UbigeoPickerState extends State<_UbigeoPicker> {
  List<UbigeoItemEntity> _departments = [];
  List<UbigeoItemEntity> _provinces = [];
  List<UbigeoItemEntity> _districts = [];

  UsersProvider get _users => context.read<UsersProvider>();

  @override
  void initState() {
    super.initState();
    widget.department.addListener(_loadProvinces);
    widget.province.addListener(_loadDistricts);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final result = await _users.departments();
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
    final result = await _users.provincesOf(id);
    if (!mounted || widget.department.value != id) return;
    if (result.isRight) setState(() => _provinces = result.right);
  }

  Future<void> _loadDistricts() async {
    final id = widget.province.value;
    if (id == null) {
      if (mounted) setState(() => _districts = []);
      return;
    }
    final result = await _users.districtsOf(id);
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
          _gap,
          _dropdown('Provincia', _provinces, widget.province.value, _pickProvince),
          _gap,
          _dropdown('Distrito', _districts, widget.district.value, (v) => widget.district.value = v),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------

class _AccessTab extends StatelessWidget {
  final _UserDraft draft;
  final bool editing;
  final List<UserOption> Function(List<UserOption> all) assignableRoles;

  const _AccessTab({required this.draft, required this.editing, required this.assignableRoles});

  _UserDraft get _d => draft;

  /// Las opciones del catálogo más las que el usuario ya tiene (que el catálogo puede no traer, por ejemplo
  /// los métodos de pago de otro usuario), para poder nombrarlas.
  static List<UserOption> _union(List<UserOption> catalog, List<UserOption> own) => [
        ...catalog,
        for (final o in own)
          if (!catalog.any((c) => c.id == o.id)) o,
      ];

  static String _summary(List<int> ids, List<UserOption> options, String empty) {
    if (ids.isEmpty) return empty;
    final names = [
      for (final id in ids) options.where((o) => o.id == id).map((o) => o.name).firstOrNull ?? '#$id',
    ];
    return names.join(', ');
  }

  /// Elige varias opciones: lo que la lista no ofrece pero ya estaba elegido se conserva (como en la web).
  Future<void> _pickMany(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<UserOption> offered,
    required ValueNotifier<List<int>> target,
    ValueNotifier<int?>? defaultTarget,
  }) async {
    final offeredIds = offered.map((o) => o.id).toSet();
    final result = await showAppMultiSelect(
      context,
      title: title,
      subtitle: 'Elige una o varias opciones',
      icon: icon,
      options: [for (final o in offered) (id: o.id, name: o.name)],
      selected: target.value.where(offeredIds.contains).toList(),
    );
    if (result == null) return;
    final next = [...result, ...target.value.where((id) => !offeredIds.contains(id))];
    target.value = next;
    // El predeterminado debe ser uno de los elegidos.
    if (defaultTarget != null && defaultTarget.value != null && !next.contains(defaultTarget.value)) {
      defaultTarget.value = null;
    }
  }

  Future<void> _pickOne(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<UserOption> options,
    required ValueNotifier<int?> target,
  }) async {
    final result = await showAppSelectOne(
      context,
      title: title,
      icon: icon,
      options: [for (final o in options) (id: o.id, name: o.name)],
      selected: target.value,
    );
    if (result != null) target.value = result.id;
  }

  /// Los selectores de "elegidos" y "predeterminado" de un mismo tema (sucursales, métodos de pago, listas).
  Widget _pair(
    BuildContext context, {
    required String manyLabel,
    required String manyTitle,
    required String defaultLabel,
    required IconData icon,
    required List<UserOption> offered,
    required List<UserOption> names,
    required ValueNotifier<List<int>> many,
    required ValueNotifier<int?> single,
    required bool mandatory,
    required String requiredMessage,
  }) {
    return ListenableBuilder(
      listenable: Listenable.merge([many, single]),
      builder: (context, _) {
        final chosen = [for (final id in many.value) names.where((o) => o.id == id).firstOrNull ?? UserOption(id: id, name: '#$id')];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerFormField(
              key: ValueKey('$manyLabel-${many.value.join(',')}'),
              label: manyLabel,
              value: () => _summary(many.value, names, 'Elige una o varias'),
              icon: icon,
              onTap: () => _pickMany(
                context,
                title: manyTitle,
                icon: icon,
                offered: offered,
                target: many,
                defaultTarget: single,
              ),
              onClear: many.value.isEmpty
                  ? null
                  : () {
                      many.value = [];
                      single.value = null;
                    },
              check: mandatory ? () => many.value.isEmpty ? requiredMessage : null : null,
            ),
            _gap,
            _PickerFormField(
              key: ValueKey('$defaultLabel-${single.value}-${many.value.join(',')}'),
              label: defaultLabel,
              value: () => single.value == null ? 'Elige uno' : _summary([single.value!], names, ''),
              icon: icon,
              onTap: chosen.isEmpty
                  ? () async {}
                  : () => _pickOne(context, title: defaultLabel, icon: icon, options: chosen, target: single),
              onClear: single.value == null ? null : () => single.value = null,
              check: mandatory ? () => single.value == null ? requiredMessage : null : null,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([_d.catalogs, _d.roles]),
      builder: (context, _) {
        final catalogs = _d.catalogs.value;
        if (catalogs == null) return const AppSkeletonForm(fields: 5);

        final user = _d.user;
        final roleNames = _union(catalogs.roles, user?.roles ?? const []);
        final warehouseNames = _union(catalogs.warehouses, user?.warehouses ?? const []);
        final paymentNames = _union(catalogs.paymentMethods, user?.paymentMethods ?? const []);
        final listNames = _union(catalogs.listPrices, user?.listPrices ?? const []);
        final conPagos = _d.conPagos;
        final conListas = _d.conListas;
        final esVendedor = _d.esVendedor;
        // El switch de ventas ajenas también sale si el usuario ya era vendedor.
        final muestraVentasAjenas = esVendedor || (user?.roles.any((r) => r.id == UserRoles.vendedorId) ?? false);
        final offeredRoles = assignableRoles(catalogs.roles);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<List<int>>(
              valueListenable: _d.roles,
              builder: (context, ids, _) => _PickerFormField(
                key: ValueKey('roles-${ids.join(',')}'),
                label: 'Rol en el sistema',
                value: () => ids.isEmpty
                    ? 'Asignar roles'
                    : [
                        for (final id in ids)
                          UserRoles.display(roleNames.where((o) => o.id == id).map((o) => o.name).firstOrNull ?? '#$id'),
                      ].join(', '),
                icon: Icons.sell_outlined,
                onTap: () => _pickMany(
                  context,
                  title: 'Rol en el sistema',
                  icon: Icons.sell_outlined,
                  offered: [for (final r in offeredRoles) UserOption(id: r.id, name: UserRoles.display(r.name))],
                  target: _d.roles,
                ),
                onClear: ids.isEmpty ? null : () => _d.roles.value = [],
                check: () => ids.isEmpty ? 'Obligatorio' : null,
              ),
            ),
            if (muestraVentasAjenas)
              ValueListenableBuilder<bool>(
                valueListenable: _d.ventasAjenas,
                builder: (_, on, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ver ventas ajenas'),
                  value: on,
                  onChanged: (v) => _d.ventasAjenas.value = v,
                ),
              ),
            _gap,
            _pair(
              context,
              manyLabel: 'Sucursales autorizadas',
              manyTitle: 'Sucursales autorizadas',
              defaultLabel: 'Almacén predeterminado',
              icon: Icons.warehouse_outlined,
              offered: catalogs.warehouses,
              names: warehouseNames,
              many: _d.almacenes,
              single: _d.warehouseId,
              mandatory: true,
              requiredMessage: 'Obligatorio',
            ),
            if (conPagos) ...[
              _gap,
              _pair(
                context,
                manyLabel: 'Operaciones permitidas',
                manyTitle: 'Operaciones permitidas',
                defaultLabel: 'Método de pago predeterminado',
                icon: Icons.payments_outlined,
                offered: catalogs.paymentMethods,
                names: paymentNames,
                many: _d.paymentMethods,
                single: _d.paymentMethodId,
                mandatory: true,
                requiredMessage: 'Obligatorio',
              ),
            ],
            if (esVendedor) ...[
              _gap,
              ValueListenableBuilder<String?>(
                valueListenable: _d.metodoEntrega,
                builder: (context, value, _) => Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<String>(
                        key: ValueKey('entrega-$value'),
                        label: 'Método de entrega predeterminado',
                        value: value,
                        items: const [
                          DropdownMenuItem(value: 'e', child: Text('Entrega Inmediata')),
                          DropdownMenuItem(value: 'd', child: Text('Despacho')),
                        ],
                        onChanged: (v) => _d.metodoEntrega.value = v,
                      ),
                    ),
                    if (value != null)
                      IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.close),
                        onPressed: () => _d.metodoEntrega.value = null,
                      ),
                  ],
                ),
              ),
            ],
            if (conListas) ...[
              _gap,
              _pair(
                context,
                manyLabel: 'Listas de precios',
                manyTitle: 'Listas de precios',
                defaultLabel: 'Lista de precios predeterminada',
                icon: Icons.attach_money,
                offered: catalogs.listPrices,
                names: listNames,
                many: _d.listPrices,
                single: _d.listPriceId,
                // Solo se exigen al crear: un usuario antiguo puede no tenerlas.
                mandatory: !editing,
                requiredMessage: 'Obligatorio',
              ),
            ],
            const AppSectionTitle('Permisos adicionales'),
            ValueListenableBuilder<Set<int>>(
              valueListenable: _d.permisos,
              builder: (context, ids, _) {
                final offered = userOfferedPermissions(catalogs.permissions);
                // Solo cuentan los que se ofrecen: los que el usuario tiene y la web no muestra no se tocan.
                final count = ids.where((id) => offered.any((p) => p.id == id)).length;
                return AppPickerField(
                  label: 'Permisos adicionales',
                  value: count == 0 ? 'Ninguno' : (count == 1 ? '1 permiso' : '$count permisos'),
                  icon: Icons.verified_user_outlined,
                  onTap: () async {
                    final result = await showUserPermissionsPicker(
                      context,
                      permissions: catalogs.permissions,
                      selected: ids,
                    );
                    if (result != null) _d.permisos.value = result;
                  },
                  onClear: count == 0 ? null : () => _d.permisos.value = {},
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 4),
              child: Text(
                'Además de los permisos de su rol, agrupados por módulo.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: _d.catalogsError,
              builder: (context, message, _) => message == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ErrorBanner(message: 'No se pudieron cargar las listas: $message'),
                    ),
            ),
          ],
        );
      },
    );
  }
}
