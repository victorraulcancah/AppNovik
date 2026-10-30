import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/client_form_entity.dart';
import '../../domain/entities/sale_entity.dart';
import '../components/components.dart';
import '../providers/clients_provider.dart';

/// Lo que se va llenando en el formulario de cliente.
class _ClientDraft {
  final tipo = ValueNotifier<String>('p');
  final dni = TextEditingController();
  final name = TextEditingController();
  final lastName = TextEditingController();
  final razonSocial = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final calle = TextEditingController();
  final direccion = TextEditingController();
  final department = ValueNotifier<String?>(null);
  final province = ValueNotifier<String?>(null);
  final district = ValueNotifier<String?>(null);

  NewClientFormEntity toEntity() => NewClientFormEntity(
        tipo: tipo.value,
        dniRuc: dni.text,
        name: name.text,
        lastName: lastName.text,
        razonSocial: razonSocial.text,
        telefono: phone.text,
        email: email.text,
        departmentId: department.value ?? '',
        provinceId: province.value ?? '',
        districtId: district.value ?? '',
        calle: calle.text,
        direccion: direccion.text,
      );

  void dispose() {
    tipo.dispose();
    for (final c in [dni, name, lastName, razonSocial, phone, email, calle, direccion]) {
      c.dispose();
    }
    department.dispose();
    province.dispose();
    district.dispose();
  }
}

/// Formulario para crear un cliente desde Ventas, con lo que la web exige al crear: tipo,
/// DNI o RUC (con consulta a RENIEC/SUNAT), nombre, teléfono, correo y distrito. Devuelve el
/// cliente creado o `null` si se cerró sin crear.
Future<ClientEntity?> showCreateClientForm(BuildContext context) async {
  final clients = context.read<ClientsProvider>();
  final draft = _ClientDraft();
  final error = ValueNotifier<String?>(null);
  ClientEntity? created;

  await showAppModal(
    context,
    title: 'Crear cliente',
    subtitle: 'Se agrega a tu empresa y queda elegido en la venta',
    icon: Icons.person_add_alt_outlined,
    primaryLabel: 'Crear',
    error: error,
    child: AppDisposer(
      onDispose: [draft.dispose, error.dispose],
      child: _ClientFormBody(draft: draft, error: error),
    ),
    onPrimary: () async {
      error.value = null;
      final result = await clients.create(draft.toEntity());
      if (result.isLeft) {
        // El modal sigue abierto con el mensaje (por ejemplo, "El Cliente ya existe").
        error.value = result.left.message;
        throw StateError(result.left.message);
      }
      created = result.right;
    },
  );

  return created;
}

class _ClientFormBody extends StatefulWidget {
  final _ClientDraft draft;
  final ValueNotifier<String?> error;

  const _ClientFormBody({required this.draft, required this.error});

  @override
  State<_ClientFormBody> createState() => _ClientFormBodyState();
}

class _ClientFormBodyState extends State<_ClientFormBody> {
  List<UbigeoItemEntity> _departments = [];
  List<UbigeoItemEntity> _provinces = [];
  List<UbigeoItemEntity> _districts = [];
  bool _lookingUp = false;

  _ClientDraft get _d => widget.draft;
  ClientsProvider get _clients => context.read<ClientsProvider>();

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final result = await _clients.departments();
    if (!mounted) return;
    if (result.isLeft) {
      widget.error.value = 'No se pudieron cargar los departamentos: ${result.left.message}';
      return;
    }
    setState(() => _departments = result.right);
  }

  Future<void> _pickDepartment(String? id) async {
    _d.department.value = id;
    _d.province.value = null;
    _d.district.value = null;
    setState(() {
      _provinces = [];
      _districts = [];
    });
    if (id == null) return;
    final result = await _clients.provincesOf(id);
    if (!mounted || _d.department.value != id) return;
    if (result.isRight) setState(() => _provinces = result.right);
  }

  Future<void> _pickProvince(String? id) async {
    _d.province.value = id;
    _d.district.value = null;
    setState(() => _districts = []);
    if (id == null) return;
    final result = await _clients.districtsOf(id);
    if (!mounted || _d.province.value != id) return;
    if (result.isRight) setState(() => _districts = result.right);
  }

  Future<void> _lookup() async {
    widget.error.value = null;
    FocusScope.of(context).unfocus();
    setState(() => _lookingUp = true);
    final result = await _clients.lookup(tipo: _d.tipo.value, number: _d.dni.text);
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
      await _applyUbigeo(found);
    } else {
      _d.name.text = found.name ?? '';
      _d.lastName.text = found.lastName ?? '';
    }
  }

  /// Con un RUC, la SUNAT trae el distrito: se eligen los tres niveles de una vez.
  Future<void> _applyUbigeo(DocumentLookupEntity found) async {
    final dep = found.departmentId;
    final prov = found.provinceId;
    final dist = found.districtId;
    if (dep == null || prov == null || dist == null) return;

    final provinces = await _clients.provincesOf(dep);
    final districts = await _clients.districtsOf(prov);
    if (!mounted || provinces.isLeft || districts.isLeft) return;
    setState(() {
      _provinces = provinces.right;
      _districts = districts.right;
    });
    _d.department.value = dep;
    _d.province.value = prov;
    _d.district.value = dist;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([_d.tipo, _d.department, _d.province, _d.district]),
      builder: (context, _) {
        final esEmpresa = _d.tipo.value == 'e';

        Widget ubigeo(
          String label,
          List<UbigeoItemEntity> items,
          ValueNotifier<String?> value,
          ValueChanged<String?> onChanged,
        ) {
          // Solo se ofrece el valor elegido si está en la lista (evita un valor sin opción).
          final selected = items.any((i) => i.id == value.value) ? value.value : null;
          return AppDropdownField<String>(
            key: ValueKey('$label-$selected-${items.length}'),
            label: label,
            value: selected,
            items: [
              for (final i in items)
                DropdownMenuItem(value: i.id, child: Text(i.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: items.isEmpty ? null : onChanged,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              selected: {_d.tipo.value},
              onSelectionChanged: (s) {
                _d.tipo.value = s.first;
                _d.dni.clear();
              },
              segments: const [
                ButtonSegment(value: 'p', icon: Icon(Icons.person_outline), label: Text('Persona')),
                ButtonSegment(value: 'e', icon: Icon(Icons.business_outlined), label: Text('Empresa')),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            if (esEmpresa) ...[
              AppTextField(
                controller: _d.razonSocial,
                label: 'Razón social',
                prefixIcon: Icons.business_outlined,
              ),
              const SizedBox(height: 16),
            ],
            AppTextField(
              controller: _d.name,
              label: esEmpresa ? 'Nombre del contacto' : 'Nombre',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _d.lastName,
              label: esEmpresa ? 'Apellido del contacto (opcional)' : 'Apellidos (opcional)',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _d.phone,
              label: 'Teléfono',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _d.email,
              label: 'Correo',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const AppSectionTitle('Dirección'),
            ubigeo('Departamento', _departments, _d.department, _pickDepartment),
            const SizedBox(height: 16),
            ubigeo('Provincia', _provinces, _d.province, _pickProvince),
            const SizedBox(height: 16),
            ubigeo('Distrito', _districts, _d.district, (v) => _d.district.value = v),
            const SizedBox(height: 16),
            AppTextField(
              controller: _d.calle,
              label: 'Urbanización, calle, etc. (opcional)',
              prefixIcon: Icons.add_road_outlined,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _d.direccion,
              label: 'Dirección (opcional)',
              prefixIcon: Icons.home_outlined,
            ),
          ],
        );
      },
    );
  }
}
