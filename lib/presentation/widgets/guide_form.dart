import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/client_form_entity.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/guide_form_entity.dart';
import '../../domain/entities/other_document_entity.dart';
import '../components/components.dart';
import '../pages/other_document_pdf_page.dart';
import '../providers/auth_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/guide_provider.dart';
import '../utils/guide_preview.dart';

final _dateFormat = DateFormat(AppConstants.dateFormat);

/// Departamento, provincia y distrito elegidos, con las listas de cada nivel.
class _Ubigeo extends ChangeNotifier {
  final ClientsProvider clients;

  String? department;
  String? province;
  String? district;
  List<UbigeoItemEntity> provinces = [];
  List<UbigeoItemEntity> districts = [];
  bool _disposed = false;

  _Ubigeo(this.clients);

  Future<void> pickDepartment(String? id) async {
    department = id;
    province = null;
    district = null;
    provinces = [];
    districts = [];
    notifyListeners();
    if (id == null) return;
    final result = await clients.provincesOf(id);
    if (_disposed || department != id) return;
    if (result.isRight) {
      provinces = result.right;
      notifyListeners();
    }
  }

  Future<void> pickProvince(String? id) async {
    province = id;
    district = null;
    districts = [];
    notifyListeners();
    if (id == null) return;
    final result = await clients.districtsOf(id);
    if (_disposed || province != id) return;
    if (result.isRight) {
      districts = result.right;
      notifyListeners();
    }
  }

  void pickDistrict(String? id) {
    district = id;
    notifyListeners();
  }

  /// Elige los tres niveles de una vez (la dirección del cliente, o el distrito que trae la SUNAT).
  Future<void> apply(String dep, String prov, String dist) async {
    final p = await clients.provincesOf(dep);
    final d = await clients.districtsOf(prov);
    if (_disposed || p.isLeft || d.isLeft) return;
    provinces = p.right;
    districts = d.right;
    department = dep;
    province = prov;
    district = dist;
    notifyListeners();
  }

  /// `Distrito, Provincia, Departamento` con lo elegido hasta ahora (`null` si no se eligió nada).
  String? label(List<UbigeoItemEntity> departments) {
    String? nameOf(List<UbigeoItemEntity> items, String? id) {
      for (final i in items) {
        if (i.id == id) return i.name;
      }
      return null;
    }

    final parts = [
      nameOf(districts, district),
      nameOf(provinces, province),
      nameOf(departments, department),
    ].whereType<String>();
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Lo que se va llenando en el formulario de la guía.
class _GuideDraft {
  final DateTime today;
  final tipo = ValueNotifier<GuideKind>(GuideKind.privada);
  final motivo = ValueNotifier<String>('01');
  late final ValueNotifier<DateTime> emision = ValueNotifier(today);
  late final ValueNotifier<DateTime> traslado = ValueNotifier(today);
  final peso = TextEditingController();
  final doc = TextEditingController();
  final razon = TextEditingController();
  final matricula = TextEditingController();
  final dniChofer = TextEditingController();
  final placa = TextEditingController();
  final nombre = TextEditingController();
  final apellido = TextEditingController();
  final licencia = TextEditingController();
  final dirSalida = TextEditingController();
  final dirLlegada = TextEditingController();
  final observaciones = TextEditingController();
  final _Ubigeo salida;
  final _Ubigeo llegada;

  /// Los datos de la venta y los catálogos ya cargaron y la venta no tiene guía: se puede crear.
  final ready = ValueNotifier<bool>(false);

  _GuideDraft(ClientsProvider clients, {required this.today, String? companyRuc})
      : salida = _Ubigeo(clients),
        llegada = _Ubigeo(clients) {
    // Una guía privada la transporta la propia empresa: su RUC va por defecto, como en la web.
    doc.text = companyRuc ?? '';
  }

  GuideFormEntity toEntity(DocumentEntity d) {
    final boletaId = d.boleta?.id;
    return GuideFormEntity(
      boletaId: boletaId,
      saleId: boletaId == null ? d.id : null,
      tipo: tipo.value,
      codTraslado: motivo.value,
      fechaEmision: emision.value,
      fechaTraslado: traslado.value,
      pesoTotal: double.tryParse(peso.text.trim().replaceAll(',', '.')),
      docTransportista: doc.text,
      razonSocialTransportista: razon.text,
      matricula: matricula.text,
      dniChofer: dniChofer.text,
      placaChofer: placa.text,
      nombreChofer: nombre.text,
      apellidoChofer: apellido.text,
      licenciaChofer: licencia.text,
      ubigeoSalida: salida.district ?? '',
      direccionSalida: dirSalida.text,
      ubigeoLlegada: llegada.district ?? '',
      direccionLlegada: dirLlegada.text,
      observaciones: observaciones.text,
    );
  }

  void dispose() {
    for (final n in [tipo, motivo, emision, traslado, ready]) {
      n.dispose();
    }
    for (final c in [
      peso, doc, razon, matricula, dniChofer, placa, nombre, apellido, licencia, //
      dirSalida, dirLlegada, observaciones,
    ]) {
      c.dispose();
    }
    salida.dispose();
    llegada.dispose();
  }
}

/// Formulario "Guía de remisión" de una venta (con los mismos campos que la web): tipo de guía,
/// motivo, fechas, peso, transportista y chofer, y el ubigeo y la dirección de salida y de
/// llegada (que ya viene con la del cliente). Con boleta o factura se emite ante la SUNAT; sin
/// comprobante electrónico es una guía local. Devuelve la guía creada o `null` si se cerró sin crear.
Future<OtherDocumentEntity?> showGuideForm(
  BuildContext context, {
  required DocumentEntity document,
  DateTime Function() now = DateTime.now,

  /// Solo para pruebas: arma la pantalla de la vista previa (por defecto, el visor de PDF).
  Widget Function(OtherDocumentEntity preview)? previewPageBuilder,
}) async {
  final guide = context.read<GuideProvider>();
  final clients = context.read<ClientsProvider>();
  final today = DateUtils.dateOnly(now());
  final draft = _GuideDraft(clients, today: today, companyRuc: guide.companyRuc);
  final error = ValueNotifier<String?>(null);
  final formKey = GlobalKey<FormState>();
  OtherDocumentEntity? created;

  await showAppModal(
    context,
    title: 'Guía de remisión',
    subtitle: '${document.comprobante} Nro: ${document.numero}',
    icon: Icons.local_shipping_outlined,
    primaryLabel: 'Crear',
    formKey: formKey,
    primaryEnabled: draft.ready,
    error: error,
    onPrimary: () async {
      error.value = null;
      final result = await guide.create(draft.toEntity(document));
      if (result.isLeft) {
        error.value = result.left.message;
        // Mantiene el modal abierto para corregir o reintentar.
        throw StateError('guía no creada');
      }
      created = result.right;
    },
    child: AppDisposer(
      onDispose: [draft.dispose, error.dispose],
      child: _GuideBody(
        document: document,
        draft: draft,
        error: error,
        now: now,
        previewPageBuilder: previewPageBuilder,
      ),
    ),
  );
  return created;
}

class _GuideBody extends StatefulWidget {
  final DocumentEntity document;
  final _GuideDraft draft;
  final ValueNotifier<String?> error;
  final DateTime Function() now;
  final Widget Function(OtherDocumentEntity preview)? previewPageBuilder;

  const _GuideBody({
    required this.document,
    required this.draft,
    required this.error,
    required this.now,
    this.previewPageBuilder,
  });

  @override
  State<_GuideBody> createState() => _GuideBodyState();
}

class _GuideBodyState extends State<_GuideBody> {
  List<UbigeoItemEntity> _departments = [];
  bool _loading = true;
  bool _hasGuide = false;
  bool _lookingUp = false;

  _GuideDraft get _d => widget.draft;
  ClientsProvider get _clients => context.read<ClientsProvider>();
  GuideProvider get _guide => context.read<GuideProvider>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _clients.departments(),
      _guide.loadDefaults(widget.document.id),
    ]);
    if (!mounted) return;
    final departments = results[0];
    final defaults = results[1];

    if (departments.isLeft) {
      widget.error.value = 'No se pudieron cargar los departamentos: ${departments.left.message}';
    } else {
      _departments = departments.right as List<UbigeoItemEntity>;
    }

    if (defaults.isLeft) {
      widget.error.value = 'No se pudo revisar la venta: ${defaults.left.message}';
    } else {
      final d = defaults.right as GuideDefaultsEntity;
      if (d.tieneGuia) {
        _hasGuide = true;
      } else {
        // La llegada es la dirección del cliente.
        _d.dirLlegada.text = d.direccion ?? '';
        if (d.tieneUbigeo) await _d.llegada.apply(d.departmentId!, d.provinceId!, d.districtId!);
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _d.ready.value = !_hasGuide && !departments.isLeft && !defaults.isLeft;
  }

  /// Busca al transportista por su DNI o RUC y trae su razón social (y, con RUC, su dirección).
  Future<void> _lookupTransport() async {
    widget.error.value = null;
    FocusScope.of(context).unfocus();
    final number = _d.doc.text.trim();
    if (number.length != 8 && number.length != 11) {
      widget.error.value = 'El DNI debe tener 8 dígitos y el RUC 11';
      return;
    }
    setState(() => _lookingUp = true);
    final result = await _clients.lookup(tipo: number.length == 8 ? 'p' : 'e', number: number);
    if (!mounted) return;
    setState(() => _lookingUp = false);

    if (result.isLeft) {
      widget.error.value = result.left.message;
      return;
    }
    final found = result.right;
    if (found.esEmpresa) {
      _d.razon.text = found.razonSocial ?? '';
      _d.dirSalida.text = found.direccion ?? '';
      if (found.departmentId != null && found.provinceId != null && found.districtId != null) {
        await _d.salida.apply(found.departmentId!, found.provinceId!, found.districtId!);
      }
    } else {
      _d.razon.text = [found.name, found.lastName].whereType<String>().join(' ');
    }
  }

  /// Un chofer ya registrado trae su nombre, apellido y licencia al escribir su DNI.
  Future<void> _onDriverDni(String value) async {
    final dni = value.replaceAll('-', '');
    if (dni.length != 8) return;
    final driver = await _guide.findDriver(dni);
    if (!mounted || driver == null) return;
    _d.nombre.text = driver.name;
    _d.apellido.text = driver.lastName;
    _d.licencia.text = driver.license;
  }

  Future<void> _pickDate(ValueNotifier<DateTime> target, {required DateTime last, required String help}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: target.value,
      firstDate: DateTime(2020),
      lastDate: last,
      helpText: help,
    );
    if (picked != null) target.value = picked;
  }

  /// Muestra el PDF de la guía con lo escrito hasta ahora, sin crear nada ni gastar el número.
  /// Como en la web, no valida: se puede previsualizar con el formulario a medias.
  Future<void> _preview() async {
    FocusScope.of(context).unfocus();
    final company = context.read<AuthProvider>().session?.company;
    if (company == null) return;
    final document = buildGuidePreview(
      form: _d.toEntity(widget.document),
      sale: widget.document,
      company: company,
      ubigeoSalida: _d.salida.label(_departments),
      ubigeoLlegada: _d.llegada.label(_departments),
      now: widget.now(),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            widget.previewPageBuilder?.call(document) ??
            OtherDocumentPdfPage(document: document, preview: true),
      ),
    );
  }

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = _d.today;

    if (_loading) {
      return const AppSkeletonForm(fields: 5);
    }
    if (_hasGuide) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: ErrorBanner(message: 'Este documento ya tiene una guía de remisión.'),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([_d.tipo, _d.motivo, _d.emision, _d.traslado]),
      builder: (context, _) {
        final public = _d.tipo.value == GuideKind.publica;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _preview,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Previsualizar'),
              ),
            ),
            const SizedBox(height: 12),
            AppDropdownField<GuideKind>(
              label: 'Tipo de guía *',
              value: _d.tipo.value,
              items: [
                for (final k in GuideKind.values) DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (k) {
                if (k == null) return;
                _d.tipo.value = k;
                // Una guía privada la transporta la propia empresa.
                if (k == GuideKind.privada && _d.doc.text.trim().isEmpty) {
                  _d.doc.text = _guide.companyRuc ?? '';
                }
              },
            ),
            const SizedBox(height: 16),
            AppDropdownField<String>(
              label: 'Motivo de traslado *',
              value: _d.motivo.value,
              items: [
                for (final e in guideTransferReasons.entries)
                  DropdownMenuItem(value: e.key, child: Text('${e.key} - ${e.value}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => _d.motivo.value = v ?? '01',
            ),
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Fecha de emisión',
              value: _dateFormat.format(_d.emision.value),
              icon: Icons.event_outlined,
              onTap: () => _pickDate(_d.emision, last: today, help: 'Fecha de emisión'),
            ),
            const SizedBox(height: 16),
            AppPickerField(
              label: 'Fecha de traslado',
              value: _dateFormat.format(_d.traslado.value),
              icon: Icons.event_outlined,
              onTap: () => _pickDate(
                _d.traslado,
                last: today.add(const Duration(days: 365)),
                help: 'Fecha de traslado',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _d.peso,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(
                labelText: 'Peso total (KG) *',
                prefixIcon: Icon(Icons.scale_outlined),
              ),
              validator: (v) {
                final peso = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                return peso == null || peso <= 0 ? 'Escribe el peso total' : null;
              },
            ),
            const AppSectionTitle('Transportista'),
            TextFormField(
              controller: _d.doc,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              onFieldSubmitted: (_) => _lookupTransport(),
              decoration: InputDecoration(
                labelText: 'DNI / RUC *',
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: _lookingUp
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        tooltip: 'Buscar transportista',
                        icon: const Icon(Icons.search),
                        onPressed: _lookupTransport,
                      ),
              ),
              validator: (v) => _required(v, 'Escribe el DNI o RUC del transportista'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _d.razon,
              label: 'Razón social *',
              prefixIcon: Icons.person_outline,
              validator: (v) => _required(v, 'Escribe la razón social'),
            ),
            if (public) ...[
              const SizedBox(height: 16),
              AppTextField(
                controller: _d.matricula,
                label: 'Registro MTC *',
                prefixIcon: Icons.badge_outlined,
                validator: (v) => _required(v, 'Escribe el registro MTC'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _d.dniChofer,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                onChanged: _onDriverDni,
                decoration: const InputDecoration(
                  labelText: 'DNI del chofer *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => _required(v, 'Escribe el DNI del chofer'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _d.placa,
                label: 'Placa del vehículo *',
                prefixIcon: Icons.directions_car_outlined,
                validator: (v) => _required(v, 'Escribe la placa'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _d.nombre,
                label: 'Nombre(s) del chofer *',
                prefixIcon: Icons.person_outline,
                validator: (v) => _required(v, 'Escribe el nombre del chofer'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _d.apellido,
                label: 'Apellido(s) del chofer *',
                prefixIcon: Icons.person_outline,
                validator: (v) => _required(v, 'Escribe el apellido del chofer'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _d.licencia,
                label: 'Licencia de conducir *',
                prefixIcon: Icons.credit_card_outlined,
                validator: (v) => _required(v, 'Escribe la licencia de conducir'),
              ),
            ],
            const AppSectionTitle('Ubigeo de salida'),
            _UbigeoFields(selection: _d.salida, departments: _departments),
            const SizedBox(height: 16),
            AppTextField(
              controller: _d.dirSalida,
              label: 'Dirección de salida *',
              prefixIcon: Icons.place_outlined,
              validator: (v) => _required(v, 'Escribe la dirección de salida'),
            ),
            const AppSectionTitle('Ubigeo de llegada'),
            _UbigeoFields(selection: _d.llegada, departments: _departments),
            const SizedBox(height: 16),
            AppTextField(
              controller: _d.dirLlegada,
              label: 'Dirección de llegada *',
              prefixIcon: Icons.place_outlined,
              validator: (v) => _required(v, 'Escribe la dirección de llegada'),
            ),
            const AppSectionTitle('Observaciones'),
            TextFormField(
              controller: _d.observaciones,
              maxLines: 3,
              maxLength: 500,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'Información adicional importante (opcional)',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Los tres desplegables de un ubigeo: departamento, provincia y distrito.
class _UbigeoFields extends StatelessWidget {
  final _Ubigeo selection;
  final List<UbigeoItemEntity> departments;

  const _UbigeoFields({required this.selection, required this.departments});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        Widget field(
          String label,
          List<UbigeoItemEntity> items,
          String? value,
          ValueChanged<String?> onChanged,
        ) {
          // Solo se ofrece el valor elegido si está en la lista (evita un valor sin opción).
          final selected = items.any((i) => i.id == value) ? value : null;
          return AppDropdownField<String>(
            key: ValueKey('$label-$selected-${items.length}'),
            label: '$label *',
            value: selected,
            items: [
              for (final i in items)
                DropdownMenuItem(value: i.id, child: Text(i.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: items.isEmpty ? null : onChanged,
            validator: (v) => v == null ? 'Elige el ${label.toLowerCase()}' : null,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field('Departamento', departments, selection.department, selection.pickDepartment),
            const SizedBox(height: 16),
            field('Provincia', selection.provinces, selection.province, selection.pickProvince),
            const SizedBox(height: 16),
            field('Distrito', selection.districts, selection.district, selection.pickDistrict),
          ],
        );
      },
    );
  }
}
